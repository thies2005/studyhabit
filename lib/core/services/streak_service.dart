import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/user_stats_provider.dart';
import 'xp_service.dart';

part 'streak_service.g.dart';

class StreakService {
  static const _graceWindowKey = 'streak.gracePeriod';
  static const _lastFreezeUseKey = 'streak.lastFreezeUseDate';

  Future<void> recordStudyDay(Ref ref) async {
    final prefs = await SharedPreferences.getInstance();
    final graceWindowHours = prefs.getDouble(_graceWindowKey) ?? 2.0;
    final stats = await ref.read(userStatsProvider.future);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? lastStudyDate;
    if (stats.lastStudyDate != null) {
      lastStudyDate = DateTime(
        stats.lastStudyDate!.year,
        stats.lastStudyDate!.month,
        stats.lastStudyDate!.day,
      );
    }

    int newStreak = stats.currentStreak;
    bool usedFreeze = false;

    if (lastStudyDate == null) {
      newStreak = 1;
    } else {
      final daysDiff = today.difference(lastStudyDate).inDays;

      if (daysDiff == 0) {
        // Already studied today — no change
        newStreak = stats.currentStreak;
      } else if (daysDiff == 1) {
        // Check grace window: if still within grace hours past midnight, treat as same day
        final lastStudyDayEnd = DateTime(
          lastStudyDate.year,
          lastStudyDate.month,
          lastStudyDate.day,
        ).add(const Duration(hours: 24)).add(Duration(hours: graceWindowHours.toInt()));

        if (now.isBefore(lastStudyDayEnd)) {
          // Still in grace window — treat as consecutive study day
          newStreak = stats.currentStreak;
        } else {
          // Past grace window — new consecutive day
          newStreak = stats.currentStreak + 1;
        }
      } else if (daysDiff == 2 && stats.freezeTokens > 0) {
        // Check freeze token
        final lastFreezeUseStr = prefs.getString(_lastFreezeUseKey);
        DateTime? lastFreezeUse;
        if (lastFreezeUseStr != null) {
          lastFreezeUse = DateTime(
            DateTime.parse(lastFreezeUseStr).year,
            DateTime.parse(lastFreezeUseStr).month,
            DateTime.parse(lastFreezeUseStr).day,
          );
        }

        final weekAgo = today.subtract(const Duration(days: 7));
        final canUseFreeze =
            lastFreezeUse == null || lastFreezeUse.isBefore(weekAgo);

        if (canUseFreeze) {
          usedFreeze = true;
          newStreak = stats.currentStreak + 1;
          await prefs.setString(_lastFreezeUseKey, today.toIso8601String());
        } else {
          newStreak = 1;
        }
      } else {
        // Streak broken
        newStreak = 1;
      }
    }

    int freezeTokens = stats.freezeTokens;
    if (usedFreeze) {
      freezeTokens--;
    }

    if (newStreak > 0 &&
        newStreak % 10 == 0 &&
        stats.currentStreak < newStreak) {
      freezeTokens++;
    }

    final newLongest = newStreak > stats.longestStreak
        ? newStreak
        : stats.longestStreak;

    final updatedStats = stats.copyWith(
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastStudyDate: now,
      freezeTokens: freezeTokens,
    );

    await ref.read(userStatsProvider.notifier).upsert(updatedStats);

    if (newStreak >= 7 && stats.currentStreak < 7) {
      await ref.read(xpServiceProvider).award(ref, XpReason.streak7);
    }
    if (newStreak >= 30 && stats.currentStreak < 30) {
      await ref.read(xpServiceProvider).award(ref, XpReason.streak30);
    }
    if (newStreak >= 100 && stats.currentStreak < 100) {
      await ref.read(xpServiceProvider).award(ref, XpReason.streak100);
    }
  }
}

@Riverpod(keepAlive: true)
StreakService streakService(Ref ref) {
  return StreakService();
}
