import 'package:drift/drift.dart';

import '../app_database.dart';

class ProjectDao {
  ProjectDao(this._db);

  final AppDatabase _db;

  Stream<List<ProjectRow>> watchAll() {
    final query = _db.select(_db.projects)
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([(table) => OrderingTerm.desc(table.lastOpenedAt)]);
    return query.watch();
  }

  Future<ProjectRow?> getById(String id) {
    final query = _db.select(_db.projects)
      ..where((table) => table.id.equals(id))
      ..where((table) => table.isDeleted.equals(false));
    return query.getSingleOrNull();
  }

  Future<void> upsert(ProjectsCompanion companion) {
    final withUpdated = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return _db.into(_db.projects).insertOnConflictUpdate(withUpdated);
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.projects)..where((table) => table.id.equals(id)))
        .write(ProjectsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
  }
}
