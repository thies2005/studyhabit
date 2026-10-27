package de.schuelken.studyhabit.core.service

import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.database.dao.UserStatsDao
import de.schuelken.studyhabit.core.model.XpReason
import de.schuelken.studyhabit.core.preferences.AppPreferences
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

class StreakManager(
    private val userStatsDao: UserStatsDao,
    private val preferences: AppPreferences,
) {
    suspend fun recordStudyDay(
        nowMillis: Long = System.currentTimeMillis(),
        awardXp: (suspend (XpReason) -> Unit)? = null
    ): UserStatsEntity {
        val stats = userStatsDao.getUserStats() ?: UserStatsEntity()
        val graceHours = preferences.gracePeriodHours
        val effectiveNow = nowMillis - (graceHours * 3600_000.0).toLong()
        val zone = ZoneId.systemDefault()
        val today = Instant.ofEpochMilli(effectiveNow).atZone(zone).toLocalDate()

        val lastStudyDate = stats.lastStudyDate?.let {
            Instant.ofEpochMilli(it).atZone(zone).toLocalDate()
        }

        var newStreak = stats.currentStreak
        var usedFreeze = false
        var daysDiff = 0

        if (lastStudyDate == null) {
            newStreak = 1
            daysDiff = 1
        } else {
            daysDiff = ChronoUnit.DAYS.between(lastStudyDate, today).toInt()
            when {
                daysDiff <= 0 -> {
                    newStreak = stats.currentStreak
                }
                daysDiff == 1 -> {
                    newStreak = stats.currentStreak + 1
                }
                daysDiff == 2 && stats.freezeTokens > 0 -> {
                    val lastFreezeStr = preferences.lastFreezeUseDate
                    val lastFreezeDate = lastFreezeStr?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
                    val canUseFreeze = lastFreezeDate == null || ChronoUnit.DAYS.between(lastFreezeDate, today) >= 7

                    if (canUseFreeze) {
                        usedFreeze = true
                        newStreak = stats.currentStreak + 1
                        preferences.lastFreezeUseDate = today.toString()
                    } else {
                        newStreak = 1
                    }
                }
                else -> {
                    newStreak = 1
                }
            }
        }

        var freezeTokens = stats.freezeTokens
        if (usedFreeze) {
            freezeTokens = (freezeTokens - 1).coerceAtLeast(0)
        }

        if (newStreak > 0 && newStreak % 10 == 0 && stats.currentStreak < newStreak) {
            freezeTokens++
        }

        val newLongest = maxOf(newStreak, stats.longestStreak)
        val todayEpochDayMs = today.atStartOfDay(zone).toInstant().toEpochMilli()

        val updatedStats = stats.copy(
            currentStreak = newStreak,
            longestStreak = newLongest,
            lastStudyDate = if (daysDiff > 0) todayEpochDayMs else stats.lastStudyDate,
            freezeTokens = freezeTokens,
            updatedAt = System.currentTimeMillis()
        )

        userStatsDao.upsert(updatedStats)

        if (awardXp != null) {
            if (newStreak >= 7 && stats.currentStreak < 7) {
                awardXp(XpReason.STREAK_7)
            }
            if (newStreak >= 30 && stats.currentStreak < 30) {
                awardXp(XpReason.STREAK_30)
            }
            if (newStreak >= 100 && stats.currentStreak < 100) {
                awardXp(XpReason.STREAK_100)
            }
        }

        return updatedStats
    }

    suspend fun evaluateCurrentStreak(nowMillis: Long = System.currentTimeMillis()): UserStatsEntity? {
        val stats = userStatsDao.getUserStats() ?: return null
        if (stats.lastStudyDate == null || stats.currentStreak == 0) return null

        val graceHours = preferences.gracePeriodHours
        val effectiveNow = nowMillis - (graceHours * 3600_000.0).toLong()
        val zone = ZoneId.systemDefault()
        val today = Instant.ofEpochMilli(effectiveNow).atZone(zone).toLocalDate()
        val lastStudy = Instant.ofEpochMilli(stats.lastStudyDate).atZone(zone).toLocalDate()

        val daysDiff = ChronoUnit.DAYS.between(lastStudy, today).toInt()
        var isDead = false

        if (daysDiff > 2) {
            isDead = true
        } else if (daysDiff == 2 && stats.freezeTokens <= 0) {
            isDead = true
        } else if (daysDiff == 2 && stats.freezeTokens > 0) {
            val lastFreezeStr = preferences.lastFreezeUseDate
            val lastFreezeDate = lastFreezeStr?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
            if (lastFreezeDate != null && ChronoUnit.DAYS.between(lastFreezeDate, today) < 7) {
                isDead = true
            }
        }

        if (isDead) {
            val resetStats = stats.copy(
                currentStreak = 0,
                updatedAt = System.currentTimeMillis()
            )
            userStatsDao.upsert(resetStats)
            return resetStats
        }
        return null
    }
}
