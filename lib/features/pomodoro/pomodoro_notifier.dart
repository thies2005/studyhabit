import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
import '../../core/services/timer_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


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
class PomodoroNotifier extends _$PomodoroNotifier with WidgetsBindingObserver {
  AppDatabase? _db;
  SessionDao? _sessionDao;
  SubjectDao? _subjectDao;
  ProjectDao? _projectDao;
  TimerPersistenceService? _persistence;
  bool _listenerRegistered = false;
  Timer? _localTimer;
  bool _handlingPhaseComplete = false;

  @override
  PomodoroState build() {
    _db = ref.watch(appDatabaseProvider);
    _sessionDao = SessionDao(_db!);
    _subjectDao = SubjectDao(_db!);
    _projectDao = ProjectDao(_db!);

    _initPersistence();

    WidgetsBinding.instance.addObserver(this);

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _localTimer?.cancel();
      _localTimer = null;
      if (_listenerRegistered) {
        FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
        _listenerRegistered = false;
      }
    });

    return PomodoroState.initial(subjectId: '');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTimeFromTimestamps();
    }
  }

  void _syncTimeFromTimestamps() {
    if (state.phase == TimerPhase.idle || state.startTimestamp == null) return;

    final now = DateTime.now();
    int actualElapsedSeconds;

    if (state.isRunning) {
      actualElapsedSeconds = now.difference(state.startTimestamp!).inSeconds -
          state.pausedDurationSeconds;
    } else {
      final pauseTime = state.lastPausedAt ?? now;
      actualElapsedSeconds = pauseTime.difference(state.startTimestamp!).inSeconds -
          state.pausedDurationSeconds;
    }

    final remaining = (state.totalSeconds - actualElapsedSeconds).clamp(0, state.totalSeconds);
    
    if (state.isOvertime) {
      final overtime = (actualElapsedSeconds - state.totalSeconds).clamp(0, double.maxFinite.toInt());
      if (state.overtimeSeconds != overtime) {
        state = state.copyWith(overtimeSeconds: overtime);
        _persistState();
      }
      return;
    }

    if (state.remainingSeconds != remaining) {
      state = state.copyWith(remainingSeconds: remaining);
      _persistState(); // Throttle might be needed but for now direct
      
      if (remaining <= 0 && state.isRunning) {
        _onPhaseComplete();
      }
    }
  }

  Future<void> _initPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    _persistence = TimerPersistenceService(prefs);
    
    final savedState = await _persistence!.loadPomodoro();
    if (savedState != null && savedState.phase != TimerPhase.idle) {
      state = savedState;
      if (state.isRunning) {
        _syncTimeFromTimestamps();
        _startLocalTimer();
        _startForegroundService();
      }
    }
  }

  void _persistState() {
    _persistence?.savePomodoro(state);
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
      if (state.isRunning) {
        _syncTimeFromTimestamps();

        String notifTitle;
        String notifText;

        if (state.isOvertime) {
          notifTitle = 'Overtime Focus';
          notifText = '+${_formatTime(state.overtimeSeconds)} extra';
        } else {
          notifTitle = state.phase == TimerPhase.work
              ? 'Focus Time'
              : state.phase == TimerPhase.shortBreak
                  ? 'Short Break'
                  : 'Long Break';
          notifText = _formatTime(state.remainingSeconds);
        }

        FlutterForegroundTask.updateService(
          notificationTitle: notifTitle,
          notificationText: notifText,
        );
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
        startTimestamp: DateTime.now(),
        pausedDurationSeconds: 0,
        lastPausedAt: null,
      );

      _startLocalTimer();
      _startForegroundService();
      _persistState();
    }
  }

  Future<void> _startForegroundService() async {
    // Check if service is already running effectively
    if (await FlutterForegroundTask.isRunningService) {
      return;
    }
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

    FlutterForegroundTask.sendDataToTask({
      'startTimestamp': state.startTimestamp?.millisecondsSinceEpoch,
      'pausedDurationSeconds': state.pausedDurationSeconds,
      'totalSeconds': state.totalSeconds,
      'isRunning': state.isRunning,
    });
  }

  void _onReceiveTaskData(Object data) {
    if (data is int) {
      // Background task sent a tick/sync
      if (state.isRunning && state.phase != TimerPhase.idle) {
        // Only update if difference is significant to avoid stutter
        if ((state.remainingSeconds - data).abs() > 1) {
          state = state.copyWith(remainingSeconds: data);
        }
      }
    } else if (data == 'PHASE_COMPLETE') {
      _onPhaseComplete();
    }
  }

  Future<void> start(PomodoroConfig config) async {
    const uuid = Uuid();
    final sessionId = uuid.v4();
    final now = DateTime.now();

    final workSeconds = config.plannedDurationMinutes * 60;

    // Update state and start timer IMMEDIATELY so UI responds instantly
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
      startTimestamp: now,
      pausedDurationSeconds: 0,
      lastPausedAt: null,
    );

    _startLocalTimer();
    _checkOemBatteryIssues();

    // DB insert + foreground service in background (non-blocking)
    _sessionDao?.insert(
      StudySessionsCompanion.insert(
        id: sessionId,
        subjectId: config.subjectId,
        topicId: Value(config.topicId),
        chapterId: Value(config.chapterId),
        startedAt: Value(now),
        plannedDurationMinutes: config.plannedDurationMinutes,
        isFreeTimer: const Value(false),
        sourceId: Value(config.sourceId),
      ),
    ).catchError((e) {
      debugPrint('Error inserting session: $e');
    });

    _startForegroundService().catchError((e) {
      debugPrint('Error starting foreground service: $e');
    });

    _persistState();
  }

  Future<void> _checkOemBatteryIssues() async {
    if (!Platform.isAndroid) return;
    
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final manufacturer = androidInfo.manufacturer.toLowerCase();
    
    final problematicOems = ['xiaomi', 'samsung', 'huawei', 'oppo', 'vivo', 'realme'];
    if (problematicOems.contains(manufacturer)) {
      // We could trigger a dialog or guide here. 
      // For now, let's just log it. The UI can check a provider.
      debugPrint('Detected problematic OEM: $manufacturer');
    }
  }

  Future<void> _onPhaseComplete() async {
    if (_handlingPhaseComplete) return;
    _handlingPhaseComplete = true;
    try {
      await _onPhaseCompleteImpl();
    } finally {
      _handlingPhaseComplete = false;
    }
  }

  Future<void> _onPhaseCompleteImpl() async {
    if (state.phase == TimerPhase.work) {
      final settings = ref.read(themeSettingsProvider).value;
      final continuousFocus = settings?.continuousFocus ?? true;

      // Calculate stats before any state change
      final elapsedSeconds = state.totalSeconds - state.remainingSeconds;
      final actualMinutes = (elapsedSeconds / 60).round();
      final completionRatio = elapsedSeconds / state.totalSeconds;
      final isEligible = completionRatio >= 0.8;

      if (isEligible) {
        await ref.read(xpServiceProvider).award(ref, XpReason.completePomodoro);
        if (state.plannedDurationMinutes >= 50) {
          await ref.read(xpServiceProvider).award(ref, XpReason.longSession);
        }
      }

      await ref.read(streakServiceProvider).recordStudyDay(ref);
      await ref.read(achievementServiceProvider).checkAndUnlock(ref);

      if (continuousFocus) {
        // Switch to overtime instead of break
        state = state.copyWith(
          isOvertime: true,
          overtimeSeconds: 0,
          pomodorosCompleted: state.pomodorosCompleted + 1,
        );
        _persistState();
        _syncForegroundTaskData();
        return;
      }

      final newPomodoros = state.pomodorosCompleted + 1;
      final isLongBreak = newPomodoros > 0 && newPomodoros % state.longBreakEvery == 0;
      final breakMinutes = isLongBreak
          ? state.longBreakDurationMinutes
          : state.breakDurationMinutes;
      final breakSeconds = breakMinutes * 60;
      final breakPhase = isLongBreak
          ? TimerPhase.longBreak
          : TimerPhase.shortBreak;

      final xpEarned = isEligible
          ? 50 + (state.plannedDurationMinutes >= 50 ? 120 : 0)
          : 0;

      state = state.copyWith(
        phase: breakPhase,
        remainingSeconds: breakSeconds,
        totalSeconds: breakSeconds,
        pomodorosCompleted: newPomodoros,
        isRunning: false,
        startTimestamp: DateTime.now(),
        pausedDurationSeconds: 0,
        lastPausedAt: DateTime.now(),
        lastActualWorkMinutes: actualMinutes,
        lastSessionXpEarned: xpEarned,
      );

      final themeSettings = ref.read(themeSettingsProvider).value;
      if (themeSettings?.autoStartBreaks ?? false) {
        resume();
      }

      await _updateSessionInDb(
        actualDurationMinutes: actualMinutes,
        pomodorosCompleted: newPomodoros,
      );

      final notifService = ref.read(notificationServiceProvider);
      try {
        await notifService.showSessionComplete(
          durationMinutes: actualMinutes,
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
        startTimestamp: DateTime.now(),
        pausedDurationSeconds: 0,
        lastPausedAt: DateTime.now(),
      );

      final themeSettings = ref.read(themeSettingsProvider).value;
      if (themeSettings?.autoStartWork ?? false) {
        resume();
      }

      _syncForegroundTaskData();
    }
  }

  void _syncForegroundTaskData() {
    FlutterForegroundTask.sendDataToTask({
      'startTimestamp': state.startTimestamp?.millisecondsSinceEpoch,
      'pausedDurationSeconds': state.pausedDurationSeconds,
      'totalSeconds': state.totalSeconds,
      'isRunning': state.isRunning,
    });
    _persistState();
  }

  void pause() {
    if (!state.isRunning) return;
    state = state.copyWith(
      isRunning: false,
      lastPausedAt: DateTime.now(),
    );
    _stopLocalTimer();
    _syncForegroundTaskData();
    _persistState();
  }

  void resume() {
    if (state.isRunning) return;
    
    final now = DateTime.now();
    int additionalPausedSeconds = 0;
    if (state.lastPausedAt != null) {
      additionalPausedSeconds = now.difference(state.lastPausedAt!).inSeconds;
    }

    state = state.copyWith(
      isRunning: true,
      pausedDurationSeconds: state.pausedDurationSeconds + additionalPausedSeconds,
      lastPausedAt: null,
    );
    _startLocalTimer();
    _syncForegroundTaskData();
    _persistState();
  }

  Future<void> stop() async {
    _stopLocalTimer();
    _localTimer = null;

    final elapsed = state.isOvertime
        ? state.totalSeconds + state.overtimeSeconds
        : state.totalSeconds - state.remainingSeconds;
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

    _persistence?.clearPomodoro();

    state = PomodoroState.initial(subjectId: '');
  }

  void skip() {
    if (state.phase == TimerPhase.work) {
      _onPhaseComplete();
    } else if (state.phase == TimerPhase.shortBreak ||
        state.phase == TimerPhase.longBreak) {
      final workSeconds = state.plannedDurationMinutes * 60;
      state = state.copyWith(
        phase: TimerPhase.work,
        remainingSeconds: workSeconds,
        totalSeconds: workSeconds,
        isRunning: false,
        startTimestamp: DateTime.now(),
        pausedDurationSeconds: 0,
        lastPausedAt: DateTime.now(),
      );

      final themeSettings = ref.read(themeSettingsProvider).value;
      if (themeSettings?.autoStartWork ?? false) {
        resume();
      }

      _syncForegroundTaskData();
    }
  }

  /// Update durations for the next pomodoro cycle (mid-session).
  void updateSettings({
    required int plannedDurationMinutes,
    required int breakDurationMinutes,
    required int longBreakDurationMinutes,
    required int longBreakEvery,
  }) {
    state = state.copyWith(
      plannedDurationMinutes: plannedDurationMinutes,
      breakDurationMinutes: breakDurationMinutes,
      longBreakDurationMinutes: longBreakDurationMinutes,
      longBreakEvery: longBreakEvery,
    );
    _persistState();
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
      sessionRow.copyWith(
        confidenceRating: Value(confidenceRating),
        notes: Value(notes),
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
      final actual = sessionRow.actualDurationMinutes;
      final planned = sessionRow.plannedDurationMinutes;
      final isEligible = planned > 0 && (actual / planned) >= 0.8;

      if (isEligible) {
        try {
          await ref.read(xpServiceProvider).award(ref, XpReason.confidence);
          newXpEarned += 10;
        } catch (e) {
          debugPrint('Error awarding confidence XP: $e');
        }
      } else {
        debugPrint('Confidence XP skipped: session completion < 80%.');
      }
    }

    await _sessionDao!.update(
      sessionRow.copyWith(
        confidenceRating: Value(confidenceRating),
        notes: Value(notes),
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
      sessionRow.copyWith(
        endedAt: Value(endedAt ?? sessionRow.endedAt),
        actualDurationMinutes: actualDurationMinutes,
        pomodorosCompleted: pomodorosCompleted,
        startPage: Value(startPage ?? sessionRow.startPage),
        endPage: Value(endPage ?? sessionRow.endPage),
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
