import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/app_logger.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/project_dao.dart';
import '../../core/models/model_mapper.dart';
import '../../core/models/project.dart';
import '../../core/providers/database_provider.dart';

part 'project_providers.g.dart';

@riverpod
Stream<List<Project>> projectList(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final dao = ProjectDao(db);
  return dao.watchAll().map((rows) => rows.map(mapProject).toList());
}

@riverpod
Future<Project?> lastOpenedProject(Ref ref) async {
  await ref.watch(projectListProvider.future);
  final projects = ref.watch(projectListProvider).value ?? [];
  final active = projects.where((p) => !p.isArchived).toList();
  if (active.isEmpty) return null;
  active.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
  return active.first;
}

@riverpod
class ProjectNotifier extends _$ProjectNotifier {
  late AppDatabase _db;
  late ProjectDao _dao;

  @override
  Stream<List<Project>> build() {
    _db = ref.watch(appDatabaseProvider);
    _dao = ProjectDao(_db);
    return _dao.watchAll().map((rows) => rows.map(mapProject).toList());
  }

  Future<Project?> create(String name, String icon, int colorValue) async {
    try {
      AppLogger.i('ProjectNotifier', 'Creating project: $name');
      const uuid = Uuid();
      final id = uuid.v4();
      final now = DateTime.now();
      await _dao.upsert(
        ProjectsCompanion.insert(
          id: id,
          name: name,
          icon: icon,
          colorValue: colorValue,
          createdAt: Value(now),
          lastOpenedAt: Value(now),
        ),
      );
      final row = await _dao.getById(id);
      if (row == null) {
        AppLogger.e('ProjectNotifier', 'Created project row is null');
        return null;
      }
      AppLogger.i('ProjectNotifier', 'Project created successfully: ${row.id}');
      return Project(
        id: row.id,
        name: row.name,
        icon: row.icon,
        colorValue: row.colorValue,
        createdAt: row.createdAt,
        lastOpenedAt: row.lastOpenedAt,
        isArchived: row.isArchived,
      );
    } catch (e, stack) {
      AppLogger.e('ProjectNotifier', 'Failed to create project', e, stack);
      return null;
    }
  }

  Future<void> switchProject(String id) async {
    try {
      AppLogger.i('ProjectNotifier', 'Switching to project: $id');
      final row = await _dao.getById(id);
      if (row == null) {
        AppLogger.w('ProjectNotifier', 'Switch target project not found: $id');
        return;
      }
      await _dao.upsert(
        ProjectsCompanion(
          id: Value(id),
          name: Value(row.name),
          icon: Value(row.icon),
          colorValue: Value(row.colorValue),
          createdAt: Value(row.createdAt),
          lastOpenedAt: Value(DateTime.now()),
          isArchived: Value(row.isArchived),
        ),
      );
      AppLogger.i('ProjectNotifier', 'Project switch successful');
    } catch (e, stack) {
      AppLogger.e('ProjectNotifier', 'Failed to switch project', e, stack);
    }
  }

  Future<void> archive(String id) async {
    await _dao.softDelete(id);
  }
}
