import 'package:drift/drift.dart';

import '../app_database.dart';

class SubjectDao {
  SubjectDao(this._db);

  final AppDatabase _db;

  Stream<List<SubjectRow>> watchByProject(String projectId) {
    final query = _db.select(_db.subjects)
      ..where((table) => table.projectId.equals(projectId))
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.watch();
  }

  Future<SubjectRow?> getById(String id) {
    final query = _db.select(_db.subjects)
      ..where((table) => table.id.equals(id))
      ..where((table) => table.isDeleted.equals(false));
    return query.getSingleOrNull();
  }

  Future<void> upsert(SubjectsCompanion companion) {
    final withUpdated = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return _db.into(_db.subjects).insertOnConflictUpdate(withUpdated);
  }

  Future<void> delete(String id) {
    return (_db.update(_db.subjects)..where((table) => table.id.equals(id)))
        .write(SubjectsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
  }

  Future<void> updateDefaultDurations({
    required int oldWork,
    required int newWork,
    required int oldBreak,
    required int newBreak,
  }) async {
    final query = _db.select(_db.subjects)
      ..where((t) => t.defaultDurationMinutes.equals(oldWork) & t.defaultBreakMinutes.equals(oldBreak))
      ..where((t) => t.isDeleted.equals(false));
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
