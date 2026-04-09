import 'package:drift/drift.dart';
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
  bool build() => true;

  Future<void> create(String subjectId, String name, int order) async {
    const uuid = Uuid();
    final db = ref.read(appDatabaseProvider);
    await db
        .into(db.topics)
        .insert(
          TopicsCompanion.insert(
            id: uuid.v4(),
            subjectId: subjectId,
            name: name,
            order: order,
          ),
        );
  }

  Future<void> rename(String id, String newName) async {
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.topics)..where((t) => t.id.equals(id))).write(
      TopicsCompanion(name: Value(newName)),
    );
  }

  Future<void> delete(String id) async {
    final db = ref.read(appDatabaseProvider);
    await (db.delete(db.topics)..where((t) => t.id.equals(id))).go();
  }
}
