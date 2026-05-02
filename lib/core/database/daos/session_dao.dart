import 'package:drift/drift.dart';

import '../app_database.dart';

class SessionDao {
  SessionDao(this._db);

  final AppDatabase _db;

  Stream<List<StudySessionRow>> watchBySubject(String subjectId) {
    final query = _db.select(_db.studySessions)
      ..where((table) => table.subjectId.equals(subjectId))
      ..orderBy([(table) => OrderingTerm.desc(table.startedAt)]);
    return query.watch();
  }

  Future<void> insert(StudySessionsCompanion companion) {
    return _db.into(_db.studySessions).insert(companion);
  }

  Future<StudySessionRow?> getById(String id) {
    return (_db.select(_db.studySessions)..where((table) => table.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> update(StudySessionsCompanion companion) {
    return _db.update(_db.studySessions).write(companion);
  }

  Future<void> updateRow(StudySessionRow row) {
    return _db.update(_db.studySessions).replace(row);
  }

  Future<void> delete(String id) {
    return (_db.delete(
      _db.studySessions,
    )..where((table) => table.id.equals(id))).go();
  }
}
