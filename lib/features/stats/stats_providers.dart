import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/daos/session_dao.dart';
import '../../core/database/daos/subject_dao.dart';
import '../../core/models/enums.dart';
import '../../core/models/model_mapper.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/user_stats_provider.dart';
import '../../core/services/xp_service.dart';
import '../projects/project_providers.dart';
import 'stats_models.dart';

part 'stats_providers.g.dart';

@riverpod
Future<StatsOverview> statsOverview(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final stats = await ref.watch(userStatsProvider.future);
  final allSessions = await db.select(db.studySessions).get();

  final totalMinutes = allSessions.fold<int>(
    0,
    (sum, s) => sum + s.actualDurationMinutes,
  );
  final totalHours = totalMinutes / 60.0;

  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  final weekSessions = allSessions.where((s) => s.startedAt.isAfter(weekAgo));
  final weekMinutes = weekSessions.fold<int>(
    0,
    (sum, s) => sum + s.actualDurationMinutes,
  );
  final weekHours = weekMinutes / 60.0;

  const xpService = XpService();
  final currentLevel = xpService.calculateLevel(stats.totalXp);

  return StatsOverview(
    totalHours: totalHours,
    weekHours: weekHours,
    currentStreak: stats.currentStreak,
    totalXp: stats.totalXp,
    currentLevel: currentLevel,
    levelName: xpService.levelName(currentLevel),
  );
}

@riverpod
Future<List<DailyActivity>> weeklyActivity(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final allSessions = await db.select(db.studySessions).get();

  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final normalizedStart = DateTime(
    weekStart.year,
    weekStart.month,
    weekStart.day,
  );

  final weekSessions = allSessions.where(
    (s) => s.startedAt.isAfter(
      normalizedStart.subtract(const Duration(seconds: 1)),
    ),
  );

  final minutesByDay = <DateTime, int>{};
  for (var i = 0; i < 7; i++) {
    final day = normalizedStart.add(Duration(days: i));
    minutesByDay[day] = 0;
  }

  for (final session in weekSessions) {
    final day = DateTime(
      session.startedAt.year,
      session.startedAt.month,
      session.startedAt.day,
    );
    if (minutesByDay.containsKey(day)) {
      minutesByDay[day] = minutesByDay[day]! + session.actualDurationMinutes;
    }
  }

  return List.generate(7, (i) {
    final day = normalizedStart.add(Duration(days: i));
    final minutes = minutesByDay[day] ?? 0;
    return DailyActivity(date: day, hours: minutes / 60.0);
  });
}

@riverpod
Future<List<SubjectTime>> subjectDistribution(Ref ref, int days) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SubjectDao(db);
  final currentProject = await ref.watch(lastOpenedProjectProvider.future);
  if (currentProject == null) return [];

  final subjects = await dao.watchByProject(currentProject.id).first;
  final allSessions = await db.select(db.studySessions).get();

  final cutoff = DateTime.now().subtract(Duration(days: days));
  final filteredSessions = allSessions
      .where((s) => s.startedAt.isAfter(cutoff))
      .toList();

  final minutesBySubject = <String, int>{};
  for (final session in filteredSessions) {
    minutesBySubject[session.subjectId] =
        (minutesBySubject[session.subjectId] ?? 0) +
        session.actualDurationMinutes;
  }

  final totalMinutes = minutesBySubject.values.fold<int>(0, (a, b) => a + b);

  final result = <SubjectTime>[];
  for (final row in subjects) {
    final minutes = minutesBySubject[row.id] ?? 0;
    final percentage = totalMinutes > 0
        ? (minutes / totalMinutes) * 100.0
        : 0.0;
    result.add(
      SubjectTime(
        subject: mapSubject(row),
        hours: minutes / 60.0,
        percentage: percentage,
      ),
    );
  }

  result.sort((a, b) => b.hours.compareTo(a.hours));
  return result;
}

@riverpod
Future<List<HeatmapDay>> heatmapData(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final allSessions = await db.select(db.studySessions).get();

  final now = DateTime.now();
  final startDay = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 83));

  final minutesByDay = <String, int>{};
  for (final session in allSessions) {
    if (session.startedAt.isBefore(startDay)) continue;
    final key =
        '${session.startedAt.year}-${session.startedAt.month}-${session.startedAt.day}';
    minutesByDay[key] =
        (minutesByDay[key] ?? 0) + session.actualDurationMinutes;
  }

  final result = <HeatmapDay>[];
  for (var i = 0; i < 84; i++) {
    final day = startDay.add(Duration(days: i));
    final key = '${day.year}-${day.month}-${day.day}';
    result.add(HeatmapDay(date: day, minutes: minutesByDay[key] ?? 0));
  }

  return result;
}

@riverpod
Future<List<SubjectBreakdown>> subjectBreakdown(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SubjectDao(db);
  final sessionDao = SessionDao(db);
  final currentProject = await ref.watch(lastOpenedProjectProvider.future);
  if (currentProject == null) return [];

  final subjects = await dao.watchByProject(currentProject.id).first;
  final result = <SubjectBreakdown>[];

  for (final row in subjects) {
    final sessions = await sessionDao.watchBySubject(row.id).first;
    final totalMinutes = sessions.fold<int>(
      0,
      (sum, s) => sum + s.actualDurationMinutes,
    );
    final ratedSessions = sessions
        .where((s) => s.confidenceRating != null)
        .toList();
    final avgConfidence = ratedSessions.isEmpty
        ? 0.0
        : ratedSessions
                  .map((s) => s.confidenceRating!)
                  .reduce((a, b) => a + b) /
              ratedSessions.length;

    final skillRows = await (db.select(
      db.skillLabels,
    )..where((t) => t.subjectId.equals(row.id))).get();

    SkillLevel skillLevel = SkillLevel.beginner;
    if (skillRows.isNotEmpty) {
      final sorted = skillRows.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      skillLevel = sorted.first.label;
    }

    result.add(
      SubjectBreakdown(
        subject: mapSubject(row),
        totalHours: totalMinutes / 60.0,
        sessionCount: sessions.length,
        avgConfidence: avgConfidence,
        skillLevel: skillLevel,
      ),
    );
  }

  result.sort((a, b) => b.totalHours.compareTo(a.totalHours));
  return result;
}

@riverpod
Future<List<XpDayData>> xpLineChartData(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final stats = await ref.watch(userStatsProvider.future);
  final allSessions = await db.select(db.studySessions).get();

  final now = DateTime.now();
  final startDay = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 29));

  final xpByDay = <String, int>{};
  for (final session in allSessions) {
    if (session.startedAt.isBefore(startDay)) continue;
    final key =
        '${session.startedAt.year}-${session.startedAt.month}-${session.startedAt.day}';
    xpByDay[key] = (xpByDay[key] ?? 0) + session.xpEarned;
  }

  final baseXp =
      stats.totalXp - xpByDay.values.fold<int>(0, (sum, v) => sum + v);

  final result = <XpDayData>[];
  var cumulative = baseXp;
  for (var i = 0; i < 30; i++) {
    final day = startDay.add(Duration(days: i));
    final key = '${day.year}-${day.month}-${day.day}';
    cumulative += xpByDay[key] ?? 0;
    result.add(XpDayData(date: day, cumulativeXp: cumulative));
  }

  return result;
}
