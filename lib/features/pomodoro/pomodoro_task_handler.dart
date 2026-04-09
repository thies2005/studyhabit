import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PomodoroTaskHandler());
}

class PomodoroTaskHandler extends TaskHandler {
  int _remaining = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Use FlutterForegroundTask.getData for cross-isolate data
    final savedData = await FlutterForegroundTask.getData(key: 'remaining');
    if (savedData is int) {
      _remaining = savedData;
    }
    if (_remaining <= 0) _remaining = 0;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_remaining > 0) {
      _remaining--;
      FlutterForegroundTask.updateService(
        notificationTitle: _formatNotifTitle(),
        notificationText: '${_formatTime(_remaining)} remaining',
      );
      FlutterForegroundTask.sendDataToMain(_remaining);
      // Persist remaining time for isolate recovery
      FlutterForegroundTask.saveData(key: 'remaining', value: _remaining);
    }
    if (_remaining <= 0) {
      FlutterForegroundTask.sendDataToMain('PHASE_COMPLETE');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onReceiveData(Object data) {
    if (data is int) {
      _remaining = data;
    }
  }

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}

  String _formatNotifTitle() {
    if (_remaining <= 0) return 'Session complete!';
    return 'Study Timer';
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
