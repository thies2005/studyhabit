package de.schuelken.studyhabit.core.service

import de.schuelken.studyhabit.core.database.AchievementEntity
import de.schuelken.studyhabit.core.database.AppDatabase
import de.schuelken.studyhabit.core.database.dao.AchievementDao
import de.schuelken.studyhabit.core.database.dao.SessionDao
import de.schuelken.studyhabit.core.database.dao.SkillLabelDao
import de.schuelken.studyhabit.core.database.dao.SourceDao
import de.schuelken.studyhabit.core.database.dao.UserStatsDao
import java.time.Instant
import java.time.ZoneId

class AchievementEvaluator(
    private val sessionDao: SessionDao,
    private val userStatsDao: UserStatsDao,
    private val sourceDao: SourceDao,
    private val skillLabelDao: SkillLabelDao,
    private val achievementDao: AchievementDao
) {
    constructor(database: AppDatabase) : this(
        database.sessionDao(),
        database.userStatsDao(),
        database.sourceDao(),
        database.skillLabelDao(),
        database.achievementDao()
    )

    suspend fun checkAndUnlock(): List<AchievementEntity> {
        val allSessions = sessionDao.getAllSessions()
        val stats = userStatsDao.getUserStats()
        val allSources = sourceDao.getAllSources()
        val allSkillLabels = skillLabelDao.getAllSkillLabels()

        val pdfSources = allSources.filter { it.type.equals("pdf", ignoreCase = true) }
        val advancedSkillRows = allSkillLabels.filter {
            it.label.equals("advanced", ignoreCase = true) || it.label.equals("expert", ignoreCase = true)
        }

        val totalPomodoros = allSessions.sumOf { it.pomodorosCompleted }
        val totalMinutes = allSessions.sumOf { it.actualDurationMinutes }
        val totalHours = totalMinutes / 60.0
        val currentStreak = stats?.currentStreak ?: 0

        val ratedSessions = allSessions.filter { (it.confidenceRating ?: 0) >= 5 }

        val subjectsWithMinutes = mutableMapOf<String, Int>()
        val subjectsWithHighConfidence = mutableMapOf<String, Int>()
        var freeTimerCount = 0
        var longSession2h = 0
        var longSession3h = 0
        var longSession5h = 0
        var sessionsBefore7am = 0
        var sessionsAfter10pm = 0
        var maxContinuousSession = 0

        val zone = ZoneId.systemDefault()
        for (s in allSessions) {
            subjectsWithMinutes[s.subjectId] = (subjectsWithMinutes[s.subjectId] ?: 0) + s.actualDurationMinutes
            if ((s.confidenceRating ?: 0) >= 5) {
                subjectsWithHighConfidence[s.subjectId] = (subjectsWithHighConfidence[s.subjectId] ?: 0) + 1
            }
            if (s.isFreeTimer) freeTimerCount++
            if (s.actualDurationMinutes >= 120) longSession2h++
            if (s.actualDurationMinutes >= 180) longSession3h++
            if (s.actualDurationMinutes >= 300) longSession5h++

            val hour = Instant.ofEpochMilli(s.startedAt).atZone(zone).hour
            if (hour < 7) sessionsBefore7am++
            if (hour >= 22) sessionsAfter10pm++

            if (s.actualDurationMinutes > maxContinuousSession) {
                maxContinuousSession = s.actualDurationMinutes
            }
        }

        val subjectsOver5h = subjectsWithMinutes.values.count { it >= 300 }
        val subjectsOver10h = subjectsWithMinutes.values.count { it >= 600 }

        val checks = mutableMapOf<String, Double>(
            // Streaks
            "streak_3" to (currentStreak / 3.0).coerceIn(0.0, 1.0),
            "streak_7" to (currentStreak / 7.0).coerceIn(0.0, 1.0),
            "streak_14" to (currentStreak / 14.0).coerceIn(0.0, 1.0),
            "streak_30" to (currentStreak / 30.0).coerceIn(0.0, 1.0),
            "streak_50" to (currentStreak / 50.0).coerceIn(0.0, 1.0),
            "streak_100" to (currentStreak / 100.0).coerceIn(0.0, 1.0),
            "streak_200" to (currentStreak / 200.0).coerceIn(0.0, 1.0),
            "streak_365" to (currentStreak / 365.0).coerceIn(0.0, 1.0),

            // Pomodoros
            "pomodoro_10" to (totalPomodoros / 10.0).coerceIn(0.0, 1.0),
            "pomodoro_25" to (totalPomodoros / 25.0).coerceIn(0.0, 1.0),
            "pomodoro_50" to (totalPomodoros / 50.0).coerceIn(0.0, 1.0),
            "pomodoro_100" to (totalPomodoros / 100.0).coerceIn(0.0, 1.0),
            "pomodoro_250" to (totalPomodoros / 250.0).coerceIn(0.0, 1.0),
            "pomodoro_500" to (totalPomodoros / 500.0).coerceIn(0.0, 1.0),
            "pomodoro_1000" to (totalPomodoros / 1000.0).coerceIn(0.0, 1.0),
            "pomodoro_2500" to (totalPomodoros / 2500.0).coerceIn(0.0, 1.0),
            "pomodoro_5000" to (totalPomodoros / 5000.0).coerceIn(0.0, 1.0),

            // Hours
            "hours_10" to (totalHours / 10.0).coerceIn(0.0, 1.0),
            "hours_25" to (totalHours / 25.0).coerceIn(0.0, 1.0),
            "hours_50" to (totalHours / 50.0).coerceIn(0.0, 1.0),
            "hours_100" to (totalHours / 100.0).coerceIn(0.0, 1.0),
            "hours_200" to (totalHours / 200.0).coerceIn(0.0, 1.0),
            "hours_500" to (totalHours / 500.0).coerceIn(0.0, 1.0),
            "hours_1000" to (totalHours / 1000.0).coerceIn(0.0, 1.0),

            // Sessions
            "sessions_5" to (allSessions.size / 5.0).coerceIn(0.0, 1.0),
            "sessions_20" to (allSessions.size / 20.0).coerceIn(0.0, 1.0),
            "sessions_50" to (allSessions.size / 50.0).coerceIn(0.0, 1.0),
            "sessions_100" to (allSessions.size / 100.0).coerceIn(0.0, 1.0),
            "sessions_250" to (allSessions.size / 250.0).coerceIn(0.0, 1.0),
            "sessions_500" to (allSessions.size / 500.0).coerceIn(0.0, 1.0),

            // Subject milestones
            "subject_5h" to if (subjectsOver5h > 0) 1.0 else 0.0,
            "subjects_2_5h" to (subjectsOver5h / 2.0).coerceIn(0.0, 1.0),
            "subjects_5_5h" to (subjectsOver5h / 5.0).coerceIn(0.0, 1.0),
            "subject_10h" to if (subjectsOver10h > 0) 1.0 else 0.0,
            "subjects_3_10h" to (subjectsOver10h / 3.0).coerceIn(0.0, 1.0),
            "subjects_5_10h" to (subjectsOver10h / 5.0).coerceIn(0.0, 1.0),

            // Free timer
            "free_timer_first" to if (freeTimerCount > 0) 1.0 else 0.0,
            "free_timer_10" to (freeTimerCount / 10.0).coerceIn(0.0, 1.0),
            "free_timer_30m" to if (maxContinuousSession >= 30) 1.0 else 0.0,
            "free_timer_2h" to if (maxContinuousSession >= 120) 1.0 else 0.0,

            // Long sessions
            "long_session_2h" to if (longSession2h > 0) 1.0 else 0.0,
            "long_session_3h" to if (longSession3h > 0) 1.0 else 0.0,
            "long_session_5h" to if (longSession5h > 0) 1.0 else 0.0,

            // Confidence
            "confidence_5" to if (ratedSessions.isNotEmpty()) 1.0 else 0.0,
            "confidence_10" to (ratedSessions.size / 10.0).coerceIn(0.0, 1.0),
            "confidence_50" to (ratedSessions.size / 50.0).coerceIn(0.0, 1.0),
            "all_5stars_3" to if (subjectsWithHighConfidence.values.any { it >= 3 }) 1.0 else 0.0,

            // Sources
            "first_pdf" to if (pdfSources.isNotEmpty()) 1.0 else 0.0,
            "sources_5" to (pdfSources.size / 5.0).coerceIn(0.0, 1.0),
            "sources_10" to (pdfSources.size / 10.0).coerceIn(0.0, 1.0),

            // Skill
            "skill_advanced" to if (advancedSkillRows.isNotEmpty()) 1.0 else 0.0,
            "skill_expert" to if (allSkillLabels.any { it.label.equals("expert", ignoreCase = true) }) 1.0 else 0.0,

            // Night/Day
            "night_owl" to if (sessionsAfter10pm > 0) 1.0 else 0.0,
            "early_bird" to if (sessionsBefore7am > 0) 1.0 else 0.0,
        )

        // all_badges calculation
        val earnedCount = checks.values.count { it >= 1.0 }
        checks["all_badges"] = (earnedCount.toDouble() / checks.size.toDouble()).coerceIn(0.0, 1.0)

        val existingAchievements = achievementDao.getAllAchievements().associateBy { it.key }
        val newlyUnlocked = mutableListOf<AchievementEntity>()
        val now = System.currentTimeMillis()

        for ((key, progress) in checks) {
            val existing = existingAchievements[key]
            val isUnlocked = progress >= 1.0
            val unlockedAt = if (isUnlocked) (existing?.unlockedAt ?: now) else existing?.unlockedAt

            val entity = AchievementEntity(
                key = key,
                unlockedAt = unlockedAt,
                progress = progress,
                updatedAt = now,
            )
            achievementDao.upsert(entity)

            if (isUnlocked && (existing == null || existing.unlockedAt == null)) {
                newlyUnlocked.add(entity)
            }
        }

        return newlyUnlocked
    }
}
