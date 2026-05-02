import 'package:drift/drift.dart';

import '../app_database.dart';

class ChapterDao {
  ChapterDao(this._db);

  final AppDatabase _db;

  Future<ChapterRow?> getById(String id) {
    final query = _db.select(_db.chapters)
      ..where((table) => table.id.equals(id));
    return query.getSingleOrNull();
  }

  Stream<List<ChapterRow>> watchByTopic(String topicId) {
    final query = _db.select(_db.chapters)
      ..where((table) => table.topicId.equals(topicId))
      ..orderBy([(table) => OrderingTerm.asc(table.order)]);
    return query.watch();
  }

  Future<void> upsert(ChaptersCompanion companion) {
    return _db.into(_db.chapters).insertOnConflictUpdate(companion);
  }

  Future<void> delete(String id) {
    return (_db.delete(
      _db.chapters,
    )..where((table) => table.id.equals(id))).go();
  }
}
