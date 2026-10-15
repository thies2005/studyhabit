package de.schuelken.studyhabit.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class HierarchyMode(val value: String) {
    @SerialName("flat")
    FLAT("flat"),
    @SerialName("twoLevel")
    TWO_LEVEL("twoLevel"),
    @SerialName("threeLevel")
    THREE_LEVEL("threeLevel");

    companion object {
        fun fromValue(value: String): HierarchyMode =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: FLAT
    }
}

@Serializable
enum class SkillLevel(val value: String) {
    @SerialName("beginner")
    BEGINNER("beginner"),
    @SerialName("intermediate")
    INTERMEDIATE("intermediate"),
    @SerialName("advanced")
    ADVANCED("advanced"),
    @SerialName("expert")
    EXPERT("expert");

    companion object {
        fun fromValue(value: String): SkillLevel =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: BEGINNER
    }
}

@Serializable
enum class SourceType(val value: String) {
    @SerialName("pdf")
    PDF("pdf"),
    @SerialName("url")
    URL("url"),
    @SerialName("videoUrl")
    VIDEO_URL("videoUrl");

    companion object {
        fun fromValue(value: String): SourceType =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: PDF
    }
}

@Serializable
enum class CompletenessMode(val value: String) {
    @SerialName("none")
    NONE("none"),
    @SerialName("hoursGoal")
    HOURS_GOAL("hoursGoal"),
    @SerialName("milestones")
    MILESTONES("milestones"),
    @SerialName("weeklyHoursGoal")
    WEEKLY_HOURS_GOAL("weeklyHoursGoal");

    companion object {
        fun fromValue(value: String): CompletenessMode =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: NONE
    }
}

@Serializable
enum class TimerPhase(val value: String) {
    @SerialName("idle")
    IDLE("idle"),
    @SerialName("work")
    WORK("work"),
    @SerialName("shortBreak")
    SHORT_BREAK("shortBreak"),
    @SerialName("longBreak")
    LONG_BREAK("longBreak");

    companion object {
        fun fromValue(value: String): TimerPhase =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: IDLE
    }
}

@Serializable
enum class TimerType(val value: String) {
    @SerialName("pomodoro")
    POMODORO("pomodoro"),
    @SerialName("free")
    FREE_TIMER("free");

    companion object {
        fun fromValue(value: String?): TimerType =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: POMODORO
    }
}

@Serializable
enum class ImportMode {
    MERGE,
    REPLACE
}

@Serializable
enum class ThemeMode(val value: String) {
    @SerialName("system")
    SYSTEM("system"),
    @SerialName("light")
    LIGHT("light"),
    @SerialName("dark")
    DARK("dark");

    companion object {
        fun fromValue(value: String?): ThemeMode =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: SYSTEM
    }
}

enum class SyncStatus {
    IDLE,
    SYNCING,
    SYNCED,
    ERROR
}

enum class XpReason {
    COMPLETE_POMODORO,
    LONG_SESSION,
    CONFIDENCE,
    ADD_SOURCE,
    SKILL_ADVANCE,
    STREAK_7,
    STREAK_30,
    STREAK_100,
    DAILY_GOAL
}
