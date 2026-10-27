package de.schuelken.studyhabit

import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.model.XpReason
import de.schuelken.studyhabit.core.preferences.AppPreferences
import de.schuelken.studyhabit.core.service.StreakManager
import de.schuelken.studyhabit.core.service.XpCalculator
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

class XpAndStreakTest {

    private lateinit var fakeDao: FakeUserStatsDao
    private lateinit var fakePrefs: FakeSharedPreferences
    private lateinit var preferences: AppPreferences
    private lateinit var streakManager: StreakManager
    private val zone = ZoneId.systemDefault()

    @Before
    fun setup() {
        fakeDao = FakeUserStatsDao()
        fakePrefs = FakeSharedPreferences()
        preferences = AppPreferences(fakePrefs)
        preferences.gracePeriodHours = 0.0
        streakManager = StreakManager(fakeDao, preferences)
    }

    // =========================================================================
    // XpCalculator Tests
    // =========================================================================

    @Test
    fun testLevelProgressionBoundaries() {
        assertEquals(1, XpCalculator.calculateLevel(0))
        assertEquals(1, XpCalculator.calculateLevel(499))
        assertEquals(2, XpCalculator.calculateLevel(500))
        assertEquals(2, XpCalculator.calculateLevel(1499))
        assertEquals(3, XpCalculator.calculateLevel(1500))
        assertEquals(4, XpCalculator.calculateLevel(3500))
        assertEquals(5, XpCalculator.calculateLevel(7000))
        assertEquals(6, XpCalculator.calculateLevel(10500))
        assertEquals(7, XpCalculator.calculateLevel(15800))
    }

    @Test
    fun testLevelNames() {
        assertEquals("Novice", XpCalculator.levelName(1))
        assertEquals("Apprentice", XpCalculator.levelName(2))
        assertEquals("Scholar", XpCalculator.levelName(3))
        assertEquals("Adept", XpCalculator.levelName(4))
        assertEquals("Expert", XpCalculator.levelName(5))
        assertEquals("Master", XpCalculator.levelName(6))
        assertEquals("Grandmaster", XpCalculator.levelName(7))
        assertEquals("Grandmaster", XpCalculator.levelName(50))
    }

    @Test
    fun testXpForReasonsAndBonuses() {
        val pomodoroXp = XpCalculator.xpForReason(XpReason.COMPLETE_POMODORO)
        val longSessionXp = XpCalculator.xpForReason(XpReason.LONG_SESSION)
        val confidenceXp = XpCalculator.xpForReason(XpReason.CONFIDENCE)
        val sourceXp = XpCalculator.xpForReason(XpReason.ADD_SOURCE)
        val skillXp = XpCalculator.xpForReason(XpReason.SKILL_ADVANCE)
        val streakXp = XpCalculator.xpForReason(XpReason.STREAK_7)
        val dailyGoalXp = XpCalculator.xpForReason(XpReason.DAILY_GOAL)

        assertEquals(50, pomodoroXp)
        assertEquals(120, longSessionXp)
        assertEquals(10, confidenceXp)
        assertEquals(5, sourceXp)
        assertEquals(100, skillXp)
        assertEquals(500, streakXp)
        assertEquals(75, dailyGoalXp)

        // Session combination bonuses
        val standardSessionWithConfidence = pomodoroXp + confidenceXp
        assertEquals(60, standardSessionWithConfidence)

        val longSessionWithConfidence = longSessionXp + confidenceXp
        assertEquals(130, longSessionWithConfidence)
    }

    @Test
    fun testCalculateSessionXp() {
        // Free timer short (< 20 min) -> 0 base XP
        val shortFree = XpCalculator.calculateSessionXp(actualMinutes = 15, isPomodoro = false)
        assertEquals(0, shortFree)

        // Free timer >= 20 min (< 50 min) -> 50 XP
        val free25 = XpCalculator.calculateSessionXp(actualMinutes = 25, isPomodoro = false)
        assertEquals(50, free25)

        // Free timer 50 min -> 2 * 50 = 100 XP
        val free50 = XpCalculator.calculateSessionXp(actualMinutes = 50, isPomodoro = false)
        assertEquals(100, free50)

        // Pomodoro with completed count
        val pomodoro2 = XpCalculator.calculateSessionXp(actualMinutes = 50, isPomodoro = true, pomodorosCompleted = 2)
        assertEquals(100, pomodoro2)

        // Pomodoro without completed count, but studied >= 80%
        val pomodoroPartialSuccess = XpCalculator.calculateSessionXp(
            actualMinutes = 20,
            isPomodoro = true,
            pomodorosCompleted = 0,
            plannedSeconds = 1500, // 25 min
            studiedSeconds = 1250  // > 80% (1200s)
        )
        assertEquals(50, pomodoroPartialSuccess)

        // Pomodoro stopped early (< 80%)
        val pomodoroFailed = XpCalculator.calculateSessionXp(
            actualMinutes = 10,
            isPomodoro = true,
            pomodorosCompleted = 0,
            plannedSeconds = 1500,
            studiedSeconds = 600
        )
        assertEquals(0, pomodoroFailed)

        // Long session bonus (>= 120 min)
        val longSession = XpCalculator.calculateSessionXp(
            actualMinutes = 120,
            isPomodoro = false
        )
        // 120 min: (120/25 = 4)*50 = 200 + 120 long session bonus = 320
        assertEquals(320, longSession)

        // High confidence rating (>= 4) adds 10 XP
        val withConfidence = XpCalculator.calculateSessionXp(
            actualMinutes = 25,
            confidence = 5,
            isPomodoro = false
        )
        assertEquals(60, withConfidence)

        // Low confidence rating (< 4) adds no bonus
        val lowConfidence = XpCalculator.calculateSessionXp(
            actualMinutes = 25,
            confidence = 3,
            isPomodoro = false
        )
        assertEquals(50, lowConfidence)
    }

    @Test
    fun testLevelProgressCalculation() {
        val progress0 = XpCalculator.getLevelProgress(0)
        assertEquals(1, progress0.currentLevel)
        assertEquals("Novice", progress0.levelName)
        assertEquals(0, progress0.xpInLevel)
        assertEquals(500, progress0.xpNeededForBand)
        assertEquals(500, progress0.xpToNextLevel)
        assertEquals(0.0f, progress0.progressPercent, 0.01f)

        val progressMid = XpCalculator.getLevelProgress(250)
        assertEquals(250, progressMid.xpInLevel)
        assertEquals(50.0f, progressMid.progressPercent, 0.01f)

        val progressBand2 = XpCalculator.getLevelProgress(1000)
        assertEquals(2, progressBand2.currentLevel)
        assertEquals("Apprentice", progressBand2.levelName)
        assertEquals(500, progressBand2.xpInLevel)
        assertEquals(1000, progressBand2.xpNeededForBand)
        assertEquals(500, progressBand2.xpToNextLevel)
        assertEquals(50.0f, progressBand2.progressPercent, 0.01f)
    }

    // =========================================================================
    // StreakManager Tests
    // =========================================================================

    @Test
    fun testFirstStudyDayInitializesStreak() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 1)
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()

        val stats = streakManager.recordStudyDay(day1Ms)
        assertEquals(1, stats.currentStreak)
        assertEquals(1, stats.longestStreak)
        assertEquals(0, stats.freezeTokens)
        assertNotNull(stats.lastStudyDate)
    }

    @Test
    fun testSameDayStudyPreservesStreak() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 1)
        val morningMs = day1.atTime(8, 0).atZone(zone).toInstant().toEpochMilli()
        val afternoonMs = day1.atTime(14, 0).atZone(zone).toInstant().toEpochMilli()

        streakManager.recordStudyDay(morningMs)
        val updated = streakManager.recordStudyDay(afternoonMs)

        assertEquals(1, updated.currentStreak)
        assertEquals(1, updated.longestStreak)
    }

    @Test
    fun testClockSkewOrWestwardTimezonePreservesStreakWithoutReset() = runBlocking {
        // Suppose user studied on Oct 2nd
        val day2 = LocalDate.of(2026, 10, 2)
        val day2Ms = day2.atStartOfDay(zone).toInstant().toEpochMilli()
        fakeDao.stats = UserStatsEntity(
            currentStreak = 5,
            longestStreak = 5,
            lastStudyDate = day2Ms,
            freezeTokens = 0
        )

        // Then device clock skewed backward to Oct 1st or user traveled westward (daysDiff = -1 <= 0)
        val day1 = LocalDate.of(2026, 10, 1)
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()

        val updated = streakManager.recordStudyDay(day1Ms)

        // Streak must NOT be reset to 1, should be preserved as 5
        assertEquals(5, updated.currentStreak)
        assertEquals(5, updated.longestStreak)
        // lastStudyDate should remain the later date (day2Ms)
        assertEquals(day2Ms, updated.lastStudyDate)
    }

    @Test
    fun testConsecutiveDayStudyIncrementsStreak() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 1)
        val day2 = LocalDate.of(2026, 10, 2)
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()
        val day2Ms = day2.atStartOfDay(zone).toInstant().toEpochMilli()

        streakManager.recordStudyDay(day1Ms)
        val updated = streakManager.recordStudyDay(day2Ms)

        assertEquals(2, updated.currentStreak)
        assertEquals(2, updated.longestStreak)
    }

    @Test
    fun testTwoDayGapWithFreezeTokenConsumesTokenAndSavesStreak() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 1)
        val day3 = LocalDate.of(2026, 10, 3) // Skipped Oct 2nd
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()
        val day3Ms = day3.atStartOfDay(zone).toInstant().toEpochMilli()

        fakeDao.stats = UserStatsEntity(
            currentStreak = 4,
            longestStreak = 4,
            lastStudyDate = day1Ms,
            freezeTokens = 2
        )

        val updated = streakManager.recordStudyDay(day3Ms)

        assertEquals(5, updated.currentStreak)
        assertEquals(1, updated.freezeTokens)
        assertEquals("2026-10-03", preferences.lastFreezeUseDate)
    }

    @Test
    fun testTwoDayGapWithinSevenDayCooldownFailsFreezeAndResetsStreak() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 5)
        val day3 = LocalDate.of(2026, 10, 7) // 2 days gap
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()
        val day3Ms = day3.atStartOfDay(zone).toInstant().toEpochMilli()

        // Previously used freeze on Oct 3rd (< 7 days ago)
        preferences.lastFreezeUseDate = "2026-10-03"

        fakeDao.stats = UserStatsEntity(
            currentStreak = 10,
            longestStreak = 10,
            lastStudyDate = day1Ms,
            freezeTokens = 2
        )

        val updated = streakManager.recordStudyDay(day3Ms)

        // Cannot use freeze due to 7-day cooldown
        assertEquals(1, updated.currentStreak)
        assertEquals(2, updated.freezeTokens) // token was not consumed
        assertEquals(10, updated.longestStreak)
    }

    @Test
    fun testTwoDayGapWithoutFreezeTokensResetsStreak() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 1)
        val day3 = LocalDate.of(2026, 10, 3)
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()
        val day3Ms = day3.atStartOfDay(zone).toInstant().toEpochMilli()

        fakeDao.stats = UserStatsEntity(
            currentStreak = 7,
            longestStreak = 7,
            lastStudyDate = day1Ms,
            freezeTokens = 0
        )

        val updated = streakManager.recordStudyDay(day3Ms)
        assertEquals(1, updated.currentStreak)
        assertEquals(7, updated.longestStreak)
    }

    @Test
    fun testTenStreakAwardsFreezeToken() = runBlocking {
        val day9 = LocalDate.of(2026, 10, 9)
        val day10 = LocalDate.of(2026, 10, 10)
        val day9Ms = day9.atStartOfDay(zone).toInstant().toEpochMilli()
        val day10Ms = day10.atStartOfDay(zone).toInstant().toEpochMilli()

        fakeDao.stats = UserStatsEntity(
            currentStreak = 9,
            longestStreak = 9,
            lastStudyDate = day9Ms,
            freezeTokens = 0
        )

        val updated = streakManager.recordStudyDay(day10Ms)
        assertEquals(10, updated.currentStreak)
        assertEquals(1, updated.freezeTokens)
    }

    @Test
    fun testAwardXpCalledAtStreakMilestones() = runBlocking {
        val day6 = LocalDate.of(2026, 10, 6)
        val day7 = LocalDate.of(2026, 10, 7)
        val day6Ms = day6.atStartOfDay(zone).toInstant().toEpochMilli()
        val day7Ms = day7.atStartOfDay(zone).toInstant().toEpochMilli()

        fakeDao.stats = UserStatsEntity(
            currentStreak = 6,
            longestStreak = 6,
            lastStudyDate = day6Ms
        )

        val awarded = mutableListOf<XpReason>()
        streakManager.recordStudyDay(day7Ms) { reason ->
            awarded.add(reason)
        }

        assertTrue(awarded.contains(XpReason.STREAK_7))
    }

    @Test
    fun testEvaluateCurrentStreakKillsDeadStreak() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 1)
        val day5 = LocalDate.of(2026, 10, 5) // 4 day gap
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()
        val day5Ms = day5.atStartOfDay(zone).toInstant().toEpochMilli()

        fakeDao.stats = UserStatsEntity(
            currentStreak = 5,
            longestStreak = 5,
            lastStudyDate = day1Ms,
            freezeTokens = 0
        )

        val result = streakManager.evaluateCurrentStreak(day5Ms)
        assertNotNull(result)
        assertEquals(0, result?.currentStreak)
    }

    @Test
    fun testEvaluateCurrentStreakDoesNotKillActiveStreak() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 1)
        val day2 = LocalDate.of(2026, 10, 2) // 1 day gap (still valid)
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()
        val day2Ms = day2.atStartOfDay(zone).toInstant().toEpochMilli()

        fakeDao.stats = UserStatsEntity(
            currentStreak = 5,
            longestStreak = 5,
            lastStudyDate = day1Ms
        )

        val result = streakManager.evaluateCurrentStreak(day2Ms)
        assertNull(result)
    }
}
