import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/app_logger.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/session_dao.dart';
import '../../core/database/daos/subject_dao.dart';
import '../../core/models/enums.dart';
import '../../core/models/model_mapper.dart';
import '../../core/models/subject.dart';
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

  Future<bool> create({
    required String name,
    String? description,
    required int colorValue,
    required HierarchyMode mode,
    required int defaultDuration,
    required int defaultBreak,
  }) async {
    try {
      AppLogger.i('SubjectNotifier', 'Creating subject: $name');
      const uuid = Uuid();
      final currentProject = await ref.read(lastOpenedProjectProvider.future);
      if (currentProject == null) {
        AppLogger.w('SubjectNotifier', 'Cannot create subject: No active project');
        return false;
      }

      await _dao.upsert(
        SubjectsCompanion.insert(
          id: uuid.v4(),
          projectId: currentProject.id,
          name: name,
          description: Value(description),
          colorValue: colorValue,
          hierarchyMode: Value(mode),
          defaultDurationMinutes: Value(defaultDuration),
          defaultBreakMinutes: Value(defaultBreak),
        ),
      );
      AppLogger.i('SubjectNotifier', 'Subject created successfully');
      return true;
    } catch (e, stack) {
      AppLogger.e('SubjectNotifier', 'Failed to create subject', e, stack);
      return false;
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
        ),
      );
    } catch (e, stack) {
      AppLogger.e('SubjectNotifier', 'Failed to update subject', e, stack);
    }
  }

  Future<void> delete(String id) async {
    try {
      AppLogger.i('SubjectNotifier', 'Deleting subject: $id');
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
  });

  final double totalHours;
  final int sessionCount;
  final double avgConfidence;
  final SkillLevel currentSkillLevel;
}

@riverpod
Future<SubjectStats> subjectStats(Ref ref, String subjectId) async {
  try {
    AppLogger.i('subjectStatsProvider', 'Calculating stats for: $subjectId');
    final db = ref.watch(appDatabaseProvider);
    final sessionDao = SessionDao(db);

    final sessions = await sessionDao.watchBySubject(subjectId).first;
    final totalMinutes = sessions.fold<int>(
      0,
      (sum, s) => sum + s.actualDurationMinutes,
    );

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

    return SubjectStats(
      totalHours: totalMinutes / 60.0,
      sessionCount: sessions.length,
      avgConfidence: avgConfidence,
      currentSkillLevel: currentLevel,
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
