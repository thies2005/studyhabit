import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/app_logger.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/session_dao.dart';
import '../../core/database/daos/subject_dao.dart';
import '../../core/database/daos/subject_milestone_dao.dart';
import '../../core/models/enums.dart';
import '../../core/models/model_mapper.dart';
import '../../core/models/subject.dart';
import '../../core/models/subject_milestone.dart';
import '../../core/providers/database_provider.dart';
import '../projects/project_providers.dart';

part 'subject_providers.g.dart';

@riverpod
Stream<List<Subject>> subjectList(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final dao = SubjectDao(db);
  final currentProject = ref.watch(lastOpenedProjectProvider);

  return currentProject.when(
    loading: () => Stream.value(<Subject>[]),
    error: (_, __) => Stream.value(<Subject>[]),
    data: (project) {
      if (project == null) return Stream.value(<Subject>[]);
      return dao
          .watchByProject(project.id)
          .map((rows) => rows.map(mapSubject).toList());
    },
  );
}

@riverpod
class SubjectNotifier extends _$SubjectNotifier {
  late AppDatabase _db;
  late SubjectDao _dao;

  @override
  Stream<List<Subject>> build() {
    _db = ref.watch(appDatabaseProvider);
    _dao = SubjectDao(_db);
    final currentProject = ref.watch(lastOpenedProjectProvider);

    return currentProject.when(
      loading: () => Stream.value(<Subject>[]),
      error: (e, stack) {
        AppLogger.e('SubjectNotifier', 'Error in lastOpenedProjectProvider', e, stack);
        return Stream.value(<Subject>[]);
      },
      data: (project) {
        if (project == null) {
          AppLogger.w('SubjectNotifier', 'No active project found');
          return Stream.value(<Subject>[]);
        }
        AppLogger.i('SubjectNotifier', 'Watching subjects for project: ${project.id}');
        return _dao
            .watchByProject(project.id)
            .map((rows) => rows.map(mapSubject).toList());
      },
    );
  }

  Future<String?> create({
    required String name,
    String? description,
    required int colorValue,
    required HierarchyMode mode,
    required int defaultDuration,
    required int defaultBreak,
    CompletenessMode completenessMode = CompletenessMode.none,
    int? targetHours,
    int? targetWeeklyHours,
  }) async {
    try {
      AppLogger.i('SubjectNotifier', 'Creating subject: $name');
      const uuid = Uuid();
      final currentProject = await ref.read(lastOpenedProjectProvider.future);
      if (currentProject == null) {
        AppLogger.w('SubjectNotifier', 'Cannot create subject: No active project');
        return null;
      }

      final newId = uuid.v4();
      await _dao.upsert(
        SubjectsCompanion.insert(
          id: newId,
          projectId: currentProject.id,
          name: name,
          description: Value(description),
          colorValue: colorValue,
          hierarchyMode: Value(mode),
          defaultDurationMinutes: Value(defaultDuration),
          defaultBreakMinutes: Value(defaultBreak),
          completenessMode: Value(completenessMode),
          targetHours: Value(targetHours),
          targetWeeklyHours: Value(targetWeeklyHours),
        ),
      );
      AppLogger.i('SubjectNotifier', 'Subject created successfully');
      return newId;
    } catch (e, stack) {
      AppLogger.e('SubjectNotifier', 'Failed to create subject', e, stack);
      return null;
    }
  }

  Future<void> updateSubject(Subject updated) async {
    try {
      AppLogger.i('SubjectNotifier', 'Updating subject: ${updated.id}');
      await _dao.upsert(
        SubjectsCompanion(
          id: Value(updated.id),
          projectId: Value(updated.projectId),
          name: Value(updated.name),
          description: Value(updated.description),
          colorValue: Value(updated.colorValue),
          hierarchyMode: Value(updated.hierarchyMode),
          defaultDurationMinutes: Value(updated.defaultDurationMinutes),
          defaultBreakMinutes: Value(updated.defaultBreakMinutes),
          xpTotal: Value(updated.xpTotal),
          completenessMode: Value(updated.completenessMode),
          targetHours: Value(updated.targetHours),
          targetWeeklyHours: Value(updated.targetWeeklyHours),
        ),
      );
    } catch (e, stack) {
      AppLogger.e('SubjectNotifier', 'Failed to update subject', e, stack);
    }
  }

  Future<void> delete(String id) async {
    try {
      AppLogger.i('SubjectNotifier', 'Deleting subject: $id');
      final milestoneDao = SubjectMilestoneDao(_db);
      await milestoneDao.deleteAllForSubject(id);
      await _dao.delete(id);
    } catch (e, stack) {
      AppLogger.e('SubjectNotifier', 'Failed to delete subject', e, stack);
    }
  }
}

class SubjectStats {
  const SubjectStats({
    required this.totalHours,
    required this.sessionCount,
    required this.avgConfidence,
    required this.currentSkillLevel,
    this.completenessPercent,
    this.completenessLabel = '',
  });

  final double totalHours;
  final int sessionCount;
  final double avgConfidence;
  final SkillLevel currentSkillLevel;
  final double? completenessPercent; // null = no tracking, 0.0-1.0 = progress
  final String completenessLabel; // "12.5 / 50h" or "3 / 7 milestones" or ""
}

@riverpod
Future<SubjectStats> subjectStats(Ref ref, String subjectId) async {
  try {
    AppLogger.i('subjectStatsProvider', 'Calculating stats for: $subjectId');
    final db = ref.watch(appDatabaseProvider);
    final sessionDao = SessionDao(db);
    final subjectDao = SubjectDao(db);
    final milestoneDao = SubjectMilestoneDao(db);

    final sessions = await sessionDao.watchBySubject(subjectId).first;
    final totalMinutes = sessions.fold<int>(
      0,
      (sum, s) => sum + s.actualDurationMinutes,
    );
    final totalHours = totalMinutes / 60.0;

    final ratedSessions = sessions
        .where((s) => s.confidenceRating != null)
        .toList();
    final avgConfidence = ratedSessions.isEmpty
        ? 0.0
        : ratedSessions.map((s) => s.confidenceRating!).reduce((a, b) => a + b) /
              ratedSessions.length;

    final skillRows = await (db.select(
      db.skillLabels,
    )..where((t) => t.subjectId.equals(subjectId))).get();

    SkillLevel currentLevel = SkillLevel.beginner;
    if (skillRows.isNotEmpty) {
      final sorted = skillRows.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      currentLevel = sorted.first.label;
    }

    // Completeness calculation
    final subjectRow = await subjectDao.getById(subjectId);
    double? completenessPercent;
    String completenessLabel = '';

    if (subjectRow != null) {
      final subject = mapSubject(subjectRow);
      switch (subject.completenessMode) {
        case CompletenessMode.none:
          completenessPercent = null;
          completenessLabel = '';
        case CompletenessMode.hoursGoal:
          if (subject.targetHours != null && subject.targetHours! > 0) {
            completenessPercent =
                (totalHours / subject.targetHours!).clamp(0.0, 1.0);
            completenessLabel =
                '${totalHours.toStringAsFixed(1)} / ${subject.targetHours}h';
          }
        case CompletenessMode.milestones:
          final milestones =
              await milestoneDao.watchBySubject(subjectId).first;
          if (milestones.isNotEmpty) {
            final completed =
                milestones.where((m) => m.isCompleted).length;
            completenessPercent = completed / milestones.length;
            completenessLabel = '$completed / ${milestones.length} milestones';
          }
        case CompletenessMode.weeklyHoursGoal:
          if (subject.targetWeeklyHours != null &&
              subject.targetWeeklyHours! > 0) {
            // Calculate this week's hours (Mon-Sun)
            final now = DateTime.now();
            final weekStart = now.subtract(Duration(days: now.weekday - 1));
            final startOfWeek = DateTime(weekStart.year, weekStart.month, weekStart.day);
            final weekMinutes = sessions
                .where((s) =>
                    s.startedAt.isAfter(startOfWeek) ||
                    s.startedAt.isAtSameMomentAs(startOfWeek))
                .fold<int>(0, (sum, s) => sum + s.actualDurationMinutes);
            final weekHours = weekMinutes / 60.0;
            completenessPercent =
                (weekHours / subject.targetWeeklyHours!).clamp(0.0, 1.0);
            completenessLabel =
                '${weekHours.toStringAsFixed(1)} / ${subject.targetWeeklyHours}h this week';
          }
      }
    }

    return SubjectStats(
      totalHours: totalHours,
      sessionCount: sessions.length,
      avgConfidence: avgConfidence,
      currentSkillLevel: currentLevel,
      completenessPercent: completenessPercent,
      completenessLabel: completenessLabel,
    );
  } catch (e, stack) {
    AppLogger.e('subjectStatsProvider', 'Failed to calculate subject stats', e, stack);
    rethrow;
  }
}

@riverpod
Future<Subject?> subjectById(Ref ref, String subjectId) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SubjectDao(db);
  final row = await dao.getById(subjectId);
  if (row == null) return null;
  return mapSubject(row);
}

// ── Milestone Providers ──

@riverpod
Stream<List<SubjectMilestone>> milestoneList(Ref ref, String subjectId) {
  final db = ref.watch(appDatabaseProvider);
  final dao = SubjectMilestoneDao(db);
  return dao.watchBySubject(subjectId).map(
        (rows) => rows.map(mapSubjectMilestone).toList(),
      );
}

@riverpod
class MilestoneNotifier extends _$MilestoneNotifier {
  late AppDatabase _db;
  late SubjectMilestoneDao _dao;

  @override
  Stream<List<SubjectMilestone>> build() {
    _db = ref.watch(appDatabaseProvider);
    _dao = SubjectMilestoneDao(_db);
    // Default: empty stream. Use milestoneListProvider(subjectId) for a specific subject.
    return Stream.value(<SubjectMilestone>[]);
  }

  Future<void> add(String subjectId, String title) async {
    try {
      const uuid = Uuid();
      // Get current max sortOrder for this subject
      final existing = await _dao.watchBySubject(subjectId).first;
      final maxOrder = existing.isEmpty
          ? 0
          : existing.map((m) => m.sortOrder).reduce((a, b) => a > b ? a : b);

      await _dao.insert(
        SubjectMilestonesCompanion.insert(
          id: uuid.v4(),
          subjectId: subjectId,
          title: title,
          sortOrder: Value(maxOrder + 1),
        ),
      );
    } catch (e, stack) {
      AppLogger.e('MilestoneNotifier', 'Failed to add milestone', e, stack);
    }
  }

  Future<void> rename(String id, String newTitle) async {
    try {
      await _dao.update(
        SubjectMilestonesCompanion(
          id: Value(id),
          title: Value(newTitle),
        ),
      );
    } catch (e, stack) {
      AppLogger.e('MilestoneNotifier', 'Failed to rename milestone', e, stack);
    }
  }

  Future<void> toggleComplete(String id) async {
    try {
      // Get current state
      final row = await (_db.select(_db.subjectMilestones)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      await _dao.updateCompletion(id, isCompleted: !row.isCompleted);
    } catch (e, stack) {
      AppLogger.e('MilestoneNotifier', 'Failed to toggle milestone', e, stack);
    }
  }

  Future<void> deleteMilestone(String id) async {
    try {
      await _dao.delete(id);
    } catch (e, stack) {
      AppLogger.e('MilestoneNotifier', 'Failed to delete milestone', e, stack);
    }
  }

  Future<void> reorder(String subjectId, List<({String id, int sortOrder})> items) async {
    try {
      await _dao.reorder(items);
    } catch (e, stack) {
      AppLogger.e('MilestoneNotifier', 'Failed to reorder milestones', e, stack);
    }
  }
}
