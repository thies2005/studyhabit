package de.schuelken.studyhabit.core.service

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import androidx.room.withTransaction
import de.schuelken.studyhabit.core.database.AppDatabase
import de.schuelken.studyhabit.core.model.SyncStatus
import de.schuelken.studyhabit.core.preferences.AppPreferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import java.io.IOException

class FolderSyncService(
    private val context: Context,
    private val database: AppDatabase,
    private val preferences: AppPreferences,
    private val exportImportService: ExportImportService,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
) {
    companion object {
        private const val TAG = "FolderSyncService"
        const val SYNC_FILE_NAME = "studyhabit_sync.json"
        const val BAK_FILE_NAME = "studyhabit_sync.bak.json"
    }

    private val _syncStatus = MutableStateFlow(SyncStatus.IDLE)
    val syncStatus: StateFlow<SyncStatus> = _syncStatus.asStateFlow()

    private val syncMutex = Mutex()
    private var debounceJob: Job? = null

    fun scheduleDebouncedSync(delayMs: Long = 3_000L) {
        if (!preferences.folderSyncEnabled.value || preferences.folderSyncUri.value.isNullOrBlank()) return
        debounceJob?.cancel()
        debounceJob = scope.launch {
            delay(delayMs)
            syncWithFolder()
        }
    }

    fun bindSyncFolder(uri: Uri) {
        try {
            val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            context.contentResolver.takePersistableUriPermission(uri, takeFlags)
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to take persistable URI permission for $uri", e)
            preferences.setFolderLastSummary("Folder permission error: ${e.localizedMessage}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to take persistable URI permission for $uri", e)
        }
        preferences.setFolderSyncUri(uri.toString())
        preferences.setFolderSyncEnabled(true)
        scope.launch {
            syncWithFolder()
        }
    }

    suspend fun syncWithFolder(): Boolean {
        if (!preferences.folderSyncEnabled.value) {
            return false
        }
        val treeUriStr = preferences.folderSyncUri.value
        if (treeUriStr.isNullOrBlank()) {
            return false
        }

        return syncMutex.withLock {
            withContext(Dispatchers.IO) {
                _syncStatus.value = SyncStatus.SYNCING
                try {
                    val treeUri = Uri.parse(treeUriStr)
                    val rootFolder = DocumentFile.fromTreeUri(context, treeUri)
                    if (rootFolder == null || !rootFolder.exists() || !rootFolder.canWrite()) {
                        throw IOException("Cannot access or write to selected sync folder")
                    }

                    val syncFile = rootFolder.findFile(SYNC_FILE_NAME)
                    var pushedCount = 0
                    var pulledCount = 0

                    if (syncFile != null && syncFile.exists() && syncFile.length() > 0) {
                        // Read existing file
                        val existingJson = context.contentResolver.openInputStream(syncFile.uri)?.use { inputStream ->
                            inputStream.bufferedReader(Charsets.UTF_8).readText()
                        } ?: throw IOException("Could not read from $SYNC_FILE_NAME")

                        val remoteDoc = try {
                            val parsed = exportImportService.json.decodeFromString<ExportDocument>(existingJson)
                            // Backup previous content to studyhabit_sync.bak.json ONLY after successful decode
                            try {
                                val bakFile = rootFolder.findFile(BAK_FILE_NAME)
                                    ?: rootFolder.createFile("application/json", BAK_FILE_NAME)
                                if (bakFile != null) {
                                    writeJsonSafely(bakFile.uri, existingJson)
                                }
                            } catch (backupEx: Exception) {
                                Log.w(TAG, "Failed to create backup $BAK_FILE_NAME", backupEx)
                            }
                            parsed
                        } catch (decodeEx: Exception) {
                            Log.w(TAG, "Failed to parse $SYNC_FILE_NAME, attempting fallback recovery from $BAK_FILE_NAME", decodeEx)
                            val bakFile = rootFolder.findFile(BAK_FILE_NAME)
                            if (bakFile != null && bakFile.exists() && bakFile.length() > 0) {
                                val bakJson = context.contentResolver.openInputStream(bakFile.uri)?.use { inputStream ->
                                    inputStream.bufferedReader(Charsets.UTF_8).readText()
                                } ?: throw decodeEx
                                exportImportService.json.decodeFromString<ExportDocument>(bakJson)
                            } else {
                                throw decodeEx
                            }
                        }

                        // Parse and perform bidirectional LWW merge
                        val counts = performLwwMerge(remoteDoc)
                        pushedCount = counts.first
                        pulledCount = counts.second

                        // Build merged document and write back to studyhabit_sync.json
                        val mergedDoc = exportImportService.buildExportDocument(includeDeleted = true)
                        val mergedJson = exportImportService.json.encodeToString(mergedDoc)
                        writeJsonSafely(syncFile.uri, mergedJson)
                    } else {
                        // No existing sync file - push entire local database
                        val initialDoc = exportImportService.buildExportDocument(includeDeleted = true)
                        val initialJson = exportImportService.json.encodeToString(initialDoc)

                        val targetFile = syncFile ?: rootFolder.createFile("application/json", SYNC_FILE_NAME)
                            ?: throw IOException("Could not create $SYNC_FILE_NAME in synced folder")

                        writeJsonSafely(targetFile.uri, initialJson)

                        pushedCount = countExportDocumentEntities(initialDoc)
                        pulledCount = 0
                    }

                    val now = System.currentTimeMillis()
                    preferences.setFolderLastSyncedAt(now)
                    val summary = if (pushedCount == 0 && pulledCount == 0) {
                        "✓ Already up to date with synced folder"
                    } else {
                        "Synced with folder: ↑ $pushedCount pushed • ↓ $pulledCount pulled"
                    }
                    preferences.setFolderLastSummary(summary)
                    _syncStatus.value = SyncStatus.SYNCED
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "syncWithFolder failed", e)
                    preferences.setFolderLastSummary("Folder sync failed: ${e.message}")
                    _syncStatus.value = SyncStatus.ERROR
                    false
                }
            }
        }
    }

    suspend fun saveToDocumentUri(uri: Uri): Boolean {
        return syncMutex.withLock {
            withContext(Dispatchers.IO) {
                try {
                    _syncStatus.value = SyncStatus.SYNCING
                    val exportDoc = exportImportService.buildExportDocument(includeDeleted = true)
                    val jsonString = exportImportService.json.encodeToString(exportDoc)
                    writeJsonSafely(uri, jsonString)
                    preferences.setFolderLastSyncedAt(System.currentTimeMillis())
                    preferences.setFolderLastSummary("Saved sync file successfully")
                    _syncStatus.value = SyncStatus.SYNCED
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "saveToDocumentUri failed", e)
                    _syncStatus.value = SyncStatus.ERROR
                    false
                }
            }
        }
    }

    suspend fun mergeFromDocumentUri(uri: Uri): Boolean {
        return syncMutex.withLock {
            withContext(Dispatchers.IO) {
                try {
                    _syncStatus.value = SyncStatus.SYNCING
                    val jsonString = context.contentResolver.openInputStream(uri)?.use { inputStream ->
                        inputStream.bufferedReader(Charsets.UTF_8).readText()
                    } ?: throw IOException("Could not open input stream for URI: $uri")

                    val remoteDoc = exportImportService.json.decodeFromString<ExportDocument>(jsonString)
                    val (pushedCount, pulledCount) = performLwwMerge(remoteDoc)

                    preferences.setFolderLastSyncedAt(System.currentTimeMillis())
                    val summary = if (pushedCount == 0 && pulledCount == 0) {
                        "✓ Already up to date with synced folder"
                    } else {
                        "Synced with folder: ↑ $pushedCount pushed • ↓ $pulledCount pulled"
                    }
                    preferences.setFolderLastSummary(summary)
                    _syncStatus.value = SyncStatus.SYNCED
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "mergeFromDocumentUri failed", e)
                    preferences.setFolderLastSummary("Folder sync failed: ${e.message}")
                    _syncStatus.value = SyncStatus.ERROR
                    false
                }
            }
        }
    }

    suspend fun syncWithSingleFileUri(uri: Uri): Boolean {
        return syncMutex.withLock {
            withContext(Dispatchers.IO) {
                try {
                    _syncStatus.value = SyncStatus.SYNCING
                    val jsonString = context.contentResolver.openInputStream(uri)?.use { inputStream ->
                        inputStream.bufferedReader(Charsets.UTF_8).readText()
                    } ?: throw IOException("Could not open input stream for URI: $uri")

                    val remoteDoc = exportImportService.json.decodeFromString<ExportDocument>(jsonString)
                    val (pushedCount, pulledCount) = performLwwMerge(remoteDoc)

                    val mergedDoc = exportImportService.buildExportDocument(includeDeleted = true)
                    val mergedJson = exportImportService.json.encodeToString(mergedDoc)
                    writeJsonSafely(uri, mergedJson)

                    preferences.setFolderLastSyncedAt(System.currentTimeMillis())
                    val summary = if (pushedCount == 0 && pulledCount == 0) {
                        "✓ Already up to date with synced folder"
                    } else {
                        "Synced with folder: ↑ $pushedCount pushed • ↓ $pulledCount pulled"
                    }
                    preferences.setFolderLastSummary(summary)
                    _syncStatus.value = SyncStatus.SYNCED
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "syncWithSingleFileUri failed", e)
                    preferences.setFolderLastSummary("Folder sync failed: ${e.message}")
                    _syncStatus.value = SyncStatus.ERROR
                    false
                }
            }
        }
    }

    private fun writeJsonSafely(uri: Uri, jsonContent: String) {
        val bytes = jsonContent.toByteArray(Charsets.UTF_8)
        val pfd = runCatching { context.contentResolver.openFileDescriptor(uri, "rw") }.getOrNull()
        if (pfd != null) {
            pfd.use { descriptor ->
                java.io.FileOutputStream(descriptor.fileDescriptor).use { fos ->
                    fos.channel.truncate(0L)
                    fos.write(bytes)
                    fos.flush()
                    runCatching { descriptor.fileDescriptor.sync() }
                }
            }
            return
        }
        (context.contentResolver.openOutputStream(uri, "wt")
            ?: context.contentResolver.openOutputStream(uri))?.use { os ->
            os.write(bytes)
            os.flush()
        } ?: throw IOException("Could not write to $uri")
    }

    private suspend fun performLwwMerge(remoteDoc: ExportDocument): Pair<Int, Int> = database.withTransaction {
        var pushedCount = 0
        var pulledCount = 0

        // 1. Projects
        val remoteProjects = remoteDoc.projects.map { it.project }
        val (pushedProj, pulledProj) = mergeEntities(
            remoteList = remoteProjects,
            localMap = database.projectDao().getModifiedSince(-1L).associateBy { it.id },
            getId = { it.id },
            getUpdatedAt = { it.updatedAt },
            upsert = { database.projectDao().upsert(it) }
        )
        pushedCount += pushedProj
        pulledCount += pulledProj

        // 2. Subjects
        val remoteSubjects = remoteDoc.projects.flatMap { it.subjects.map { s -> s.subject } }
        val (pushedSubj, pulledSubj) = mergeEntities(
            remoteList = remoteSubjects,
            localMap = database.subjectDao().getModifiedSince(-1L).associateBy { it.id },
            getId = { it.id },
            getUpdatedAt = { it.updatedAt },
            upsert = { database.subjectDao().upsert(it) }
        )
        pushedCount += pushedSubj
        pulledCount += pulledSubj

        // 3. Topics
        val remoteTopics = remoteDoc.projects.flatMap { it.subjects.flatMap { s -> s.topics } }
        val (pushedTopics, pulledTopics) = mergeEntities(
            remoteList = remoteTopics,
            localMap = database.topicDao().getModifiedSince(-1L).associateBy { it.id },
            getId = { it.id },
            getUpdatedAt = { it.updatedAt },
            upsert = { database.topicDao().upsert(it) }
        )
        pushedCount += pushedTopics
        pulledCount += pulledTopics

        // 4. Chapters
        val remoteChapters = remoteDoc.projects.flatMap { it.subjects.flatMap { s -> s.chapters } }
        val (pushedChapters, pulledChapters) = mergeEntities(
            remoteList = remoteChapters,
            localMap = database.chapterDao().getModifiedSince(-1L).associateBy { it.id },
            getId = { it.id },
            getUpdatedAt = { it.updatedAt },
            upsert = { database.chapterDao().upsert(it) }
        )
        pushedCount += pushedChapters
        pulledCount += pulledChapters

        // 5. Sessions
        val remoteSessions = remoteDoc.projects.flatMap { it.subjects.flatMap { s -> s.sessions } }
        val (pushedSessions, pulledSessions) = mergeEntities(
            remoteList = remoteSessions,
            localMap = database.sessionDao().getModifiedSince(-1L).associateBy { it.id },
            getId = { it.id },
            getUpdatedAt = { it.updatedAt },
            upsert = { database.sessionDao().upsert(it) }
        )
        pushedCount += pushedSessions
        pulledCount += pulledSessions

        // 6. Sources
        val remoteSources = remoteDoc.projects.flatMap { it.subjects.flatMap { s -> s.sources } }
        val (pushedSources, pulledSources) = mergeEntities(
            remoteList = remoteSources,
            localMap = database.sourceDao().getModifiedSince(-1L).associateBy { it.id },
            getId = { it.id },
            getUpdatedAt = { it.updatedAt },
            upsert = { database.sourceDao().upsert(it) }
        )
        pushedCount += pushedSources
        pulledCount += pulledSources

        // 7. Skill Labels
        val remoteSkillLabels = remoteDoc.projects.flatMap { it.subjects.flatMap { s -> s.skillLabels } }
        val (pushedSkillLabels, pulledSkillLabels) = mergeEntities(
            remoteList = remoteSkillLabels,
            localMap = database.skillLabelDao().getModifiedSince(-1L).associateBy { it.id },
            getId = { it.id },
            getUpdatedAt = { it.updatedAt },
            upsert = { database.skillLabelDao().upsert(it) }
        )
        pushedCount += pushedSkillLabels
        pulledCount += pulledSkillLabels

        // 8. Milestones
        val remoteMilestones = remoteDoc.projects.flatMap { it.subjects.flatMap { s -> s.milestones } }
        val (pushedMilestones, pulledMilestones) = mergeEntities(
            remoteList = remoteMilestones,
            localMap = database.milestoneDao().getModifiedSince(-1L).associateBy { it.id },
            getId = { it.id },
            getUpdatedAt = { it.updatedAt },
            upsert = { database.milestoneDao().upsert(it) }
        )
        pushedCount += pushedMilestones
        pulledCount += pulledMilestones

        // 9. Achievements
        val (pushedAchievements, pulledAchievements) = mergeEntities(
            remoteList = remoteDoc.achievements,
            localMap = database.achievementDao().getAllAchievements().associateBy { it.key },
            getId = { it.key },
            getUpdatedAt = { it.updatedAt },
            upsert = { database.achievementDao().upsert(it) }
        )
        pushedCount += pushedAchievements
        pulledCount += pulledAchievements

        // Reconcile each subject's xpTotal against its non-deleted sessions
        val allSessions = database.sessionDao().getAllSessions()
        val xpBySubject = allSessions.groupBy { it.subjectId }.mapValues { (_, list) -> list.sumOf { it.xpEarned } }
        for (subj in database.subjectDao().getAllSubjects()) {
            val sessionXp = xpBySubject[subj.id] ?: 0
            if (sessionXp > subj.xpTotal) {
                database.subjectDao().upsert(subj.copy(xpTotal = sessionXp, updatedAt = maxOf(subj.updatedAt, System.currentTimeMillis())))
            }
        }

        // Reconcile UserStatsEntity from merged non-deleted sessions and monotonic maxima
        val remoteStats = remoteDoc.userStats
        val localStats = database.userStatsDao().getUserStats()
        val totalSessionMinutes = allSessions.sumOf { it.actualDurationMinutes }
        val totalSessionXp = allSessions.sumOf { it.xpEarned }
        val mergedTotalMinutes = maxOf(localStats?.totalStudyMinutes ?: 0, remoteStats.totalStudyMinutes, totalSessionMinutes)
        val mergedTotalXp = maxOf(localStats?.totalXp ?: 0, remoteStats.totalXp, totalSessionXp)
        val mergedLevel = XpCalculator.calculateLevel(mergedTotalXp)
        val mergedLongestStreak = maxOf(localStats?.longestStreak ?: 0, remoteStats.longestStreak)
        val newerStats = if (localStats == null || remoteStats.updatedAt >= localStats.updatedAt) remoteStats else localStats
        val reconciledStats = newerStats.copy(
            totalXp = mergedTotalXp,
            currentLevel = mergedLevel,
            totalStudyMinutes = mergedTotalMinutes,
            longestStreak = maxOf(mergedLongestStreak, newerStats.currentStreak),
            updatedAt = maxOf(localStats?.updatedAt ?: 0L, remoteStats.updatedAt)
        )
        if (localStats == null || reconciledStats != localStats) {
            database.userStatsDao().upsert(reconciledStats)
            if (localStats == null || remoteStats.updatedAt > localStats.updatedAt) pulledCount++ else pushedCount++
        }

        // Only apply remoteDoc.settings if remoteDoc.settings != null && (remoteDoc.settingsUpdatedAt > preferences.settingsUpdatedAt || preferences.settingsUpdatedAt == 0L)
        if (remoteDoc.settings != null && (remoteDoc.settingsUpdatedAt > preferences.settingsUpdatedAt || preferences.settingsUpdatedAt == 0L)) {
            preferences.applySettingsMap(remoteDoc.settings)
            if (remoteDoc.settingsUpdatedAt > 0L) {
                preferences.settingsUpdatedAt = remoteDoc.settingsUpdatedAt
            }
            pulledCount++
        }

        // Validate activeProjectId so a secondary device automatically selects the synced project if its current activeProjectId is null or missing
        val allProjects = database.projectDao().getAllProjects()
        val currentActive = preferences.activeProjectId.value
        if (currentActive == null || allProjects.none { it.id == currentActive }) {
            preferences.setActiveProjectId(allProjects.firstOrNull()?.id)
        }

        Pair(pushedCount, pulledCount)
    }

    private suspend fun <T> mergeEntities(
        remoteList: List<T>,
        localMap: Map<String, T>,
        getId: (T) -> String,
        getUpdatedAt: (T) -> Long,
        upsert: suspend (T) -> Unit,
    ): Pair<Int, Int> {
        var pulled = 0
        var pushed = 0
        val remoteMap = remoteList.associateBy(getId)

        for (remote in remoteList) {
            val id = getId(remote)
            val local = localMap[id]
            if (local == null || getUpdatedAt(remote) > getUpdatedAt(local)) {
                upsert(remote)
                pulled++
            } else if (getUpdatedAt(local) > getUpdatedAt(remote)) {
                pushed++
            }
        }

        for ((id, _) in localMap) {
            if (!remoteMap.containsKey(id)) {
                pushed++
            }
        }

        return Pair(pushed, pulled)
    }

    private fun countExportDocumentEntities(doc: ExportDocument): Int {
        var count = doc.projects.size
        for (project in doc.projects) {
            count += project.subjects.size
            for (subject in project.subjects) {
                count += subject.topics.size
                count += subject.chapters.size
                count += subject.sessions.size
                count += subject.sources.size
                count += subject.skillLabels.size
                count += subject.milestones.size
            }
        }
        count += doc.achievements.size
        count += 1 // userStats
        return count
    }
}
