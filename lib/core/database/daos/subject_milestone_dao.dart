import 'package:drift/drift.dart';

import '../app_database.dart';

class SubjectMilestoneDao {
  SubjectMilestoneDao(this._db);

  final AppDatabase _db;

  Stream<List<SubjectMilestoneRow>> watchBySubject(String subjectId) {
    final query = _db.select(_db.subjectMilestones)
      ..where((table) => table.subjectId.equals(subjectId))
      ..orderBy([(table) => OrderingTerm.asc(table.sortOrder)]);
    return query.watch();
  }

  Future<void> insert(SubjectMilestonesCompanion companion) {
    return _db.into(_db.subjectMilestones).insert(companion);
  }

  Future<void> update(SubjectMilestonesCompanion companion) {
    return (_db.update(_db.subjectMilestones)
          ..where((table) => table.id.equals(companion.id.value)))
        .write(companion);
  }

  Future<void> updateCompletion(String id, {required bool isCompleted}) {
    return (_db.update(_db.subjectMilestones)
          ..where((table) => table.id.equals(id)))
        .write(
      SubjectMilestonesCompanion(
        isCompleted: Value(isCompleted),
        completedAt: Value(isCompleted ? DateTime.now() : null),
      ),
    );
  }

  Future<void> delete(String id) {
    return (_db.delete(_db.subjectMilestones)
          ..where((table) => table.id.equals(id)))
        .go();
  }

  Future<void> deleteAllForSubject(String subjectId) {
    return (_db.delete(_db.subjectMilestones)
          ..where((table) => table.subjectId.equals(subjectId)))
        .go();
  }

  Future<void> reorder(List<({String id, int sortOrder})> items) async {
    await _db.batch((batch) {
      for (final item in items) {
        batch.update(
          _db.subjectMilestones,
          SubjectMilestonesCompanion(sortOrder: Value(item.sortOrder)),
          where: (table) => table.id.equals(item.id),
        );
      }
    });
  }
}
