package de.schuelken.studyhabit

import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.service.SessionEditHelper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class SessionEditHelperTest {

    private fun createSession(
        isFreeTimer: Boolean = false,
        plannedMinutes: Int = 25,
        actualMinutes: Int = 25,
        confidence: Int? = 4
    ): StudySessionEntity {
        return StudySessionEntity(
            id = UUID.randomUUID().toString(),
            subjectId = "subj-1",
            startedAt = 1000L,
            endedAt = 1000L + actualMinutes * 60_000L,
            actualDurationMinutes = actualMinutes,
            plannedDurationMinutes = plannedMinutes,
            isFreeTimer = isFreeTimer,
            pomodorosCompleted = if (!isFreeTimer && actualMinutes >= plannedMinutes) 1 else 0,
            confidenceRating = confidence,
            xpEarned = 60
        )
    }

    @Test
    fun testPomodoroEffectiveCountAboveEightyPercentThreshold() {
        // 25-minute Pomodoro:
        // 80% of 25m = 20m.
        // 25m -> 1 pomodoro
        assertEquals(1, SessionEditHelper.calculateEffectivePomodoros(false, 25, 25))

        // 20m -> hits 80% threshold -> 1 pomodoro
        assertEquals(1, SessionEditHelper.calculateEffectivePomodoros(false, 25, 20))

        // 21m -> hits 80% threshold -> 1 pomodoro
        assertEquals(1, SessionEditHelper.calculateEffectivePomodoros(false, 25, 21))

        // 19m -> strictly below 80% (19/25 = 76%) -> 0 pomodoros
        assertEquals(0, SessionEditHelper.calculateEffectivePomodoros(false, 25, 19))

        // 10m -> 0 pomodoros
        assertEquals(0, SessionEditHelper.calculateEffectivePomodoros(false, 25, 10))
    }

    @Test
    fun testPomodoroEffectiveCountMultiplePomodoros() {
        // 25-minute Pomodoro expanded:
        // 50m / 25m = 2 pomodoros
        assertEquals(2, SessionEditHelper.calculateEffectivePomodoros(false, 25, 50))

        // 60m / 25m = 2 pomodoros
        assertEquals(2, SessionEditHelper.calculateEffectivePomodoros(false, 25, 60))

        // 75m / 25m = 3 pomodoros
        assertEquals(3, SessionEditHelper.calculateEffectivePomodoros(false, 25, 75))
    }

    @Test
    fun testFreeTimerAlwaysZeroEffectivePomodoros() {
        assertEquals(0, SessionEditHelper.calculateEffectivePomodoros(true, 0, 25))
        assertEquals(0, SessionEditHelper.calculateEffectivePomodoros(true, 0, 60))
        assertEquals(0, SessionEditHelper.calculateEffectivePomodoros(true, 25, 50))
    }

    @Test
    fun testXpRecalculationOnTrimmingSession() {
        val session = createSession(isFreeTimer = false, plannedMinutes = 25, actualMinutes = 25, confidence = 4)

        // 25m with 4 stars:
        // 1 pomodoro complete (50 XP) + confidence rating >= 4 (10 XP) = 60 XP
        val originalXp = SessionEditHelper.calculateSessionXp(session, 25, 4)
        assertEquals(60, originalXp)

        // Trim to 20m (hits 80% threshold -> 1 pomodoro = 50 XP + 10 XP confidence = 60 XP)
        val trimmed20Xp = SessionEditHelper.calculateSessionXp(session, 20, 4)
        assertEquals(60, trimmed20Xp)

        // Trim to 15m (drops below 80% threshold -> 0 pomodoros + 10 XP confidence = 10 XP)
        val trimmed15Xp = SessionEditHelper.calculateSessionXp(session, 15, 4)
        assertEquals(10, trimmed15Xp)

        // Trim to 15m with lower confidence rating (2 stars -> 0 confidence XP -> 0 XP)
        val trimmed15LowConfXp = SessionEditHelper.calculateSessionXp(session, 15, 2)
        assertEquals(0, trimmed15LowConfXp)

        assertTrue(trimmed15Xp < originalXp)
        assertTrue(trimmed15LowConfXp < trimmed15Xp)
    }

    @Test
    fun testXpRecalculationOnExpandingSession() {
        val session = createSession(isFreeTimer = false, plannedMinutes = 25, actualMinutes = 25, confidence = 5)

        // Expanding to 50m (2 completed pomodoros = 2 * 50 = 100 XP + 10 XP confidence = 110 XP)
        val expanded50Xp = SessionEditHelper.calculateSessionXp(session, 50, 5)
        assertEquals(110, expanded50Xp)

        // Expanding to 125m (5 pomodoros = 250 XP + 120 XP long session + 10 XP confidence = 380 XP)
        val expanded125Xp = SessionEditHelper.calculateSessionXp(session, 125, 5)
        assertEquals(380, expanded125Xp)
    }

    @Test
    fun testFreeTimerXpRecalculation() {
        val freeSession = createSession(isFreeTimer = true, plannedMinutes = 0, actualMinutes = 30, confidence = 4)

        // Free timer < 20 min -> 0 XP + 10 XP confidence = 10 XP
        val shortFreeXp = SessionEditHelper.calculateSessionXp(freeSession, 15, 4)
        assertEquals(10, shortFreeXp)

        // Free timer 25 min -> (25/25) * 50 = 50 + 10 = 60 XP
        val free25Xp = SessionEditHelper.calculateSessionXp(freeSession, 25, 4)
        assertEquals(60, free25Xp)

        // Free timer 60 min -> (60/25) * 50 = 2 * 50 = 100 + 10 = 110 XP
        val free60Xp = SessionEditHelper.calculateSessionXp(freeSession, 60, 4)
        assertEquals(110, free60Xp)
    }

    @Test
    fun testMinutesClamping() {
        // Less than 1 minute clamps to 1
        assertEquals(1, SessionEditHelper.calculateEffectivePomodoros(false, 1, 0))
        val session = createSession(actualMinutes = 25)
        val clampedMinXp = SessionEditHelper.calculateSessionXp(session, -10, 3)
        val oneMinXp = SessionEditHelper.calculateSessionXp(session, 1, 3)
        assertEquals(oneMinXp, clampedMinXp)

        // More than 720 minutes clamps to 720
        val clampedMaxXp = SessionEditHelper.calculateSessionXp(session, 1000, 3)
        val max720Xp = SessionEditHelper.calculateSessionXp(session, 720, 3)
        assertEquals(max720Xp, clampedMaxXp)
    }
}
