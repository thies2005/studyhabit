import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

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
  static const _vibrationKey = 'pomodoro.vibration';
  static const _notificationsKey = 'notifications.enabled';
  static const _studyReminderEnabledKey = 'notifications.studyReminderEnabled';
  static const _studyReminderMinutesKey = 'notifications.studyReminderMinutes';
  static const _dailyReminderHourKey = 'notifications.dailyReminderHour';
  static const _dailyReminderMinuteKey = 'notifications.dailyReminderMinute';
  static const _gracePeriodKey = 'streak.gracePeriod';

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

    final fontScale = _prefs.getDouble(_fontScaleKey) ?? 1.0;
    final workDuration = _prefs.getInt(_workDurationKey) ?? 25;
    final shortBreak = _prefs.getInt(_shortBreakKey) ?? 5;
    final longBreak = _prefs.getInt(_longBreakKey) ?? 15;
    final longBreakEvery = _prefs.getInt(_longBreakEveryKey) ?? 4;
    final autoStartBreaks = _prefs.getBool(_autoStartBreaksKey) ?? false;
    final vibration = _prefs.getBool(_vibrationKey) ?? true;
    final notifications = _prefs.getBool(_notificationsKey) ?? true;
    final studyReminderEnabled = _prefs.getBool(_studyReminderEnabledKey) ?? false;
    final studyReminderMinutes = _prefs.getInt(_studyReminderMinutesKey) ?? 30;
    final dailyReminderHour = _prefs.getInt(_dailyReminderHourKey) ?? 9;
    final dailyReminderMinute = _prefs.getInt(_dailyReminderMinuteKey) ?? 0;
    final gracePeriod = _prefs.getDouble(_gracePeriodKey) ?? 2.0;

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
      vibration: vibration,
      notificationsEnabled: notifications,
      studyReminderEnabled: studyReminderEnabled,
      studyReminderMinutes: studyReminderMinutes,
      dailyReminderHour: dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute,
      gracePeriodHours: gracePeriod,
    );
  }

  Future<void> setSeedColor(int index) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(seedColorIndex: index);
    state = AsyncValue.data(next);
    await _prefs.setInt(_seedColorKey, index);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(themeMode: mode);
    state = AsyncValue.data(next);
    await _prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> setThemeStyle(AppThemeStyle style) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(themeStyle: style);
    state = AsyncValue.data(next);
    await _prefs.setInt(_themeStyleKey, style.index);
  }

  Future<void> setUseDynamicColor(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(useDynamicColor: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_dynamicColorKey, enabled);
  }

  Future<void> setFontScale(double scale) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(fontScale: scale);
    state = AsyncValue.data(next);
    await _prefs.setDouble(_fontScaleKey, scale);
  }

  Future<void> setWorkDuration(int minutes) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(workDuration: minutes);
    state = AsyncValue.data(next);
    await _prefs.setInt(_workDurationKey, minutes);
  }

  Future<void> setShortBreak(int minutes) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(shortBreak: minutes);
    state = AsyncValue.data(next);
    await _prefs.setInt(_shortBreakKey, minutes);
  }

  Future<void> setLongBreak(int minutes) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(longBreak: minutes);
    state = AsyncValue.data(next);
    await _prefs.setInt(_longBreakKey, minutes);
  }

  Future<void> setLongBreakEvery(int count) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(longBreakEvery: count);
    state = AsyncValue.data(next);
    await _prefs.setInt(_longBreakEveryKey, count);
  }

  Future<void> setAutoStartBreaks(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(autoStartBreaks: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_autoStartBreaksKey, enabled);
  }

  Future<void> setVibration(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(vibration: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_vibrationKey, enabled);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(notificationsEnabled: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_notificationsKey, enabled);
  }

  Future<void> setGracePeriodHours(double hours) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(gracePeriodHours: hours);
    state = AsyncValue.data(next);
    await _prefs.setDouble(_gracePeriodKey, hours);
  }

  Future<void> setStudyReminderEnabled(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(studyReminderEnabled: enabled);
    state = AsyncValue.data(next);
    await _prefs.setBool(_studyReminderEnabledKey, enabled);
  }

  Future<void> setStudyReminderMinutes(int minutes) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final next = current.copyWith(studyReminderMinutes: minutes);
    state = AsyncValue.data(next);
    await _prefs.setInt(_studyReminderMinutesKey, minutes);
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
  }
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
    required this.vibration,
    required this.notificationsEnabled,
    required this.studyReminderEnabled,
    required this.studyReminderMinutes,
    required this.dailyReminderHour,
    required this.dailyReminderMinute,
    required this.gracePeriodHours,
  });

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
  final bool vibration;
  final bool notificationsEnabled;
  final bool studyReminderEnabled;
  final int studyReminderMinutes;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final double gracePeriodHours;

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
    bool? vibration,
    bool? notificationsEnabled,
    bool? studyReminderEnabled,
    int? studyReminderMinutes,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    double? gracePeriodHours,
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
      vibration: vibration ?? this.vibration,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      studyReminderEnabled: studyReminderEnabled ?? this.studyReminderEnabled,
      studyReminderMinutes: studyReminderMinutes ?? this.studyReminderMinutes,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      gracePeriodHours: gracePeriodHours ?? this.gracePeriodHours,
    );
  }
}
