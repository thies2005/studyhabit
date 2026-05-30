import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/session_dao.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/xp_service.dart';
import 'free_timer_state.dart';
import '../../core/services/timer_persistence_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../core/services/sync_service.dart';


part 'free_timer_notifier.g.dart';

@Riverpod(keepAlive: true)
class FreeTimerNotifier extends _$FreeTimerNotifier with WidgetsBindingObserver {
  SessionDao? _sessionDao;
  Timer? _tickTimer;
  TimerPersistenceService? _persistence;
  bool _listenerRegistered = false;
  int? _lastDbMinutesUpdate;

  @override
  FreeTimerState build() {
    final db = ref.watch(appDatabaseProvider);
    _sessionDao = SessionDao(db);

    _persistence = TimerPersistenceService(TimerPersistenceService.prefs);

    WidgetsBinding.instance.addObserver(this);

    ref.onDispose(() {
      _tickTimer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
      if (_listenerRegistered && (Platform.isAndroid || Platform.isIOS)) {
        FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
        _listenerRegistered = false;
      }
    });

    final saved = _persistence!.loadFreeTimerSync();
    if (saved != null && saved.activeSessionId != null) {
      if (saved.isRunning) {
        _startTickingDelayed();
        _startForegroundServiceDelayed();
      }
      return saved;
    }

    return FreeTimerState.initial();
  }

  void reloadFromPersistence() {
    final saved = _persistence?.loadFreeTimerSync();
    if (saved != null && saved.activeSessionId != null) {
      state = saved;
      if (state.isRunning) {
        _startTickingDelayed();
        _startForegroundServiceDelayed();
      } else {
        _tickTimer?.cancel();
        _stopForegroundService();
      }
    } else {
      if (state.activeSessionId != null) {
        _tickTimer?.cancel();
        _stopForegroundService();
        state = FreeTimerState.initial();
      }
    }
  }

  void _startTickingDelayed() {
    Future.microtask(() {
      _startTicking();
    });
  }

  void _startForegroundServiceDelayed() {
    Future.microtask(() {
      _startForegroundService();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTimeFromTimestamps();
    }
  }

  void _syncTimeFromTimestamps() {
    if (state.activeSessionId == null || state.startedAt == null) return;

    final now = DateTime.now();
    int actualElapsedSeconds;

    if (state.isRunning) {
      actualElapsedSeconds = now.difference(state.startedAt!).inSeconds -
          state.pausedDurationSeconds;
    } else {
      final pauseTime = state.lastPausedAt ?? now;
      actualElapsedSeconds = pauseTime.difference(state.startedAt!).inSeconds -
          state.pausedDurationSeconds;
    }

    final elapsed = actualElapsedSeconds.clamp(0, double.maxFinite.toInt());
    if (state.elapsedSeconds != elapsed) {
      state = state.copyWith(elapsedSeconds: elapsed);
      _persistState();
      _checkAndUpdateDbDuration(elapsed);
    }
  }

  Future<void> _checkAndUpdateDbDuration(int elapsedSeconds) async {
    if (state.activeSessionId == null) return;
    final newMinutes = (elapsedSeconds / 60.0).round();
    if (_lastDbMinutesUpdate == newMinutes) return;

    _lastDbMinutesUpdate = newMinutes;
    final session = await _sessionDao?.getById(state.activeSessionId!);
    if (session != null) {
      await _sessionDao?.updateRow(
        session.copyWith(
          actualDurationMinutes: newMinutes,
        ),
      );
    }
  }

  void _persistState() {
    _persistence?.saveFreeTimer(state);
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isRunning && state.startedAt != null) {
        final now = DateTime.now();
        final effectiveElapsed = now.difference(state.startedAt!).inSeconds -
            state.pausedDurationSeconds;
        final elapsed = effectiveElapsed.clamp(0, double.maxFinite.toInt());
        state = state.copyWith(elapsedSeconds: elapsed);
        _checkAndUpdateDbDuration(elapsed);
      }
    });
  }

  Future<void> start({
    required String subjectId,
    String? topicId,
    String? chapterId,
  }) async {
    const uuid = Uuid();
    final sessionId = uuid.v4();
    final now = DateTime.now();

    _lastDbMinutesUpdate = 0;

    state = FreeTimerState(
      isRunning: true,
      elapsedSeconds: 0,
      pausedDurationSeconds: 0,
      subjectId: subjectId,
      topicId: topicId,
      chapterId: chapterId,
      activeSessionId: sessionId,
      startedAt: now,
    );

    _startTicking();
    _startForegroundService();
    _persistState();

    // Insert dummy session to DB
    await _sessionDao?.insert(
      StudySessionsCompanion.insert(
        id: sessionId,
        subjectId: subjectId,
        topicId: Value(topicId),
        chapterId: Value(chapterId),
        startedAt: Value(now),
        plannedDurationMinutes: 0,
        isFreeTimer: const Value(true),
      ),
    );
    ref.read(syncEngineProvider.notifier).syncNow();
  }

  void pause() {
    if (!state.isRunning) return;
    state = state.copyWith(
      isRunning: false,
      lastPausedAt: DateTime.now(),
    );
    _syncForegroundTaskData();
    _persistState();
    ref.read(syncEngineProvider.notifier).syncNow();
  }

  void resume() {
    if (state.isRunning || state.lastPausedAt == null) return;
    final now = DateTime.now();
    final pausedSeconds = now.difference(state.lastPausedAt!).inSeconds;

    state = state.copyWith(
      isRunning: true,
      pausedDurationSeconds: state.pausedDurationSeconds + pausedSeconds,
      lastPausedAt: null,
    );
    _syncForegroundTaskData();
    _persistState();
    ref.read(syncEngineProvider.notifier).syncNow();
  }

  Future<void> stop() async {
    if (state.activeSessionId == null) return;

    _tickTimer?.cancel();
    _tickTimer = null;

    // Recalculate accurately from timestamps to prevent stale values (Finding 2)
    final now = DateTime.now();
    int actualElapsedSeconds = 0;
    if (state.startedAt != null) {
      if (state.isRunning) {
        actualElapsedSeconds = now.difference(state.startedAt!).inSeconds -
            state.pausedDurationSeconds;
      } else {
        final pauseTime = state.lastPausedAt ?? now;
        actualElapsedSeconds = pauseTime.difference(state.startedAt!).inSeconds -
            state.pausedDurationSeconds;
      }
    }
    actualElapsedSeconds = actualElapsedSeconds.clamp(0, double.maxFinite.toInt());
    final elapsedMinutes = (actualElapsedSeconds / 60.0).round(); // round to avoid truncation (Finding 8)
    final endedAt = now;

    // Delete dummy session from DB if <= 0 minutes (Finding 9)
    if (elapsedMinutes <= 0) {
      try {
        await _sessionDao?.delete(state.activeSessionId!);
        ref.read(syncEngineProvider.notifier).syncNow();
      } catch (e) {
        debugPrint('Error deleting dummy session: $e');
      }
    } else {
      // Award streak if >= 1 min
      if (elapsedMinutes >= 1) {
        try {
          await ref.read(streakServiceProvider).recordStudyDay(ref);
        } catch (e) {
          debugPrint('Error recording study day: $e');
        }
      }

      // Award achievements
      try {
        await AchievementService().checkAndUnlock(ref.read(appDatabaseProvider));
      } catch (e) {
        debugPrint('Error checking achievements: $e');
      }
      try {
        await _checkDailyGoalXp();
      } catch (e) {
        debugPrint('Error checking daily goal XP: $e');
      }

      // Update session in DB
      try {
        final session = await _sessionDao?.getById(state.activeSessionId!);
        if (session != null) {
          await _sessionDao?.updateRow(
            session.copyWith(
              actualDurationMinutes: elapsedMinutes,
              endedAt: Value(endedAt),
            ),
          );
          ref.read(syncEngineProvider.notifier).syncNow();
        }
      } catch (e) {
        debugPrint('Error updating session in DB: $e');
      }
    }

    // Note: XP is handled by review sheet if confidence is given
    // We keep the state so the review sheet can access activeSessionId
    _persistence?.clearFreeTimer();
    state = state.copyWith(isRunning: false, activeSessionId: null);
    try {
      await _stopForegroundService();
    } catch (e) {
      debugPrint('Error stopping foreground service: $e');
    }
  }

  void reset() {
    _persistence?.clearFreeTimer();
    state = FreeTimerState.initial();
    _tickTimer?.cancel();
    _stopForegroundService();
  }

  Future<void> awardConfidenceXpAndNotes({
    required int? confidenceRating,
    String? notes,
    String? sessionId,
  }) async {
    final id = sessionId ?? state.activeSessionId;
    if (id == null) return;

    final session = await _sessionDao?.getById(id);
    if (session == null) return;

    int newXpEarned = session.xpEarned;

    if (confidenceRating != null && session.confidenceRating == null) {
      await ref.read(xpServiceProvider).award(ref, XpReason.confidence);
      newXpEarned += 10;
    }

    await _sessionDao?.updateRow(
      session.copyWith(
        confidenceRating: Value(confidenceRating),
        notes: Value(notes),
        xpEarned: newXpEarned,
      ),
    );
    ref.read(syncEngineProvider.notifier).debouncedSync();
  }

  Future<void> _startForegroundService() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    // Check if service is already running effectively
    if (await FlutterForegroundTask.isRunningService) {
      _syncForegroundTaskData();
      return;
    }
    _ensureListener();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'study_timer',
        channelName: 'Study Timer',
        channelDescription: 'Ongoing study timer notification',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    await FlutterForegroundTask.startService(
      notificationTitle: 'Free Timer Running',
      notificationText: '00:00 elapsed',
      callback: freeTimerCallback,
    );
    _syncForegroundTaskData();
  }

  Future<void> _stopForegroundService() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await FlutterForegroundTask.stopService();
    } on TimeoutException {
      debugPrint('FreeTimer: stopService timed out after 3s');
    } catch (e) {
      debugPrint('FreeTimer: Error stopping foreground service: $e');
    }
  }

  void _ensureListener() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (!_listenerRegistered) {
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
      _listenerRegistered = true;
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is int) {
      if (state.isRunning && state.activeSessionId != null) {
        if ((state.elapsedSeconds - data).abs() > 1) {
          state = state.copyWith(elapsedSeconds: data);
          _persistState();
          _checkAndUpdateDbDuration(data);
        }
      }
    }
  }

  void _syncForegroundTaskData() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (!state.isRunning) return;
    
    // We send timestamps so the background task can calculate accurately
    FlutterForegroundTask.sendDataToTask({
      'type': 'FREE_TIMER',
      'startedAt': state.startedAt?.toIso8601String(),
      'pausedDurationSeconds': state.pausedDurationSeconds,
      'isRunning': state.isRunning,
    });
  }

  Future<void> _checkDailyGoalXp() async {
    final settings = ref.read(themeSettingsProvider).value;
    if (settings == null || settings.todayGoalMinutes <= 0) return;

    final todayStr = _todayDateString();
    if (settings.lastDailyGoalAwardDate == todayStr) return;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessions = await (db.select(db.studySessions)
          ..where((t) => t.startedAt.isBiggerOrEqualValue(today)))
        .get();
    final todayMinutes = sessions.fold<int>(
      0,
      (sum, s) => sum + s.actualDurationMinutes,
    );

    if (todayMinutes >= settings.todayGoalMinutes) {
      await ref.read(xpServiceProvider).award(ref, XpReason.dailyGoal);
      await ref
          .read(themeSettingsProvider.notifier)
          .setLastDailyGoalAwardDate(todayStr);
    }
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// Global callback for foreground task (must be top-level)
@pragma('vm:entry-point')
void freeTimerCallback() {
  FlutterForegroundTask.setTaskHandler(FreeTimerTaskHandler());
}

class FreeTimerTaskHandler extends TaskHandler {
  DateTime? _startedAt;
  int _pausedDurationSeconds = 0;
  bool _isRunning = false;
  int _lastElapsed = -1;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final startedAtStr = await FlutterForegroundTask.getData<String>(key: 'startedAt');
    if (startedAtStr != null) {
      _startedAt = DateTime.parse(startedAtStr);
    }
    _pausedDurationSeconds = await FlutterForegroundTask.getData<int>(key: 'pausedDurationSeconds') ?? 0;
    _isRunning = await FlutterForegroundTask.getData<bool>(key: 'isRunning') ?? false;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_isRunning && _startedAt != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_startedAt!).inSeconds - _pausedDurationSeconds;
      final elapsedSeconds = elapsed.clamp(0, double.maxFinite.toInt());

      if (elapsedSeconds != _lastElapsed) {
        _lastElapsed = elapsedSeconds;

        final hours = elapsedSeconds ~/ 3600;
        final mins = (elapsedSeconds % 3600) ~/ 60;
        final secs = elapsedSeconds % 60;

        final timeStr = hours > 0 
          ? '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'
          : '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

        FlutterForegroundTask.updateService(
          notificationTitle: 'Focused Session',
          notificationText: '$timeStr elapsed',
        );

        FlutterForegroundTask.sendDataToMain(elapsedSeconds);
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
  
  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final startedAtStr = data['startedAt'] as String?;
      final pausedSeconds = data['pausedDurationSeconds'] as int? ?? 0;
      final isRunning = data['isRunning'] as bool? ?? false;
      
      _pausedDurationSeconds = pausedSeconds;
      _isRunning = isRunning;
      if (startedAtStr != null) {
        _startedAt = DateTime.parse(startedAtStr);
        FlutterForegroundTask.saveData(key: 'startedAt', value: startedAtStr);
      }
      FlutterForegroundTask.saveData(key: 'pausedDurationSeconds', value: _pausedDurationSeconds);
      FlutterForegroundTask.saveData(key: 'isRunning', value: _isRunning);

      if (_startedAt != null) {
        final elapsed = DateTime.now().difference(_startedAt!).inSeconds - _pausedDurationSeconds;
        final elapsedSeconds = elapsed.clamp(0, double.maxFinite.toInt());
        _lastElapsed = elapsedSeconds;
        
        final hours = elapsedSeconds ~/ 3600;
        final mins = (elapsedSeconds % 3600) ~/ 60;
        final secs = elapsedSeconds % 60;
        
        final timeStr = hours > 0 
          ? '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'
          : '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

        FlutterForegroundTask.updateService(
          notificationTitle: 'Focused Session',
          notificationText: '$timeStr elapsed',
        );
      }
    }
  }
}
