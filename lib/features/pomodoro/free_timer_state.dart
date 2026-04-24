import 'package:freezed_annotation/freezed_annotation.dart';

part 'free_timer_state.freezed.dart';
part 'free_timer_state.g.dart';


@freezed
abstract class FreeTimerState with _$FreeTimerState {
  const factory FreeTimerState({
    required bool isRunning,
    required int elapsedSeconds,
    required int pausedDurationSeconds,
    String? subjectId,
    String? topicId,
    String? chapterId,
    String? activeSessionId,
    DateTime? startedAt,
    DateTime? lastPausedAt,
  }) = _FreeTimerState;

  factory FreeTimerState.fromJson(Map<String, dynamic> json) =>
      _$FreeTimerStateFromJson(json);

  factory FreeTimerState.initial() => const FreeTimerState(
        isRunning: false,
        elapsedSeconds: 0,
        pausedDurationSeconds: 0,
      );
}
