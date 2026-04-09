import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/user_stats_provider.dart';

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
    };
  }

  Future<void> award(Object ref, XpReason reason) async {
    final xp = xpForReason(reason);
    final notifier = switch (ref) {
      Ref r => r.read(userStatsProvider.notifier),
      WidgetRef r => r.read(userStatsProvider.notifier),
      _ => throw ArgumentError.value(ref, 'ref', 'Expected Ref or WidgetRef'),
    };
    final stats = switch (ref) {
      Ref r => await r.read(userStatsProvider.future),
      WidgetRef r => await r.read(userStatsProvider.future),
      _ => throw ArgumentError.value(ref, 'ref', 'Expected Ref or WidgetRef'),
    };
    final newTotalXp = stats.totalXp + xp;
    final newLevel = calculateLevel(newTotalXp);

    await notifier.upsert(
      stats.copyWith(totalXp: newTotalXp, currentLevel: newLevel),
    );
  }

  int calculateLevel(int totalXp) {
    if (totalXp < 500) return 1;
    if (totalXp < 1500) return 2;
    if (totalXp < 3500) return 3;
    if (totalXp < 7000) return 4;
    if (totalXp < 10500) return 5;

    int threshold = 7000;
    int level = 5;
    while (level < 100) {
      final next = ((threshold * 1.5) / 100).round() * 100;
      threshold = next;
      level++;
      if (totalXp < threshold) return level;
    }
    return level;
  }

  int xpToNextLevel(int totalXp) {
    final current = calculateLevel(totalXp);
    return levelThreshold(current + 1) - totalXp;
  }

  int currentLevelXp(int totalXp) {
    final current = calculateLevel(totalXp);
    final prevThreshold = current <= 1 ? 0 : levelThreshold(current - 1);
    return totalXp - prevThreshold;
  }

  int currentLevelXpNeeded(int totalXp) {
    final current = calculateLevel(totalXp);
    final prevThreshold = current <= 1 ? 0 : levelThreshold(current - 1);
    return levelThreshold(current) - prevThreshold;
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
