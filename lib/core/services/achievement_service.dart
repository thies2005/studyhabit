import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../providers/database_provider.dart';
import '../services/app_logger.dart';

part 'achievement_service.g.dart';

class AchievementUnlock {
  const AchievementUnlock({required this.key, required this.progress});

  final String key;
  final double progress;
}

class AchievementService {
  Future<List<AchievementUnlock>> checkAndUnlock(Ref ref) async {
    try {
      AppLogger.i('AchievementService', 'Checking achievements');
      final db = ref.read(appDatabaseProvider);

      final allSessions = await db.select(db.studySessions).get();
      final statsRows = await db.select(db.userStatsTable).get();
      final statsRow = statsRows.isEmpty ? null : statsRows.first;

      final totalPomodoros = allSessions.fold<int>(
        0,
        (sum, s) => sum + s.pomodorosCompleted,
      );
      final totalMinutes = allSessions.fold<int>(
        0,
        (sum, s) => sum + s.actualDurationMinutes,
      );
      final totalHours = totalMinutes / 60.0;

      final currentStreak = statsRow?.currentStreak ?? 0;

      final ratedSessions = allSessions
          .where((s) => s.confidenceRating != null && s.confidenceRating! >= 5)
          .toList();

      final subjectsWithTime = <String, int>{};
      for (final session in allSessions) {
        subjectsWithTime[session.subjectId] =
            (subjectsWithTime[session.subjectId] ?? 0) +
            session.actualDurationMinutes;
      }
      final subjectsOver5h = subjectsWithTime.values
          .where((m) => m >= 300)
          .length;
      final subjectsOver10h = subjectsWithTime.values
          .where((m) => m >= 600)
          .length;

      final pdfSources = await (db.select(
        db.sources,
      )..where((t) => t.type.equals('pdf'))).get();

      final advancedSkillRows = await (db.select(
        db.skillLabels,
      )..where((t) => t.label.equals('advanced'))).get();

      final allAchievements = await db.select(db.achievements).get();
      final achievementMap = <String, AchievementRow>{};
      for (final row in allAchievements) {
        achievementMap[row.key] = row;
      }

      final checks = <String, double>{
        'streak_3': (currentStreak / 3).clamp(0.0, 1.0),
        'streak_7': (currentStreak / 7).clamp(0.0, 1.0),
        'streak_30': (currentStreak / 30).clamp(0.0, 1.0),
        'streak_100': (currentStreak / 100).clamp(0.0, 1.0),
        'pomodoro_10': (totalPomodoros / 10).clamp(0.0, 1.0),
        'pomodoro_100': (totalPomodoros / 100).clamp(0.0, 1.0),
        'pomodoro_500': (totalPomodoros / 500).clamp(0.0, 1.0),
        'hours_10': (totalHours / 10).clamp(0.0, 1.0),
        'hours_100': (totalHours / 100).clamp(0.0, 100.0),
        'subject_5h': (subjectsOver5h > 0 ? 1.0 : 0.0),
        'subject_10h': (subjectsOver10h > 0 ? 1.0 : 0.0),
        'first_pdf': pdfSources.isNotEmpty ? 1.0 : 0.0,
        'confidence_5': (ratedSessions.isNotEmpty ? 1.0 : 0.0),
        'skill_advanced': advancedSkillRows.isNotEmpty ? 1.0 : 0.0,
        'all_badges': _calcAllBadgesProgress(
          currentStreak,
          totalPomodoros,
          totalHours,
          pdfSources.isNotEmpty,
          ratedSessions.isNotEmpty,
          advancedSkillRows.isNotEmpty,
        ),
      };

      final newlyUnlocked = <AchievementUnlock>[];

      for (final entry in checks.entries) {
        final key = entry.key;
        final progress = entry.value;
        final existing = achievementMap[key];

        final companion = AchievementsCompanion(
          key: Value(key),
          progress: Value(progress),
          unlockedAt: Value(
            progress >= 1.0
                ? existing?.unlockedAt ?? DateTime.now()
                : existing?.unlockedAt,
          ),
        );

        if (existing == null) {
          await db.into(db.achievements).insertOnConflictUpdate(companion);
        } else {
          await db
              .update(db.achievements)
              .replace(
                AchievementRow(
                  key: key,
                  unlockedAt: companion.unlockedAt.value,
                  progress: progress,
                ),
              );
        }

        if (progress >= 1.0 &&
            (existing == null || existing.unlockedAt == null)) {
          newlyUnlocked.add(AchievementUnlock(key: key, progress: progress));
        }
      }

      AppLogger.i('AchievementService', 'Check complete: ${newlyUnlocked.length} unlocked');
      return newlyUnlocked;
    } catch (e, stack) {
      AppLogger.e('AchievementService', 'Achievement check failed', e, stack);
      return [];
    }
  }

  double _calcAllBadgesProgress(
    int streak,
    int totalPomodoros,
    double totalHours,
    bool hasPdf,
    bool hasConfidence5,
    bool hasAdvancedSkill,
  ) {
    int earned = 0;
    if (streak >= 3) earned++;
    if (streak >= 7) earned++;
    if (streak >= 30) earned++;
    if (streak >= 100) earned++;
    if (totalPomodoros >= 10) earned++;
    if (totalPomodoros >= 100) earned++;
    if (totalPomodoros >= 500) earned++;
    if (totalHours >= 10) earned++;
    if (totalHours >= 100) earned++;
    if (hasPdf) earned++;
    if (hasConfidence5) earned++;
    if (hasAdvancedSkill) earned++;

    return earned / 14.0;
  }
}

@Riverpod(keepAlive: true)
AchievementService achievementService(Ref ref) {
  return AchievementService();
}
