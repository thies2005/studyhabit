package de.schuelken.studyhabit.core.service

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.room.withTransaction
import de.schuelken.studyhabit.core.database.AppDatabase
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.model.SyncStatus
import de.schuelken.studyhabit.core.preferences.AppPreferences
import de.schuelken.studyhabit.ui.widget.StudyHabitWidgetProvider
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import java.io.FileNotFoundException
import java.io.IOException
import java.util.UUID

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
        private const val URI_FLAGS = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }

    private val _syncStatus = MutableStateFlow(SyncStatus.IDLE)
    val syncStatus: StateFlow<SyncStatus> = _syncStatus.asStateFlow()
    private val _manualFileSummary = MutableStateFlow<String?>(null)
    val manualFileSummary: StateFlow<String?> = _manualFileSummary.asStateFlow()
    private val syncMutex = Mutex()
    private var debounceJob: Job? = null

    @Synchronized
    fun scheduleDebouncedSync(delayMs: Long = 3_000L) {
        if (selectedFolder() == null) return
        debounceJob?.cancel()
        debounceJob = scope.launch {
            delay(delayMs)
            // A later change can cancel the debounce timer, never an active publication.
            scope.launch { syncWithFolder() }
        }
    }

    suspend fun bindSyncFolder(uri: Uri): Boolean = syncMutex.withLock {
        withContext(Dispatchers.IO) {
            val previous = preferences.folderSyncUri.value
            val hadAccess = hasAccess(uri)
            try {
                context.contentResolver.takePersistableUriPermission(uri, URI_FLAGS)
                if (!hasAccess(uri)) throw SecurityException("The provider did not grant lasting read and write access")
                FolderSyncDocuments(context.contentResolver, uri).requireWritableFolder()
                currentCoroutineContext().ensureActive()
            } catch (e: CancellationException) {
                if (!hadAccess) releaseFolderAccess(uri)
                throw e
            } catch (e: Exception) {
                if (!hadAccess) releaseFolderAccess(uri)
                Log.w(TAG, "Could not keep folder access", e)
                setError("Folder selection failed: ${e.message ?: "Folder unavailable"}. Choose a writable folder.")
                return@withContext false
            }
            if (previous != uri.toString()) {
                preferences.setFolderLastSyncedAt(0)
                previous?.let { releaseFolderAccess(Uri.parse(it)) }
            }
            preferences.setFolderSyncUri(uri.toString())
            preferences.setFolderSyncEnabled(true)
            scope.launch { syncWithFolder() }
            true
        }
    }

    private fun releaseFolderAccess(uri: Uri) {
        try {
            context.contentResolver.releasePersistableUriPermission(uri, URI_FLAGS)
        } catch (_: SecurityException) {
            // The provider may already have revoked this grant.
        }
    }

    private fun selectedFolder(): String? =
        preferences.folderSyncUri.value?.takeIf { it.isNotBlank() && preferences.folderSyncEnabled.value }

    private fun hasAccess(uri: Uri): Boolean = context.contentResolver.persistedUriPermissions.any {
        it.uri == uri && it.isReadPermission && it.isWritePermission
    }

    private fun writerId(): String {
        // This state is local to the install and excluded from sync/export (app backup is disabled).
        val install = context.getSharedPreferences("folder_sync_install", Context.MODE_PRIVATE)
        install.getString("writer_id", null)?.let { return it }
        val id = UUID.randomUUID().toString()
        if (!install.edit().putString("writer_id", id).commit()) throw IOException("Could not save the sync device identity")
        return id
    }

    private data class ReadResult(val snapshots: List<ExportDocument>, val incomplete: Int, val hasPublication: Boolean)

    private fun readSnapshots(folder: FolderSyncDocuments): ReadResult {
        val entries = folder.list()
        val snapshots = mutableListOf<ExportDocument>()
        var incomplete = 0
        // All complete publications participate. A later upload can never hide another writer's work.
        entries.filter { FolderSyncProtocol.isPublication(it.name) }.forEach { entry ->
            try {
                val contents = folder.read(entry.uri)
                snapshots.add(FolderSyncProtocol.portable(FolderSyncProtocol.decode(contents)))
            } catch (_: FileNotFoundException) {
                incomplete++
            } catch (_: IllegalArgumentException) {
                incomplete++
            }
        }
        val legacy = entries.filter { it.name == SYNC_FILE_NAME }
        val backups = entries.filter { it.name == BAK_FILE_NAME }
        fun readLegacy(entries: List<FolderSyncDocuments.Entry>): List<ExportDocument> = entries.mapNotNull {
            try {
                FolderSyncProtocol.portable(BackupCodec.decode(folder.read(it.uri)))
            } catch (_: FileNotFoundException) {
                null
            } catch (_: IllegalArgumentException) {
                null
            }
        }
        val old = readLegacy(legacy).ifEmpty { readLegacy(backups) }
        if (old.isEmpty() && (legacy.isNotEmpty() || backups.isNotEmpty())) {
            if (snapshots.isEmpty()) {
                throw IOException("The old sync file and backup could not be read. Existing files were preserved.")
            }
            incomplete++
        }
        val hasPublication = snapshots.isNotEmpty()
        snapshots.addAll(old)
        return ReadResult(snapshots, incomplete, hasPublication)
    }

    suspend fun syncWithFolder(): Boolean = syncMutex.withLock {
        val selected = selectedFolder() ?: return@withLock false
        withContext(Dispatchers.IO) {
            _syncStatus.value = SyncStatus.SYNCING
            try {
                val uri = Uri.parse(selected)
                if (!hasAccess(uri)) throw IOException("Folder access was lost. Select the folder again.")
                val folder = FolderSyncDocuments(context.contentResolver, uri)
                val remote = readSnapshots(folder)
                currentCoroutineContext().ensureActive()
                if (selectedFolder() != selected) {
                    _syncStatus.value = SyncStatus.IDLE
                    return@withContext false
                }
                val result = mergeAndSnapshot(remote.snapshots)
                if (result.pulled > 0) StudyHabitWidgetProvider.updateAllWidgets(context)
                if (selectedFolder() != selected) {
                    _syncStatus.value = SyncStatus.IDLE
                    return@withContext false
                }
                val shouldPublish = result.pushed > 0 || !remote.hasPublication
                if (shouldPublish) {
                    currentCoroutineContext().ensureActive()
                    val contents = FolderSyncProtocol.encode(FolderSyncProtocol.portable(result.document))
                    folder.publish(FolderSyncProtocol.fileName(writerId(), UUID.randomUUID().toString()), contents)
                }
                if (selectedFolder() != selected) {
                    _syncStatus.value = SyncStatus.IDLE
                    return@withContext false
                }
                val changed = shouldPublish || result.pulled > 0
                val summary = if (changed) {
                    "Folder checked: ${if (shouldPublish) "${result.pushed} changes published" else "no upload"} • ${result.pulled} changes merged"
                } else {
                    "Up to date with files available on this device"
                }
                setSuccess(summary + if (remote.incomplete > 0) " • ${remote.incomplete} incomplete files skipped" else "")
                true
            } catch (e: CancellationException) {
                _syncStatus.value = SyncStatus.IDLE
                throw e
            } catch (e: Exception) {
                Log.w(TAG, "Folder sync failed", e)
                if (selectedFolder() == selected) {
                    setError("Folder sync failed: ${e.message ?: "Folder unavailable"}")
                } else {
                    _syncStatus.value = SyncStatus.IDLE
                }
                false
            }
        }
    }

    suspend fun saveToDocumentUri(uri: Uri): Boolean = runManual("Save file") {
        val document = database.withTransaction { exportImportService.buildExportDocument(includeDeleted = true) }
        writeManualDocument(uri, exportImportService.json.encodeToString(document))
        "Saved a copy to the selected document"
    }

    suspend fun mergeFromDocumentUri(uri: Uri): Boolean = runManual("Merge file") {
        val document = readManualDocument(uri)
        val result = mergeAndSnapshot(listOf(document))
        if (result.pulled > 0) StudyHabitWidgetProvider.updateAllWidgets(context)
        "${result.pulled} changes merged from the selected document"
    }

    private fun readManualDocument(uri: Uri): ExportDocument {
        val contents = context.contentResolver.openInputStream(uri)?.use {
            it.bufferedReader(Charsets.UTF_8).readText()
        } ?: throw IOException("Could not open the selected document")
        return FolderSyncProtocol.portable(BackupCodec.decode(contents))
    }

    private fun writeManualDocument(uri: Uri, contents: String) {
        context.contentResolver.openOutputStream(uri, "wt")?.use { it.write(contents.toByteArray(Charsets.UTF_8)) }
            ?: throw IOException("Could not open the selected document for writing")
    }

    private suspend fun runManual(label: String, action: suspend () -> String): Boolean =
        syncMutex.withLock {
            withContext(Dispatchers.IO) {
                _manualFileSummary.value = "$label…"
                try {
                    _manualFileSummary.value = action()
                    true
                } catch (e: CancellationException) {
                    _manualFileSummary.value = null
                    throw e
                } catch (e: Exception) {
                    Log.w(TAG, "$label failed", e)
                    _manualFileSummary.value = "$label failed: ${e.message ?: "Document unavailable"}"
                    false
                }
            }
        }

    private fun setSuccess(summary: String) {
        preferences.setFolderLastSyncedAt(System.currentTimeMillis())
        preferences.setFolderLastSummary(summary)
        _syncStatus.value = SyncStatus.SYNCED
    }

    private fun setError(summary: String) {
        preferences.setFolderLastSummary(summary)
        _syncStatus.value = SyncStatus.ERROR
    }

    private data class Result(val pushed: Int, val pulled: Int, val document: ExportDocument)
    private data class Settings(val values: Map<String, JsonElement>?, val updatedAt: Long) {
        fun stableContent(): String = JsonObject(values.orEmpty().toSortedMap()).toString()
    }

    private suspend fun mergeAndSnapshot(remote: List<ExportDocument>): Result {
        var appliedSettings: Settings? = null
        var selectedProject: String? = null
        val result = database.withTransaction {
            var pushedCount = 0
            var pulledCount = 0
            fun count(counts: Pair<Int, Int>) {
                pushedCount += counts.first
                pulledCount += counts.second
            }
            val localStats = database.userStatsDao().getUserStats()
            val localSessions = database.sessionDao().getAllSessions()

            count(mergeEntities(
                remote.flatMap { doc -> doc.projects.map { it.project } },
                database.projectDao().getModifiedSince(-1L), { it.id }, { it.updatedAt }, { it.isDeleted },
                stable = { exportImportService.json.encodeToString(it.copy(lastOpenedAt = 0)) },
            ) { incoming, local ->
                database.projectDao().upsert(incoming.copy(lastOpenedAt = local?.lastOpenedAt ?: 0))
            })

            val remoteSubjects = remote.flatMap { doc -> doc.projects.flatMap { it.subjects } }
            count(mergeEntities(
                remoteSubjects.map { it.subject },
                database.subjectDao().getModifiedSince(-1L), { it.id }, { it.updatedAt }, { it.isDeleted },
                stable = { exportImportService.json.encodeToString(it.copy(xpTotal = 0)) },
            ) { incoming, _ -> database.subjectDao().upsert(incoming) })
            count(mergeEntities(
                remoteSubjects.flatMap { it.topics },
                database.topicDao().getModifiedSince(-1L), { it.id }, { it.updatedAt }, { it.isDeleted },
            ) { incoming, _ -> database.topicDao().upsert(incoming) })
            count(mergeEntities(
                remoteSubjects.flatMap { it.chapters },
                database.chapterDao().getModifiedSince(-1L), { it.id }, { it.updatedAt }, { it.isDeleted },
            ) { incoming, _ -> database.chapterDao().upsert(incoming) })
            count(mergeEntities(
                remoteSubjects.flatMap { it.sessions },
                database.sessionDao().getModifiedSince(-1L), { it.id }, { it.updatedAt }, { it.isDeleted },
            ) { incoming, _ -> database.sessionDao().upsert(incoming) })
            count(mergeEntities(
                remoteSubjects.flatMap { it.sources },
                database.sourceDao().getModifiedSince(-1L), { it.id }, { it.updatedAt }, { it.isDeleted },
                stable = { source ->
                    exportImportService.json.encodeToString(if (source.type == "pdf") source.copy(filePath = null) else source)
                },
            ) { incoming, local ->
                val source = if (incoming.type == "pdf") {
                    incoming.copy(filePath = local?.takeIf { it.type == "pdf" }?.filePath)
                } else incoming
                database.sourceDao().upsert(source)
            })
            count(mergeEntities(
                remoteSubjects.flatMap { it.skillLabels },
                database.skillLabelDao().getModifiedSince(-1L), { it.id }, { it.updatedAt }, { it.isDeleted },
            ) { incoming, _ -> database.skillLabelDao().upsert(incoming) })
            count(mergeEntities(
                remoteSubjects.flatMap { it.milestones },
                database.milestoneDao().getModifiedSince(-1L), { it.id }, { it.updatedAt }, { it.isDeleted },
            ) { incoming, _ -> database.milestoneDao().upsert(incoming) })
            count(mergeEntities(
                remote.flatMap { it.achievements },
                database.achievementDao().getAllAchievements(), { it.key }, { it.updatedAt }, { false },
            ) { incoming, _ -> database.achievementDao().upsert(incoming) })

            val mergedSessions = database.sessionDao().getAllSessions()
            val subjectXp = mergedSessions.groupBy { it.subjectId }.mapValues { (_, sessions) ->
                sessions.sumOf { it.xpEarned.toLong() }.coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()
            }
            for (subject in database.subjectDao().getAllSubjects()) {
                val xp = subjectXp[subject.id] ?: 0
                if (subject.xpTotal != xp) database.subjectDao().upsert(subject.copy(xpTotal = xp))
            }

            val remoteStats = remote.map { it.userStats }.maxWithOrNull(::compareStats)
            val localBonus = localStats?.let { FolderSyncProtocol.bonusXp(it, localSessions) } ?: 0
            val remoteBonus = remote.maxOfOrNull { FolderSyncProtocol.bonusXp(it.userStats, FolderSyncProtocol.sessions(it)) } ?: 0
            val remoteLongest = remote.maxOfOrNull { it.userStats.longestStreak } ?: 0
            val base = when {
                localStats == null -> remoteStats ?: UserStatsEntity(updatedAt = 0)
                remoteStats == null -> localStats
                compareStats(localStats, remoteStats) >= 0 -> localStats
                else -> remoteStats
            }
            val stats = FolderSyncProtocol.reconcileStats(
                base, mergedSessions, maxOf(localBonus, remoteBonus), maxOf(localStats?.longestStreak ?: 0, remoteLongest)
            )
            if (localStats != null && (remoteStats == null || compareStats(localStats, remoteStats) > 0 ||
                    localBonus > remoteBonus || localStats.longestStreak > remoteLongest)
            ) pushedCount++
            if (stats != localStats && (localStats != null || remoteStats != null || mergedSessions.isNotEmpty())) {
                database.userStatsDao().upsert(stats)
                pulledCount++
            }

            val snapshot = exportImportService.buildExportDocument(includeDeleted = true)
            val localSettings = Settings(snapshot.settings, snapshot.settingsUpdatedAt)
            val remoteSettings = remote.filter { it.settings != null }
                .map { Settings(it.settings, it.settingsUpdatedAt) }
                .maxWithOrNull(::compareSettings)
            val settings = if (remoteSettings != null && (localSettings.values == null ||
                    compareSettings(remoteSettings, localSettings) > 0)
            ) {
                appliedSettings = remoteSettings
                pulledCount++
                remoteSettings
            } else {
                if (localSettings.values != null && (remoteSettings == null || compareSettings(localSettings, remoteSettings) > 0)) {
                    pushedCount++
                }
                localSettings
            }

            val projects = database.projectDao().getAllProjects()
            val current = preferences.activeProjectId.value
            if (projects.none { it.id == current }) selectedProject = projects.firstOrNull()?.id

            Result(pushedCount, pulledCount, snapshot.copy(
                userStats = stats,
                settings = settings.values,
                settingsUpdatedAt = settings.updatedAt,
            ))
        }
        // Preferences cannot be rolled back by Room, so apply them only after commit.
        appliedSettings?.let {
            preferences.applySettingsMap(it.values.orEmpty())
            preferences.settingsUpdatedAt = it.updatedAt
        }
        selectedProject?.let { preferences.setActiveProjectId(it) }
        return result
    }

    private fun compareStats(left: UserStatsEntity, right: UserStatsEntity): Int =
        FolderSyncProtocol.compare(left, right, { it.updatedAt }, { false }) {
            exportImportService.json.encodeToString(it.copy(totalXp = 0, totalStudyMinutes = 0, currentLevel = 0, longestStreak = 0))
        }

    private fun compareSettings(left: Settings, right: Settings): Int =
        FolderSyncProtocol.compare(left, right, { it.updatedAt }, { false }, Settings::stableContent)

    private suspend inline fun <reified T> mergeEntities(
        remote: List<T>,
        local: List<T>,
        noinline id: (T) -> String,
        noinline updatedAt: (T) -> Long,
        noinline deleted: (T) -> Boolean,
        noinline stable: (T) -> String = { exportImportService.json.encodeToString(it) },
        upsert: (incoming: T, local: T?) -> Unit,
    ): Pair<Int, Int> {
        val plan = FolderSyncProtocol.planRows(remote, local, id, updatedAt, deleted, stable)
        for ((incoming, previous) in plan.updates) upsert(incoming, previous)
        return plan.pushed to plan.updates.size
    }
}
