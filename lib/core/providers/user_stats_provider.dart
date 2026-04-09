import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../database/daos/stats_dao.dart';
import '../models/model_mapper.dart';
import '../models/user_stats.dart';
import 'database_provider.dart';
import '../../core/services/app_logger.dart';

part 'user_stats_provider.g.dart';

@Riverpod(keepAlive: true)
class UserStatsNotifier extends _$UserStatsNotifier {
  late AppDatabase _db;
  late StatsDao _statsDao;

  @override
  Stream<UserStats> build() async* {
    _db = ref.watch(appDatabaseProvider);
    _statsDao = StatsDao(_db);

    try {
      await _statsDao.initStats();
      AppLogger.i('UserStatsNotifier', 'Stats initialization successful');
    } catch (e, stack) {
      AppLogger.e('UserStatsNotifier', 'Stats initialization failed', e, stack);
    }

    yield* _db
        .select(_db.userStatsTable)
        .watchSingleOrNull()
        .map((row) {
          AppLogger.i('UserStatsNotifier', 'Stats row updated: ${row?.id}');
          return mapUserStats(row);
        });
  }

  Future<void> upsert(UserStats stats) async {
    await _statsDao.upsertStats(toUserStatsCompanion(stats));
  }
}
