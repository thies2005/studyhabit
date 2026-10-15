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
        const val DEFAULT_SERVER_URL = "https://studyhabit.schuelken.uk"
        const val PREF_SERVER_URL = "sync.serverUrl"
        const val PREF_LAST_SYNCED = "sync.lastSyncedAt"
        const val PREF_LAST_SYNCED_USER = "sync.lastSyncedUserId"
        const val PREF_HAS_MIGRATED_OFFLINE = "sync.hasMigratedOfflineSessions"

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

        fun isAllowedSettingKey(k: String): Boolean =
            k.startsWith("theme.") ||
            k.startsWith("pomodoro.") ||
            k.startsWith("notifications.") ||
            k.startsWith("streak.") ||
            k.startsWith("goal.") ||
            k == PREF_ACTIVE_TIMER_TYPE ||
            k == PREF_POMODORO_STATE_JSON ||
            k == PREF_FREE_TIMER_STATE_JSON
    }

    private val _serverUrl = MutableStateFlow(prefs.getString(PREF_SERVER_URL, DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL)
    val serverUrl: StateFlow<String> = _serverUrl.asStateFlow()

    private val _themeMode = MutableStateFlow(
        ThemeMode.entries.getOrElse(prefs.getInt(PREF_THEME_MODE, ThemeMode.SYSTEM.ordinal)) { ThemeMode.SYSTEM }
    )
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    private val _seedColorIndex = MutableStateFlow(prefs.getInt(PREF_SEED_COLOR_INDEX, 0).coerceIn(0, 11))
    val seedColorIndex: StateFlow<Int> = _seedColorIndex.asStateFlow()

    private val _themeStyleIndex = MutableStateFlow(prefs.getInt(PREF_THEME_STYLE, 0).coerceIn(0, 6))
    val themeStyleIndex: StateFlow<Int> = _themeStyleIndex.asStateFlow()

    private val _useDynamicColor = MutableStateFlow(prefs.getBoolean(PREF_DYNAMIC_COLOR, false))
    val useDynamicColor: StateFlow<Boolean> = _useDynamicColor.asStateFlow()

    private val _fontScale = MutableStateFlow(prefs.getFloat(PREF_FONT_SCALE, 1.0f).coerceIn(0.85f, 1.3f))
    val fontScale: StateFlow<Float> = _fontScale.asStateFlow()

    private val _activeProjectId = MutableStateFlow(prefs.getString(PREF_ACTIVE_PROJECT_ID, null))
    val activeProjectId: StateFlow<String?> = _activeProjectId.asStateFlow()

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

    var gracePeriodHours: Double
        get() = prefs.getFloat(PREF_GRACE_PERIOD, 2.0f).toDouble()
        set(value) {
            prefs.edit().putFloat(PREF_GRACE_PERIOD, value.toFloat()).apply()
            markSettingsUpdated()
        }

    var workDuration: Int
        get() = prefs.getInt(PREF_WORK_DURATION, 25)
        set(value) {
            prefs.edit().putInt(PREF_WORK_DURATION, value).apply()
            markSettingsUpdated()
        }

    var shortBreakDuration: Int
        get() = prefs.getInt(PREF_SHORT_BREAK, 5)
        set(value) {
            prefs.edit().putInt(PREF_SHORT_BREAK, value).apply()
            markSettingsUpdated()
        }

    var longBreakDuration: Int
        get() = prefs.getInt(PREF_LONG_BREAK, 15)
        set(value) {
            prefs.edit().putInt(PREF_LONG_BREAK, value).apply()
            markSettingsUpdated()
        }

    var longBreakEvery: Int
        get() = prefs.getInt(PREF_LONG_BREAK_EVERY, 4)
        set(value) {
            prefs.edit().putInt(PREF_LONG_BREAK_EVERY, value).apply()
            markSettingsUpdated()
        }

    var autoStartBreaks: Boolean
        get() = prefs.getBoolean(PREF_AUTO_START_BREAKS, false)
        set(value) {
            prefs.edit().putBoolean(PREF_AUTO_START_BREAKS, value).apply()
            markSettingsUpdated()
        }

    var autoStartWork: Boolean
        get() = prefs.getBoolean(PREF_AUTO_START_WORK, false)
        set(value) {
            prefs.edit().putBoolean(PREF_AUTO_START_WORK, value).apply()
            markSettingsUpdated()
        }

    var vibrationEnabled: Boolean
        get() = prefs.getBoolean(PREF_VIBRATION, true)
        set(value) {
            prefs.edit().putBoolean(PREF_VIBRATION, value).apply()
            markSettingsUpdated()
        }

    var continuousFocus: Boolean
        get() = prefs.getBoolean(PREF_CONTINUOUS_FOCUS, true)
        set(value) {
            prefs.edit().putBoolean(PREF_CONTINUOUS_FOCUS, value).apply()
            markSettingsUpdated()
        }

    var notificationsEnabled: Boolean
        get() = prefs.getBoolean(PREF_NOTIFICATIONS_ENABLED, true)
        set(value) {
            prefs.edit().putBoolean(PREF_NOTIFICATIONS_ENABLED, value).apply()
            markSettingsUpdated()
        }

    var studyReminderEnabled: Boolean
        get() = prefs.getBoolean(PREF_STUDY_REMINDER_ENABLED, false)
        set(value) {
            prefs.edit().putBoolean(PREF_STUDY_REMINDER_ENABLED, value).apply()
            markSettingsUpdated()
        }

    var studyReminderMinutes: Int
        get() = prefs.getInt(PREF_STUDY_REMINDER_MINUTES, 30)
        set(value) {
            prefs.edit().putInt(PREF_STUDY_REMINDER_MINUTES, value).apply()
            markSettingsUpdated()
        }

    var dailyGoalMinutes: Int
        get() = prefs.getInt(PREF_DAILY_GOAL_MINUTES, 60)
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
        return prefs.getInt(key, dailyGoalMinutes)
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
        get() = prefs.getString(PREF_LAST_DAILY_GOAL_AWARD_DATE, null)
        set(value) = prefs.edit().putString(PREF_LAST_DAILY_GOAL_AWARD_DATE, value).apply()

    var lastFreezeUseDate: String?
        get() = prefs.getString(PREF_LAST_FREEZE_USE, null)
        set(value) = prefs.edit().putString(PREF_LAST_FREEZE_USE, value).apply()

    var lastSyncedAt: Long
        get() = prefs.getLong(PREF_LAST_SYNCED, 0L)
        set(value) = prefs.edit().putLong(PREF_LAST_SYNCED, value).apply()

    var lastSyncedUserId: String?
        get() = prefs.getString(PREF_LAST_SYNCED_USER, null)
        set(value) = prefs.edit().putString(PREF_LAST_SYNCED_USER, value).apply()

    var hasMigratedOfflineSessions: Boolean
        get() = prefs.getBoolean(PREF_HAS_MIGRATED_OFFLINE, false)
        set(value) = prefs.edit().putBoolean(PREF_HAS_MIGRATED_OFFLINE, value).apply()

    var settingsUpdatedAt: Long
        get() = prefs.getLong(PREF_SETTINGS_UPDATED_AT, 0L)
        set(value) = prefs.edit().putLong(PREF_SETTINGS_UPDATED_AT, value).apply()

    fun markSettingsUpdated() {
        val now = System.currentTimeMillis()
        prefs.edit().putLong(PREF_SETTINGS_UPDATED_AT, now).apply()
    }

    var activeTimerType: String?
        get() = prefs.getString(PREF_ACTIVE_TIMER_TYPE, null)
        set(value) {
            if (value == null) prefs.edit().remove(PREF_ACTIVE_TIMER_TYPE).apply()
            else prefs.edit().putString(PREF_ACTIVE_TIMER_TYPE, value).apply()
            markSettingsUpdated()
        }

    var pomodoroStateJson: String?
        get() = prefs.getString(PREF_POMODORO_STATE_JSON, null)
        set(value) {
            if (value == null) prefs.edit().remove(PREF_POMODORO_STATE_JSON).apply()
            else prefs.edit().putString(PREF_POMODORO_STATE_JSON, value).apply()
            markSettingsUpdated()
        }

    var freeTimerStateJson: String?
        get() = prefs.getString(PREF_FREE_TIMER_STATE_JSON, null)
        set(value) {
            if (value == null) prefs.edit().remove(PREF_FREE_TIMER_STATE_JSON).apply()
            else prefs.edit().putString(PREF_FREE_TIMER_STATE_JSON, value).apply()
            markSettingsUpdated()
        }

    fun clearActiveTimers() {
        prefs.edit()
            .remove(PREF_ACTIVE_TIMER_TYPE)
            .remove(PREF_POMODORO_STATE_JSON)
            .remove(PREF_FREE_TIMER_STATE_JSON)
            .apply()
        markSettingsUpdated()
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
                val boolVal = element.booleanOrNull
                if (boolVal != null) {
                    editor.putBoolean(key, boolVal)
                    continue
                }
                val intVal = element.intOrNull
                if (intVal != null) {
                    editor.putInt(key, intVal)
                    continue
                }
                val doubleVal = element.doubleOrNull
                if (doubleVal != null) {
                    editor.putFloat(key, doubleVal.toFloat())
                    continue
                }
                editor.putString(key, element.content)
            }
        }
        editor.apply()
        // Refresh StateFlows
        _themeMode.value = ThemeMode.entries.getOrElse(prefs.getInt(PREF_THEME_MODE, ThemeMode.SYSTEM.ordinal)) { ThemeMode.SYSTEM }
        _seedColorIndex.value = prefs.getInt(PREF_SEED_COLOR_INDEX, 0).coerceIn(0, 11)
        _themeStyleIndex.value = prefs.getInt(PREF_THEME_STYLE, 0).coerceIn(0, 6)
        _useDynamicColor.value = prefs.getBoolean(PREF_DYNAMIC_COLOR, false)
        _fontScale.value = prefs.getFloat(PREF_FONT_SCALE, 1.0f).coerceIn(0.85f, 1.3f)
    }
}
