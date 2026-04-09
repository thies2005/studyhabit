import 'package:drift/drift.dart';
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
  bool build() => true;

  Future<void> create(String topicId, String name, int order) async {
    const uuid = Uuid();
    final db = ref.read(appDatabaseProvider);
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: uuid.v4(),
            topicId: topicId,
            name: name,
            order: order,
          ),
        );
  }

  Future<void> rename(String id, String newName) async {
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.chapters)..where((t) => t.id.equals(id))).write(
      ChaptersCompanion(name: Value(newName)),
    );
  }

  Future<void> delete(String id) async {
    final db = ref.read(appDatabaseProvider);
    await (db.delete(db.chapters)..where((t) => t.id.equals(id))).go();
  }
}
