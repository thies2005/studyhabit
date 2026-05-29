import 'package:drift/drift.dart';

import '../app_database.dart';

class SourceDao {
  SourceDao(this._db);

  final AppDatabase _db;

  Stream<List<SourceRow>> watchBySubject(String subjectId) {
    final query = _db.select(_db.sources)
      ..where((table) => table.subjectId.equals(subjectId))
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([(table) => OrderingTerm.desc(table.addedAt)]);
    return query.watch();
  }

  Future<void> upsert(SourcesCompanion companion) {
    final withUpdated = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return _db.into(_db.sources).insertOnConflictUpdate(withUpdated);
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
        currentPage: currentPage != null ? Value(currentPage) : const Value.absent(),
        progressPercent: progressPercent != null ? Value(progressPercent) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<SourceRow?> getById(String id) {
    return (_db.select(_db.sources)
          ..where((table) => table.id.equals(id))
          ..where((table) => table.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<void> delete(String id) {
    return (_db.update(_db.sources)..where((table) => table.id.equals(id)))
        .write(SourcesCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
  }
}
