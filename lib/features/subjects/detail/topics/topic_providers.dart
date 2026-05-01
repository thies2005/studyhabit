import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:studytracker/core/database/app_database.dart';
import 'package:studytracker/core/models/topic.dart';
import 'package:studytracker/core/providers/database_provider.dart';

part 'topic_providers.g.dart';

@riverpod
Stream<List<Topic>> topicList(Ref ref, String subjectId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.topics)
    ..where((t) => t.subjectId.equals(subjectId))
    ..orderBy([(t) => OrderingTerm.asc(t.order)]);
  return query.watch().map((rows) {
    return rows
        .map(
          (row) => Topic(
            id: row.id,
            subjectId: row.subjectId,
            name: row.name,
            order: row.order,
          ),
        )
        .toList();
  });
}

@riverpod
class TopicNotifier extends _$TopicNotifier {
  @override
  int build() => 0;

  Future<void> create(String subjectId, String name) async {
    try {
      const uuid = Uuid();
      final db = ref.read(appDatabaseProvider);

      // Get the current max order for this subject's topics
      final existingTopics = await (db.select(db.topics)
        ..where((t) => t.subjectId.equals(subjectId)))
        .get();
      final maxOrder = existingTopics.isEmpty
          ? 0
          : existingTopics.map((t) => t.order).reduce((a, b) => a > b ? a : b);

      await db.into(db.topics).insert(
        TopicsCompanion.insert(
          id: uuid.v4(),
          subjectId: subjectId,
          name: name,
          order: maxOrder + 1,
        ),
      );
    } catch (e, st) {
      debugPrint('Error creating topic: $e\n$st');
      rethrow;
    }
  }

  Future<void> rename(String id, String newName) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await (db.update(db.topics)..where((t) => t.id.equals(id))).write(
        TopicsCompanion(name: Value(newName)),
      );
    } catch (e, st) {
      debugPrint('Error renaming topic: $e\n$st');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await (db.delete(db.topics)..where((t) => t.id.equals(id))).go();
    } catch (e, st) {
      debugPrint('Error deleting topic: $e\n$st');
      rethrow;
    }
  }
}
