import 'package:freezed_annotation/freezed_annotation.dart';

part 'subject_milestone.freezed.dart';
part 'subject_milestone.g.dart';

@freezed
abstract class SubjectMilestone with _$SubjectMilestone {
  const factory SubjectMilestone({
    required String id,
    required String subjectId,
    required String title,
    @Default(false) bool isCompleted,
    @Default(0) int sortOrder,
    @Default(null) DateTime? completedAt,
  }) = _SubjectMilestone;

  factory SubjectMilestone.fromJson(Map<String, dynamic> json) =>
      _$SubjectMilestoneFromJson(json);
}
