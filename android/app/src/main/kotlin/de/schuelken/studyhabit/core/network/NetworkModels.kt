package de.schuelken.studyhabit.core.network

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

@Serializable
data class LoginRequest(
    val email: String,
    val password: String,
)

@Serializable
data class RegisterRequest(
    val email: String,
    val password: String,
)

@Serializable
data class UserInfo(
    val id: String,
    val email: String,
)

@Serializable
data class AuthData(
    val accessToken: String,
    val user: UserInfo,
)

@Serializable
data class ApiResponse<T>(
    val data: T,
)

@Serializable
data class SuccessResponse(
    val success: Boolean,
)

@Serializable
data class SyncPushPayload(
    val projects: List<SyncProjectItem>? = null,
    val subjects: List<SyncSubjectItem>? = null,
    val topics: List<SyncTopicItem>? = null,
    val chapters: List<SyncChapterItem>? = null,
    val sessions: List<SyncSessionItem>? = null,
    val sources: List<SyncSourceItem>? = null,
    val skillLabels: List<SyncSkillLabelItem>? = null,
    val subjectMilestones: List<SyncMilestoneItem>? = null,
    val achievements: List<SyncAchievementItem>? = null,
    val userStats: SyncUserStatsItem? = null,
    val userSettings: SyncUserSettingsItem? = null,
)

@Serializable
data class SyncResponse(
    val data: SyncData,
)

@Serializable
data class SyncData(
    val pull: SyncPullData,
    val push: SyncPushResult? = null,
)

@Serializable
data class SyncPullData(
    val projects: List<SyncProjectItem> = emptyList(),
    val subjects: List<SyncSubjectItem> = emptyList(),
    val topics: List<SyncTopicItem> = emptyList(),
    val chapters: List<SyncChapterItem> = emptyList(),
    val sessions: List<SyncSessionItem> = emptyList(),
    val sources: List<SyncSourceItem> = emptyList(),
    val skillLabels: List<SyncSkillLabelItem> = emptyList(),
    val subjectMilestones: List<SyncMilestoneItem> = emptyList(),
    val achievements: List<SyncAchievementItem> = emptyList(),
    val userStats: SyncUserStatsItem? = null,
    val userSettings: SyncUserSettingsItem? = null,
    val serverTime: String,
)

@Serializable
data class SyncPushResult(
    val applied: Map<String, Int> = emptyMap(),
    val conflicts: Map<String, Int> = emptyMap(),
    val errors: List<SyncErrorItem> = emptyList(),
)

@Serializable
data class SyncErrorItem(
    val entity: String? = null,
    val id: String? = null,
    val error: String? = null,
)

@Serializable
data class SyncProjectItem(
    val id: String,
    val userId: String? = null,
    val name: String,
    val icon: String = "📚",
    val colorValue: Int,
    val createdAt: String,
    val lastOpenedAt: String,
    val isArchived: Boolean = false,
    val defaultWorkDuration: Int = 25,
    val defaultBreakDuration: Int = 5,
    val defaultLongBreakDuration: Int = 15,
    val defaultLongBreakEvery: Int = 4,
    val studyReminderMinutes: Int = 30,
    val updatedAt: String,
    val isDeleted: Boolean = false,
)

@Serializable
data class SyncSubjectItem(
    val id: String,
    val projectId: String,
    val name: String,
    val description: String? = null,
    val colorValue: Int,
    val hierarchyMode: String = "flat",
    val defaultDurationMinutes: Int = 25,
    val defaultBreakMinutes: Int = 5,
    val completenessMode: String = "none",
    val targetHours: Double? = null,
    val targetWeeklyHours: Double? = null,
    val xpTotal: Int = 0,
    val createdAt: String,
    val updatedAt: String,
    val isDeleted: Boolean = false,
)

@Serializable
data class SyncTopicItem(
    val id: String,
    val subjectId: String,
    val name: String,
    val order: Int = 0,
    val createdAt: String? = null,
    val updatedAt: String,
    val isDeleted: Boolean = false,
)

@Serializable
data class SyncChapterItem(
    val id: String,
    val topicId: String,
    val name: String,
    val order: Int = 0,
    val createdAt: String? = null,
    val updatedAt: String,
    val isDeleted: Boolean = false,
)

@Serializable
data class SyncSessionItem(
    val id: String,
    val subjectId: String,
    val topicId: String? = null,
    val chapterId: String? = null,
    val startedAt: String,
    val endedAt: String? = null,
    val plannedDurationMinutes: Int = 25,
    val actualDurationMinutes: Int = 0,
    val pomodorosCompleted: Int = 0,
    val confidenceRating: Int? = null,
    val notes: String? = null,
    val xpEarned: Int = 0,
    val sourceId: String? = null,
    val startPage: Int? = null,
    val endPage: Int? = null,
    val isFreeTimer: Boolean = false,
    val createdAt: String? = null,
    val updatedAt: String,
    val isDeleted: Boolean = false,
)

@Serializable
data class SyncSourceItem(
    val id: String,
    val subjectId: String,
    val topicId: String? = null,
    val chapterId: String? = null,
    val type: String = "pdf",
    val title: String,
    val filePath: String? = null,
    val url: String? = null,
    val currentPage: Int? = null,
    val totalPages: Int? = null,
    val progressPercent: Double? = null,
    val notes: String? = null,
    val addedAt: String? = null,
    val updatedAt: String,
    val isDeleted: Boolean = false,
)

@Serializable
data class SyncSkillLabelItem(
    val id: String,
    val subjectId: String,
    val topicId: String? = null,
    val chapterId: String? = null,
    val label: String = "beginner",
    val updatedAt: String,
    val isDeleted: Boolean = false,
)

@Serializable
data class SyncMilestoneItem(
    val id: String,
    val subjectId: String,
    val title: String,
    val isCompleted: Boolean = false,
    val sortOrder: Int = 0,
    val completedAt: String? = null,
    val updatedAt: String,
    val isDeleted: Boolean = false,
)

@Serializable
data class SyncAchievementItem(
    val key: String,
    val unlockedAt: String? = null,
    val progress: Double = 0.0,
    val updatedAt: String,
)

@Serializable
data class SyncUserStatsItem(
    val id: String = "default_stats",
    val userId: String? = null,
    val totalXp: Int = 0,
    val currentLevel: Int = 1,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val lastStudyDate: String? = null,
    val totalStudyMinutes: Int = 0,
    val freezeTokens: Int = 0,
    val updatedAt: String,
)

@Serializable
data class SyncUserSettingsItem(
    val settings: Map<String, JsonElement>,
    val updatedAt: String,
)

@Serializable
data class XpHistoryItem(
    val date: String,
    val xp: Int,
    val cumulativeXp: Int,
)
