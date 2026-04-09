import 'package:freezed_annotation/freezed_annotation.dart';

part 'achievement.freezed.dart';
part 'achievement.g.dart';

@freezed
abstract class Achievement with _$Achievement {
  const factory Achievement({
    required String key,
    DateTime? unlockedAt,
    required double progress,
  }) = _Achievement;

  factory Achievement.fromJson(Map<String, dynamic> json) =>
      _$AchievementFromJson(json);
}
