import '../app_database.dart';
import '../../services/app_logger.dart';
import 'package:drift/drift.dart';

class StatsDao {
  StatsDao(this._db);

  final AppDatabase _db;

  Future<UserStatsRow?> getStats() {
    return _db.select(_db.userStatsTable).getSingleOrNull();
  }

  Future<void> upsertStats(UserStatsTableCompanion companion) {
    final withUpdated = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return _db.into(_db.userStatsTable).insertOnConflictUpdate(withUpdated);
  }

  Future<void> initStats() async {
    final existing = await getStats();
    if (existing != null) {
      AppLogger.i('StatsDao', 'Stats row already exists');
      return;
    }

    AppLogger.i('StatsDao', 'Creating initial stats row');
    await upsertStats(const UserStatsTableCompanion(
      id: Value('default_stats'),
    ));
  }
}
