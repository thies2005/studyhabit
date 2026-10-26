package de.schuelken.studyhabit.core.service

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import de.schuelken.studyhabit.core.database.AppDatabase
import de.schuelken.studyhabit.core.preferences.AppPreferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
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

    private val syncMutex = Mutex()

    fun bindSyncFolder(uri: Uri) {
        try {
            val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            context.contentResolver.takePersistableUriPermission(uri, takeFlags)
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

                        // Backup previous content to studyhabit_sync.bak.json
                        try {
                            val bakFile = rootFolder.findFile(BAK_FILE_NAME)
                                ?: rootFolder.createFile("application/json", BAK_FILE_NAME)
                            if (bakFile != null) {
                                (context.contentResolver.openOutputStream(bakFile.uri, "wt")
                                    ?: context.contentResolver.openOutputStream(bakFile.uri))?.use { os ->
                                    os.write(existingJson.toByteArray(Charsets.UTF_8))
                                }
                            }
                        } catch (backupEx: Exception) {
                            Log.w(TAG, "Failed to create backup $BAK_FILE_NAME", backupEx)
                        }

                        // Parse and perform bidirectional LWW merge
                        val remoteDoc = exportImportService.json.decodeFromString<ExportDocument>(existingJson)
                        val counts = performLwwMerge(remoteDoc)
                        pushedCount = counts.first
                        pulledCount = counts.second

                        // Build merged document and write back to studyhabit_sync.json
                        val mergedDoc = exportImportService.buildExportDocument(includeDeleted = true)
                        val mergedJson = exportImportService.json.encodeToString(mergedDoc)
                        (context.contentResolver.openOutputStream(syncFile.uri, "wt")
                            ?: context.contentResolver.openOutputStream(syncFile.uri))?.use { os ->
                            os.write(mergedJson.toByteArray(Charsets.UTF_8))
                        } ?: throw IOException("Could not write to $SYNC_FILE_NAME")
                    } else {
                        // No existing sync file - push entire local database
                        val initialDoc = exportImportService.buildExportDocument(includeDeleted = true)
                        val initialJson = exportImportService.json.encodeToString(initialDoc)

                        val targetFile = syncFile ?: rootFolder.createFile("application/json", SYNC_FILE_NAME)
                            ?: throw IOException("Could not create $SYNC_FILE_NAME in synced folder")

                        (context.contentResolver.openOutputStream(targetFile.uri, "wt")
                            ?: context.contentResolver.openOutputStream(targetFile.uri))?.use { os ->
                            os.write(initialJson.toByteArray(Charsets.UTF_8))
                        } ?: throw IOException("Could not write initial $SYNC_FILE_NAME")

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
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "syncWithFolder failed", e)
                    preferences.setFolderLastSummary("Folder sync failed: ${e.message}")
                    false
                }
            }
        }
    }

    suspend fun saveToDocumentUri(uri: Uri): Boolean {
        return syncMutex.withLock {
            withContext(Dispatchers.IO) {
                try {
                    val exportDoc = exportImportService.buildExportDocument(includeDeleted = true)
                    val jsonString = exportImportService.json.encodeToString(exportDoc)
                    (context.contentResolver.openOutputStream(uri, "wt")
                        ?: context.contentResolver.openOutputStream(uri))?.use { os ->
                        os.write(jsonString.toByteArray(Charsets.UTF_8))
                    } ?: throw IOException("Could not open output stream for URI: $uri")
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "saveToDocumentUri failed", e)
                    false
                }
            }
        }
    }

    suspend fun mergeFromDocumentUri(uri: Uri): Boolean {
        return syncMutex.withLock {
            withContext(Dispatchers.IO) {
                try {
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
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "mergeFromDocumentUri failed", e)
                    preferences.setFolderLastSummary("Folder sync failed: ${e.message}")
                    false
                }
            }
        }
    }

    suspend fun syncWithSingleFileUri(uri: Uri): Boolean {
        return syncMutex.withLock {
            withContext(Dispatchers.IO) {
                try {
                    val jsonString = context.contentResolver.openInputStream(uri)?.use { inputStream ->
                        inputStream.bufferedReader(Charsets.UTF_8).readText()
                    } ?: throw IOException("Could not open input stream for URI: $uri")

                    val remoteDoc = exportImportService.json.decodeFromString<ExportDocument>(jsonString)
                    val (pushedCount, pulledCount) = performLwwMerge(remoteDoc)

                    val mergedDoc = exportImportService.buildExportDocument(includeDeleted = true)
                    val mergedJson = exportImportService.json.encodeToString(mergedDoc)
                    (context.contentResolver.openOutputStream(uri, "wt")
                        ?: context.contentResolver.openOutputStream(uri))?.use { os ->
                        os.write(mergedJson.toByteArray(Charsets.UTF_8))
                    } ?: throw IOException("Could not write merged JSON to URI: $uri")

                    preferences.setFolderLastSyncedAt(System.currentTimeMillis())
                    val summary = if (pushedCount == 0 && pulledCount == 0) {
                        "✓ Already up to date with synced folder"
                    } else {
                        "Synced with folder: ↑ $pushedCount pushed • ↓ $pulledCount pulled"
                    }
                    preferences.setFolderLastSummary(summary)
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "syncWithSingleFileUri failed", e)
                    preferences.setFolderLastSummary("Folder sync failed: ${e.message}")
                    false
                }
            }
        }
    }

    private suspend fun performLwwMerge(remoteDoc: ExportDocument): Pair<Int, Int> {
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

        // 10. User Stats
        val remoteStats = remoteDoc.userStats
        val localStats = database.userStatsDao().getUserStats()
        if (localStats == null || remoteStats.updatedAt > localStats.updatedAt) {
            database.userStatsDao().upsert(remoteStats)
            pulledCount++
        } else if (localStats.updatedAt > remoteStats.updatedAt) {
            pushedCount++
        }

        // 11. Settings
        remoteDoc.settings?.let { settings ->
            preferences.applySettingsMap(settings)
        }

        return Pair(pushedCount, pulledCount)
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
