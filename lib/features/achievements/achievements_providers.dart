import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/services/app_logger.dart';

import '../../core/models/achievement.dart';
import '../../core/models/model_mapper.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/user_stats_provider.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/xp_service.dart';

part 'achievements_providers.g.dart';

@Riverpod(keepAlive: true)
class AchievementList extends _$AchievementList {
  @override
  Future<List<Achievement>> build() async {
    try {
      AppLogger.i('AchievementList', 'Building achievement list');
      final db = ref.watch(appDatabaseProvider);
      final service = AchievementService();
      
      try {
        await service.checkAndUnlock(ref);
      } catch (e, stack) {
        AppLogger.e('AchievementList', 'Initial checkAndUnlock failed', e, stack);
      }

      final allRows = await db.select(db.achievements).get();
      AppLogger.i('AchievementList', 'Retrieved ${allRows.length} achievement rows');
      
      return allRows.map(mapAchievement).toList()..sort((a, b) {
        if (a.unlockedAt != null && b.unlockedAt == null) return -1;
        if (a.unlockedAt == null && b.unlockedAt != null) return 1;
        return a.key.compareTo(b.key);
      });
    } catch (e, stack) {
      AppLogger.e('AchievementList', 'Failed to build AchievementList', e, stack);
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

@riverpod
Future<AchievementsOverview> achievementsOverview(Ref ref) async {
  try {
    AppLogger.i('achievementsOverviewProvider', 'Calculating achievements overview');
    final stats = await ref.watch(userStatsProvider.future);
    const xpService = XpService();
    final level = xpService.calculateLevel(stats.totalXp);
    final xpInLevel = xpService.currentLevelXp(stats.totalXp);
    final xpNeeded = xpService.currentLevelXpNeeded(stats.totalXp);
    final progress = xpNeeded > 0 ? xpInLevel / xpNeeded : 0.0;

    return AchievementsOverview(
      totalXp: stats.totalXp,
      currentLevel: level,
      levelName: xpService.levelName(level),
      xpInLevel: xpInLevel,
      xpForNextLevel: xpNeeded,
      levelProgress: progress.clamp(0.0, 1.0),
      currentStreak: stats.currentStreak,
    );
  } catch (e, stack) {
    AppLogger.e('achievementsOverviewProvider', 'Failed to calculate achievements overview', e, stack);
    rethrow;
  }
}

class AchievementsOverview {
  const AchievementsOverview({
    required this.totalXp,
    required this.currentLevel,
    required this.levelName,
    required this.xpInLevel,
    required this.xpForNextLevel,
    required this.levelProgress,
    required this.currentStreak,
  });

  final int totalXp;
  final int currentLevel;
  final String levelName;
  final int xpInLevel;
  final int xpForNextLevel;
  final double levelProgress;
  final int currentStreak;
}
