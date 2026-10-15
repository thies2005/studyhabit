package de.schuelken.studyhabit.core.database

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import kotlinx.serialization.Serializable

@Serializable
@Entity(tableName = "projects")
data class ProjectEntity(
    @PrimaryKey val id: String,
    val name: String,
    val icon: String = "📚",
    @ColumnInfo(name = "color_value") val colorValue: Int,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "last_opened_at") val lastOpenedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_archived") val isArchived: Boolean = false,
    @ColumnInfo(name = "default_work_duration") val defaultWorkDuration: Int = 25,
    @ColumnInfo(name = "default_break_duration") val defaultBreakDuration: Int = 5,
    @ColumnInfo(name = "default_long_break_duration") val defaultLongBreakDuration: Int = 15,
    @ColumnInfo(name = "default_long_break_every") val defaultLongBreakEvery: Int = 4,
    @ColumnInfo(name = "study_reminder_minutes") val studyReminderMinutes: Int = 30,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Serializable
@Entity(tableName = "subjects")
data class SubjectEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "project_id") val projectId: String,
    val name: String,
    val description: String? = null,
    @ColumnInfo(name = "color_value") val colorValue: Int,
    @ColumnInfo(name = "hierarchy_mode") val hierarchyMode: String = "flat",
    @ColumnInfo(name = "default_duration_minutes") val defaultDurationMinutes: Int = 25,
    @ColumnInfo(name = "default_break_minutes") val defaultBreakMinutes: Int = 5,
    @ColumnInfo(name = "xp_total") val xpTotal: Int = 0,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "completeness_mode") val completenessMode: String = "none",
    @ColumnInfo(name = "target_hours") val targetHours: Int? = null,
    @ColumnInfo(name = "target_weekly_hours") val targetWeeklyHours: Int? = null,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Serializable
@Entity(tableName = "topics")
data class TopicEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "subject_id") val subjectId: String,
    val name: String,
    val order: Int = 0,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Serializable
@Entity(tableName = "chapters")
data class ChapterEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "topic_id") val topicId: String,
    val name: String,
    val order: Int = 0,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Serializable
@Entity(tableName = "study_sessions")
data class StudySessionEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "subject_id") val subjectId: String,
    @ColumnInfo(name = "topic_id") val topicId: String? = null,
    @ColumnInfo(name = "chapter_id") val chapterId: String? = null,
    @ColumnInfo(name = "started_at") val startedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "ended_at") val endedAt: Long? = null,
    @ColumnInfo(name = "planned_duration_minutes") val plannedDurationMinutes: Int = 25,
    @ColumnInfo(name = "actual_duration_minutes") val actualDurationMinutes: Int = 0,
    @ColumnInfo(name = "pomodoros_completed") val pomodorosCompleted: Int = 0,
    @ColumnInfo(name = "confidence_rating") val confidenceRating: Int? = null,
    val notes: String? = null,
    @ColumnInfo(name = "xp_earned") val xpEarned: Int = 0,
    @ColumnInfo(name = "source_id") val sourceId: String? = null,
    @ColumnInfo(name = "start_page") val startPage: Int? = null,
    @ColumnInfo(name = "end_page") val endPage: Int? = null,
    @ColumnInfo(name = "is_free_timer") val isFreeTimer: Boolean = false,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Serializable
@Entity(tableName = "skill_labels")
data class SkillLabelEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "subject_id") val subjectId: String,
    @ColumnInfo(name = "topic_id") val topicId: String? = null,
    @ColumnInfo(name = "chapter_id") val chapterId: String? = null,
    val label: String = "beginner",
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Serializable
@Entity(tableName = "sources")
data class SourceEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "subject_id") val subjectId: String,
    @ColumnInfo(name = "topic_id") val topicId: String? = null,
    @ColumnInfo(name = "chapter_id") val chapterId: String? = null,
    val type: String = "pdf",
    val title: String,
    @ColumnInfo(name = "file_path") val filePath: String? = null,
    val url: String? = null,
    @ColumnInfo(name = "current_page") val currentPage: Int? = null,
    @ColumnInfo(name = "total_pages") val totalPages: Int? = null,
    @ColumnInfo(name = "progress_percent") val progressPercent: Double? = null,
    val notes: String? = null,
    @ColumnInfo(name = "added_at") val addedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Serializable
@Entity(tableName = "achievements")
data class AchievementEntity(
    @PrimaryKey val key: String,
    @ColumnInfo(name = "unlocked_at") val unlockedAt: Long? = null,
    val progress: Double = 0.0,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
)

@Serializable
@Entity(tableName = "user_stats_table")
data class UserStatsEntity(
    @PrimaryKey val id: String = "default_stats",
    @ColumnInfo(name = "total_xp") val totalXp: Int = 0,
    @ColumnInfo(name = "current_level") val currentLevel: Int = 1,
    @ColumnInfo(name = "current_streak") val currentStreak: Int = 0,
    @ColumnInfo(name = "longest_streak") val longestStreak: Int = 0,
    @ColumnInfo(name = "last_study_date") val lastStudyDate: Long? = null,
    @ColumnInfo(name = "total_study_minutes") val totalStudyMinutes: Int = 0,
    @ColumnInfo(name = "freeze_tokens") val freezeTokens: Int = 0,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
)

@Serializable
@Entity(tableName = "subject_milestones")
data class SubjectMilestoneEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "subject_id") val subjectId: String,
    val title: String,
    @ColumnInfo(name = "is_completed") val isCompleted: Boolean = false,
    @ColumnInfo(name = "sort_order") val sortOrder: Int = 0,
    @ColumnInfo(name = "completed_at") val completedAt: Long? = null,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)
