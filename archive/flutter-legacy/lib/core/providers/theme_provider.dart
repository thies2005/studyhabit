import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/app_logger.dart';

part 'theme_provider.g.dart';

@Riverpod(keepAlive: true)
class ThemeSettings extends _$ThemeSettings {
  static const _seedColorKey = 'theme.seedColorIndex';
  static const _themeModeKey = 'theme.themeMode';
  static const _themeStyleKey = 'theme.style';
  static const _dynamicColorKey = 'theme.useDynamicColor';
  static const _fontScaleKey = 'theme.fontScale';
  static const _workDurationKey = 'pomodoro.workDuration';
  static const _shortBreakKey = 'pomodoro.shortBreak';
  static const _longBreakKey = 'pomodoro.longBreak';
  static const _longBreakEveryKey = 'pomodoro.longBreakEvery';
  static const _autoStartBreaksKey = 'pomodoro.autoStartBreaks';
  static const _autoStartWorkKey = 'pomodoro.autoStartWork';
  static const _vibrationKey = 'pomodoro.vibration';
  static const _notificationsKey = 'notifications.enabled';
  static const _studyReminderEnabledKey = 'notifications.studyReminderEnabled';
  static const _studyReminderMinutesKey = 'notifications.studyReminderMinutes';
  static const _dailyReminderHourKey = 'notifications.dailyReminderHour';
  static const _dailyReminderMinuteKey = 'notifications.dailyReminderMinute';
  static const _dailyReminderEnabledKey = 'notifications.dailyReminderEnabled';
  static const _gracePeriodKey = 'streak.gracePeriod';
  static const _continuousFocusKey = 'pomodoro.continuousFocus';
  static const _dailyGoalMinutesKey = 'goal.dailyMinutes';
  static const _dailyGoalMondayKey = 'goal.monday';
  static const _dailyGoalTuesdayKey = 'goal.tuesday';
  static const _dailyGoalWednesdayKey = 'goal.wednesday';
  static const _dailyGoalThursdayKey = 'goal.thursday';
  static const _dailyGoalFridayKey = 'goal.friday';
  static const _dailyGoalSaturdayKey = 'goal.saturday';
  static const _dailyGoalSundayKey = 'goal.sunday';
  static const _lastDailyGoalAwardDateKey = 'goal.lastAwardDate';
  static const _settingsUpdatedAtKey = 'theme.settingsUpdatedAt';


  late SharedPreferences _prefs;

  @override
  Future<ThemeSettingsState> build() async {
    _prefs = await SharedPreferences.getInstance();
    final savedSeedColorIndex = _prefs.getInt(_seedColorKey) ?? 0;
    final seedColorIndex = savedSeedColorIndex.clamp(
      0,
      AppTheme.presetSeeds.length - 1,
    );

    final themeModeIndex =
        _prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    final themeStyleIndex = _prefs.getInt(_themeStyleKey) ?? 0;
    final useDynamicColor = _prefs.getBool(_dynamicColorKey) ?? false;

    final resolvedThemeMode = ThemeMode.values.firstWhere(
      (value) => value.index == themeModeIndex,
      orElse: () => ThemeMode.system,
    );

    final resolvedThemeStyle = AppThemeStyle.values.firstWhere(
      (value) => value.index == themeStyleIndex,
      orElse: () => AppThemeStyle.atmosphericTeal,
    );

    final fontScale = _getDoubleSafe(_fontScaleKey, 1.0);
    final workDuration = _prefs.getInt(_workDurationKey) ?? 25;
    final shortBreak = _prefs.getInt(_shortBreakKey) ?? 5;
    final longBreak = _prefs.getInt(_longBreakKey) ?? 15;
    final longBreakEvery = _prefs.getInt(_longBreakEveryKey) ?? 4;
    final autoStartBreaks = _prefs.getBool(_autoStartBreaksKey) ?? false;
    final autoStartWork = _prefs.getBool(_autoStartWorkKey) ?? false;
    final vibration = _prefs.getBool(_vibrationKey) ?? true;
    final notifications = _prefs.getBool(_notificationsKey) ?? true;
    final studyReminderEnabled = _prefs.getBool(_studyReminderEnabledKey) ?? false;
    final studyReminderMinutes = _prefs.getInt(_studyReminderMinutesKey) ?? 30;
    final dailyReminderHour = _prefs.getInt(_dailyReminderHourKey) ?? 9;
    final dailyReminderMinute = _prefs.getInt(_dailyReminderMinuteKey) ?? 0;
    final dailyReminderEnabled = _prefs.getBool(_dailyReminderEnabledKey) ?? false;
    final gracePeriod = _getDoubleSafe(_gracePeriodKey, 2.0);
    final continuousFocus = _prefs.getBool(_continuousFocusKey) ?? true;
    final dailyGoalMinutes = _prefs.getInt(_dailyGoalMinutesKey) ?? 0;
    final dailyGoalsByWeekday = <int, int>{
      DateTime.monday: _prefs.getInt(_dailyGoalMondayKey) ?? dailyGoalMinutes,
      DateTime.tuesday: _prefs.getInt(_dailyGoalTuesdayKey) ?? dailyGoalMinutes,
      DateTime.wednesday:
          _prefs.getInt(_dailyGoalWednesdayKey) ?? dailyGoalMinutes,
      DateTime.thursday:
          _prefs.getInt(_dailyGoalThursdayKey) ?? dailyGoalMinutes,
      DateTime.friday: _prefs.getInt(_dailyGoalFridayKey) ?? dailyGoalMinutes,
      DateTime.saturday:
          _prefs.getInt(_dailyGoalSaturdayKey) ?? dailyGoalMinutes,
      DateTime.sunday: _prefs.getInt(_dailyGoalSundayKey) ?? dailyGoalMinutes,
    };
    final lastDailyGoalAwardDate = _prefs.getString(_lastDailyGoalAwardDateKey) ?? '';

    return ThemeSettingsState(
      seedColorIndex: seedColorIndex,
      themeMode: resolvedThemeMode,
      themeStyle: resolvedThemeStyle,
      useDynamicColor: useDynamicColor,
      fontScale: fontScale,
      workDuration: workDuration,
      shortBreak: shortBreak,
      longBreak: longBreak,
      longBreakEvery: longBreakEvery,
      autoStartBreaks: autoStartBreaks,
      autoStartWork: autoStartWork,
      vibration: vibration,
      notificationsEnabled: notifications,
      studyReminderEnabled: studyReminderEnabled,
      studyReminderMinutes: studyReminderMinutes,
      dailyReminderHour: dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute,
      dailyReminderEnabled: dailyReminderEnabled,
      gracePeriodHours: gracePeriod,
      continuousFocus: continuousFocus,
      dailyGoalMinutes: dailyGoalMinutes,
      dailyGoalsByWeekday: dailyGoalsByWeekday,
      lastDailyGoalAwardDate: lastDailyGoalAwardDate,
    );
  }

  double _getDoubleSafe(String key, double defaultValue) {
    try {
      final value = _prefs.get(key);
      if (value is num) return value.toDouble();
      return defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> loadSettings(Map<String, dynamic> settings, {DateTime? remoteUpdatedAt}) async {
    for (final entry in settings.entries) {
      final value = entry.value;
      if (entry.key == _fontScaleKey || entry.key == _gracePeriodKey) {
        if (value is num) {
          await _prefs.setDouble(entry.key, value.toDouble());
        }
      } else if (value is int) {
        await _prefs.setInt(entry.key, value);
      } else if (value is double) {
        await _prefs.setDouble(entry.key, value);
      } else if (value is bool) {
        await _prefs.setBool(entry.key, value);
      } else if (value is String) {
        await _prefs.setString(entry.key, value);
      }
    }
    if (remoteUpdatedAt != null) {
      await _prefs.setInt(_settingsUpdatedAtKey, remoteUpdatedAt.millisecondsSinceEpoch);
    } else {
      await _markSettingsUpdated();
    }
    // Re-build state by forcing a new read from SharedPreferences
    ref.invalidateSelf();
  }

  Future<void> _markSettingsUpdated() async {
    await _prefs.setInt(_settingsUpdatedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> setSeedColor(int index) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(seedColorIndex: index);
    state = AsyncValue.data(next);
    await _prefs.setInt(_seedColorKey, index);
    await _markSettingsUpdated();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(themeMode: mode);
    state = AsyncValue.data(next);
    await _prefs.setInt(_themeModeKey, mode.index);
    await _markSettingsUpdated();
  }

  Future<void> setThemeStyle(AppThemeStyle style) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(themeStyle: style);
    state = AsyncValue.data(next);
    await _prefs.setInt(_themeStyleKey, style.index);
    await _markSettingsUpdated();
  }

  Future<void> setUseDynamicColor(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(useDynamicColor: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_dynamicColorKey, enabled);
    await _markSettingsUpdated();
  }

  Future<void> setFontScale(double scale) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(fontScale: scale);
    state = AsyncValue.data(next);
    await _prefs.setDouble(_fontScaleKey, scale);
    await _markSettingsUpdated();
  }

  Future<void> setWorkDuration(int minutes) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(workDuration: minutes);
    state = AsyncValue.data(next);
    await _prefs.setInt(_workDurationKey, minutes);
    await _markSettingsUpdated();
  }

  Future<void> setShortBreak(int minutes) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(shortBreak: minutes);
    state = AsyncValue.data(next);
    await _prefs.setInt(_shortBreakKey, minutes);
    await _markSettingsUpdated();
  }

  Future<void> setLongBreak(int minutes) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(longBreak: minutes);
    state = AsyncValue.data(next);
    await _prefs.setInt(_longBreakKey, minutes);
    await _markSettingsUpdated();
  }

  Future<void> setLongBreakEvery(int count) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(longBreakEvery: count);
    state = AsyncValue.data(next);
    await _prefs.setInt(_longBreakEveryKey, count);
    await _markSettingsUpdated();
  }

  Future<void> setAutoStartBreaks(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(autoStartBreaks: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_autoStartBreaksKey, enabled);
    await _markSettingsUpdated();
  }

  Future<void> setAutoStartWork(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(autoStartWork: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_autoStartWorkKey, enabled);
    await _markSettingsUpdated();
  }

  Future<void> setVibration(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(vibration: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_vibrationKey, enabled);
    await _markSettingsUpdated();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(notificationsEnabled: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_notificationsKey, enabled);
    await _markSettingsUpdated();

    // If master notifications disabled, cancel all scheduled notifications
    final notifService = NotificationService();
    if (!enabled) {
      try {
        await notifService.cancelDailyReminder();
        await notifService.cancelReminder();
      } catch (e) {
        AppLogger.e('ThemeSettings', 'Error cancelling notifications', e);
      }
    } else {
      // Re-schedule daily reminder if it was enabled
      if (current.dailyReminderEnabled) {
        try {
          await notifService.scheduleDailyReminder(
            hour: current.dailyReminderHour,
            minute: current.dailyReminderMinute,
          );
        } catch (e) {
          AppLogger.e('ThemeSettings', 'Error scheduling daily reminder', e);
        }
      }
    }
  }

  Future<void> setGracePeriodHours(double hours) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(gracePeriodHours: hours);
    state = AsyncValue.data(next);
    await _prefs.setDouble(_gracePeriodKey, hours);
    await _markSettingsUpdated();
  }

  Future<void> setStudyReminderEnabled(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(studyReminderEnabled: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_studyReminderEnabledKey, enabled);
    await _markSettingsUpdated();
  }

  Future<void> setStudyReminderMinutes(int minutes) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(studyReminderMinutes: minutes);
    state = AsyncValue.data(next);
    await _prefs.setInt(_studyReminderMinutesKey, minutes);
    await _markSettingsUpdated();
  }

  Future<void> setDailyReminderTime({required int hour, required int minute}) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(
      dailyReminderHour: hour,
      dailyReminderMinute: minute,
    );
    state = AsyncValue.data(next);
    await _prefs.setInt(_dailyReminderHourKey, hour);
    await _prefs.setInt(_dailyReminderMinuteKey, minute);
    await _markSettingsUpdated();

    // Re-schedule the daily reminder if it's enabled
    if (current.notificationsEnabled && current.dailyReminderEnabled) {
      final notifService = NotificationService();
      try {
        await notifService.scheduleDailyReminder(
          hour: hour,
          minute: minute,
        );
        AppLogger.i('ThemeSettings', 'Daily reminder rescheduled to $hour:${minute.toString().padLeft(2, '0')}');
      } catch (e) {
        AppLogger.e('ThemeSettings', 'Error rescheduling daily reminder', e);
      }
    }
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(dailyReminderEnabled: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_dailyReminderEnabledKey, enabled);
    await _markSettingsUpdated();

    // Actually schedule or cancel the daily reminder
    if (current.notificationsEnabled) {
      final notifService = NotificationService();
      try {
        if (enabled) {
          await notifService.scheduleDailyReminder(
            hour: current.dailyReminderHour,
            minute: current.dailyReminderMinute,
          );
          AppLogger.i('ThemeSettings', 'Daily reminder scheduled at ${current.dailyReminderHour}:${current.dailyReminderMinute.toString().padLeft(2, '0')}');
        } else {
          await notifService.cancelDailyReminder();
          AppLogger.i('ThemeSettings', 'Daily reminder cancelled');
        }
      } catch (e) {
        AppLogger.e('ThemeSettings', 'Error toggling daily reminder', e);
      }
    }
  }

  Future<void> setContinuousFocus(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(continuousFocus: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_continuousFocusKey, enabled);
    await _markSettingsUpdated();
  }

  Future<void> setDailyGoalMinutes(int minutes) async {
    final current = state.asData?.value;
    if (current == null) return;

    final next = current.copyWith(
      dailyGoalMinutes: minutes,
      dailyGoalsByWeekday: {
        for (final weekday in ThemeSettingsState.weekdays) weekday: minutes,
      },
    );
    state = AsyncValue.data(next);
    await _prefs.setInt(_dailyGoalMinutesKey, minutes);
    for (final entry in _dailyGoalPreferenceKeys.entries) {
      await _prefs.setInt(entry.value, minutes);
    }
    await _markSettingsUpdated();
  }

  Future<void> setDailyGoalForWeekday(int weekday, int minutes) async {
    final current = state.asData?.value;
    if (current == null) return;

    final updatedGoals = Map<int, int>.from(current.dailyGoalsByWeekday)
      ..[weekday] = minutes;
    final next = current.copyWith(dailyGoalsByWeekday: updatedGoals);
    state = AsyncValue.data(next);
    final key = _dailyGoalPreferenceKeys[weekday];
    if (key != null) {
      await _prefs.setInt(key, minutes);
    }
    await _markSettingsUpdated();
  }

  Future<void> setLastDailyGoalAwardDate(String date) async {
    final current = state.asData?.value;
    if (current == null) return;

    final next = current.copyWith(lastDailyGoalAwardDate: date);
    state = AsyncValue.data(next);
    await _prefs.setString(_lastDailyGoalAwardDateKey, date);
    await _markSettingsUpdated();
  }

  static const Map<int, String> _dailyGoalPreferenceKeys = {
    DateTime.monday: _dailyGoalMondayKey,
    DateTime.tuesday: _dailyGoalTuesdayKey,
    DateTime.wednesday: _dailyGoalWednesdayKey,
    DateTime.thursday: _dailyGoalThursdayKey,
    DateTime.friday: _dailyGoalFridayKey,
    DateTime.saturday: _dailyGoalSaturdayKey,
    DateTime.sunday: _dailyGoalSundayKey,
  };
}

class ThemeSettingsState {
  const ThemeSettingsState({
    required this.seedColorIndex,
    required this.themeMode,
    required this.themeStyle,
    required this.useDynamicColor,
    required this.fontScale,
    required this.workDuration,
    required this.shortBreak,
    required this.longBreak,
    required this.longBreakEvery,
    required this.autoStartBreaks,
    required this.autoStartWork,
    required this.vibration,
    required this.notificationsEnabled,
    required this.studyReminderEnabled,
    required this.studyReminderMinutes,
    required this.dailyReminderHour,
    required this.dailyReminderMinute,
    required this.dailyReminderEnabled,
    required this.gracePeriodHours,
    required this.continuousFocus,
    required this.dailyGoalMinutes,
    required this.dailyGoalsByWeekday,
    required this.lastDailyGoalAwardDate,
  });

  static const weekdays = <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  final int seedColorIndex;
  final ThemeMode themeMode;
  final AppThemeStyle themeStyle;
  final bool useDynamicColor;
  final double fontScale;
  final int workDuration;
  final int shortBreak;
  final int longBreak;
  final int longBreakEvery;
  final bool autoStartBreaks;
  final bool autoStartWork;
  final bool vibration;
  final bool notificationsEnabled;
  final bool studyReminderEnabled;
  final int studyReminderMinutes;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final bool dailyReminderEnabled;
  final double gracePeriodHours;
  final bool continuousFocus;
  final int dailyGoalMinutes;
  final Map<int, int> dailyGoalsByWeekday;
  final String lastDailyGoalAwardDate;

  int goalForWeekday(int weekday) {
    return dailyGoalsByWeekday[weekday] ?? dailyGoalMinutes;
  }

  int get todayGoalMinutes => goalForWeekday(DateTime.now().weekday);

  ThemeSettingsState copyWith({
    int? seedColorIndex,
    ThemeMode? themeMode,
    AppThemeStyle? themeStyle,
    bool? useDynamicColor,
    double? fontScale,
    int? workDuration,
    int? shortBreak,
    int? longBreak,
    int? longBreakEvery,
    bool? autoStartBreaks,
    bool? autoStartWork,
    bool? vibration,
    bool? notificationsEnabled,
    bool? studyReminderEnabled,
    int? studyReminderMinutes,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    bool? dailyReminderEnabled,
    double? gracePeriodHours,
    bool? continuousFocus,
    int? dailyGoalMinutes,
    Map<int, int>? dailyGoalsByWeekday,
    String? lastDailyGoalAwardDate,
  }) {
    return ThemeSettingsState(
      seedColorIndex: seedColorIndex ?? this.seedColorIndex,
      themeMode: themeMode ?? this.themeMode,
      themeStyle: themeStyle ?? this.themeStyle,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      fontScale: fontScale ?? this.fontScale,
      workDuration: workDuration ?? this.workDuration,
      shortBreak: shortBreak ?? this.shortBreak,
      longBreak: longBreak ?? this.longBreak,
      longBreakEvery: longBreakEvery ?? this.longBreakEvery,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      autoStartWork: autoStartWork ?? this.autoStartWork,
      vibration: vibration ?? this.vibration,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      studyReminderEnabled: studyReminderEnabled ?? this.studyReminderEnabled,
      studyReminderMinutes: studyReminderMinutes ?? this.studyReminderMinutes,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      gracePeriodHours: gracePeriodHours ?? this.gracePeriodHours,
      continuousFocus: continuousFocus ?? this.continuousFocus,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      dailyGoalsByWeekday:
          dailyGoalsByWeekday ?? this.dailyGoalsByWeekday,
      lastDailyGoalAwardDate: lastDailyGoalAwardDate ?? this.lastDailyGoalAwardDate,
    );
  }
}
