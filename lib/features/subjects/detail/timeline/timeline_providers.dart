import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/daos/session_dao.dart';
import '../../../../core/database/daos/topic_dao.dart';
import '../../../../core/database/daos/chapter_dao.dart';
import '../../../../core/models/model_mapper.dart';
import '../../../../core/models/study_session.dart';
import '../../../../core/models/topic.dart';
import '../../../../core/models/chapter.dart';
import '../../../../core/providers/database_provider.dart';

part 'timeline_providers.g.dart';

@riverpod
Stream<Map<DateTime, List<StudySession>>> sessionsByDate(
  Ref ref,
  String subjectId,
) {
  final db = ref.watch(appDatabaseProvider);
  final sessionDao = SessionDao(db);

  return sessionDao.watchBySubject(subjectId).map((rows) {
    final sessions = rows.map(mapStudySession).toList();
    final grouped = <DateTime, List<StudySession>>{};

    for (final session in sessions) {
      final date = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      grouped.putIfAbsent(date, () => []).add(session);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, grouped[k]!)));
  });
}

@riverpod
Future<Topic?> topicById(Ref ref, String topicId) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = TopicDao(db);
  final row = await dao.getById(topicId);
  if (row == null) return null;
  return mapTopic(row);
}

@riverpod
Future<Chapter?> chapterById(Ref ref, String chapterId) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = ChapterDao(db);
  final row = await dao.getById(chapterId);
  if (row == null) return null;
  return mapChapter(row);
}
