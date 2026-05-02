import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
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

      final allSources = await db.select(db.sources).get();
      final allSkillLabels = await db.select(db.skillLabels).get();

      final pdfSources = allSources.where((s) => s.type == SourceType.pdf).toList();
      final advancedSkillRows = allSkillLabels.where((s) => s.label == SkillLevel.advanced || s.label == SkillLevel.expert).toList();

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

      // Group sessions by subject for more complex checks
      final subjectsWithMinutes = <String, int>{};
      final subjectsWithSessions = <String, int>{};
      final subjectsWithHighConfidence = <String, int>{};
      
      int freeTimerCount = 0;
      int longSession2h = 0;
      int longSession3h = 0;
      int longSession5h = 0;
      int sessionsBefore7am = 0;
      int sessionsAfter10pm = 0;
      int maxContinuousSession = 0;
      
      for (final s in allSessions) {
        subjectsWithMinutes[s.subjectId] = (subjectsWithMinutes[s.subjectId] ?? 0) + s.actualDurationMinutes;
        subjectsWithSessions[s.subjectId] = (subjectsWithSessions[s.subjectId] ?? 0) + 1;
        
        if (s.confidenceRating != null && s.confidenceRating! >= 5) {
          subjectsWithHighConfidence[s.subjectId] = (subjectsWithHighConfidence[s.subjectId] ?? 0) + 1;
        }
        
        if (s.isFreeTimer) {
          freeTimerCount++;
        }

        if (s.actualDurationMinutes >= 120) longSession2h++;
        if (s.actualDurationMinutes >= 180) longSession3h++;
        if (s.actualDurationMinutes >= 300) longSession5h++;

        final hour = s.startedAt.hour;
        if (hour < 7) sessionsBefore7am++;
        if (hour >= 22) sessionsAfter10pm++;
        
        if (s.actualDurationMinutes > maxContinuousSession) maxContinuousSession = s.actualDurationMinutes;
      }
      
      final subjectsOver5h = subjectsWithMinutes.values.where((m) => m >= 300).length;
      final subjectsOver10h = subjectsWithMinutes.values.where((m) => m >= 600).length;

      final allAchievements = await db.select(db.achievements).get();
      final achievementMap = <String, AchievementRow>{};
      for (final row in allAchievements) {
        achievementMap[row.key] = row;
      }

      final checks = <String, double>{
        // Streaks
        'streak_3': (currentStreak / 3).clamp(0.0, 1.0),
        'streak_7': (currentStreak / 7).clamp(0.0, 1.0),
        'streak_14': (currentStreak / 14).clamp(0.0, 1.0),
        'streak_30': (currentStreak / 30).clamp(0.0, 1.0),
        'streak_50': (currentStreak / 50).clamp(0.0, 1.0),
        'streak_100': (currentStreak / 100).clamp(0.0, 1.0),
        'streak_200': (currentStreak / 200).clamp(0.0, 1.0),
        'streak_365': (currentStreak / 365).clamp(0.0, 1.0),

        // Pomodoros
        'pomodoro_10': (totalPomodoros / 10).clamp(0.0, 1.0),
        'pomodoro_25': (totalPomodoros / 25).clamp(0.0, 1.0),
        'pomodoro_50': (totalPomodoros / 50).clamp(0.0, 1.0),
        'pomodoro_100': (totalPomodoros / 100).clamp(0.0, 1.0),
        'pomodoro_250': (totalPomodoros / 250).clamp(0.0, 1.0),
        'pomodoro_500': (totalPomodoros / 500).clamp(0.0, 1.0),
        'pomodoro_1000': (totalPomodoros / 1000).clamp(0.0, 1.0),
        'pomodoro_2500': (totalPomodoros / 2500).clamp(0.0, 1.0),
        'pomodoro_5000': (totalPomodoros / 5000).clamp(0.0, 1.0),

        // Hours
        'hours_10': (totalHours / 10).clamp(0.0, 1.0),
        'hours_25': (totalHours / 25).clamp(0.0, 1.0),
        'hours_50': (totalHours / 50).clamp(0.0, 1.0),
        'hours_100': (totalHours / 100).clamp(0.0, 1.0),
        'hours_200': (totalHours / 200).clamp(0.0, 1.0),
        'hours_500': (totalHours / 500).clamp(0.0, 1.0),
        'hours_1000': (totalHours / 1000).clamp(0.0, 1.0),

        // Sessions
        'sessions_5': (allSessions.length / 5).clamp(0.0, 1.0),
        'sessions_20': (allSessions.length / 20).clamp(0.0, 1.0),
        'sessions_50': (allSessions.length / 50).clamp(0.0, 1.0),
        'sessions_100': (allSessions.length / 100).clamp(0.0, 1.0),
        'sessions_250': (allSessions.length / 250).clamp(0.0, 1.0),
        'sessions_500': (allSessions.length / 500).clamp(0.0, 1.0),

        // Subject milestones
        'subject_5h': (subjectsOver5h > 0 ? 1.0 : 0.0),
        'subjects_2_5h': (subjectsOver5h / 2).clamp(0.0, 1.0),
        'subjects_5_5h': (subjectsOver5h / 5).clamp(0.0, 1.0),
        'subject_10h': (subjectsOver10h > 0 ? 1.0 : 0.0),
        'subjects_3_10h': (subjectsOver10h / 3).clamp(0.0, 1.0),
        'subjects_5_10h': (subjectsOver10h / 5).clamp(0.0, 1.0),

        // Free timer
        'free_timer_first': (freeTimerCount > 0 ? 1.0 : 0.0),
        'free_timer_10': (freeTimerCount / 10).clamp(0.0, 1.0),
        'free_timer_30m': (maxContinuousSession >= 30 ? 1.0 : 0.0),
        'free_timer_2h': (maxContinuousSession >= 120 ? 1.0 : 0.0),

        // Long sessions
        'long_session_2h': (longSession2h > 0 ? 1.0 : 0.0),
        'long_session_3h': (longSession3h > 0 ? 1.0 : 0.0),
        'long_session_5h': (longSession5h > 0 ? 1.0 : 0.0),

        // Confidence
        'confidence_5': (ratedSessions.isNotEmpty ? 1.0 : 0.0),
        'confidence_10': (ratedSessions.length / 10).clamp(0.0, 1.0),
        'confidence_50': (ratedSessions.length / 50).clamp(0.0, 1.0),
        'all_5stars_3': (subjectsWithHighConfidence.values.where((v) => v >= 3).isNotEmpty ? 1.0 : 0.0),

        // Sources
        'first_pdf': pdfSources.isNotEmpty ? 1.0 : 0.0,
        'sources_5': (pdfSources.length / 5).clamp(0.0, 1.0),
        'sources_10': (pdfSources.length / 10).clamp(0.0, 1.0),

        // Skill
        'skill_advanced': (advancedSkillRows.isNotEmpty ? 1.0 : 0.0),
        'skill_expert': (allSkillLabels.any((s) => s.label == SkillLevel.expert) ? 1.0 : 0.0),

        // Night/Day
        'night_owl': (sessionsAfter10pm > 0 ? 1.0 : 0.0),
        'early_bird': (sessionsBefore7am > 0 ? 1.0 : 0.0),
      };

      // Calculate all_badges progress (excludes itself from the total count)
      int earnedCount = 0;
      for (final progress in checks.values) {
        if (progress >= 1.0) earnedCount++;
      }
      checks['all_badges'] = (earnedCount / checks.length.toDouble()).clamp(0.0, 1.0);

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

        if (progress >= 1.0 && (existing == null || existing.unlockedAt == null)) {
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

  double _calcAllBadgesProgress({Map<String, double>? checks, int earnedCount = -1}) {
    if (earnedCount >= 0) return (earnedCount / 65.0).clamp(0.0, 1.0);
    if (checks == null) return 0.0;
    
    int earned = 0;
    for (final v in checks.values) {
      if (v >= 1.0) earned++;
    }
    return (earned / 65.0).clamp(0.0, 1.0);
  }
}

@Riverpod(keepAlive: true)
AchievementService achievementService(Ref ref) {
  return AchievementService();
}
