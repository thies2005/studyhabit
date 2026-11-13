package de.schuelken.studyhabit

import de.schuelken.studyhabit.core.service.*
import de.schuelken.studyhabit.core.model.*
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.preferences.AppPreferences
import de.schuelken.studyhabit.core.theme.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.JsonPrimitive
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
            for (background in listOf(scheme.background, scheme.surface, scheme.surfaceVariant, scheme.primaryContainer)) {
                assertTrue(contrastRatio(scheme.primary, background) >= 4.5f)
                assertTrue(contrastRatio(scheme.tertiary, background) >= 4.5f)
            }
            assertTrue(contrastRatio(scheme.tertiary, scheme.tertiaryContainer) >= 4.5f)
            assertTrue(contrastRatio(scheme.onPrimary, scheme.primary) >= 4.5f)
            assertTrue(contrastRatio(scheme.onTertiary, scheme.tertiary) >= 4.5f)
        }
    }

    @Test fun appPreferencesExcludeBlockerKeysAndClampNumericSettings() {
        val prefs = AppPreferences(FakeSharedPreferences())

        // Blocker defaults and local-only privacy
        assertFalse(prefs.appBlockerEnabled)
        assertFalse(prefs.blockerDisclosureAccepted)
        assertFalse(AppPreferences.isAllowedSettingKey(AppPreferences.PREF_APP_BLOCKER_ENABLED))
        assertFalse(AppPreferences.isAllowedSettingKey(AppPreferences.PREF_BLOCK_ONLY_FOCUS))
        assertFalse(AppPreferences.isAllowedSettingKey(AppPreferences.PREF_BLOCKED_APPS))
        assertFalse(AppPreferences.isAllowedSettingKey(AppPreferences.PREF_BLOCKER_DISCLOSURE_ACCEPTED))

        prefs.appBlockerEnabled = true
        prefs.blockerDisclosureAccepted = true
        prefs.blockOnlyDuringFocusPhase = false
        prefs.blockedAppPackages = setOf("com.example.distraction")
        prefs.workDuration = 45

        val exported = prefs.getAllowedSettingsMap()
        assertFalse(exported.keys.any { it.startsWith("blocker.") })
        assertEquals(45, exported[AppPreferences.PREF_WORK_DURATION])

        // Applying remote settings cannot mutate blocker.* keys and clamps/rejects invalid values
        prefs.applySettingsMap(
            mapOf(
                AppPreferences.PREF_APP_BLOCKER_ENABLED to JsonPrimitive(false),
                AppPreferences.PREF_BLOCKED_APPS to JsonPrimitive("com.evil.override"),
                AppPreferences.PREF_WORK_DURATION to JsonPrimitive(999),
                AppPreferences.PREF_SHORT_BREAK to JsonPrimitive(0),
                AppPreferences.PREF_LONG_BREAK to JsonPrimitive(500),
                AppPreferences.PREF_LONG_BREAK_EVERY to JsonPrimitive(99),
                AppPreferences.PREF_DAILY_GOAL_MINUTES to JsonPrimitive(9999),
                AppPreferences.PREF_STUDY_REMINDER_MINUTES to JsonPrimitive(0),
                AppPreferences.PREF_GRACE_PERIOD to JsonPrimitive(99.0),
                AppPreferences.PREF_FONT_SCALE to JsonPrimitive(5.0),
            )
        )
        assertTrue(prefs.appBlockerEnabled)
        assertEquals(setOf("com.example.distraction"), prefs.blockedAppPackages)
        assertEquals(120, prefs.workDuration)
        assertEquals(1, prefs.shortBreakDuration)
        assertEquals(60, prefs.longBreakDuration)
        assertEquals(12, prefs.longBreakEvery)
        assertEquals(720, prefs.dailyGoalMinutes)
        assertEquals(1, prefs.studyReminderMinutes)
        assertEquals(12.0, prefs.gracePeriodHours, 0.001)
        assertEquals(1.30f, prefs.fontScale.value, 0.001f)

        // NaN / Infinity values are rejected without overwriting valid clamped values
        prefs.applySettingsMap(
            mapOf(
                AppPreferences.PREF_GRACE_PERIOD to JsonPrimitive("NaN"),
                AppPreferences.PREF_FONT_SCALE to JsonPrimitive("Infinity"),
                AppPreferences.PREF_WORK_DURATION to JsonPrimitive("NaN"),
            )
        )
        assertEquals(12.0, prefs.gracePeriodHours, 0.001)
        assertEquals(1.30f, prefs.fontScale.value, 0.001f)
        assertEquals(120, prefs.workDuration)
    }
}
