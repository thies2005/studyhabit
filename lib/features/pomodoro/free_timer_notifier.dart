import 'dart:async';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/session_dao.dart';
import '../../core/providers/database_provider.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/xp_service.dart';
import 'free_timer_state.dart';
import '../../core/services/timer_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';


part 'free_timer_notifier.g.dart';

@Riverpod(keepAlive: true)
class FreeTimerNotifier extends _$FreeTimerNotifier {
  SessionDao? _sessionDao;
  Timer? _tickTimer;
  TimerPersistenceService? _persistence;

  @override
  FreeTimerState build() {
    final db = ref.watch(appDatabaseProvider);
    _sessionDao = SessionDao(db);

    _initPersistence();

    ref.onDispose(() {
      _tickTimer?.cancel();
    });

    return FreeTimerState.initial();
  }

  Future<void> _initPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    _persistence = TimerPersistenceService(prefs);

    final saved = await _persistence!.loadFreeTimer();
    if (saved != null && saved.activeSessionId != null) {
      state = saved;
      if (state.isRunning) {
        _startTicking();
        _startForegroundService();
      }
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
        state = state.copyWith(elapsedSeconds: effectiveElapsed.clamp(0, double.maxFinite.toInt()));
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
  }

  void pause() {
    if (!state.isRunning) return;
    state = state.copyWith(
      isRunning: false,
      lastPausedAt: DateTime.now(),
    );
    _syncForegroundTaskData();
    _persistState();
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
  }

  Future<void> stop() async {
    if (state.activeSessionId == null) return;

    _tickTimer?.cancel();
    _tickTimer = null;

    final elapsedMinutes = state.elapsedSeconds ~/ 60;
    final endedAt = DateTime.now();

    // Award streak if >= 1 min
    if (elapsedMinutes >= 1) {
      await ref.read(streakServiceProvider).recordStudyDay(ref);
    }

    // Award achievements
    await ref.read(achievementServiceProvider).checkAndUnlock(ref);

    // Update session in DB
    final session = await _sessionDao?.getById(state.activeSessionId!);
    if (session != null) {
      await _sessionDao?.update(
        session.copyWith(
          actualDurationMinutes: elapsedMinutes,
          endedAt: Value(endedAt),
        ),
      );
    }

    // Note: XP is handled by review sheet if confidence is given
    // We keep the state so the review sheet can access activeSessionId
    _persistence?.clearFreeTimer();
    state = state.copyWith(isRunning: false);
    _stopForegroundService();
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
  }) async {
    if (state.activeSessionId == null) return;

    final session = await _sessionDao?.getById(state.activeSessionId!);
    if (session == null) return;

    int newXpEarned = session.xpEarned;

    if (confidenceRating != null && session.confidenceRating == null) {
      await ref.read(xpServiceProvider).award(ref, XpReason.confidence);
      newXpEarned += 10;
    }

    await _sessionDao?.update(
      session.copyWith(
        confidenceRating: Value(confidenceRating),
        notes: Value(notes),
        xpEarned: newXpEarned,
      ),
    );
  }

  Future<void> _startForegroundService() async {
    // Check if service is already running effectively
    if (await FlutterForegroundTask.isRunningService) {
      _syncForegroundTaskData();
      return;
    }

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
    await FlutterForegroundTask.stopService();
  }

  void _syncForegroundTaskData() {
    if (!state.isRunning) return;
    
    // We send timestamps so the background task can calculate accurately
    FlutterForegroundTask.sendDataToTask({
      'type': 'FREE_TIMER',
      'startedAt': state.startedAt?.toIso8601String(),
      'pausedDurationSeconds': state.pausedDurationSeconds,
      'isRunning': state.isRunning,
    });
  }
}

// Global callback for foreground task (must be top-level)
@pragma('vm:entry-point')
void freeTimerCallback() {
  FlutterForegroundTask.setTaskHandler(FreeTimerTaskHandler());
}

class FreeTimerTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Initial data handled via sendDataToTask
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Background ticking is handled via data sync to main UI
    // and calculation on return. 
    // Usually we update notification here.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
  
  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final startedAtStr = data['startedAt'] as String?;
      final pausedSeconds = data['pausedDurationSeconds'] as int? ?? 0;
      
      if (startedAtStr != null) {
        final startedAt = DateTime.parse(startedAtStr);
        final elapsed = DateTime.now().difference(startedAt).inSeconds - pausedSeconds;
        
        final hours = elapsed ~/ 3600;
        final mins = (elapsed % 3600) ~/ 60;
        final secs = elapsed % 60;
        
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
