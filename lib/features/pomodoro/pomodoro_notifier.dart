import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/project_dao.dart';
import '../../core/database/daos/session_dao.dart';
import '../../core/database/daos/subject_dao.dart';
import '../../core/models/enums.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/xp_service.dart';
import 'pomodoro_state.dart';
import 'pomodoro_task_handler.dart';

part 'pomodoro_notifier.g.dart';

class PomodoroConfig {
  const PomodoroConfig({
    required this.subjectId,
    this.topicId,
    this.chapterId,
    required this.plannedDurationMinutes,
    required this.breakDurationMinutes,
    this.longBreakDurationMinutes = 15,
    this.longBreakEvery = 4,
    this.sourceId,
  });

  final String subjectId;
  final String? topicId;
  final String? chapterId;
  final int plannedDurationMinutes;
  final int breakDurationMinutes;
  final int longBreakDurationMinutes;
  final int longBreakEvery;
  final String? sourceId;
}

@Riverpod(keepAlive: true)
class PomodoroNotifier extends _$PomodoroNotifier {
  AppDatabase? _db;
  SessionDao? _sessionDao;
  SubjectDao? _subjectDao;
  ProjectDao? _projectDao;
  bool _listenerRegistered = false;
  Timer? _localTimer;

  @override
  PomodoroState build() {
    _db = ref.watch(appDatabaseProvider);
    _sessionDao = SessionDao(_db!);
    _subjectDao = SubjectDao(_db!);
    _projectDao = ProjectDao(_db!);

    ref.onDispose(() {
      _localTimer?.cancel();
      _localTimer = null;
      if (_listenerRegistered) {
        FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
        _listenerRegistered = false;
      }
    });



    return PomodoroState.initial(subjectId: '');
  }

  void _ensureListener() {
    if (!_listenerRegistered) {
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
      _listenerRegistered = true;
    }
  }

  void _startLocalTimer() {
    _localTimer?.cancel();
    _localTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isRunning && state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);

        final phaseLabel = state.phase == TimerPhase.work
            ? 'Focus Time'
            : state.phase == TimerPhase.shortBreak
                ? 'Short Break'
                : 'Long Break';

        FlutterForegroundTask.updateService(
          notificationTitle: phaseLabel,
          notificationText: _formatTime(state.remainingSeconds),
        );

        if (state.remainingSeconds <= 0) {
          _onPhaseComplete();
        }
      }
    });
  }

  void _stopLocalTimer() {
    _localTimer?.cancel();
  }

  void startTimer() {
    if (state.phase == TimerPhase.idle && state.subjectId.isNotEmpty) {
      final workSeconds = state.plannedDurationMinutes * 60;

      state = state.copyWith(
        phase: TimerPhase.work,
        isRunning: true,
        remainingSeconds: workSeconds,
        totalSeconds: workSeconds,
      );

      _startLocalTimer();
      _startForegroundService();
    }
  }

  Future<void> _startForegroundService() async {
    _ensureListener();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'study_timer',
        channelName: 'Pomodoro Timer',
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
      notificationTitle: 'Focus Time',
      notificationText: '${state.plannedDurationMinutes} min session',
      callback: startCallback,
    );

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Focus Time',
      notificationText: _formatTime(state.remainingSeconds),
    );

    FlutterForegroundTask.sendDataToTask(state.remainingSeconds);
  }

  void _onReceiveTaskData(Object data) {
    if (data is int) {
      if (state.isRunning && state.phase != TimerPhase.idle) {
        state = state.copyWith(remainingSeconds: data);
      }
    } else if (data == 'PHASE_COMPLETE') {
      _onPhaseComplete();
    }
  }

  Future<void> start(PomodoroConfig config) async {
    const uuid = Uuid();
    final sessionId = uuid.v4();
    final now = DateTime.now();

    await _sessionDao!.insert(
      StudySessionsCompanion.insert(
        id: sessionId,
        subjectId: config.subjectId,
        topicId: Value(config.topicId),
        chapterId: Value(config.chapterId),
        startedAt: Value(now),
        plannedDurationMinutes: config.plannedDurationMinutes,
        sourceId: Value(config.sourceId),
      ),
    );

    final workSeconds = config.plannedDurationMinutes * 60;

    state = PomodoroState(
      phase: TimerPhase.work,
      remainingSeconds: workSeconds,
      totalSeconds: workSeconds,
      pomodorosCompleted: 0,
      isRunning: true,
      activeSessionId: sessionId,
      subjectId: config.subjectId,
      topicId: config.topicId,
      chapterId: config.chapterId,
      plannedDurationMinutes: config.plannedDurationMinutes,
      breakDurationMinutes: config.breakDurationMinutes,
      longBreakDurationMinutes: config.longBreakDurationMinutes,
      longBreakEvery: config.longBreakEvery,
    );

    await _startForegroundService();

    _startLocalTimer();
  }

  Future<void> _onPhaseComplete() async {
    if (state.phase == TimerPhase.work) {
      final newPomodoros = state.pomodorosCompleted + 1;

      await ref.read(xpServiceProvider).award(ref, XpReason.completePomodoro);

      final actualMinutes = state.plannedDurationMinutes;
      if (actualMinutes >= 50) {
        await ref.read(xpServiceProvider).award(ref, XpReason.longSession);
      }

      await ref.read(streakServiceProvider).recordStudyDay(ref);
      await ref.read(achievementServiceProvider).checkAndUnlock(ref);

      final isLongBreak =
          newPomodoros > 0 && newPomodoros % state.longBreakEvery == 0;
      final breakMinutes = isLongBreak
          ? state.longBreakDurationMinutes
          : state.breakDurationMinutes;
      final breakSeconds = breakMinutes * 60;
      final breakPhase = isLongBreak
          ? TimerPhase.longBreak
          : TimerPhase.shortBreak;

      state = state.copyWith(
        phase: breakPhase,
        remainingSeconds: breakSeconds,
        totalSeconds: breakSeconds,
        pomodorosCompleted: newPomodoros,
        isRunning: false,
      );

      await _updateSessionInDb(
        actualDurationMinutes: state.plannedDurationMinutes,
        pomodorosCompleted: newPomodoros,
      );

      final notifService = ref.read(notificationServiceProvider);
      try {
        await notifService.showSessionComplete(
          durationMinutes: state.plannedDurationMinutes,
          pomodorosCompleted: newPomodoros,
        );

        final subject = await _subjectDao?.getById(state.subjectId);
        if (subject != null) {
          final project = await _projectDao?.getById(subject.projectId);
          bool reminderEnabled = false;
          int reminderMinutes = 30;

          if (project != null) {
            reminderMinutes = project.studyReminderMinutes;
            reminderEnabled = true;
          } else {
            final themeSettingsAsync = ref.read(themeSettingsProvider);
            final settings = themeSettingsAsync.value;
            if (settings != null) {
              reminderEnabled = settings.studyReminderEnabled;
              reminderMinutes = settings.studyReminderMinutes;
            }
          }

          if (reminderEnabled) {
            await notifService.scheduleStudyReminder(
              delay: Duration(minutes: reminderMinutes),
              subjectName: subject.name,
            );
          }
        }
      } catch (e) {
        debugPrint('Error showing notification: $e');
      }
    } else if (state.phase == TimerPhase.shortBreak ||
        state.phase == TimerPhase.longBreak) {
      final workSeconds = state.plannedDurationMinutes * 60;
      state = state.copyWith(
        phase: TimerPhase.work,
        remainingSeconds: workSeconds,
        totalSeconds: workSeconds,
        isRunning: false,
      );

      FlutterForegroundTask.sendDataToTask(workSeconds);
    }
  }

  void pause() {
    state = state.copyWith(isRunning: false);
    _stopLocalTimer();
  }

  void resume() {
    state = state.copyWith(isRunning: true);
    _startLocalTimer();
  }

  Future<void> stop() async {
    _stopLocalTimer();
    _localTimer = null;

    final elapsed = state.totalSeconds - state.remainingSeconds;
    final actualMinutes = elapsed ~/ 60;

    if (state.pomodorosCompleted > 0 || actualMinutes >= 1) {
      await ref.read(streakServiceProvider).recordStudyDay(ref);
    }

    await _updateSessionInDb(
      actualDurationMinutes: actualMinutes,
      pomodorosCompleted: state.pomodorosCompleted,
      endedAt: DateTime.now(),
    );

    await ref.read(achievementServiceProvider).checkAndUnlock(ref);
    await FlutterForegroundTask.stopService();

    // Cancel any pending reminder
    try {
      await ref.read(notificationServiceProvider).cancelReminder();
    } catch (e) {
      debugPrint('Error cancelling reminder: $e');
    }

    state = PomodoroState.initial(subjectId: state.subjectId);
  }

  void skipBreak() {
    if (state.phase == TimerPhase.shortBreak ||
        state.phase == TimerPhase.longBreak) {
      final workSeconds = state.plannedDurationMinutes * 60;
      state = state.copyWith(
        phase: TimerPhase.work,
        remainingSeconds: workSeconds,
        totalSeconds: workSeconds,
        isRunning: false,
      );

      FlutterForegroundTask.sendDataToTask(workSeconds);
    }
  }

  Future<void> updateSessionConfidenceAndNotes({
    required int? confidenceRating,
    String? notes,
  }) async {
    final sessionId = state.activeSessionId;
    if (sessionId == null || _db == null) return;

    final sessionRow = await (_db!.select(
      _db!.studySessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();

    if (sessionRow == null) return;

    await _sessionDao!.update(
      StudySessionRow(
        id: sessionRow.id,
        subjectId: sessionRow.subjectId,
        topicId: sessionRow.topicId,
        chapterId: sessionRow.chapterId,
        startedAt: sessionRow.startedAt,
        endedAt: sessionRow.endedAt,
        plannedDurationMinutes: sessionRow.plannedDurationMinutes,
        actualDurationMinutes: sessionRow.actualDurationMinutes,
        pomodorosCompleted: sessionRow.pomodorosCompleted,
        confidenceRating: confidenceRating,
        notes: notes,
        xpEarned: sessionRow.xpEarned,
      ),
    );
  }

  Future<void> awardConfidenceXpAndNotes({
    required int? confidenceRating,
    String? notes,
  }) async {
    final sessionId = state.activeSessionId;
    if (sessionId == null || _db == null) return;

    final sessionRow = await (_db!.select(
      _db!.studySessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();

    if (sessionRow == null) return;

    int newXpEarned = sessionRow.xpEarned;

    // Award confidence XP (only if rating is set and hasn't been awarded yet)
    if (confidenceRating != null && sessionRow.confidenceRating == null) {
      try {
        await ref.read(xpServiceProvider).award(ref, XpReason.confidence);
        newXpEarned += 10;
      } catch (e) {
        debugPrint('Error awarding confidence XP: $e');
      }
    }

    await _sessionDao!.update(
      StudySessionRow(
        id: sessionRow.id,
        subjectId: sessionRow.subjectId,
        topicId: sessionRow.topicId,
        chapterId: sessionRow.chapterId,
        startedAt: sessionRow.startedAt,
        endedAt: sessionRow.endedAt,
        plannedDurationMinutes: sessionRow.plannedDurationMinutes,
        actualDurationMinutes: sessionRow.actualDurationMinutes,
        pomodorosCompleted: sessionRow.pomodorosCompleted,
        confidenceRating: confidenceRating,
        notes: notes,
        xpEarned: newXpEarned,
      ),
    );
  }

  Future<void> _updateSessionInDb({
    required int actualDurationMinutes,
    required int pomodorosCompleted,
    DateTime? endedAt,
    int? startPage,
    int? endPage,
  }) async {
    final sessionId = state.activeSessionId;
    if (sessionId == null || _db == null) return;

    final sessionRow = await (_db!.select(
      _db!.studySessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();

    if (sessionRow == null) return;

    await _sessionDao!.update(
      StudySessionRow(
        id: sessionRow.id,
        subjectId: sessionRow.subjectId,
        topicId: sessionRow.topicId,
        chapterId: sessionRow.chapterId,
        startedAt: sessionRow.startedAt,
        endedAt: endedAt ?? sessionRow.endedAt,
        plannedDurationMinutes: sessionRow.plannedDurationMinutes,
        actualDurationMinutes: actualDurationMinutes,
        pomodorosCompleted: pomodorosCompleted,
        confidenceRating: sessionRow.confidenceRating,
        notes: sessionRow.notes,
        xpEarned: sessionRow.xpEarned,
        sourceId: sessionRow.sourceId,
        startPage: startPage ?? sessionRow.startPage,
        endPage: endPage ?? sessionRow.endPage,
      ),
    );
  }

  Future<void> updateSessionPageRange({
    required int startPage,
    required int endPage,
  }) async {
    await _updateSessionInDb(
      actualDurationMinutes: state.plannedDurationMinutes,
      pomodorosCompleted: state.pomodorosCompleted,
      startPage: startPage,
      endPage: endPage,
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
