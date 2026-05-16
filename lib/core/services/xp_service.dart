import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../models/user_stats.dart';
import '../providers/database_provider.dart';
import '../providers/user_stats_provider.dart';
import 'achievement_service.dart';

part 'xp_service.g.dart';

enum XpReason {
  completePomodoro,
  longSession,
  confidence,
  addSource,
  skillAdvance,
  streak7,
  streak30,
  streak100,
  dailyGoal,
}

class XpService {
  const XpService();

  int xpForReason(XpReason reason) {
    return switch (reason) {
      XpReason.completePomodoro => 50,
      XpReason.longSession => 120,
      XpReason.confidence => 10,
      XpReason.addSource => 5,
      XpReason.skillAdvance => 100,
      XpReason.streak7 => 500,
      XpReason.streak30 => 500,
      XpReason.streak100 => 500,
      XpReason.dailyGoal => 75,
    };
  }

  Future<void> _applyAward({
    required UserStatsNotifier notifier,
    required UserStats currentStats,
    required AppDatabase db,
    required XpReason reason,
  }) async {
    final xp = xpForReason(reason);
    final newTotalXp = currentStats.totalXp + xp;
    final newLevel = calculateLevel(newTotalXp);

    await notifier.upsert(
      currentStats.copyWith(totalXp: newTotalXp, currentLevel: newLevel),
    );

    final achievementService = AchievementService();
    await achievementService.checkAndUnlock(db);
  }

  Future<void> award(Ref ref, XpReason reason) async {
    final notifier = ref.read(userStatsProvider.notifier);
    final stats = await ref.read(userStatsProvider.future);
    final db = ref.read(appDatabaseProvider);
    await _applyAward(
      notifier: notifier,
      currentStats: stats,
      db: db,
      reason: reason,
    );
  }

  Future<void> awardFromWidget(WidgetRef ref, XpReason reason) async {
    final notifier = ref.read(userStatsProvider.notifier);
    final stats = await ref.read(userStatsProvider.future);
    final db = ref.read(appDatabaseProvider);
    await _applyAward(
      notifier: notifier,
      currentStats: stats,
      db: db,
      reason: reason,
    );
  }

  int calculateLevel(int totalXp) {
    if (totalXp < 500) return 1;
    if (totalXp < 1500) return 2;
    if (totalXp < 3500) return 3;
    if (totalXp < 7000) return 4;
    if (totalXp < 10500) return 5;

    int threshold = 10500;
    int level = 6;
    while (level < 100 && totalXp >= threshold) {
      threshold = ((threshold * 1.5) / 100).round() * 100;
      level++;
    }
    return level;
  }

  int xpToNextLevel(int totalXp) {
    final current = calculateLevel(totalXp);
    return levelThreshold(current + 1) - totalXp;
  }

  int currentLevelXp(int totalXp) {
    final current = calculateLevel(totalXp);
    return totalXp - levelThreshold(current);
  }

  int currentLevelXpNeeded(int totalXp) {
    final current = calculateLevel(totalXp);
    return levelThreshold(current + 1) - levelThreshold(current);
  }

  int levelThreshold(int level) {
    return switch (level) {
      1 => 0,
      2 => 500,
      3 => 1500,
      4 => 3500,
      5 => 7000,
      _ => _recursiveThreshold(level),
    };
  }

  int _recursiveThreshold(int level) {
    if (level <= 5) return levelThreshold(level);
    final prev = _recursiveThreshold(level - 1);
    return ((prev * 1.5) / 100).round() * 100;
  }

  String levelName(int level) {
    if (level <= 1) return 'Novice';
    if (level == 2) return 'Apprentice';
    if (level == 3) return 'Scholar';
    if (level == 4) return 'Adept';
    if (level == 5) return 'Expert';
    if (level == 6) return 'Master';
    return 'Grandmaster';
  }
}

@Riverpod(keepAlive: true)
XpService xpService(Ref ref) {
  return const XpService();
}
