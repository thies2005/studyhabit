import 'package:drift/drift.dart';

import '../app_database.dart';

class SourceDao {
  SourceDao(this._db);

  final AppDatabase _db;

  Stream<List<SourceRow>> watchBySubject(String subjectId) {
    final query = _db.select(_db.sources)
      ..where((table) => table.subjectId.equals(subjectId))
      ..orderBy([(table) => OrderingTerm.desc(table.addedAt)]);
    return query.watch();
  }

  Future<void> upsert(SourcesCompanion companion) {
    return _db.into(_db.sources).insertOnConflictUpdate(companion);
  }

  Future<void> updateProgress(
    String id, {
    int? currentPage,
    double? progressPercent,
  }) {
    return (_db.update(
      _db.sources,
    )..where((table) => table.id.equals(id))).write(
      SourcesCompanion(
        currentPage: Value(currentPage),
        progressPercent: Value(progressPercent),
      ),
    );
  }

  Future<void> delete(String id) {
    return (_db.delete(
      _db.sources,
    )..where((table) => table.id.equals(id))).go();
  }
}
