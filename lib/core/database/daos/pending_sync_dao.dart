import 'package:drift/drift.dart';

import '../app_database.dart';

class PendingSyncDao {
  final AppDatabase _db;

  PendingSyncDao(this._db);

  Future<void> insertOp(PendingSyncOpRow op) {
    return _db.into(_db.pendingSyncOps).insert(op);
  }

  Future<List<PendingSyncOpRow>> getPending() {
    final query = _db.select(_db.pendingSyncOps)..where((t) => t.isSynced.equals(false));
    return query.get();
  }

  Future<void> markSynced(String id) {
    return (_db.update(_db.pendingSyncOps)..where((t) => t.id.equals(id)))
        .write(const PendingSyncOpsCompanion(isSynced: Value(true)));
  }

  Future<void> markAllSynced(List<String> ids) {
    return (_db.update(_db.pendingSyncOps)..where((t) => t.id.isIn(ids)))
        .write(const PendingSyncOpsCompanion(isSynced: Value(true)));
  }

  Future<void> deleteOlderThan(DateTime cutoff) {
    return (_db.delete(_db.pendingSyncOps)
          ..where((t) => t.createdAt.isSmallerThanValue(cutoff) & t.isSynced.equals(true)))
        .go();
  }

  Stream<int> watchPendingCount() {
    final query = _db.select(_db.pendingSyncOps)..where((t) => t.isSynced.equals(false));
    return query.watch().map((list) => list.length);
  }
}
