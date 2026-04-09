import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/enums.dart';

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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TopicRow')
class Topics extends Table {
  TextColumn get id => text()();

  TextColumn get subjectId => text().references(Subjects, #id)();

  TextColumn get name => text()();

  IntColumn get order => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ChapterRow')
class Chapters extends Table {
  TextColumn get id => text()();

  TextColumn get topicId => text().references(Topics, #id)();

  TextColumn get name => text()();

  IntColumn get order => integer()();

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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AchievementRow')
class Achievements extends Table {
  TextColumn get key => text()();

  DateTimeColumn get unlockedAt => dateTime().nullable()();

  RealColumn get progress => real().withDefault(const Constant(0.0))();

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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PendingSyncOpRow')
class PendingSyncOps extends Table {
  TextColumn get id => text()();

  TextColumn get entity => text()();

  TextColumn get operation => text()();

  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

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
    PendingSyncOps,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'studytracker.sqlite');
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(pendingSyncOps);
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
      },
    );
  }
}
