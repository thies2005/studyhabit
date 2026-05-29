import 'package:drift/drift.dart';

import '../app_database.dart';

class SubjectMilestoneDao {
  SubjectMilestoneDao(this._db);

  final AppDatabase _db;

  Stream<List<SubjectMilestoneRow>> watchBySubject(String subjectId) {
    final query = _db.select(_db.subjectMilestones)
      ..where((table) => table.subjectId.equals(subjectId))
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([(table) => OrderingTerm.asc(table.sortOrder)]);
    return query.watch();
  }

  Future<void> insert(SubjectMilestonesCompanion companion) {
    final withUpdated = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return _db.into(_db.subjectMilestones).insert(withUpdated);
  }

  Future<void> update(SubjectMilestonesCompanion companion) {
    final withUpdated = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return (_db.update(_db.subjectMilestones)
          ..where((table) => table.id.equals(companion.id.value)))
        .write(withUpdated);
  }

  Future<void> updateCompletion(String id, {required bool isCompleted}) {
    return (_db.update(_db.subjectMilestones)
          ..where((table) => table.id.equals(id)))
        .write(
      SubjectMilestonesCompanion(
        isCompleted: Value(isCompleted),
        completedAt: Value(isCompleted ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(String id) {
    return (_db.update(_db.subjectMilestones)
          ..where((table) => table.id.equals(id)))
        .write(SubjectMilestonesCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
  }

  Future<void> deleteAllForSubject(String subjectId) {
    return (_db.update(_db.subjectMilestones)
          ..where((table) => table.subjectId.equals(subjectId)))
        .write(SubjectMilestonesCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
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
