package de.schuelken.studyhabit.core.service

import de.schuelken.studyhabit.core.database.AchievementEntity
import de.schuelken.studyhabit.core.database.AppDatabase
import de.schuelken.studyhabit.core.database.ChapterEntity
import de.schuelken.studyhabit.core.database.ProjectEntity
import de.schuelken.studyhabit.core.database.SkillLabelEntity
import de.schuelken.studyhabit.core.database.SourceEntity
import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.database.SubjectEntity
import de.schuelken.studyhabit.core.database.SubjectMilestoneEntity
import de.schuelken.studyhabit.core.database.TopicEntity
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.model.SyncStatus
import de.schuelken.studyhabit.core.network.StudyHabitApi
import de.schuelken.studyhabit.core.network.SyncAchievementItem
import de.schuelken.studyhabit.core.network.SyncChapterItem
import de.schuelken.studyhabit.core.network.SyncMilestoneItem
import de.schuelken.studyhabit.core.network.SyncProjectItem
import de.schuelken.studyhabit.core.network.SyncPullData
import de.schuelken.studyhabit.core.network.SyncPushPayload
import de.schuelken.studyhabit.core.network.SyncSessionItem
import de.schuelken.studyhabit.core.network.SyncSkillLabelItem
import de.schuelken.studyhabit.core.network.SyncSourceItem
import de.schuelken.studyhabit.core.network.SyncSubjectItem
import de.schuelken.studyhabit.core.network.SyncTopicItem
import de.schuelken.studyhabit.core.network.SyncUserSettingsItem
import de.schuelken.studyhabit.core.network.SyncUserStatsItem
import de.schuelken.studyhabit.core.network.TokenStorage
import de.schuelken.studyhabit.core.preferences.AppPreferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import java.time.Instant

class SyncEngine(
    private val api: StudyHabitApi,
    private val database: AppDatabase,
    private val preferences: AppPreferences,
    private val tokenStorage: TokenStorage,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO),
) {
    private val _syncStatus = MutableStateFlow(SyncStatus.IDLE)
    val syncStatus: StateFlow<SyncStatus> = _syncStatus.asStateFlow()

    private val syncMutex = Mutex()
    private var debounceJob: Job? = null

    private fun normalizeColorForPush(color: Int): Int = color and 0x00FFFFFF
    private fun normalizeColorForPull(color: Int): Int = (color and 0x00FFFFFF) or -0x1000000

    private fun toIsoString(timestamp: Long): String =
        Instant.ofEpochMilli(timestamp).toString()

    private fun parseIsoString(iso: String): Long =
        runCatching { Instant.parse(iso).toEpochMilli() }.getOrDefault(System.currentTimeMillis())

    fun scheduleDebouncedSync() {
        debounceJob?.cancel()
        debounceJob = scope.launch {
            delay(30_000)
            syncNow()
        }
    }

    suspend fun syncNow(): Boolean {
        debounceJob?.cancel()
        val token = tokenStorage.getToken()
        if (token.isNullOrBlank()) {
            _syncStatus.value = SyncStatus.IDLE
            return false
        }

        val currentUserId = tokenStorage.getUserId() ?: ""
        return syncMutex.withLock {
            _syncStatus.value = SyncStatus.SYNCING
            try {
                // Check user switch
                val lastSyncedUser = preferences.lastSyncedUserId
                if (currentUserId.isNotEmpty() && lastSyncedUser != null && lastSyncedUser != currentUserId) {
                    clearLocalData()
                    preferences.lastSyncedUserId = currentUserId
                    preferences.lastSyncedAt = 0L
                } else if (currentUserId.isNotEmpty() && lastSyncedUser == null) {
                    preferences.lastSyncedUserId = currentUserId
                }

                val sinceMs = preferences.lastSyncedAt
                val sinceIso = if (sinceMs > 0) toIsoString(sinceMs) else Instant.EPOCH.toString()

                val pushPayload = collectPushPayload(sinceMs)
                val response = api.fullSync(sinceIso, pushPayload)
                val pull = response.data.pull

                applyRemoteChanges(pull)

                preferences.lastSyncedAt = parseIsoString(pull.serverTime)
                _syncStatus.value = SyncStatus.SYNCED
                true
            } catch (e: Exception) {
                _syncStatus.value = SyncStatus.ERROR
                false
            }
        }
    }

    private suspend fun clearLocalData() {
        database.skillLabelDao().deleteAll()
        database.milestoneDao().deleteAll()
        database.sourceDao().deleteAll()
        database.sessionDao().deleteAll()
        database.chapterDao().deleteAll()
        database.topicDao().deleteAll()
        database.subjectDao().deleteAll()
        database.projectDao().deleteAll()
        database.achievementDao().deleteAll()
        database.userStatsDao().deleteAll()
    }

    private suspend fun collectPushPayload(sinceMs: Long): SyncPushPayload {
        val projects = database.projectDao().getModifiedSince(sinceMs).map {
            SyncProjectItem(
                id = it.id,
                name = it.name,
                icon = it.icon,
                colorValue = normalizeColorForPush(it.colorValue),
                createdAt = toIsoString(it.createdAt),
                lastOpenedAt = toIsoString(it.lastOpenedAt),
                isArchived = it.isArchived,
                defaultWorkDuration = it.defaultWorkDuration,
                defaultBreakDuration = it.defaultBreakDuration,
                defaultLongBreakDuration = it.defaultLongBreakDuration,
                defaultLongBreakEvery = it.defaultLongBreakEvery,
                studyReminderMinutes = it.studyReminderMinutes,
                updatedAt = toIsoString(it.updatedAt),
                isDeleted = it.isDeleted,
            )
        }

        val subjects = database.subjectDao().getModifiedSince(sinceMs).map {
            SyncSubjectItem(
                id = it.id,
                projectId = it.projectId,
                name = it.name,
                description = it.description,
                colorValue = normalizeColorForPush(it.colorValue),
                hierarchyMode = it.hierarchyMode,
                defaultDurationMinutes = it.defaultDurationMinutes,
                defaultBreakMinutes = it.defaultBreakMinutes,
                completenessMode = it.completenessMode,
                targetHours = it.targetHours,
                targetWeeklyHours = it.targetWeeklyHours,
                xpTotal = it.xpTotal,
                createdAt = toIsoString(it.createdAt),
                updatedAt = toIsoString(it.updatedAt),
                isDeleted = it.isDeleted,
            )
        }

        val topics = database.topicDao().getModifiedSince(sinceMs).map {
            SyncTopicItem(
                id = it.id,
                subjectId = it.subjectId,
                name = it.name,
                order = it.order,
                createdAt = toIsoString(it.createdAt),
                updatedAt = toIsoString(it.updatedAt),
                isDeleted = it.isDeleted,
            )
        }

        val chapters = database.chapterDao().getModifiedSince(sinceMs).map {
            SyncChapterItem(
                id = it.id,
                topicId = it.topicId,
                name = it.name,
                order = it.order,
                createdAt = toIsoString(it.createdAt),
                updatedAt = toIsoString(it.updatedAt),
                isDeleted = it.isDeleted,
            )
        }

        val sessions = database.sessionDao().getModifiedSince(sinceMs).map {
            SyncSessionItem(
                id = it.id,
                subjectId = it.subjectId,
                topicId = it.topicId,
                chapterId = it.chapterId,
                startedAt = toIsoString(it.startedAt),
                endedAt = it.endedAt?.let { ended -> toIsoString(ended) },
                plannedDurationMinutes = it.plannedDurationMinutes,
                actualDurationMinutes = it.actualDurationMinutes,
                pomodorosCompleted = it.pomodorosCompleted,
                confidenceRating = it.confidenceRating,
                notes = it.notes,
                xpEarned = it.xpEarned,
                sourceId = it.sourceId,
                startPage = it.startPage,
                endPage = it.endPage,
                isFreeTimer = it.isFreeTimer,
                updatedAt = toIsoString(it.updatedAt),
                isDeleted = it.isDeleted,
            )
        }

        val sources = database.sourceDao().getModifiedSince(sinceMs).map {
            SyncSourceItem(
                id = it.id,
                subjectId = it.subjectId,
                topicId = it.topicId,
                chapterId = it.chapterId,
                type = it.type,
                title = it.title,
                filePath = it.filePath,
                url = it.url,
                currentPage = it.currentPage,
                totalPages = it.totalPages,
                progressPercent = it.progressPercent,
                notes = it.notes,
                addedAt = toIsoString(it.addedAt),
                updatedAt = toIsoString(it.updatedAt),
                isDeleted = it.isDeleted,
            )
        }

        val skillLabels = database.skillLabelDao().getModifiedSince(sinceMs).map {
            SyncSkillLabelItem(
                id = it.id,
                subjectId = it.subjectId,
                topicId = it.topicId,
                chapterId = it.chapterId,
                label = it.label,
                updatedAt = toIsoString(it.updatedAt),
                isDeleted = it.isDeleted,
            )
        }

        val milestones = database.milestoneDao().getModifiedSince(sinceMs).map {
            SyncMilestoneItem(
                id = it.id,
                subjectId = it.subjectId,
                title = it.title,
                isCompleted = it.isCompleted,
                sortOrder = it.sortOrder,
                completedAt = it.completedAt?.let { comp -> toIsoString(comp) },
                updatedAt = toIsoString(it.updatedAt),
                isDeleted = it.isDeleted,
            )
        }

        val achievements = database.achievementDao().getModifiedSince(sinceMs).map {
            SyncAchievementItem(
                key = it.key,
                unlockedAt = it.unlockedAt?.let { unl -> toIsoString(unl) },
                progress = it.progress,
                updatedAt = toIsoString(it.updatedAt),
            )
        }

        val stats = database.userStatsDao().getModifiedSince(sinceMs).firstOrNull()?.let {
            SyncUserStatsItem(
                id = it.id,
                totalXp = it.totalXp,
                currentLevel = it.currentLevel,
                currentStreak = it.currentStreak,
                longestStreak = it.longestStreak,
                lastStudyDate = it.lastStudyDate?.let { date -> toIsoString(date) },
                totalStudyMinutes = it.totalStudyMinutes,
                freezeTokens = it.freezeTokens,
                updatedAt = toIsoString(it.updatedAt),
            )
        }

        val settingsUpdatedAt = preferences.settingsUpdatedAt
        val userSettings = if (settingsUpdatedAt > sinceMs) {
            val map = preferences.getAllowedSettingsMap().mapValues { (_, value) ->
                when (value) {
                    is Boolean -> JsonPrimitive(value)
                    is Number -> JsonPrimitive(value)
                    is String -> JsonPrimitive(value)
                    else -> JsonPrimitive(value.toString())
                }
            }
            if (map.isNotEmpty()) {
                SyncUserSettingsItem(settings = map, updatedAt = toIsoString(settingsUpdatedAt))
            } else null
        } else null

        return SyncPushPayload(
            projects = projects.ifEmpty { null },
            subjects = subjects.ifEmpty { null },
            topics = topics.ifEmpty { null },
            chapters = chapters.ifEmpty { null },
            sessions = sessions.ifEmpty { null },
            sources = sources.ifEmpty { null },
            skillLabels = skillLabels.ifEmpty { null },
            subjectMilestones = milestones.ifEmpty { null },
            achievements = achievements.ifEmpty { null },
            userStats = stats,
            userSettings = userSettings,
        )
    }

    private suspend fun applyRemoteChanges(pull: SyncPullData) {
        // Projects
        for (item in pull.projects) {
            val serverUpdated = parseIsoString(item.updatedAt)
            val local = database.projectDao().getProjectById(item.id)
            if (local == null || serverUpdated > local.updatedAt) {
                database.projectDao().upsert(
                    ProjectEntity(
                        id = item.id,
                        name = item.name,
                        icon = item.icon,
                        colorValue = normalizeColorForPull(item.colorValue),
                        createdAt = parseIsoString(item.createdAt),
                        lastOpenedAt = parseIsoString(item.lastOpenedAt),
                        isArchived = item.isArchived,
                        defaultWorkDuration = item.defaultWorkDuration,
                        defaultBreakDuration = item.defaultBreakDuration,
                        defaultLongBreakDuration = item.defaultLongBreakDuration,
                        defaultLongBreakEvery = item.defaultLongBreakEvery,
                        studyReminderMinutes = item.studyReminderMinutes,
                        updatedAt = serverUpdated,
                        isDeleted = item.isDeleted,
                    )
                )
            }
        }

        // Subjects
        for (item in pull.subjects) {
            val serverUpdated = parseIsoString(item.updatedAt)
            val local = database.subjectDao().getSubjectById(item.id)
            if (local == null || serverUpdated > local.updatedAt) {
                database.subjectDao().upsert(
                    SubjectEntity(
                        id = item.id,
                        projectId = item.projectId,
                        name = item.name,
                        description = item.description,
                        colorValue = normalizeColorForPull(item.colorValue),
                        hierarchyMode = item.hierarchyMode,
                        defaultDurationMinutes = item.defaultDurationMinutes,
                        defaultBreakMinutes = item.defaultBreakMinutes,
                        completenessMode = item.completenessMode,
                        targetHours = item.targetHours,
                        targetWeeklyHours = item.targetWeeklyHours,
                        xpTotal = item.xpTotal,
                        createdAt = parseIsoString(item.createdAt),
                        updatedAt = serverUpdated,
                        isDeleted = item.isDeleted,
                    )
                )
            }
        }

        // Topics
        for (item in pull.topics) {
            val serverUpdated = parseIsoString(item.updatedAt)
            val local = database.topicDao().getTopicById(item.id)
            if (local == null || serverUpdated > local.updatedAt) {
                database.topicDao().upsert(
                    TopicEntity(
                        id = item.id,
                        subjectId = item.subjectId,
                        name = item.name,
                        order = item.order,
                        createdAt = item.createdAt?.let { parseIsoString(it) } ?: System.currentTimeMillis(),
                        updatedAt = serverUpdated,
                        isDeleted = item.isDeleted,
                    )
                )
            }
        }

        // Chapters
        for (item in pull.chapters) {
            val serverUpdated = parseIsoString(item.updatedAt)
            val local = database.chapterDao().getChapterById(item.id)
            if (local == null || serverUpdated > local.updatedAt) {
                database.chapterDao().upsert(
                    ChapterEntity(
                        id = item.id,
                        topicId = item.topicId,
                        name = item.name,
                        order = item.order,
                        createdAt = item.createdAt?.let { parseIsoString(it) } ?: System.currentTimeMillis(),
                        updatedAt = serverUpdated,
                        isDeleted = item.isDeleted,
                    )
                )
            }
        }

        // Sessions
        for (item in pull.sessions) {
            val serverUpdated = parseIsoString(item.updatedAt)
            val local = database.sessionDao().getSessionById(item.id)
            if (local == null || serverUpdated > local.updatedAt) {
                database.sessionDao().upsert(
                    StudySessionEntity(
                        id = item.id,
                        subjectId = item.subjectId,
                        topicId = item.topicId,
                        chapterId = item.chapterId,
                        startedAt = parseIsoString(item.startedAt),
                        endedAt = item.endedAt?.let { parseIsoString(it) },
                        plannedDurationMinutes = item.plannedDurationMinutes,
                        actualDurationMinutes = item.actualDurationMinutes,
                        pomodorosCompleted = item.pomodorosCompleted,
                        confidenceRating = item.confidenceRating,
                        notes = item.notes,
                        xpEarned = item.xpEarned,
                        sourceId = item.sourceId,
                        startPage = item.startPage,
                        endPage = item.endPage,
                        isFreeTimer = item.isFreeTimer,
                        updatedAt = serverUpdated,
                        isDeleted = item.isDeleted,
                    )
                )
            }
        }

        // Sources
        for (item in pull.sources) {
            val serverUpdated = parseIsoString(item.updatedAt)
            val local = database.sourceDao().getSourceById(item.id)
            if (local == null || serverUpdated > local.updatedAt) {
                database.sourceDao().upsert(
                    SourceEntity(
                        id = item.id,
                        subjectId = item.subjectId,
                        topicId = item.topicId,
                        chapterId = item.chapterId,
                        type = item.type,
                        title = item.title,
                        filePath = item.filePath,
                        url = item.url,
                        currentPage = item.currentPage,
                        totalPages = item.totalPages,
                        progressPercent = item.progressPercent,
                        notes = item.notes,
                        addedAt = item.addedAt?.let { parseIsoString(it) } ?: System.currentTimeMillis(),
                        updatedAt = serverUpdated,
                        isDeleted = item.isDeleted,
                    )
                )
            }
        }

        // Skill Labels
        for (item in pull.skillLabels) {
            database.skillLabelDao().upsert(
                SkillLabelEntity(
                    id = item.id,
                    subjectId = item.subjectId,
                    topicId = item.topicId,
                    chapterId = item.chapterId,
                    label = item.label,
                    updatedAt = parseIsoString(item.updatedAt),
                    isDeleted = item.isDeleted,
                )
            )
        }

        // Milestones
        for (item in pull.subjectMilestones) {
            database.milestoneDao().upsert(
                SubjectMilestoneEntity(
                    id = item.id,
                    subjectId = item.subjectId,
                    title = item.title,
                    isCompleted = item.isCompleted,
                    sortOrder = item.sortOrder,
                    completedAt = item.completedAt?.let { parseIsoString(it) },
                    updatedAt = parseIsoString(item.updatedAt),
                    isDeleted = item.isDeleted,
                )
            )
        }

        // Achievements
        for (item in pull.achievements) {
            val serverUpdated = parseIsoString(item.updatedAt)
            val local = database.achievementDao().getAchievementByKey(item.key)
            if (local == null || serverUpdated > local.updatedAt) {
                database.achievementDao().upsert(
                    AchievementEntity(
                        key = item.key,
                        unlockedAt = item.unlockedAt?.let { parseIsoString(it) },
                        progress = item.progress,
                        updatedAt = serverUpdated,
                    )
                )
            }
        }

        // User Stats
        pull.userStats?.let { stats ->
            val serverUpdated = parseIsoString(stats.updatedAt)
            val local = database.userStatsDao().getUserStats()
            if (local == null || serverUpdated > local.updatedAt) {
                database.userStatsDao().upsert(
                    UserStatsEntity(
                        id = stats.id,
                        totalXp = stats.totalXp,
                        currentLevel = stats.currentLevel,
                        currentStreak = stats.currentStreak,
                        longestStreak = stats.longestStreak,
                        lastStudyDate = stats.lastStudyDate?.let { parseIsoString(it) },
                        totalStudyMinutes = stats.totalStudyMinutes,
                        freezeTokens = stats.freezeTokens,
                        updatedAt = serverUpdated,
                    )
                )
            }
        }

        // User Settings
        pull.userSettings?.let { settingsItem ->
            val serverUpdated = parseIsoString(settingsItem.updatedAt)
            if (serverUpdated > preferences.settingsUpdatedAt) {
                preferences.applySettingsMap(settingsItem.settings)
                preferences.settingsUpdatedAt = serverUpdated
            }
        }
    }
}
