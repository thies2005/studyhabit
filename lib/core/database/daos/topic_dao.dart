import '../app_database.dart';

class TopicDao {
  TopicDao(this._db);

  final AppDatabase _db;

  Future<TopicRow?> getById(String id) {
    final query = _db.select(_db.topics)..where((table) => table.id.equals(id));
    return query.getSingleOrNull();
  }
}
