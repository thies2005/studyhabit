import 'package:drift/drift.dart';

import '../app_database.dart';

class ChapterDao {
  ChapterDao(this._db);

  final AppDatabase _db;

  Future<ChapterRow?> getById(String id) {
    final query = _db.select(_db.chapters)
      ..where((table) => table.id.equals(id))
      ..where((table) => table.isDeleted.equals(false));
    return query.getSingleOrNull();
  }

  Stream<List<ChapterRow>> watchByTopic(String topicId) {
    final query = _db.select(_db.chapters)
      ..where((table) => table.topicId.equals(topicId))
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([(table) => OrderingTerm.asc(table.order)]);
    return query.watch();
  }

  Future<void> upsert(ChaptersCompanion companion) {
    final withUpdated = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return _db.into(_db.chapters).insertOnConflictUpdate(withUpdated);
  }

  Future<void> delete(String id) {
    return (_db.update(_db.chapters)..where((table) => table.id.equals(id)))
        .write(ChaptersCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
  }
}
