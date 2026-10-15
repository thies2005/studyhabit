import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/models/enums.dart';
import '../../core/models/subject.dart';

part 'stats_models.freezed.dart';

@freezed
abstract class StatsOverview with _$StatsOverview {
  const factory StatsOverview({
    required double totalHours,
    required double weekHours,
    required int currentStreak,
    required int totalXp,
    required int currentLevel,
    required String levelName,
  }) = _StatsOverview;
}

@freezed
abstract class DailyActivity with _$DailyActivity {
  const factory DailyActivity({required DateTime date, required double hours}) =
      _DailyActivity;
}

@freezed
abstract class SubjectTime with _$SubjectTime {
  const factory SubjectTime({
    required Subject subject,
    required double hours,
    required double percentage,
  }) = _SubjectTime;
}

@freezed
abstract class HeatmapDay with _$HeatmapDay {
  const factory HeatmapDay({required DateTime date, required int minutes}) =
      _HeatmapDay;
}

@freezed
abstract class SubjectBreakdown with _$SubjectBreakdown {
  const factory SubjectBreakdown({
    required Subject subject,
    required double totalHours,
    required int sessionCount,
    required double avgConfidence,
    required SkillLevel skillLevel,
  }) = _SubjectBreakdown;
}

@freezed
abstract class XpDayData with _$XpDayData {
  const factory XpDayData({required DateTime date, required int cumulativeXp}) =
      _XpDayData;
}
