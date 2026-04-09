import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'skill_label.freezed.dart';
part 'skill_label.g.dart';

@freezed
abstract class SkillLabel with _$SkillLabel {
  const factory SkillLabel({
    required String id,
    required String subjectId,
    String? topicId,
    String? chapterId,
    required SkillLevel label,
    required DateTime updatedAt,
  }) = _SkillLabel;

  factory SkillLabel.fromJson(Map<String, dynamic> json) =>
      _$SkillLabelFromJson(json);
}
