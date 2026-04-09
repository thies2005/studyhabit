import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'subject.freezed.dart';
part 'subject.g.dart';

@freezed
abstract class Subject with _$Subject {
  const factory Subject({
    required String id,
    required String projectId,
    required String name,
    String? description,
    required int colorValue,
    required HierarchyMode hierarchyMode,
    required int defaultDurationMinutes,
    required int defaultBreakMinutes,
    required int xpTotal,
    required DateTime createdAt,
  }) = _Subject;

  factory Subject.fromJson(Map<String, dynamic> json) =>
      _$SubjectFromJson(json);
}
