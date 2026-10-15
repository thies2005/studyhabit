package de.schuelken.studyhabit.core.service

import de.schuelken.studyhabit.core.model.XpReason
import kotlin.math.roundToInt

data class LevelProgress(
    val currentLevel: Int,
    val levelName: String,
    val xpInLevel: Int,
    val xpNeededForBand: Int,
    val xpToNextLevel: Int,
    val progressPercent: Float,
)

object XpCalculator {
    const val XP_COMPLETE_POMODORO = 50
    const val XP_LONG_SESSION = 120
    const val XP_CONFIDENCE = 10
    const val XP_ADD_SOURCE = 5
    const val XP_SKILL_ADVANCE = 100
    const val XP_STREAK = 500
    const val XP_DAILY_GOAL = 75

    val LEVEL_NAMES = listOf(
        "Novice",
        "Apprentice",
        "Scholar",
        "Adept",
        "Expert",
        "Master",
        "Grandmaster"
    )

    fun xpForReason(reason: XpReason): Int = when (reason) {
        XpReason.COMPLETE_POMODORO -> XP_COMPLETE_POMODORO
        XpReason.LONG_SESSION -> XP_LONG_SESSION
        XpReason.CONFIDENCE -> XP_CONFIDENCE
        XpReason.ADD_SOURCE -> XP_ADD_SOURCE
        XpReason.SKILL_ADVANCE -> XP_SKILL_ADVANCE
        XpReason.STREAK_7 -> XP_STREAK
        XpReason.STREAK_30 -> XP_STREAK
        XpReason.STREAK_100 -> XP_STREAK
        XpReason.DAILY_GOAL -> XP_DAILY_GOAL
    }

    fun calculateLevel(totalXp: Int): Int {
        if (totalXp < 500) return 1
        if (totalXp < 1500) return 2
        if (totalXp < 3500) return 3
        if (totalXp < 7000) return 4
        if (totalXp < 10500) return 5

        var threshold = 10500
        var level = 6
        while (level < 100 && totalXp >= ((threshold * 1.5) / 100.0).roundToInt() * 100) {
            threshold = ((threshold * 1.5) / 100.0).roundToInt() * 100
            level++
        }
        return level
    }

    fun levelThreshold(level: Int): Int {
        if (level <= 1) return 0
        if (level == 2) return 500
        if (level == 3) return 1500
        if (level == 4) return 3500
        if (level == 5) return 7000
        var threshold = 10500
        for (l in 6 until level) {
            threshold = ((threshold * 1.5) / 100.0).roundToInt() * 100
        }
        return threshold
    }

    fun levelName(level: Int): String {
        val idx = (level.coerceAtLeast(1) - 1).coerceAtMost(LEVEL_NAMES.size - 1)
        return LEVEL_NAMES[idx]
    }

    fun xpToNextLevel(totalXp: Int): Int {
        val currentLevel = calculateLevel(totalXp)
        return (levelThreshold(currentLevel + 1) - totalXp).coerceAtLeast(0)
    }

    fun currentLevelXp(totalXp: Int): Int {
        val currentLevel = calculateLevel(totalXp)
        return (totalXp - levelThreshold(currentLevel)).coerceAtLeast(0)
    }

    fun currentLevelXpNeeded(totalXp: Int): Int {
        val currentLevel = calculateLevel(totalXp)
        return (levelThreshold(currentLevel + 1) - levelThreshold(currentLevel)).coerceAtLeast(1)
    }

    fun getLevelProgress(totalXp: Int): LevelProgress {
        val currentLevel = calculateLevel(totalXp)
        val currentFloor = levelThreshold(currentLevel)
        val nextCeiling = levelThreshold(currentLevel + 1)
        val xpInLevel = (totalXp - currentFloor).coerceAtLeast(0)
        val xpNeededForBand = (nextCeiling - currentFloor).coerceAtLeast(1)
        val xpToNext = (nextCeiling - totalXp).coerceAtLeast(0)
        val progressPercent = ((xpInLevel.toFloat() / xpNeededForBand.toFloat()) * 100f).coerceIn(0f, 100f)
        return LevelProgress(
            currentLevel = currentLevel,
            levelName = levelName(currentLevel),
            xpInLevel = xpInLevel,
            xpNeededForBand = xpNeededForBand,
            xpToNextLevel = xpToNext,
            progressPercent = progressPercent,
        )
    }
}
