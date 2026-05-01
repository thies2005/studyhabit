import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:studytracker/core/database/app_database.dart';
import 'package:studytracker/core/models/chapter.dart';
import 'package:studytracker/core/providers/database_provider.dart';

part 'chapter_providers.g.dart';

@riverpod
Stream<List<Chapter>> chapterList(Ref ref, String topicId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.chapters)
    ..where((t) => t.topicId.equals(topicId))
    ..orderBy([(t) => OrderingTerm.asc(t.order)]);
  return query.watch().map((rows) {
    return rows
        .map(
          (row) => Chapter(
            id: row.id,
            topicId: row.topicId,
            name: row.name,
            order: row.order,
          ),
        )
        .toList();
  });
}

@riverpod
class ChapterNotifier extends _$ChapterNotifier {
  @override
  int build() => 0;

  Future<void> create(String topicId, String name) async {
    try {
      const uuid = Uuid();
      final db = ref.read(appDatabaseProvider);

      // Get the current max order for this topic's chapters
      final existingChapters = await (db.select(db.chapters)
        ..where((t) => t.topicId.equals(topicId)))
        .get();
      final maxOrder = existingChapters.isEmpty
          ? 0
          : existingChapters.map((t) => t.order).reduce((a, b) => a > b ? a : b);

      await db.into(db.chapters).insert(
        ChaptersCompanion.insert(
          id: uuid.v4(),
          topicId: topicId,
          name: name,
          order: maxOrder + 1,
        ),
      );
    } catch (e, st) {
      debugPrint('Error creating chapter: $e\n$st');
      rethrow;
    }
  }

  Future<void> rename(String id, String newName) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await (db.update(db.chapters)..where((t) => t.id.equals(id))).write(
        ChaptersCompanion(name: Value(newName)),
      );
    } catch (e, st) {
      debugPrint('Error renaming chapter: $e\n$st');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await (db.delete(db.chapters)..where((t) => t.id.equals(id))).go();
    } catch (e, st) {
      debugPrint('Error deleting chapter: $e\n$st');
      rethrow;
    }
  }
}
