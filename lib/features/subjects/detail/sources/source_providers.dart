import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/source_dao.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/model_mapper.dart';
import '../../../../core/models/source.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/xp_service.dart';

part 'source_providers.g.dart';

@riverpod
Stream<List<Source>> sourceList(Ref ref, String subjectId) {
  final db = ref.watch(appDatabaseProvider);
  final dao = SourceDao(db);

  return dao
      .watchBySubject(subjectId)
      .map((rows) => rows.map(mapSource).toList());
}

@riverpod
Future<Source> sourceById(Ref ref, String sourceId) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = await (db.select(
    db.sources,
  )..where((t) => t.id.equals(sourceId))).get();
  if (rows.isEmpty) {
    throw StateError('Source not found: $sourceId');
  }
  return mapSource(rows.first);
}

@riverpod
class SourceNotifier extends _$SourceNotifier {
  @override
  Stream<List<Source>> build(String subjectId) {
    final db = ref.watch(appDatabaseProvider);
    final dao = SourceDao(db);

    return dao
        .watchBySubject(subjectId)
        .map((rows) => rows.map(mapSource).toList());
  }

  Future<void> addPdf({
    required String subjectId,
    String? topicId,
    String? chapterId,
    required String title,
    required String filePath,
    int? totalPages,
  }) async {
    const uuid = Uuid();
    final db = ref.read(appDatabaseProvider);
    final dao = SourceDao(db);

    await dao.upsert(
      SourcesCompanion.insert(
        id: uuid.v4(),
        subjectId: subjectId,
        topicId: Value(topicId),
        chapterId: Value(chapterId),
        type: SourceType.pdf,
        title: title,
        filePath: Value(filePath),
        currentPage: const Value(1),
        totalPages: totalPages == null
            ? const Value.absent()
            : Value(totalPages),
        progressPercent: const Value(0.0),
      ),
    );

    final xpService = ref.read(xpServiceProvider);
    await xpService.award(ref, XpReason.addSource);
  }

  Future<void> addUrl({
    required String subjectId,
    String? topicId,
    String? chapterId,
    required SourceType type,
    required String title,
    required String url,
  }) async {
    const uuid = Uuid();
    final db = ref.read(appDatabaseProvider);
    final dao = SourceDao(db);

    await dao.upsert(
      SourcesCompanion.insert(
        id: uuid.v4(),
        subjectId: subjectId,
        topicId: Value(topicId),
        chapterId: Value(chapterId),
        type: type,
        title: title,
        url: Value(url),
        progressPercent: const Value(0.0),
      ),
    );

    final xpService = ref.read(xpServiceProvider);
    await xpService.award(ref, XpReason.addSource);
  }

  Future<void> updateProgress(
    String id, {
    int? currentPage,
    double? progressPercent,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final dao = SourceDao(db);

    await dao.updateProgress(
      id,
      currentPage: currentPage,
      progressPercent: progressPercent,
    );
  }

  Future<void> delete(String id) async {
    final db = ref.read(appDatabaseProvider);
    final dao = SourceDao(db);
    await dao.delete(id);
  }
}
