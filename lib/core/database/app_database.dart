import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/enums.dart';
import '../services/app_logger.dart';

part 'app_database.g.dart';

class HierarchyModeConverter extends TypeConverter<HierarchyMode, String> {
  const HierarchyModeConverter();

  @override
  HierarchyMode fromSql(String fromDb) {
    return HierarchyMode.values.firstWhere(
      (value) => value.name == fromDb,
      orElse: () => HierarchyMode.flat,
    );
  }

  @override
  String toSql(HierarchyMode value) => value.name;
}

class SkillLevelConverter extends TypeConverter<SkillLevel, String> {
  const SkillLevelConverter();

  @override
  SkillLevel fromSql(String fromDb) {
    return SkillLevel.values.firstWhere(
      (value) => value.name == fromDb,
      orElse: () => SkillLevel.beginner,
    );
  }

  @override
  String toSql(SkillLevel value) => value.name;
}

class SourceTypeConverter extends TypeConverter<SourceType, String> {
  const SourceTypeConverter();

  @override
  SourceType fromSql(String fromDb) {
    return SourceType.values.firstWhere(
      (value) => value.name == fromDb,
      orElse: () => SourceType.pdf,
    );
  }

  @override
  String toSql(SourceType value) => value.name;
}

class CompletenessModeConverter extends TypeConverter<CompletenessMode, String> {
  const CompletenessModeConverter();

  @override
  CompletenessMode fromSql(String fromDb) {
    return CompletenessMode.values.firstWhere(
      (value) => value.name == fromDb,
      orElse: () => CompletenessMode.none,
    );
  }

  @override
  String toSql(CompletenessMode value) => value.name;
}

@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get icon => text()();

  IntColumn get colorValue => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastOpenedAt =>
      dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  IntColumn get defaultWorkDuration => integer().withDefault(const Constant(25))();

  IntColumn get defaultBreakDuration => integer().withDefault(const Constant(5))();

  IntColumn get defaultLongBreakDuration =>
      integer().withDefault(const Constant(15))();

  IntColumn get defaultLongBreakEvery => integer().withDefault(const Constant(4))();

  IntColumn get studyReminderMinutes => integer().withDefault(const Constant(30))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SubjectRow')
class Subjects extends Table {
  TextColumn get id => text()();

  TextColumn get projectId => text().references(Projects, #id)();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  IntColumn get colorValue => integer()();

  TextColumn get hierarchyMode => text()
      .map(const HierarchyModeConverter())
      .withDefault(const Constant('flat'))();

  IntColumn get defaultDurationMinutes =>
      integer().withDefault(const Constant(25))();

  IntColumn get defaultBreakMinutes =>
      integer().withDefault(const Constant(5))();

  IntColumn get xpTotal => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get completenessMode => text()
      .map(const CompletenessModeConverter())
      .withDefault(const Constant('none'))();

  IntColumn get targetHours => integer().nullable()();

  IntColumn get targetWeeklyHours => integer().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TopicRow')
class Topics extends Table {
  TextColumn get id => text()();

  TextColumn get subjectId => text().references(Subjects, #id)();

  TextColumn get name => text()();

  IntColumn get order => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ChapterRow')
class Chapters extends Table {
  TextColumn get id => text()();

  TextColumn get topicId => text().references(Topics, #id)();

  TextColumn get name => text()();

  IntColumn get order => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('StudySessionRow')
class StudySessions extends Table {
  TextColumn get id => text()();

  TextColumn get subjectId => text().references(Subjects, #id)();

  TextColumn get topicId => text().references(Topics, #id).nullable()();

  TextColumn get chapterId => text().references(Chapters, #id).nullable()();

  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get endedAt => dateTime().nullable()();

  IntColumn get plannedDurationMinutes => integer()();

  IntColumn get actualDurationMinutes =>
      integer().withDefault(const Constant(0))();

  IntColumn get pomodorosCompleted =>
      integer().withDefault(const Constant(0))();

  IntColumn get confidenceRating => integer().nullable()();

  TextColumn get notes => text().nullable()();

  IntColumn get xpEarned => integer().withDefault(const Constant(0))();

  TextColumn get sourceId => text().nullable()();

  IntColumn get startPage => integer().nullable()();

  IntColumn get endPage => integer().nullable()();

  BoolColumn get isFreeTimer => boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SkillLabelRow')
class SkillLabels extends Table {
  TextColumn get id => text()();

  TextColumn get subjectId => text().references(Subjects, #id)();

  TextColumn get topicId => text().references(Topics, #id).nullable()();

  TextColumn get chapterId => text().references(Chapters, #id).nullable()();

  TextColumn get label => text().map(const SkillLevelConverter())();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SourceRow')
class Sources extends Table {
  TextColumn get id => text()();

  TextColumn get subjectId => text().references(Subjects, #id)();

  TextColumn get topicId => text().references(Topics, #id).nullable()();

  TextColumn get chapterId => text().references(Chapters, #id).nullable()();

  TextColumn get type => text().map(const SourceTypeConverter())();

  TextColumn get title => text()();

  TextColumn get filePath => text().nullable()();

  TextColumn get url => text().nullable()();

  IntColumn get currentPage => integer().nullable()();

  IntColumn get totalPages => integer().nullable()();

  RealColumn get progressPercent => real().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AchievementRow')
class Achievements extends Table {
  TextColumn get key => text()();

  DateTimeColumn get unlockedAt => dateTime().nullable()();

  RealColumn get progress => real().withDefault(const Constant(0.0))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DataClassName('UserStatsRow')
class UserStatsTable extends Table {
  TextColumn get id => text().withDefault(const Constant('default_stats'))();

  IntColumn get totalXp => integer().withDefault(const Constant(0))();

  IntColumn get currentLevel => integer().withDefault(const Constant(1))();

  IntColumn get currentStreak => integer().withDefault(const Constant(0))();

  IntColumn get longestStreak => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastStudyDate => dateTime().nullable()();

  IntColumn get totalStudyMinutes => integer().withDefault(const Constant(0))();

  IntColumn get freezeTokens => integer().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}



@DataClassName('SubjectMilestoneRow')
class SubjectMilestones extends Table {
  TextColumn get id => text()();

  TextColumn get subjectId => text().references(Subjects, #id)();

  TextColumn get title => text()();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get completedAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Projects,
    Subjects,
    Topics,
    Chapters,
    StudySessions,
    SkillLabels,
    Sources,
    Achievements,
    UserStatsTable,
    SubjectMilestones,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Filename (without directory) used for the SQLite database on disk.
  /// drift_flutter appends `.sqlite` automatically, so we pass the bare stem
  /// to `driftDatabase(name: ...)` and reference this constant when checking
  /// for legacy files.
  static const String _kDatabaseFileName = 'studyhabit.sqlite';

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'studyhabit',
      native: const DriftNativeOptions(
        databaseDirectory: _resolveDatabaseDirectory,
      ),
    );
  }

  /// Resolves the directory used to store the SQLite database file.
  ///
  /// On mobile platforms (Android/iOS), [getApplicationDocumentsDirectory]
  /// works reliably. On desktop platforms (Linux/Windows/macOS), however,
  /// that directory may not exist, may be read-only (Snap/Flatpak sandboxes),
  /// or may be reported as `null` by the platform plugin (e.g. when
  /// `XDG_DOCUMENTS_DIR` is unset on Linux), which causes SQLite to fail with
  /// `SQLITE_CANTOPEN` (error 14).
  ///
  /// To fix that we:
  ///   1. Prefer [getApplicationSupportDirectory], which is the correct
  ///      location for app-owned data and is created automatically by the
  ///      platform plugin when missing.
  ///   2. Fall back to [getApplicationDocumentsDirectory] for older installs.
  ///   3. Always make sure the chosen directory exists before returning it.
  ///   4. Migrate any existing database file left by previous versions
  ///      (which wrote into the documents directory under a slightly different
  ///      name) into the resolved directory so existing users keep their data.
  static Future<Object> _resolveDatabaseDirectory() async {
    final candidates = <String>[];

    try {
      final support = await getApplicationSupportDirectory();
      candidates.add(support.path);
    } catch (e) {
      AppLogger.w(
        'AppDatabase',
        'getApplicationSupportDirectory unavailable: $e',
      );
    }

    try {
      final docs = await getApplicationDocumentsDirectory();
      candidates.add(docs.path);
    } catch (e) {
      AppLogger.w(
        'AppDatabase',
        'getApplicationDocumentsDirectory unavailable: $e',
      );
    }

    if (candidates.isEmpty) {
      // Should be unreachable because path_provider always returns a value
      // on supported platforms, but bail out early instead of crashing.
      throw StateError(
        'No writable database directory could be resolved for this platform. '
        'Ensure path_provider is configured for the current target.',
      );
    }

    for (final candidate in candidates) {
      if (await _ensureUsableDirectory(candidate)) {
        await _migrateLegacyDatabase(candidate);
        return candidate;
      }
    }

    // Every candidate was unwritable — surface a clear error rather than
    // letting drift report a cryptic SQLITE_CANTOPEN further down the line.
    throw StateError(
      'No writable database directory could be opened. Tried: ${candidates.join(", ")}',
    );
  }

  /// Moves any existing database file from previous install locations into
  /// [targetDirectory]. All of these legacy layouts are handled:
  ///
  ///   - `<documents>/studyhabit.sqlite.sqlite`
  ///     (caused by the previous `name: 'studyhabit.sqlite'` argument;
  ///     drift_flutter appends another `.sqlite`)
  ///   - `<documents>/studyhabit.sqlite`
  ///     (bare file produced when only the directory was different)
  ///   - `<documents>/studytracker.sqlite.sqlite` and `studytracker.sqlite`
  ///     (the original app name before the StudyHabit rename)
  ///
  /// If a database already exists at the target location, legacy files are
  /// left untouched so we never overwrite newer data.
  ///
  /// [legacyDirectoryProvider] is exposed for tests so they can inject a fake
  /// documents directory. In production it defaults to
  /// [getApplicationDocumentsDirectory].
  static Future<void> _migrateLegacyDatabase(
    String targetDirectory, {
    Future<Directory> Function()? legacyDirectoryProvider,
  }) async {
    try {
      final targetFile = File(p.join(targetDirectory, _kDatabaseFileName));
      if (targetFile.existsSync()) {
        return; // Nothing to do; current location already populated.
      }

      final lookup = legacyDirectoryProvider ?? getApplicationDocumentsDirectory;
      Directory legacyDir;
      try {
        legacyDir = await lookup();
      } catch (_) {
        return;
      }

      // Order matters: prefer the most recent name first so we don't pick up
      // an abandoned studytracker file from before the rename if a more recent
      // studyhabit file exists.
      final legacyCandidates = <File>[
        File(p.join(legacyDir.path, 'studyhabit.sqlite.sqlite')),
        File(p.join(legacyDir.path, 'studyhabit.sqlite')),
        File(p.join(legacyDir.path, 'studytracker.sqlite.sqlite')),
        File(p.join(legacyDir.path, 'studytracker.sqlite')),
      ];

      for (final legacy in legacyCandidates) {
        if (legacy.existsSync()) {
          AppLogger.i(
            'AppDatabase',
            'Migrating legacy database from ${legacy.path} to ${targetFile.path}',
          );
          // Try a fast rename first; fall back to copy+delete across volumes.
          try {
            await legacy.rename(targetFile.path);
          } catch (_) {
            await legacy.copy(targetFile.path);
            try {
              await legacy.delete();
            } catch (_) {
              // Non-fatal: we've already copied the data.
            }
          }
          return;
        }
      }
    } catch (e) {
      AppLogger.w('AppDatabase', 'Legacy database migration failed: $e');
    }
  }

  /// Verifies that [path] is a directory we can write into, creating it if
  /// necessary. Returns `false` if the directory cannot be created or written.
  static Future<bool> _ensureUsableDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      // Probe write permissions with a short-lived temp file.
      final probe = File(p.join(path, '.drift_probe'));
      await probe.writeAsString('ok', flush: true);
      try {
        await probe.delete();
      } catch (_) {
        // Non-fatal: the probe was created, so we have write access.
      }
      return true;
    } catch (e) {
      AppLogger.w('AppDatabase', 'Directory "$path" is not usable: $e');
      return false;
    }
  }

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Previously created pendingSyncOps, now removed
        }
        if (from < 3) {
          await m.addColumn(studySessions, studySessions.sourceId);
          await m.addColumn(studySessions, studySessions.startPage);
          await m.addColumn(studySessions, studySessions.endPage);
        }
        if (from < 4) {
          await m.addColumn(projects, projects.defaultWorkDuration);
          await m.addColumn(projects, projects.defaultBreakDuration);
          await m.addColumn(projects, projects.defaultLongBreakDuration);
          await m.addColumn(projects, projects.defaultLongBreakEvery);
          await m.addColumn(projects, projects.studyReminderMinutes);
        }
        if (from < 5) {
          await m.addColumn(studySessions, studySessions.isFreeTimer);
        }
        if (from < 6) {
          await m.addColumn(subjects, subjects.completenessMode);
          await m.addColumn(subjects, subjects.targetHours);
          await m.createTable(subjectMilestones);
        }
        if (from < 7) {
          await m.addColumn(subjects, subjects.targetWeeklyHours);
        }
        if (from < 8) {
          await m.addColumn(projects, projects.updatedAt);
          await m.addColumn(subjects, subjects.updatedAt);
          await m.addColumn(topics, topics.updatedAt);
          await m.addColumn(chapters, chapters.updatedAt);
          await m.addColumn(studySessions, studySessions.updatedAt);
          await m.addColumn(sources, sources.updatedAt);
          await m.addColumn(achievements, achievements.updatedAt);
          await m.addColumn(userStatsTable, userStatsTable.updatedAt);
          await m.addColumn(subjectMilestones, subjectMilestones.updatedAt);
        }
        if (from < 9) {
          await m.addColumn(projects, projects.isDeleted);
          await m.addColumn(subjects, subjects.isDeleted);
          await m.addColumn(topics, topics.isDeleted);
          await m.addColumn(chapters, chapters.isDeleted);
          await m.addColumn(studySessions, studySessions.isDeleted);
          await m.addColumn(skillLabels, skillLabels.isDeleted);
          await m.addColumn(sources, sources.isDeleted);
          await m.addColumn(subjectMilestones, subjectMilestones.isDeleted);
        }
        if (from < 10) {
          // S2 fix: Add createdAt to Topics and Chapters for sync
          await m.addColumn(topics, topics.createdAt);
          await m.addColumn(chapters, chapters.createdAt);
        }
      },
    );
  }
}
