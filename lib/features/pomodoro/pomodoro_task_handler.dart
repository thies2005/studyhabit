import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PomodoroTaskHandler());
}

class PomodoroTaskHandler extends TaskHandler {
  DateTime? _startTimestamp;
  int _pausedDurationSeconds = 0;
  int _totalSeconds = 0;
  bool _isRunning = false;
  int _lastRemaining = 0;
  bool _phaseCompleteSent = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final startTime = await FlutterForegroundTask.getData<int>(key: 'startTimestamp');
    if (startTime != null) {
      _startTimestamp = DateTime.fromMillisecondsSinceEpoch(startTime);
    }
    _pausedDurationSeconds = await FlutterForegroundTask.getData<int>(key: 'pausedDurationSeconds') ?? 0;
    _totalSeconds = await FlutterForegroundTask.getData<int>(key: 'totalSeconds') ?? 0;
    _isRunning = await FlutterForegroundTask.getData<bool>(key: 'isRunning') ?? false;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_isRunning && _startTimestamp != null) {
      final now = DateTime.now();
      final actualElapsedSeconds = now.difference(_startTimestamp!).inSeconds - _pausedDurationSeconds;
      final remaining = (_totalSeconds - actualElapsedSeconds).clamp(0, _totalSeconds);

      if (remaining != _lastRemaining) {
        _lastRemaining = remaining;
        FlutterForegroundTask.updateService(
          notificationTitle: _formatNotifTitle(remaining),
          notificationText: '${_formatTime(remaining)} remaining',
        );
        FlutterForegroundTask.sendDataToMain(remaining);
      }

      if (remaining <= 0 && !_phaseCompleteSent) {
        _phaseCompleteSent = true;
        FlutterForegroundTask.sendDataToMain('PHASE_COMPLETE');
      }
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map<String, dynamic>) {
      // Reset phase complete flag when receiving new state (phase changed)
      _phaseCompleteSent = false;
      
      if (data.containsKey('startTimestamp')) {
        final val = data['startTimestamp'];
        _startTimestamp = val != null ? DateTime.fromMillisecondsSinceEpoch(val as int) : null;
        FlutterForegroundTask.saveData(key: 'startTimestamp', value: val);
      }
      if (data.containsKey('pausedDurationSeconds')) {
        _pausedDurationSeconds = data['pausedDurationSeconds'] as int;
        FlutterForegroundTask.saveData(key: 'pausedDurationSeconds', value: _pausedDurationSeconds);
      }
      if (data.containsKey('totalSeconds')) {
        _totalSeconds = data['totalSeconds'] as int;
        FlutterForegroundTask.saveData(key: 'totalSeconds', value: _totalSeconds);
      }
      if (data.containsKey('isRunning')) {
        _isRunning = data['isRunning'] as bool;
        FlutterForegroundTask.saveData(key: 'isRunning', value: _isRunning);
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}

  String _formatNotifTitle(int remaining) {
    if (remaining <= 0) return 'Session complete!';
    return 'Study Timer';
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
