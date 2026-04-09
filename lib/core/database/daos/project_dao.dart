import 'package:drift/drift.dart';

import '../app_database.dart';

class ProjectDao {
  ProjectDao(this._db);

  final AppDatabase _db;

  Stream<List<ProjectRow>> watchAll() {
    final query = _db.select(_db.projects)
      ..orderBy([(table) => OrderingTerm.desc(table.lastOpenedAt)]);
    return query.watch();
  }

  Future<ProjectRow?> getById(String id) {
    final query = _db.select(_db.projects)
      ..where((table) => table.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<void> upsert(ProjectsCompanion companion) {
    return _db.into(_db.projects).insertOnConflictUpdate(companion);
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.projects)..where((table) => table.id.equals(id)))
        .write(const ProjectsCompanion(isArchived: Value(true)));
  }
}
