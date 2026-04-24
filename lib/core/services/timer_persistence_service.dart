import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/pomodoro/pomodoro_state.dart';
import '../../features/pomodoro/free_timer_state.dart';

class TimerPersistenceService {
  static const String _activeTimerKey = 'active_timer_type';
  static const String _pomodoroStateKey = 'pomodoro_state_json';
  static const String _freeTimerStateKey = 'free_timer_state_json';

  final SharedPreferences _prefs;

  TimerPersistenceService(this._prefs);

  Future<void> savePomodoro(PomodoroState state) async {
    await _prefs.setString(_activeTimerKey, 'pomodoro');
    await _prefs.setString(_pomodoroStateKey, jsonEncode(state.toJson()));
  }

  Future<PomodoroState?> loadPomodoro() async {
    final jsonStr = _prefs.getString(_pomodoroStateKey);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PomodoroState.fromJson(map);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveFreeTimer(FreeTimerState state) async {
    await _prefs.setString(_activeTimerKey, 'free');
    await _prefs.setString(_freeTimerStateKey, jsonEncode(state.toJson()));
  }

  Future<FreeTimerState?> loadFreeTimer() async {
    final jsonStr = _prefs.getString(_freeTimerStateKey);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return FreeTimerState.fromJson(map);
    } catch (e) {
      return null;
    }
  }

  String? getActiveTimerType() {
    return _prefs.getString(_activeTimerKey);
  }

  Future<void> clearPomodoro() async {
    await _prefs.remove(_pomodoroStateKey);
    if (getActiveTimerType() == 'pomodoro') {
      await _prefs.remove(_activeTimerKey);
    }
  }

  Future<void> clearFreeTimer() async {
    await _prefs.remove(_freeTimerStateKey);
    if (getActiveTimerType() == 'free') {
      await _prefs.remove(_activeTimerKey);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_activeTimerKey);
    await _prefs.remove(_pomodoroStateKey);
    await _prefs.remove(_freeTimerStateKey);
  }
}
