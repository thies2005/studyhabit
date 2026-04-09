import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_stats.freezed.dart';
part 'user_stats.g.dart';

@freezed
abstract class UserStats with _$UserStats {
  const factory UserStats({
    required int totalXp,
    required int currentLevel,
    required int currentStreak,
    required int longestStreak,
    DateTime? lastStudyDate,
    required int totalStudyMinutes,
    required int freezeTokens,
  }) = _UserStats;

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
}
