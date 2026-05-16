import 'package:drift/drift.dart';

import '../app_database.dart';

class SubjectDao {
  SubjectDao(this._db);

  final AppDatabase _db;

  Stream<List<SubjectRow>> watchByProject(String projectId) {
    final query = _db.select(_db.subjects)
      ..where((table) => table.projectId.equals(projectId))
      ..orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.watch();
  }

  Future<SubjectRow?> getById(String id) {
    final query = _db.select(_db.subjects)
      ..where((table) => table.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<void> upsert(SubjectsCompanion companion) {
    return _db.into(_db.subjects).insertOnConflictUpdate(companion);
  }

  Future<void> delete(String id) {
    return (_db.delete(
      _db.subjects,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<void> updateDefaultDurations({
    required int oldWork,
    required int newWork,
    required int oldBreak,
    required int newBreak,
  }) async {
    final query = _db.select(_db.subjects)
      ..where((t) => t.defaultDurationMinutes.equals(oldWork) & t.defaultBreakMinutes.equals(oldBreak));
    final rows = await query.get();
    for (final row in rows) {
      await _db.into(_db.subjects).insertOnConflictUpdate(
        row.copyWith(
          defaultDurationMinutes: newWork,
          defaultBreakMinutes: newBreak,
        ),
      );
    }
  }
}
