import 'dart:async';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../network/api_client.dart';
import '../network/connectivity_provider.dart';
import '../providers/database_provider.dart';
import '../providers/server_url_provider.dart';
import 'auth_service.dart';
import 'app_logger.dart';
import '../models/enums.dart';
import '../providers/theme_provider.dart';
import '../../features/pomodoro/pomodoro_notifier.dart';
import '../../features/pomodoro/free_timer_notifier.dart';

part 'sync_service.g.dart';

enum SyncStatus { idle, syncing, synced, error }

@Riverpod(keepAlive: true)
class SyncEngine extends _$SyncEngine {
  static const _lastSyncedKey = 'sync.lastSyncedAt';
  static const _lastSyncedUserKey = 'sync.lastSyncedUserId';
  
  static const _dataEntityTypes = {
    'project', 'subject', 'topic', 'chapter', 'session',
    'source', 'skillLabel', 'subjectMilestone',
  };

  late AppDatabase _db;
  late SharedPreferences _prefs;
  Timer? _syncTimer;
  bool _syncPending = false;
  bool _forceFullSync = false;

  @override
  SyncStatus build() {
    _db = ref.watch(appDatabaseProvider);
    _prefs = ref.watch(sharedPreferencesInstanceProvider);

    ref.listen(authProvider, (previous, next) {
      final wasAuthed = previous?.maybeWhen(authenticated: (_, __) => true, orElse: () => false) ?? false;
      final isAuthed = next.maybeWhen(authenticated: (_, __) => true, orElse: () => false);
      if (!wasAuthed && isAuthed) {
        _forceFullSync = true;
        () async {
          try {
            await fullSync();
          } catch (e, stack) {
            AppLogger.e('SyncEngine', 'Post-auth sync failed', e, stack);
            state = SyncStatus.error;
          }
        }();
      }
    });

    return SyncStatus.idle;
  }

  Future<void> resetLastSyncedAt() async {
    await _prefs.setInt(_lastSyncedKey, 0);
    AppLogger.i('SyncEngine', 'Reset lastSyncedAt to epoch for first sync after auth.');
  }

  DateTime get lastSyncedAt {
    final ms = _prefs.getInt(_lastSyncedKey) ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastSyncedAt(DateTime dateTime) async {
    await _prefs.setInt(_lastSyncedKey, dateTime.millisecondsSinceEpoch);
  }

  Future<void> resetLastSyncedUser() async {
    await _prefs.remove(_lastSyncedUserKey);
  }

  void debouncedSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 30), () {
      fullSync();
    });
  }

  Future<void> syncNow() async {
    _syncTimer?.cancel();
    await fullSync();
  }

  Future<void> fullSync() async {
    // 1. Pre-flight checks
    final authState = ref.read(authProvider);
    final isLoggedIn = authState.maybeWhen(
      authenticated: (_, __) => true,
      orElse: () => false,
    );
    if (!isLoggedIn) {
      AppLogger.d('SyncEngine', 'Skipping sync: User not logged in.');
      return;
    }

    final userId = authState.maybeWhen(authenticated: (id, _) => id, orElse: () => '');

    final isOnlineVal = await ref.read(isOnlineProvider.future).catchError((_) => false);
    if (!isOnlineVal) {
      AppLogger.d('SyncEngine', 'Skipping sync: Device is offline.');
      return;
    }

    if (state == SyncStatus.syncing) {
      AppLogger.d('SyncEngine', 'Sync already in progress. Queuing next sync.');
      _syncPending = true;
      return;
    }

    _syncTimer?.cancel();

    if (_forceFullSync) {
      _forceFullSync = false;
      await _prefs.setInt(_lastSyncedKey, 0);
      AppLogger.i('SyncEngine', 'Force full sync: reset lastSyncedAt to epoch.');
    }

    if (userId.isNotEmpty) {
      final lastSyncedUserId = _prefs.getString(_lastSyncedUserKey);
      if (lastSyncedUserId != userId) {
        await _prefs.setString(_lastSyncedUserKey, userId);
        await _prefs.setInt(_lastSyncedKey, 0);
        AppLogger.i('SyncEngine', 'Detected new user. Reset lastSyncedAt to epoch.');
      } else {
        final ms = _prefs.getInt(_lastSyncedKey) ?? 0;
        if (ms > 0) {
          final p = await (_db.select(_db.projects)..limit(1)).get();
          if (p.isEmpty) {
            await _prefs.setInt(_lastSyncedKey, 0);
            AppLogger.w('SyncEngine', 'Local DB is empty but lastSyncedAt > 0. Forcing full sync (likely a fresh install with restored prefs).');
          }
        }
      }
    }

    state = SyncStatus.syncing;
    AppLogger.i('SyncEngine', 'Starting full synchronization...');

    // One-time migration: bump updatedAt of old offline sessions
    final hasMigrated = _prefs.getBool('sync.hasMigratedOfflineSessions') ?? false;
    if (!hasMigrated) {
      final lastSyncedAtMs = _prefs.getInt(_lastSyncedKey) ?? 0;
      if (lastSyncedAtMs > 0) {
        final cutoff = DateTime.fromMillisecondsSinceEpoch(lastSyncedAtMs);
        final oldSessions = await (_db.select(_db.studySessions)..where((t) => t.updatedAt.isSmallerOrEqualValue(cutoff))).get();
        if (oldSessions.isNotEmpty) {
          AppLogger.i('SyncEngine', 'Migrating ${oldSessions.length} old offline sessions to trigger sync...');
          for (final session in oldSessions) {
            await (_db.update(_db.studySessions)..where((t) => t.id.equals(session.id))).write(
              StudySessionsCompanion(updatedAt: Value(DateTime.now().add(const Duration(seconds: 1)))),
            );
          }
        }
      }
      await _prefs.setBool('sync.hasMigratedOfflineSessions', true);
    }

    try {
      final since = lastSyncedAt;
      final dio = ref.read(apiClientProvider);

      // 2. Fetch local changes since lastSync
      final pushPayload = await _collectLocalChanges(since);

      // 3. Make the API call to /sync/full
      final response = await dio.post(
        '/sync/full',
        queryParameters: {'since': since.toUtc().toIso8601String()},
        data: pushPayload,
      );

      final responseData = response.data['data'];
      final pullData = responseData['pull'] as Map<String, dynamic>;
      final serverTimeStr = pullData['serverTime'] as String;
      final serverTime = DateTime.parse(serverTimeStr);

      final pushData = responseData['push'] as Map<String, dynamic>?;
      bool hasDataErrors = false;
      final forbiddenSessionIds = <String>[];
      final forbiddenSourceIds = <String>[];
      final forbiddenSubjectIds = <String>[];
      final forbiddenTopicIds = <String>[];
      final forbiddenChapterIds = <String>[];
      if (pushData != null) {
        final errors = pushData['errors'] as List?;
        if (errors != null && errors.isNotEmpty) {
          for (final e in errors) {
            final errMap = e as Map<String, dynamic>;
            final entity = errMap['entity'] as String?;
            final errorType = errMap['error'] as String?;
            final errId = errMap['id'] as String?;
            if (errorType == 'forbidden') {
              if (entity == 'session' && errId != null) {
                forbiddenSessionIds.add(errId);
              } else if (entity == 'source' && errId != null) {
                forbiddenSourceIds.add(errId);
              } else if (entity == 'subject' && errId != null) {
                forbiddenSubjectIds.add(errId);
              } else if (entity == 'topic' && errId != null) {
                forbiddenTopicIds.add(errId);
              } else if (entity == 'chapter' && errId != null) {
                forbiddenChapterIds.add(errId);
              }
              continue;
            }
            if (entity != null && _dataEntityTypes.contains(entity)) {
              hasDataErrors = true;
            }
          }
          if (errors.isNotEmpty) {
            AppLogger.e('SyncEngine', 'Server returned ${errors.length} sync errors: $errors');
          }
        }
      }

      if (forbiddenSessionIds.isNotEmpty) {
        AppLogger.w('SyncEngine', 'Soft-deleting ${forbiddenSessionIds.length} orphaned sessions (subject not owned by user)');
        for (final id in forbiddenSessionIds) {
          await (_db.update(_db.studySessions)..where((t) => t.id.equals(id)))
              .write(StudySessionsCompanion(isDeleted: const Value(true), updatedAt: Value(serverTime)));
        }
      }
      if (forbiddenSourceIds.isNotEmpty) {
        AppLogger.w('SyncEngine', 'Soft-deleting ${forbiddenSourceIds.length} orphaned sources (subject not owned by user)');
        for (final id in forbiddenSourceIds) {
          await (_db.update(_db.sources)..where((t) => t.id.equals(id)))
              .write(SourcesCompanion(isDeleted: const Value(true), updatedAt: Value(serverTime)));
        }
      }
      if (forbiddenChapterIds.isNotEmpty) {
        AppLogger.w('SyncEngine', 'Soft-deleting ${forbiddenChapterIds.length} orphaned chapters (topic not owned by user)');
        for (final id in forbiddenChapterIds) {
          await (_db.update(_db.chapters)..where((t) => t.id.equals(id)))
              .write(ChaptersCompanion(isDeleted: const Value(true), updatedAt: Value(serverTime)));
        }
      }
      if (forbiddenTopicIds.isNotEmpty) {
        AppLogger.w('SyncEngine', 'Soft-deleting ${forbiddenTopicIds.length} orphaned topics (subject not owned by user)');
        for (final id in forbiddenTopicIds) {
          await (_db.update(_db.topics)..where((t) => t.id.equals(id)))
              .write(TopicsCompanion(isDeleted: const Value(true), updatedAt: Value(serverTime)));
        }
      }
      if (forbiddenSubjectIds.isNotEmpty) {
        AppLogger.w('SyncEngine', 'Soft-deleting ${forbiddenSubjectIds.length} orphaned subjects (project not owned by user)');
        for (final id in forbiddenSubjectIds) {
          await (_db.update(_db.subjects)..where((t) => t.id.equals(id)))
              .write(SubjectsCompanion(isDeleted: const Value(true), updatedAt: Value(serverTime)));
        }
      }

      // 4. Apply remote changes locally
      await _applyRemoteChanges(pullData);

      // 5. Update last synced timestamp ONLY if no data-entity push errors
      if (hasDataErrors) {
        AppLogger.w('SyncEngine', 'Not updating lastSyncedAt due to data-entity push errors. Failed items will be retried on next sync.');
        state = SyncStatus.error;
      } else {
        await setLastSyncedAt(serverTime);
        state = SyncStatus.synced;
        AppLogger.i('SyncEngine', 'Synchronization completed successfully at $serverTime');
      }
    } catch (e, stack) {
      state = SyncStatus.error;
      AppLogger.e('SyncEngine', 'Sync failed', e, stack);
    } finally {
      if (_syncPending) {
        _syncPending = false;
        AppLogger.i('SyncEngine', 'Executing pending sync...');
        await fullSync();
      }
    }
  }

  Future<Map<String, dynamic>> _collectLocalChanges(DateTime since) async {
    final isFirstSync = since.millisecondsSinceEpoch == 0;

    // Query rows modified locally since the last sync time
    final projects = await (isFirstSync
        ? (_db.select(_db.projects)..where((t) => t.isDeleted.equals(false)))
        : (_db.select(_db.projects)..where((t) => t.updatedAt.isBiggerThanValue(since)))
    ).get();
    final subjects = await (isFirstSync
        ? (_db.select(_db.subjects)..where((t) => t.isDeleted.equals(false)))
        : (_db.select(_db.subjects)..where((t) => t.updatedAt.isBiggerThanValue(since)))
    ).get();
    final topics = await (isFirstSync
        ? (_db.select(_db.topics)..where((t) => t.isDeleted.equals(false)))
        : (_db.select(_db.topics)..where((t) => t.updatedAt.isBiggerThanValue(since)))
    ).get();
    final chapters = await (isFirstSync
        ? (_db.select(_db.chapters)..where((t) => t.isDeleted.equals(false)))
        : (_db.select(_db.chapters)..where((t) => t.updatedAt.isBiggerThanValue(since)))
    ).get();
    final sessions = await (isFirstSync
        ? (_db.select(_db.studySessions)..where((t) => t.isDeleted.equals(false)))
        : (_db.select(_db.studySessions)..where((t) => t.updatedAt.isBiggerThanValue(since)))
    ).get();
    final sources = await (isFirstSync
        ? (_db.select(_db.sources)..where((t) => t.isDeleted.equals(false)))
        : (_db.select(_db.sources)..where((t) => t.updatedAt.isBiggerThanValue(since)))
    ).get();
    final skillLabels = await (isFirstSync
        ? (_db.select(_db.skillLabels)..where((t) => t.isDeleted.equals(false)))
        : (_db.select(_db.skillLabels)..where((t) => t.updatedAt.isBiggerThanValue(since)))
    ).get();
    final milestones = await (isFirstSync
        ? (_db.select(_db.subjectMilestones)..where((t) => t.isDeleted.equals(false)))
        : (_db.select(_db.subjectMilestones)..where((t) => t.updatedAt.isBiggerThanValue(since)))
    ).get();
    final achievements = await (isFirstSync ? _db.select(_db.achievements) : (_db.select(_db.achievements)..where((t) => t.updatedAt.isBiggerThanValue(since)))).get();
    
    // User stats
    final stats = await _db.select(_db.userStatsTable).getSingleOrNull();
    Map<String, dynamic>? statsJson;
    if (stats != null && (isFirstSync || stats.updatedAt.isAfter(since))) {
      final authState = ref.read(authProvider);
      final userId = authState.maybeWhen(authenticated: (id, _) => id, orElse: () => '');
      statsJson = {
        'userId': userId,
        'totalXp': stats.totalXp,
        'currentLevel': stats.currentLevel,
        'currentStreak': stats.currentStreak,
        'longestStreak': stats.longestStreak,
        'lastStudyDate': stats.lastStudyDate?.toUtc().toIso8601String(),
        'totalStudyMinutes': stats.totalStudyMinutes,
        'freezeTokens': stats.freezeTokens,
        'updatedAt': stats.updatedAt.toUtc().toIso8601String(),
      };
    }

    final settingsUpdatedAtMs = _prefs.getInt('theme.settingsUpdatedAt') ?? 0;
    final settingsUpdatedAt = DateTime.fromMillisecondsSinceEpoch(settingsUpdatedAtMs);
    Map<String, dynamic>? settingsPayload;
    if (isFirstSync || settingsUpdatedAt.isAfter(since)) {
      final settingsKeys = _prefs.getKeys().where(
        (k) =>
            k.startsWith('theme.') ||
            k.startsWith('pomodoro.') ||
            k.startsWith('notifications.') ||
            k.startsWith('streak.') ||
            k.startsWith('goal.') ||
            k == 'active_timer_type' ||
            k == 'pomodoro_state_json' ||
            k == 'free_timer_state_json',
      );
      final settingsMap = <String, dynamic>{};
      for (final key in settingsKeys) {
        if (key == 'theme.settingsUpdatedAt') continue;
        final value = _prefs.get(key);
        if (value != null) settingsMap[key] = value;
      }
      if (settingsMap.isNotEmpty) {
        settingsPayload = {
          'settings': settingsMap,
          'updatedAt': settingsUpdatedAt.toUtc().toIso8601String(),
        };
      }
    }

    return {
      if (projects.isNotEmpty) 'projects': projects.map((p) => _projectToJson(p)).toList(),
      if (subjects.isNotEmpty) 'subjects': subjects.map((s) => _subjectToJson(s)).toList(),
      if (topics.isNotEmpty) 'topics': topics.map((t) => _topicToJson(t)).toList(),
      if (chapters.isNotEmpty) 'chapters': chapters.map((c) => _chapterToJson(c)).toList(),
      if (sessions.isNotEmpty) 'sessions': sessions.map((s) => _sessionToJson(s)).toList(),
      if (sources.isNotEmpty) 'sources': sources.map((s) => _sourceToJson(s)).toList(),
      if (skillLabels.isNotEmpty) 'skillLabels': skillLabels.map((s) => _skillLabelToJson(s)).toList(),
      if (milestones.isNotEmpty) 'subjectMilestones': milestones.map((m) => _milestoneToJson(m)).toList(),
      if (achievements.isNotEmpty) 'achievements': achievements.map((a) => _achievementToJson(a)).toList(),
      if (statsJson != null) 'userStats': statsJson,
      if (settingsPayload != null) 'userSettings': settingsPayload,
    };
  }

  Future<void> _applyRemoteChanges(Map<String, dynamic> pull) async {

    // 1. Projects
    final projectsJson = pull['projects'] as List? ?? [];
    for (final item in projectsJson) {
      final id = item['id'] as String;
      final serverUpdatedAt = DateTime.parse(item['updatedAt']);
      final local = await (_db.select(_db.projects)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local == null || serverUpdatedAt.isAfter(local.updatedAt)) {
        await _db.into(_db.projects).insertOnConflictUpdate(_projectFromJson(item));
      }
    }

    // 2. Subjects
    final subjectsJson = pull['subjects'] as List? ?? [];
    for (final item in subjectsJson) {
      final id = item['id'] as String;
      final serverUpdatedAt = DateTime.parse(item['updatedAt']);
      final local = await (_db.select(_db.subjects)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local == null || serverUpdatedAt.isAfter(local.updatedAt)) {
        await _db.into(_db.subjects).insertOnConflictUpdate(_subjectFromJson(item));
      }
    }

    // 3. Topics
    final topicsJson = pull['topics'] as List? ?? [];
    for (final item in topicsJson) {
      final id = item['id'] as String;
      final serverUpdatedAt = DateTime.parse(item['updatedAt']);
      final local = await (_db.select(_db.topics)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local == null || serverUpdatedAt.isAfter(local.updatedAt)) {
        await _db.into(_db.topics).insertOnConflictUpdate(_topicFromJson(item));
      }
    }

    // 4. Chapters
    final chaptersJson = pull['chapters'] as List? ?? [];
    for (final item in chaptersJson) {
      final id = item['id'] as String;
      final serverUpdatedAt = DateTime.parse(item['updatedAt']);
      final local = await (_db.select(_db.chapters)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local == null || serverUpdatedAt.isAfter(local.updatedAt)) {
        await _db.into(_db.chapters).insertOnConflictUpdate(_chapterFromJson(item));
      }
    }

    // 5. Sessions
    final sessionsJson = pull['sessions'] as List? ?? [];
    for (final item in sessionsJson) {
      final id = item['id'] as String;
      final serverUpdatedAt = DateTime.parse(item['updatedAt']);
      final local = await (_db.select(_db.studySessions)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local == null || serverUpdatedAt.isAfter(local.updatedAt)) {
        await _db.into(_db.studySessions).insertOnConflictUpdate(_sessionFromJson(item));
      }
    }

    // 6. Sources
    final sourcesJson = pull['sources'] as List? ?? [];
    for (final item in sourcesJson) {
      final id = item['id'] as String;
      final serverUpdatedAt = DateTime.parse(item['updatedAt']);
      final local = await (_db.select(_db.sources)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local == null || serverUpdatedAt.isAfter(local.updatedAt)) {
        await _db.into(_db.sources).insertOnConflictUpdate(_sourceFromJson(item));
      }
    }

    // 7. Skill Labels
    final skillLabelsJson = pull['skillLabels'] as List? ?? [];
    for (final item in skillLabelsJson) {
      final id = item['id'] as String;
      final serverUpdatedAt = DateTime.parse(item['updatedAt']);
      final local = await (_db.select(_db.skillLabels)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local == null || serverUpdatedAt.isAfter(local.updatedAt)) {
        await _db.into(_db.skillLabels).insertOnConflictUpdate(_skillLabelFromJson(item));
      }
    }

    // 8. Milestones
    final milestonesJson = pull['subjectMilestones'] as List? ?? [];
    for (final item in milestonesJson) {
      final id = item['id'] as String;
      final serverUpdatedAt = DateTime.parse(item['updatedAt']);
      final local = await (_db.select(_db.subjectMilestones)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local == null || serverUpdatedAt.isAfter(local.updatedAt)) {
        await _db.into(_db.subjectMilestones).insertOnConflictUpdate(_milestoneFromJson(item));
      }
    }

    // 8.5 Achievements
    final achievementsJson = pull['achievements'] as List? ?? [];
    for (final item in achievementsJson) {
      final key = item['key'] as String;
      final serverUpdatedAt = DateTime.parse(item['updatedAt']);
      final local = await (_db.select(_db.achievements)..where((t) => t.key.equals(key))).getSingleOrNull();
      if (local == null || serverUpdatedAt.isAfter(local.updatedAt)) {
        await _db.into(_db.achievements).insertOnConflictUpdate(_achievementFromJson(item));
      }
    }

    // 9. User Stats (Max-Wins Conflict Resolution)
    final statsJson = pull['userStats'] as Map<String, dynamic>?;
    if (statsJson != null) {
      final local = await _db.select(_db.userStatsTable).getSingleOrNull();
      final serverUpdatedAt = DateTime.parse(statsJson['updatedAt']);
      if (local == null || serverUpdatedAt.isAfter(local.updatedAt)) {
        await _db.into(_db.userStatsTable).insertOnConflictUpdate(_statsFromJson(statsJson));
      }
    }

    // 10. User Settings
    final userSettingsPayload = pull['userSettings'] as Map<String, dynamic>?;
    if (userSettingsPayload != null) {
      final settingsJson = userSettingsPayload['settings'] as Map<String, dynamic>?;
      final serverUpdatedAt = DateTime.parse(userSettingsPayload['updatedAt'] as String);
      final localUpdatedAtMs = _prefs.getInt('theme.settingsUpdatedAt') ?? 0;
      final localUpdatedAt = DateTime.fromMillisecondsSinceEpoch(localUpdatedAtMs);

      if (settingsJson != null && serverUpdatedAt.isAfter(localUpdatedAt)) {
        await ref.read(themeSettingsProvider.notifier).loadSettings(settingsJson, remoteUpdatedAt: serverUpdatedAt);
        ref.read(pomodoroProvider.notifier).reloadFromPersistence();
        ref.read(freeTimerProvider.notifier).reloadFromPersistence();
      }
    }
  }

  // Helper converters between Drift Row and JSON
  Map<String, dynamic> _projectToJson(ProjectRow r) => {
        'id': r.id,
        'userId': ref.read(authProvider).maybeWhen(authenticated: (id, _) => id, orElse: () => ''),
        'name': r.name,
        'icon': r.icon,
        'colorValue': _normalizeColorForSync(r.colorValue),
        'createdAt': r.createdAt.toUtc().toIso8601String(),
        'lastOpenedAt': r.lastOpenedAt.toUtc().toIso8601String(),
        'isArchived': r.isArchived,
        'defaultWorkDuration': r.defaultWorkDuration,
        'defaultBreakDuration': r.defaultBreakDuration,
        'defaultLongBreakDuration': r.defaultLongBreakDuration,
        'defaultLongBreakEvery': r.defaultLongBreakEvery,
        'studyReminderMinutes': r.studyReminderMinutes,
        'isDeleted': r.isDeleted,
        'updatedAt': r.updatedAt.toUtc().toIso8601String(),
      };

  ProjectRow _projectFromJson(Map<String, dynamic> j) => ProjectRow(
        id: j['id'],
        name: j['name'],
        icon: j['icon'] ?? '📚',
        colorValue: _normalizeColorFromSync(j['colorValue']),
        createdAt: DateTime.parse(j['createdAt']),
        lastOpenedAt: DateTime.parse(j['lastOpenedAt']),
        isArchived: j['isArchived'] ?? false,
        defaultWorkDuration: j['defaultWorkDuration'] ?? 25,
        defaultBreakDuration: j['defaultBreakDuration'] ?? 5,
        defaultLongBreakDuration: j['defaultLongBreakDuration'] ?? 15,
        defaultLongBreakEvery: j['defaultLongBreakEvery'] ?? 4,
        studyReminderMinutes: j['studyReminderMinutes'] ?? 30,
        isDeleted: j['isDeleted'] as bool? ?? false,
        updatedAt: DateTime.parse(j['updatedAt']),
      );

  Map<String, dynamic> _subjectToJson(SubjectRow r) => {
        'id': r.id,
        'projectId': r.projectId,
        'name': r.name,
        'description': r.description,
        'colorValue': _normalizeColorForSync(r.colorValue),
        'hierarchyMode': r.hierarchyMode.name,
        'defaultDurationMinutes': r.defaultDurationMinutes,
        'defaultBreakMinutes': r.defaultBreakMinutes,
        'xpTotal': r.xpTotal,
        'createdAt': r.createdAt.toUtc().toIso8601String(),
        'completenessMode': r.completenessMode.name,
        'targetHours': r.targetHours,
        'targetWeeklyHours': r.targetWeeklyHours,
        'isDeleted': r.isDeleted,
        'updatedAt': r.updatedAt.toUtc().toIso8601String(),
      };

  SubjectRow _subjectFromJson(Map<String, dynamic> j) => SubjectRow(
        id: j['id'],
        projectId: j['projectId'],
        name: j['name'],
        description: j['description'],
        colorValue: _normalizeColorFromSync(j['colorValue']),
        hierarchyMode: HierarchyMode.values.firstWhere((e) => e.name == j['hierarchyMode'], orElse: () => HierarchyMode.flat),
        defaultDurationMinutes: j['defaultDurationMinutes'] ?? 25,
        defaultBreakMinutes: j['defaultBreakMinutes'] ?? 5,
        xpTotal: j['xpTotal'] ?? 0,
        createdAt: DateTime.parse(j['createdAt']),
        completenessMode: CompletenessMode.values.firstWhere((e) => e.name == j['completenessMode'], orElse: () => CompletenessMode.none),
        targetHours: (j['targetHours'] as num?)?.toInt(),
        targetWeeklyHours: (j['targetWeeklyHours'] as num?)?.toInt(),
        isDeleted: j['isDeleted'] as bool? ?? false,
        updatedAt: DateTime.parse(j['updatedAt']),
      );

  Map<String, dynamic> _topicToJson(TopicRow r) => {
        'id': r.id,
        'subjectId': r.subjectId,
        'name': r.name,
        'order': r.order,
        'isDeleted': r.isDeleted,
        'updatedAt': r.updatedAt.toUtc().toIso8601String(),
      };

  TopicRow _topicFromJson(Map<String, dynamic> j) => TopicRow(
        id: j['id'],
        subjectId: j['subjectId'],
        name: j['name'],
        order: j['order'] ?? 0,
        isDeleted: j['isDeleted'] as bool? ?? false,
        updatedAt: DateTime.parse(j['updatedAt']),
      );

  Map<String, dynamic> _chapterToJson(ChapterRow r) => {
        'id': r.id,
        'topicId': r.topicId,
        'name': r.name,
        'order': r.order,
        'isDeleted': r.isDeleted,
        'updatedAt': r.updatedAt.toUtc().toIso8601String(),
      };

  ChapterRow _chapterFromJson(Map<String, dynamic> j) => ChapterRow(
        id: j['id'],
        topicId: j['topicId'],
        name: j['name'],
        order: j['order'] ?? 0,
        isDeleted: j['isDeleted'] as bool? ?? false,
        updatedAt: DateTime.parse(j['updatedAt']),
      );

  Map<String, dynamic> _sessionToJson(StudySessionRow r) => {
        'id': r.id,
        'subjectId': r.subjectId,
        'topicId': r.topicId,
        'chapterId': r.chapterId,
        'startedAt': r.startedAt.toUtc().toIso8601String(),
        'endedAt': r.endedAt?.toUtc().toIso8601String(),
        'plannedDurationMinutes': r.plannedDurationMinutes,
        'actualDurationMinutes': r.actualDurationMinutes,
        'pomodorosCompleted': r.pomodorosCompleted,
        'confidenceRating': r.confidenceRating,
        'notes': r.notes,
        'xpEarned': r.xpEarned,
        'sourceId': r.sourceId,
        'startPage': r.startPage,
        'endPage': r.endPage,
        'isFreeTimer': r.isFreeTimer,
        'isDeleted': r.isDeleted,
        'updatedAt': r.updatedAt.toUtc().toIso8601String(),
      };

  StudySessionRow _sessionFromJson(Map<String, dynamic> j) => StudySessionRow(
        id: j['id'],
        subjectId: j['subjectId'],
        topicId: j['topicId'],
        chapterId: j['chapterId'],
        startedAt: DateTime.parse(j['startedAt']),
        endedAt: j['endedAt'] != null ? DateTime.parse(j['endedAt']) : null,
        plannedDurationMinutes: j['plannedDurationMinutes'] ?? 25,
        actualDurationMinutes: j['actualDurationMinutes'] ?? 0,
        pomodorosCompleted: j['pomodorosCompleted'] ?? 0,
        confidenceRating: j['confidenceRating'],
        notes: j['notes'],
        xpEarned: j['xpEarned'] ?? 0,
        sourceId: j['sourceId'],
        startPage: j['startPage'],
        endPage: j['endPage'],
        isFreeTimer: j['isFreeTimer'] ?? false,
        isDeleted: j['isDeleted'] as bool? ?? false,
        updatedAt: DateTime.parse(j['updatedAt']),
      );

  Map<String, dynamic> _sourceToJson(SourceRow r) => {
        'id': r.id,
        'subjectId': r.subjectId,
        'topicId': r.topicId,
        'chapterId': r.chapterId,
        'type': r.type.name,
        'title': r.title,
        'filePath': r.filePath,
        'url': r.url,
        'currentPage': r.currentPage,
        'totalPages': r.totalPages,
        'progressPercent': r.progressPercent,
        'notes': r.notes,
        'addedAt': r.addedAt.toUtc().toIso8601String(),
        'isDeleted': r.isDeleted,
        'updatedAt': r.updatedAt.toUtc().toIso8601String(),
      };

  SourceRow _sourceFromJson(Map<String, dynamic> j) => SourceRow(
        id: j['id'],
        subjectId: j['subjectId'],
        topicId: j['topicId'],
        chapterId: j['chapterId'],
        type: SourceType.values.firstWhere((e) => e.name == j['type'], orElse: () => SourceType.pdf),
        title: j['title'],
        filePath: j['filePath'],
        url: j['url'],
        currentPage: j['currentPage'],
        totalPages: j['totalPages'],
        progressPercent: (j['progressPercent'] as num?)?.toDouble(),
        notes: j['notes'],
        addedAt: DateTime.parse(j['addedAt']),
        isDeleted: j['isDeleted'] as bool? ?? false,
        updatedAt: DateTime.parse(j['updatedAt']),
      );

  Map<String, dynamic> _skillLabelToJson(SkillLabelRow r) => {
        'id': r.id,
        'subjectId': r.subjectId,
        'topicId': r.topicId,
        'chapterId': r.chapterId,
        'label': r.label.name,
        'isDeleted': r.isDeleted,
        'updatedAt': r.updatedAt.toUtc().toIso8601String(),
      };

  SkillLabelRow _skillLabelFromJson(Map<String, dynamic> j) => SkillLabelRow(
        id: j['id'],
        subjectId: j['subjectId'],
        topicId: j['topicId'],
        chapterId: j['chapterId'],
        label: SkillLevel.values.firstWhere((e) => e.name == j['label'], orElse: () => SkillLevel.beginner),
        isDeleted: j['isDeleted'] as bool? ?? false,
        updatedAt: DateTime.parse(j['updatedAt']),
      );

  Map<String, dynamic> _milestoneToJson(SubjectMilestoneRow m) => {
        'id': m.id,
        'subjectId': m.subjectId,
        'title': m.title,
        'isCompleted': m.isCompleted,
        'sortOrder': m.sortOrder,
        'completedAt': m.completedAt?.toUtc().toIso8601String(),
        'isDeleted': m.isDeleted,
        'updatedAt': m.updatedAt.toUtc().toIso8601String(),
      };

  SubjectMilestoneRow _milestoneFromJson(Map<String, dynamic> j) => SubjectMilestoneRow(
        id: j['id'],
        subjectId: j['subjectId'],
        title: j['title'],
        isCompleted: j['isCompleted'] ?? false,
        sortOrder: j['sortOrder'] ?? 0,
        completedAt: j['completedAt'] != null ? DateTime.parse(j['completedAt']) : null,
        isDeleted: j['isDeleted'] as bool? ?? false,
        updatedAt: DateTime.parse(j['updatedAt']),
      );

  Map<String, dynamic> _achievementToJson(AchievementRow r) => {
        'key': r.key,
        'unlockedAt': null,
        'progress': r.progress,
        'updatedAt': r.updatedAt.toUtc().toIso8601String(),
      };

  int _normalizeColorForSync(Object? value) {
    if (value == null) return 0;
    final v = value is num ? value.toInt() : (value is int ? value : 0);
    return v & 0xFFFFFF;
  }

  int _normalizeColorFromSync(Object? value) {
    if (value == null) return 0xFF000000;
    final v = value is num ? value.toInt() : (value is int ? value : 0);
    return (v & 0xFFFFFF) | 0xFF000000;
  }

  AchievementRow _achievementFromJson(Map<String, dynamic> j) => AchievementRow(
        key: j['key'],
        unlockedAt: j['unlockedAt'] != null ? DateTime.parse(j['unlockedAt']) : null,
        progress: (j['progress'] as num?)?.toDouble() ?? 0.0,
        updatedAt: DateTime.parse(j['updatedAt']),
      );

  UserStatsRow _statsFromJson(Map<String, dynamic> j) => UserStatsRow(
        id: 'default_stats',
        totalXp: j['totalXp'] ?? 0,
        currentLevel: j['currentLevel'] ?? 1,
        currentStreak: j['currentStreak'] ?? 0,
        longestStreak: j['longestStreak'] ?? 0,
        lastStudyDate: j['lastStudyDate'] != null ? DateTime.parse(j['lastStudyDate']) : null,
        totalStudyMinutes: j['totalStudyMinutes'] ?? 0,
        freezeTokens: j['freezeTokens'] ?? 0,
        updatedAt: DateTime.parse(j['updatedAt']),
      );
}
