package de.schuelken.studyhabit.core.preferences

import android.content.Context
import android.content.SharedPreferences
import de.schuelken.studyhabit.core.model.ThemeMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull

class AppPreferences(private val prefs: SharedPreferences) {
    constructor(context: Context) : this(
        context.getSharedPreferences("studyhabit_prefs", Context.MODE_PRIVATE)
    )

    companion object {
        const val DEFAULT_SERVER_URL = ""
        const val PREF_LEGACY_URL_CLEANED = "sync.legacyUrlCleaned_v2"
        const val PREF_SERVER_URL = "sync.serverUrl"
        const val PREF_LAST_SYNCED = "sync.lastSyncedAt"
        const val PREF_LAST_SYNCED_USER = "sync.lastSyncedUserId"
        const val PREF_HAS_MIGRATED_OFFLINE = "sync.hasMigratedOfflineSessions"
        const val PREF_LAST_SYNC_SUMMARY = "sync.lastSyncSummary"
        const val PREF_LAST_SYNC_ERROR = "sync.lastSyncError"
        const val PREF_FOLDER_SYNC_URI = "sync.folderUri"
        const val PREF_FOLDER_SYNC_ENABLED = "sync.folderEnabled"
        const val PREF_FOLDER_LAST_SYNCED = "sync.folderLastSyncedAt"
        const val PREF_FOLDER_LAST_SUMMARY = "sync.folderLastSummary"

        const val PREF_SEED_COLOR_INDEX = "theme.seedColorIndex"
        const val PREF_THEME_MODE = "theme.themeMode"
        const val PREF_THEME_STYLE = "theme.style"
        const val PREF_DYNAMIC_COLOR = "theme.useDynamicColor"
        const val PREF_FONT_SCALE = "theme.fontScale"
        const val PREF_GRACE_PERIOD = "streak.gracePeriod"
        const val PREF_SETTINGS_UPDATED_AT = "theme.settingsUpdatedAt"

        const val PREF_WORK_DURATION = "pomodoro.workDuration"
        const val PREF_SHORT_BREAK = "pomodoro.shortBreak"
        const val PREF_LONG_BREAK = "pomodoro.longBreak"
        const val PREF_LONG_BREAK_EVERY = "pomodoro.longBreakEvery"
        const val PREF_AUTO_START_BREAKS = "pomodoro.autoStartBreaks"
        const val PREF_AUTO_START_WORK = "pomodoro.autoStartWork"
        const val PREF_VIBRATION = "pomodoro.vibration"
        const val PREF_CONTINUOUS_FOCUS = "pomodoro.continuousFocus"

        const val PREF_NOTIFICATIONS_ENABLED = "notifications.enabled"
        const val PREF_STUDY_REMINDER_ENABLED = "notifications.studyReminderEnabled"
        const val PREF_STUDY_REMINDER_MINUTES = "notifications.studyReminderMinutes"

        const val PREF_ACTIVE_PROJECT_ID = "active_project_id"
        const val PREF_ACTIVE_TIMER_TYPE = "active_timer_type"
        const val PREF_POMODORO_STATE_JSON = "pomodoro_state_json"
        const val PREF_FREE_TIMER_STATE_JSON = "free_timer_state_json"
        const val PREF_LAST_FREEZE_USE = "streak.lastFreezeUseDate"

        const val PREF_DAILY_GOAL_MINUTES = "goal.dailyMinutes"
        const val PREF_DAILY_GOAL_MONDAY = "goal.monday"
        const val PREF_DAILY_GOAL_TUESDAY = "goal.tuesday"
        const val PREF_DAILY_GOAL_WEDNESDAY = "goal.wednesday"
        const val PREF_DAILY_GOAL_THURSDAY = "goal.thursday"
        const val PREF_DAILY_GOAL_FRIDAY = "goal.friday"
        const val PREF_DAILY_GOAL_SATURDAY = "goal.saturday"
        const val PREF_DAILY_GOAL_SUNDAY = "goal.sunday"
        const val PREF_LAST_DAILY_GOAL_AWARD_DATE = "goal.lastAwardDate"

        const val PREF_APP_BLOCKER_ENABLED = "blocker.enabled"
        const val PREF_BLOCK_ONLY_FOCUS = "blocker.onlyFocusPhase"
        const val PREF_BLOCKED_APPS = "blocker.packages"

        private val floatKeys = setOf(PREF_FONT_SCALE, PREF_GRACE_PERIOD)
        private val intKeys = setOf(
            PREF_SEED_COLOR_INDEX, PREF_THEME_MODE, PREF_THEME_STYLE,
            PREF_WORK_DURATION, PREF_SHORT_BREAK, PREF_LONG_BREAK, PREF_LONG_BREAK_EVERY,
            PREF_STUDY_REMINDER_MINUTES, PREF_DAILY_GOAL_MINUTES,
            PREF_DAILY_GOAL_MONDAY, PREF_DAILY_GOAL_TUESDAY, PREF_DAILY_GOAL_WEDNESDAY,
            PREF_DAILY_GOAL_THURSDAY, PREF_DAILY_GOAL_FRIDAY, PREF_DAILY_GOAL_SATURDAY,
            PREF_DAILY_GOAL_SUNDAY
        )
        private val booleanKeys = setOf(
            PREF_DYNAMIC_COLOR, PREF_AUTO_START_BREAKS, PREF_AUTO_START_WORK,
            PREF_VIBRATION, PREF_CONTINUOUS_FOCUS, PREF_NOTIFICATIONS_ENABLED,
            PREF_STUDY_REMINDER_ENABLED, PREF_HAS_MIGRATED_OFFLINE,
            PREF_FOLDER_SYNC_ENABLED, PREF_APP_BLOCKER_ENABLED, PREF_BLOCK_ONLY_FOCUS
        )
        private val longKeys = setOf(
            PREF_LAST_SYNCED, PREF_SETTINGS_UPDATED_AT, PREF_FOLDER_LAST_SYNCED
        )

        fun isAllowedSettingKey(k: String): Boolean =
            k.startsWith("theme.") ||
            k.startsWith("pomodoro.") ||
            k.startsWith("notifications.") ||
            k.startsWith("streak.") ||
            k.startsWith("goal.") ||
            k.startsWith("blocker.")
    }

    private fun healAndMigratePreferences() {
        val all = prefs.all
        val editor = prefs.edit()
        var changed = false
        for ((k, v) in all) {
            when (k) {
                in floatKeys -> if (v !is Float) {
                    val f = (v as? Number)?.toFloat() ?: v?.toString()?.toFloatOrNull()
                    if (f != null) { editor.putFloat(k, f); changed = true }
                    else { editor.remove(k); changed = true }
                }
                in intKeys -> if (v !is Int) {
                    val i = (v as? Number)?.toInt() ?: v?.toString()?.toIntOrNull()
                    if (i != null) { editor.putInt(k, i); changed = true }
                    else { editor.remove(k); changed = true }
                }
                in longKeys -> if (v !is Long) {
                    val l = (v as? Number)?.toLong() ?: v?.toString()?.toLongOrNull()
                    if (l != null) { editor.putLong(k, l); changed = true }
                    else { editor.remove(k); changed = true }
                }
                in booleanKeys -> if (v !is Boolean) {
                    val b = v?.toString()?.toBooleanStrictOrNull()
                    if (b != null) { editor.putBoolean(k, b); changed = true }
                    else { editor.remove(k); changed = true }
                }
            }
        }
        if (!prefs.getBoolean(PREF_LEGACY_URL_CLEANED, false)) {
            val currentUrl = all[PREF_SERVER_URL] as? String
            if (currentUrl == "https://studyhabit.schuelken.uk") {
                editor.putString(PREF_SERVER_URL, "")
            }
            editor.putBoolean(PREF_LEGACY_URL_CLEANED, true)
            changed = true
        }
        if (changed) {
            editor.commit()
        }
    }

    fun getFloatSafe(key: String, default: Float): Float =
        (prefs.all[key] as? Number)?.toFloat() ?: default

    fun getIntSafe(key: String, default: Int): Int =
        (prefs.all[key] as? Number)?.toInt() ?: default

    fun getLongSafe(key: String, default: Long): Long =
        (prefs.all[key] as? Number)?.toLong() ?: default

    fun getBooleanSafe(key: String, default: Boolean): Boolean =
        (prefs.all[key] as? Boolean) ?: default

    fun getStringSafe(key: String, default: String? = null): String? =
        (prefs.all[key] as? String) ?: default

    init {
        healAndMigratePreferences()
    }

    private val _serverUrl = MutableStateFlow(getStringSafe(PREF_SERVER_URL, DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL)
    val serverUrl: StateFlow<String> = _serverUrl.asStateFlow()

    private val _themeMode = MutableStateFlow(
        ThemeMode.entries.getOrElse(getIntSafe(PREF_THEME_MODE, ThemeMode.SYSTEM.ordinal)) { ThemeMode.SYSTEM }
    )
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    private val _seedColorIndex = MutableStateFlow(getIntSafe(PREF_SEED_COLOR_INDEX, 0).coerceIn(0, 11))
    val seedColorIndex: StateFlow<Int> = _seedColorIndex.asStateFlow()

    private val _themeStyleIndex = MutableStateFlow(getIntSafe(PREF_THEME_STYLE, 0).coerceIn(0, 6))
    val themeStyleIndex: StateFlow<Int> = _themeStyleIndex.asStateFlow()

    private val _useDynamicColor = MutableStateFlow(getBooleanSafe(PREF_DYNAMIC_COLOR, false))
    val useDynamicColor: StateFlow<Boolean> = _useDynamicColor.asStateFlow()

    private val _fontScale = MutableStateFlow(getFloatSafe(PREF_FONT_SCALE, 1.0f).coerceIn(0.85f, 1.3f))
    val fontScale: StateFlow<Float> = _fontScale.asStateFlow()

    private val _activeProjectId = MutableStateFlow(getStringSafe(PREF_ACTIVE_PROJECT_ID, null))
    val activeProjectId: StateFlow<String?> = _activeProjectId.asStateFlow()

    private val _lastSyncSummary = MutableStateFlow(getStringSafe(PREF_LAST_SYNC_SUMMARY, "") ?: "")
    val lastSyncSummary: StateFlow<String> = _lastSyncSummary.asStateFlow()

    private val _lastSyncError = MutableStateFlow(getStringSafe(PREF_LAST_SYNC_ERROR, null))
    val lastSyncError: StateFlow<String?> = _lastSyncError.asStateFlow()

    private val _lastSyncedAtFlow = MutableStateFlow(getLongSafe(PREF_LAST_SYNCED, 0L))
    val lastSyncedAtFlow: StateFlow<Long> = _lastSyncedAtFlow.asStateFlow()

    private val _folderSyncUri = MutableStateFlow(getStringSafe(PREF_FOLDER_SYNC_URI, null))
    val folderSyncUri: StateFlow<String?> = _folderSyncUri.asStateFlow()

    private val _folderSyncEnabled = MutableStateFlow(getBooleanSafe(PREF_FOLDER_SYNC_ENABLED, false))
    val folderSyncEnabled: StateFlow<Boolean> = _folderSyncEnabled.asStateFlow()

    private val _folderLastSyncedAtFlow = MutableStateFlow(getLongSafe(PREF_FOLDER_LAST_SYNCED, 0L))
    val folderLastSyncedAtFlow: StateFlow<Long> = _folderLastSyncedAtFlow.asStateFlow()

    private val _folderLastSummary = MutableStateFlow(getStringSafe(PREF_FOLDER_LAST_SUMMARY, "") ?: "")
    val folderLastSummary: StateFlow<String> = _folderLastSummary.asStateFlow()

    fun setServerUrl(url: String) {
        val clean = url.trim().removeSuffix("/")
        prefs.edit().putString(PREF_SERVER_URL, clean).apply()
        _serverUrl.value = clean
    }

    fun setThemeMode(mode: ThemeMode) {
        prefs.edit().putInt(PREF_THEME_MODE, mode.ordinal).apply()
        _themeMode.value = mode
        markSettingsUpdated()
    }

    fun setSeedColorIndex(index: Int) {
        val clamped = index.coerceIn(0, 11)
        prefs.edit().putInt(PREF_SEED_COLOR_INDEX, clamped).apply()
        _seedColorIndex.value = clamped
        markSettingsUpdated()
    }

    fun setThemeStyleIndex(index: Int) {
        val clamped = index.coerceIn(0, 6)
        prefs.edit().putInt(PREF_THEME_STYLE, clamped).apply()
        _themeStyleIndex.value = clamped
        markSettingsUpdated()
    }

    fun setUseDynamicColor(enabled: Boolean) {
        prefs.edit().putBoolean(PREF_DYNAMIC_COLOR, enabled).apply()
        _useDynamicColor.value = enabled
        markSettingsUpdated()
    }

    fun setFontScale(scale: Float) {
        val clamped = scale.coerceIn(0.85f, 1.3f)
        prefs.edit().putFloat(PREF_FONT_SCALE, clamped).apply()
        _fontScale.value = clamped
        markSettingsUpdated()
    }

    fun setActiveProjectId(id: String?) {
        if (id == null) {
            prefs.edit().remove(PREF_ACTIVE_PROJECT_ID).apply()
        } else {
            prefs.edit().putString(PREF_ACTIVE_PROJECT_ID, id).apply()
        }
        _activeProjectId.value = id
    }

    fun setLastSyncSummary(summary: String) {
        prefs.edit().putString(PREF_LAST_SYNC_SUMMARY, summary).apply()
        _lastSyncSummary.value = summary
    }

    fun setLastSyncError(error: String?) {
        if (error == null) {
            prefs.edit().remove(PREF_LAST_SYNC_ERROR).apply()
        } else {
            prefs.edit().putString(PREF_LAST_SYNC_ERROR, error).apply()
        }
        _lastSyncError.value = error
    }

    fun setFolderSyncUri(uri: String?) {
        if (uri == null) {
            prefs.edit().remove(PREF_FOLDER_SYNC_URI).apply()
        } else {
            prefs.edit().putString(PREF_FOLDER_SYNC_URI, uri).apply()
        }
        _folderSyncUri.value = uri
    }

    fun setFolderSyncEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(PREF_FOLDER_SYNC_ENABLED, enabled).apply()
        _folderSyncEnabled.value = enabled
    }

    fun setFolderLastSyncedAt(timestamp: Long) {
        prefs.edit().putLong(PREF_FOLDER_LAST_SYNCED, timestamp).apply()
        _folderLastSyncedAtFlow.value = timestamp
    }

    fun setFolderLastSummary(summary: String) {
        prefs.edit().putString(PREF_FOLDER_LAST_SUMMARY, summary).apply()
        _folderLastSummary.value = summary
    }

    var gracePeriodHours: Double
        get() = getFloatSafe(PREF_GRACE_PERIOD, 2.0f).toDouble()
        set(value) {
            prefs.edit().putFloat(PREF_GRACE_PERIOD, value.toFloat()).apply()
            markSettingsUpdated()
        }

    var workDuration: Int
        get() = getIntSafe(PREF_WORK_DURATION, 25)
        set(value) {
            prefs.edit().putInt(PREF_WORK_DURATION, value).apply()
            markSettingsUpdated()
        }

    var shortBreakDuration: Int
        get() = getIntSafe(PREF_SHORT_BREAK, 5)
        set(value) {
            prefs.edit().putInt(PREF_SHORT_BREAK, value).apply()
            markSettingsUpdated()
        }

    var longBreakDuration: Int
        get() = getIntSafe(PREF_LONG_BREAK, 15)
        set(value) {
            prefs.edit().putInt(PREF_LONG_BREAK, value).apply()
            markSettingsUpdated()
        }

    var longBreakEvery: Int
        get() = getIntSafe(PREF_LONG_BREAK_EVERY, 4)
        set(value) {
            prefs.edit().putInt(PREF_LONG_BREAK_EVERY, value).apply()
            markSettingsUpdated()
        }

    var autoStartBreaks: Boolean
        get() = getBooleanSafe(PREF_AUTO_START_BREAKS, false)
        set(value) {
            prefs.edit().putBoolean(PREF_AUTO_START_BREAKS, value).apply()
            markSettingsUpdated()
        }

    var autoStartWork: Boolean
        get() = getBooleanSafe(PREF_AUTO_START_WORK, false)
        set(value) {
            prefs.edit().putBoolean(PREF_AUTO_START_WORK, value).apply()
            markSettingsUpdated()
        }

    var vibrationEnabled: Boolean
        get() = getBooleanSafe(PREF_VIBRATION, true)
        set(value) {
            prefs.edit().putBoolean(PREF_VIBRATION, value).apply()
            markSettingsUpdated()
        }

    var continuousFocus: Boolean
        get() = getBooleanSafe(PREF_CONTINUOUS_FOCUS, true)
        set(value) {
            prefs.edit().putBoolean(PREF_CONTINUOUS_FOCUS, value).apply()
            markSettingsUpdated()
        }

    var notificationsEnabled: Boolean
        get() = getBooleanSafe(PREF_NOTIFICATIONS_ENABLED, true)
        set(value) {
            prefs.edit().putBoolean(PREF_NOTIFICATIONS_ENABLED, value).apply()
            markSettingsUpdated()
        }

    var studyReminderEnabled: Boolean
        get() = getBooleanSafe(PREF_STUDY_REMINDER_ENABLED, false)
        set(value) {
            prefs.edit().putBoolean(PREF_STUDY_REMINDER_ENABLED, value).apply()
            markSettingsUpdated()
        }

    var studyReminderMinutes: Int
        get() = getIntSafe(PREF_STUDY_REMINDER_MINUTES, 30)
        set(value) {
            prefs.edit().putInt(PREF_STUDY_REMINDER_MINUTES, value).apply()
            markSettingsUpdated()
        }

    var dailyGoalMinutes: Int
        get() = getIntSafe(PREF_DAILY_GOAL_MINUTES, 60)
        set(value) {
            prefs.edit().putInt(PREF_DAILY_GOAL_MINUTES, value).apply()
            markSettingsUpdated()
        }

    fun getWeekdayGoalMinutes(weekday: Int): Int { // 1 = Monday .. 7 = Sunday
        val key = when (weekday) {
            1 -> PREF_DAILY_GOAL_MONDAY
            2 -> PREF_DAILY_GOAL_TUESDAY
            3 -> PREF_DAILY_GOAL_WEDNESDAY
            4 -> PREF_DAILY_GOAL_THURSDAY
            5 -> PREF_DAILY_GOAL_FRIDAY
            6 -> PREF_DAILY_GOAL_SATURDAY
            7 -> PREF_DAILY_GOAL_SUNDAY
            else -> PREF_DAILY_GOAL_MINUTES
        }
        return getIntSafe(key, dailyGoalMinutes)
    }

    fun setWeekdayGoalMinutes(weekday: Int, minutes: Int) {
        val key = when (weekday) {
            1 -> PREF_DAILY_GOAL_MONDAY
            2 -> PREF_DAILY_GOAL_TUESDAY
            3 -> PREF_DAILY_GOAL_WEDNESDAY
            4 -> PREF_DAILY_GOAL_THURSDAY
            5 -> PREF_DAILY_GOAL_FRIDAY
            6 -> PREF_DAILY_GOAL_SATURDAY
            7 -> PREF_DAILY_GOAL_SUNDAY
            else -> PREF_DAILY_GOAL_MINUTES
        }
        prefs.edit().putInt(key, minutes).apply()
        markSettingsUpdated()
    }

    var lastDailyGoalAwardDate: String?
        get() = getStringSafe(PREF_LAST_DAILY_GOAL_AWARD_DATE, null)
        set(value) = prefs.edit().putString(PREF_LAST_DAILY_GOAL_AWARD_DATE, value).apply()

    var lastFreezeUseDate: String?
        get() = getStringSafe(PREF_LAST_FREEZE_USE, null)
        set(value) = prefs.edit().putString(PREF_LAST_FREEZE_USE, value).apply()

    var lastSyncedAt: Long
        get() = getLongSafe(PREF_LAST_SYNCED, 0L)
        set(value) {
            prefs.edit().putLong(PREF_LAST_SYNCED, value).apply()
            _lastSyncedAtFlow.value = value
        }

    var lastSyncedUserId: String?
        get() = getStringSafe(PREF_LAST_SYNCED_USER, null)
        set(value) = prefs.edit().putString(PREF_LAST_SYNCED_USER, value).apply()

    var hasMigratedOfflineSessions: Boolean
        get() = getBooleanSafe(PREF_HAS_MIGRATED_OFFLINE, false)
        set(value) = prefs.edit().putBoolean(PREF_HAS_MIGRATED_OFFLINE, value).apply()

    var settingsUpdatedAt: Long
        get() = getLongSafe(PREF_SETTINGS_UPDATED_AT, 0L)
        set(value) = prefs.edit().putLong(PREF_SETTINGS_UPDATED_AT, value).apply()

    fun markSettingsUpdated() {
        val now = System.currentTimeMillis()
        prefs.edit().putLong(PREF_SETTINGS_UPDATED_AT, now).apply()
    }

    var activeTimerType: String?
        get() = getStringSafe(PREF_ACTIVE_TIMER_TYPE, null)
        set(value) {
            if (value == null) prefs.edit().remove(PREF_ACTIVE_TIMER_TYPE).apply()
            else prefs.edit().putString(PREF_ACTIVE_TIMER_TYPE, value).apply()
        }

    var pomodoroStateJson: String?
        get() = getStringSafe(PREF_POMODORO_STATE_JSON, null)
        set(value) {
            if (value == null) prefs.edit().remove(PREF_POMODORO_STATE_JSON).apply()
            else prefs.edit().putString(PREF_POMODORO_STATE_JSON, value).apply()
        }

    var freeTimerStateJson: String?
        get() = getStringSafe(PREF_FREE_TIMER_STATE_JSON, null)
        set(value) {
            if (value == null) prefs.edit().remove(PREF_FREE_TIMER_STATE_JSON).apply()
            else prefs.edit().putString(PREF_FREE_TIMER_STATE_JSON, value).apply()
        }

    fun clearActiveTimers() {
        prefs.edit()
            .remove(PREF_ACTIVE_TIMER_TYPE)
            .remove(PREF_POMODORO_STATE_JSON)
            .remove(PREF_FREE_TIMER_STATE_JSON)
            .apply()
    }

    val folderLastSyncedAt: Long
        get() = getLongSafe(PREF_FOLDER_LAST_SYNCED, 0L)

    var appBlockerEnabled: Boolean
        get() = getBooleanSafe(PREF_APP_BLOCKER_ENABLED, true)
        set(value) {
            prefs.edit().putBoolean(PREF_APP_BLOCKER_ENABLED, value).apply()
        }

    var blockOnlyDuringFocusPhase: Boolean
        get() = getBooleanSafe(PREF_BLOCK_ONLY_FOCUS, true)
        set(value) {
            prefs.edit().putBoolean(PREF_BLOCK_ONLY_FOCUS, value).apply()
        }

    var blockedAppPackages: Set<String>
        get() {
            val raw = getStringSafe(PREF_BLOCKED_APPS, "") ?: ""
            if (raw.isBlank()) return emptySet()
            return raw.split(",").map { it.trim() }.filter { it.isNotEmpty() }.toSet()
        }
        set(value) {
            val raw = value.joinToString(",")
            prefs.edit().putString(PREF_BLOCKED_APPS, raw).apply()
        }

    fun getAllowedSettingsMap(): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        for ((key, value) in prefs.all) {
            if (isAllowedSettingKey(key) && key != PREF_SETTINGS_UPDATED_AT && value != null) {
                result[key] = value
            }
        }
        return result
    }

    fun applySettingsMap(settings: Map<String, JsonElement>) {
        val editor = prefs.edit()
        for ((key, element) in settings) {
            if (!isAllowedSettingKey(key)) continue
            if (element is JsonPrimitive) {
                when (key) {
                    in floatKeys -> {
                        val v = element.doubleOrNull?.toFloat() ?: element.content.toFloatOrNull()
                        if (v != null) editor.putFloat(key, v)
                    }
                    in intKeys -> {
                        val v = element.intOrNull ?: element.doubleOrNull?.toInt() ?: element.content.toIntOrNull()
                        if (v != null) editor.putInt(key, v)
                    }
                    in booleanKeys -> {
                        val v = element.booleanOrNull ?: element.content.toBooleanStrictOrNull()
                        if (v != null) editor.putBoolean(key, v)
                    }
                    in longKeys -> {
                        val v = element.doubleOrNull?.toLong() ?: element.content.toLongOrNull()
                        if (v != null) editor.putLong(key, v)
                    }
                    else -> {
                        editor.putString(key, element.content)
                    }
                }
            }
        }
        editor.apply()
        _themeMode.value = ThemeMode.entries.getOrElse(getIntSafe(PREF_THEME_MODE, ThemeMode.SYSTEM.ordinal)) { ThemeMode.SYSTEM }
        _seedColorIndex.value = getIntSafe(PREF_SEED_COLOR_INDEX, 0).coerceIn(0, 11)
        _themeStyleIndex.value = getIntSafe(PREF_THEME_STYLE, 0).coerceIn(0, 6)
        _useDynamicColor.value = getBooleanSafe(PREF_DYNAMIC_COLOR, false)
        _fontScale.value = getFloatSafe(PREF_FONT_SCALE, 1.0f).coerceIn(0.85f, 1.3f)
    }
}
