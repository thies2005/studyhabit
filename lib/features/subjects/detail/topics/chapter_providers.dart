import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:studytracker/core/database/app_database.dart';
import 'package:studytracker/core/models/chapter.dart';
import 'package:studytracker/core/models/model_mapper.dart';
import 'package:studytracker/core/providers/database_provider.dart';
import 'package:studytracker/core/services/app_logger.dart';

part 'chapter_providers.g.dart';

@riverpod
Stream<List<Chapter>> chapterList(Ref ref, String topicId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.chapters)
    ..where((t) => t.topicId.equals(topicId))
    ..orderBy([(t) => OrderingTerm.asc(t.order)]);
  return query.watch().map((rows) {
    return rows.map(mapChapter).toList();
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
      AppLogger.e('ChapterNotifier', 'Error creating chapter', e, st);
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
      AppLogger.e('ChapterNotifier', 'Error renaming chapter', e, st);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await (db.delete(db.chapters)..where((t) => t.id.equals(id))).go();
    } catch (e, st) {
      AppLogger.e('ChapterNotifier', 'Error deleting chapter', e, st);
      rethrow;
    }
  }
}
