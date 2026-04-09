import 'package:json_annotation/json_annotation.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum HierarchyMode { flat, twoLevel, threeLevel }

@JsonEnum(fieldRename: FieldRename.snake)
enum SkillLevel { beginner, intermediate, advanced, expert }

@JsonEnum(fieldRename: FieldRename.snake)
enum SourceType { pdf, url, videoUrl }

@JsonEnum(fieldRename: FieldRename.snake)
enum TimerPhase { idle, work, shortBreak, longBreak }

@JsonEnum(fieldRename: FieldRename.snake)
enum ImportMode { merge, replace }
