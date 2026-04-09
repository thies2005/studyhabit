import 'package:freezed_annotation/freezed_annotation.dart';

part 'study_session.freezed.dart';
part 'study_session.g.dart';

@freezed
abstract class StudySession with _$StudySession {
  const factory StudySession({
    required String id,
    required String subjectId,
    String? topicId,
    String? chapterId,
    required DateTime startedAt,
    DateTime? endedAt,
    required int plannedDurationMinutes,
    required int actualDurationMinutes,
    required int pomodorosCompleted,
    int? confidenceRating,
    String? notes,
    required int xpEarned,
  }) = _StudySession;

  factory StudySession.fromJson(Map<String, dynamic> json) =>
      _$StudySessionFromJson(json);
}
