package de.schuelken.studyhabit

import de.schuelken.studyhabit.core.service.*
import de.schuelken.studyhabit.core.model.*
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.theme.*
import kotlinx.serialization.encodeToString
import org.junit.Assert.*
import org.junit.Test

class AuditRegressionTest {
    private fun work() = TimerState(isRunning = true, phase = TimerPhase.WORK,
        totalSeconds = 1500, workDurationSeconds = 1500, shortBreakSeconds = 300)
    private fun advance(s: TimerState) = TimerAccounting.advance(s, 900, 4, false, false)
    @Test fun earlySkipNeverInventsTimeOrCompletion() {
        val skipped = advance(TimerAccounting.snapshot(work(), 249, 0))
        assertEquals(249, skipped.totalWorkSeconds)
        assertEquals(0, skipped.pomodorosCompleted)
        assertEquals(TimerPhase.SHORT_BREAK, skipped.phase)
    }
    @Test fun completedFourthPhaseEarnsLongBreak() {
        val done = advance(TimerAccounting.snapshot(work().copy(pomodorosCompleted = 3), 1500, 4500))
        assertEquals(TimerPhase.LONG_BREAK, done.phase)
        assertEquals(6000, done.totalWorkSeconds)
        assertEquals(4, done.pomodorosCompleted)
    }
    @Test fun skipAfterFourthCompletionDoesNotRepeatLongBreak() {
        assertEquals(TimerPhase.SHORT_BREAK, advance(TimerAccounting.snapshot(work().copy(pomodorosCompleted = 4), 1, 6000)).phase)
    }
    @Test fun breakTimeNeverAddsStudyTimeAndSelectedDurationSurvives() {
        val pausedBreak = advance(TimerAccounting.snapshot(work(), 249, 0))
        val next = advance(TimerAccounting.snapshot(pausedBreak, 200, 249))
        assertEquals(249, next.totalWorkSeconds)
        assertEquals(1500, next.totalSeconds)
        assertEquals(1500, next.plannedWorkSeconds)
    }
    @Test fun recoverySeparatesPriorWorkAndCurrentOvertime() {
        val snapshot = TimerAccounting.snapshot(work(), 1600, 1500)
        assertEquals(1500, TimerAccounting.priorWorkSeconds(snapshot))
        val restored = TimerAccounting.snapshot(snapshot.copy(isPaused = true), 1600, TimerAccounting.priorWorkSeconds(snapshot))
        assertEquals(3100, advance(restored).totalWorkSeconds)
        assertEquals(100, restored.overtimeSeconds)
    }
    @Test fun invalidDurationAndReductionCannotBeAccepted() {
        for (v in listOf("", "0", "721", "99999999999999999")) assertNull(StudyDurationInput.minutes(v))
        assertEquals(720, StudyDurationInput.minutes("720"))
        assertNull(StudyDurationInput.reduction("25", 25))
        assertNull(StudyDurationInput.reduction("99999999999999", 25))
        assertEquals(24, StudyDurationInput.reduction("24", 25))
    }
    @Test fun backupSchemaAndVersionAreValidated() {
        val doc = ExportDocument(exportedAt = "2026-10-31", userStats = UserStatsEntity(), projects = emptyList(), achievements = emptyList())
        for (version in listOf(1, 2)) assertEquals(version, BackupCodec.decode(BackupCodec.json.encodeToString(doc.copy(exportVersion = version))).exportVersion)
        for (invalid in listOf("{", "{}", "{\"qa_invalid_backup\":true}", BackupCodec.json.encodeToString(doc.copy(exportVersion = 3)))) {
            assertTrue(runCatching { BackupCodec.decode(invalid) }.isFailure)
        }
    }
    @Test fun urlsRequireSupportedSchemeAndHostButAllowLocalServers() {
        for (url in listOf("https://example.com/book", "http://localhost:3000", "http://study-server/book")) assertTrue(SourceValidation.isWebUrl(url))
        for (url in listOf("", "not-a-url", "javascript:alert(1)", "https://", "https://user:password@example.com")) assertFalse(SourceValidation.isWebUrl(url))
    }
    @Test fun presetsAddWithoutDiscardingManualSelections() {
        assertTrue(BlockerPresets.isSocial("com.instagram.android", false))
        assertTrue(BlockerPresets.isSocial("social.example", true))
        assertFalse(BlockerPresets.isSocial("com.android.calendar", false))
        assertEquals(setOf("manual", "social"), BlockerPresets.select(setOf("manual"), setOf("social")))
        assertEquals(setOf("manual"), BlockerPresets.select(setOf("manual"), emptySet()))
    }
    @Test fun allSeedPalettesHaveReadablePrimaryPairs() {
        for (seed in AppThemeTokens.presetSeeds + AppThemeTokens.curatedPalettes.map { it.seedColor }) for (dark in listOf(true, false)) {
            val scheme = seedColorScheme(seed, dark)
            for (background in listOf(scheme.background, scheme.surface, scheme.surfaceVariant, scheme.primaryContainer)) assertTrue(contrastRatio(scheme.primary, background) >= 4.5f)
            assertTrue(contrastRatio(scheme.onPrimary, scheme.primary) >= 4.5f)
        }
    }
}
