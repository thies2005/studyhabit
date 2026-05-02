import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/models/enums.dart';

part 'pomodoro_state.freezed.dart';
part 'pomodoro_state.g.dart';


@freezed
abstract class PomodoroState with _$PomodoroState {
  const factory PomodoroState({
    required TimerPhase phase,
    required int remainingSeconds,
    required int totalSeconds,
    required int pomodorosCompleted,
    required bool isRunning,
    DateTime? startTimestamp,
    @Default(0) int pausedDurationSeconds,
    DateTime? lastPausedAt,
    String? activeSessionId,
    required String subjectId,
    String? topicId,
    String? chapterId,
    @Default(25) int plannedDurationMinutes,
    @Default(5) int breakDurationMinutes,
    @Default(15) int longBreakDurationMinutes,
    @Default(4) int longBreakEvery,
    @Default(0) int lastActualWorkMinutes,   // actual minutes of the last completed work phase
    @Default(0) int lastSessionXpEarned,     // XP earned (pre-confidence) for review display
    @Default(false) bool isOvertime,
    @Default(0) int overtimeSeconds,
    @Default(false) bool confidenceXpAwarded, // Prevents duplicate confidence XP awards
  }) = _PomodoroState;

  factory PomodoroState.fromJson(Map<String, dynamic> json) =>
      _$PomodoroStateFromJson(json);

  factory PomodoroState.initial({
    required String subjectId,
    String? topicId,
    String? chapterId,
    int plannedDurationMinutes = 25,
    int breakDurationMinutes = 5,
    int longBreakDurationMinutes = 15,
    int longBreakEvery = 4,
  }) {
    return PomodoroState(
      phase: TimerPhase.idle,
      remainingSeconds: plannedDurationMinutes * 60,
      totalSeconds: plannedDurationMinutes * 60,
      pomodorosCompleted: 0,
      isRunning: false,
      subjectId: subjectId,
      topicId: topicId,
      chapterId: chapterId,
      plannedDurationMinutes: plannedDurationMinutes,
      breakDurationMinutes: breakDurationMinutes,
      longBreakDurationMinutes: longBreakDurationMinutes,
      longBreakEvery: longBreakEvery,
    );
  }
}
