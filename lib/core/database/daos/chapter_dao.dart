import '../app_database.dart';

class ChapterDao {
  ChapterDao(this._db);

  final AppDatabase _db;

  Future<ChapterRow?> getById(String id) {
    final query = _db.select(_db.chapters)
      ..where((table) => table.id.equals(id));
    return query.getSingleOrNull();
  }
}
