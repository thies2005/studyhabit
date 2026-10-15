import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_database.dart';
import '../../services/timer_persistence_service.dart';

class SessionDao {
  SessionDao(this._db);

  final AppDatabase _db;

  Future<void> cleanupOrphanedSessions() async {
    final orphanedQuery = _db.select(_db.studySessions)
      ..where((table) => table.endedAt.isNull())
      ..where((table) => table.isDeleted.equals(false));
    final orphaned = await orphanedQuery.get();

    if (orphaned.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final persistence = TimerPersistenceService(prefs);
    final savedPomodoro = await persistence.loadPomodoro();
    final savedFreeTimer = await persistence.loadFreeTimer();

    final activeSessionIds = {
      if (savedPomodoro?.activeSessionId != null) savedPomodoro!.activeSessionId!,
      if (savedFreeTimer?.activeSessionId != null) savedFreeTimer!.activeSessionId!,
    };

    for (final session in orphaned) {
      if (activeSessionIds.contains(session.id)) {
        continue; // Skip the currently active session
      }

      // Reconstruct durations for the orphaned session
      final startedAt = session.startedAt;
      final planned = session.plannedDurationMinutes;
      final endedAt = startedAt.add(Duration(minutes: planned > 0 ? planned : 25));
      final finalEndedAt = endedAt.isAfter(DateTime.now()) ? DateTime.now() : endedAt;

      final durationMinutes = finalEndedAt.difference(startedAt).inMinutes;
      final clampedDuration = durationMinutes.clamp(1, 999999);

      await (_db.update(_db.studySessions)..where((t) => t.id.equals(session.id))).write(
        StudySessionsCompanion(
          endedAt: Value(finalEndedAt),
          actualDurationMinutes: Value(clampedDuration),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Stream<List<StudySessionRow>> watchBySubject(String subjectId) {
    final query = _db.select(_db.studySessions)
      ..where((table) => table.subjectId.equals(subjectId))
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([(table) => OrderingTerm.desc(table.startedAt)]);
    return query.watch();
  }

  Future<List<StudySessionRow>> getBySubject(String subjectId) {
    final query = _db.select(_db.studySessions)
      ..where((table) => table.subjectId.equals(subjectId))
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([(table) => OrderingTerm.desc(table.startedAt)]);
    return query.get();
  }

  Future<void> insert(StudySessionsCompanion companion) {
    final withUpdated = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return _db.into(_db.studySessions).insert(withUpdated);
  }

  Future<StudySessionRow?> getById(String id) {
    return (_db.select(_db.studySessions)
          ..where((table) => table.id.equals(id))
          ..where((table) => table.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<void> update(StudySessionsCompanion companion) {
    final withUpdated = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return _db.update(_db.studySessions).write(withUpdated);
  }

  Future<void> updateRow(StudySessionRow row) {
    return _db.update(_db.studySessions).replace(row.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> delete(String id) {
    return (_db.update(_db.studySessions)..where((table) => table.id.equals(id)))
        .write(StudySessionsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
  }
}
