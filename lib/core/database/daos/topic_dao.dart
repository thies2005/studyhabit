import 'package:drift/drift.dart';

import '../app_database.dart';

class TopicDao {
  TopicDao(this._db);

  final AppDatabase _db;

  Future<TopicRow?> getById(String id) {
    final query = _db.select(_db.topics)..where((table) => table.id.equals(id));
    return query.getSingleOrNull();
  }

  Stream<List<TopicRow>> watchBySubject(String subjectId) {
    final query = _db.select(_db.topics)
      ..where((table) => table.subjectId.equals(subjectId))
      ..orderBy([(table) => OrderingTerm.asc(table.order)]);
    return query.watch();
  }

  Future<void> upsert(TopicsCompanion companion) {
    return _db.into(_db.topics).insertOnConflictUpdate(companion);
  }

  Future<void> delete(String id) {
    return (_db.delete(
      _db.topics,
    )..where((table) => table.id.equals(id))).go();
  }
}
