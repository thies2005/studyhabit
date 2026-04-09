import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';
part 'project.g.dart';

@freezed
abstract class Project with _$Project {
  const factory Project({
    required String id,
    required String name,
    required String icon,
    required int colorValue,
    required DateTime createdAt,
    required DateTime lastOpenedAt,
    required bool isArchived,
    @Default(25) int defaultWorkDuration,
    @Default(5) int defaultBreakDuration,
    @Default(15) int defaultLongBreakDuration,
    @Default(4) int defaultLongBreakEvery,
    @Default(30) int studyReminderMinutes,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
}
