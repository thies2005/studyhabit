import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../providers/database_provider.dart';
import 'export_service.dart';

part 'import_service.g.dart';

class ImportResult {
  const ImportResult({
    required this.projectCount,
    required this.subjectCount,
    required this.sessionCount,
    required this.sourceCount,
    required this.errors,
  });

  final int projectCount;
  final int subjectCount;
  final int sessionCount;
  final int sourceCount;
  final List<String> errors;

  Map<String, dynamic> toJson() {
    return {
      'projectCount': projectCount,
      'subjectCount': subjectCount,
      'sessionCount': sessionCount,
      'sourceCount': sourceCount,
      'errors': errors,
    };
  }

  ImportResult copyWith({
    int? projectCount,
    int? subjectCount,
    int? sessionCount,
    int? sourceCount,
    List<String>? errors,
  }) {
    return ImportResult(
      projectCount: projectCount ?? this.projectCount,
      subjectCount: subjectCount ?? this.subjectCount,
      sessionCount: sessionCount ?? this.sessionCount,
      sourceCount: sourceCount ?? this.sourceCount,
      errors: errors ?? this.errors,
    );
  }
}

@Riverpod(keepAlive: true)
ImportService importService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ImportService(db);
}

class ImportService {
  ImportService(this._db);

  final AppDatabase _db;

  Future<ImportResult> importFromJson(File file, ImportMode mode) async {
    final errors = <String>[];
    int projectCount = 0;
    int subjectCount = 0;
    int sessionCount = 0;
    int sourceCount = 0;

    try {
      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final version = json['exportVersion'] as int?;
      if (version != 1) {
        throw Exception('Unsupported export version: $version');
      }

      final document = ExportDocument.fromJson(json);

      await _db.transaction(() async {
        if (mode == ImportMode.replace) {
          await _clearAllData();
        }

        for (final exportProject in document.projects) {
          final project = exportProject.project;
          await _db.into(_db.projects).insertOnConflictUpdate(
            ProjectsCompanion(
              id: Value(project.id),
              name: Value(project.name),
              icon: Value(project.icon),
              colorValue: Value(project.colorValue),
              createdAt: Value(project.createdAt),
              lastOpenedAt: Value(project.lastOpenedAt),
              isArchived: Value(project.isArchived),
              defaultWorkDuration: Value(project.defaultWorkDuration),
              defaultBreakDuration: Value(project.defaultBreakDuration),
              defaultLongBreakDuration: Value(project.defaultLongBreakDuration),
              defaultLongBreakEvery: Value(project.defaultLongBreakEvery),
              studyReminderMinutes: Value(project.studyReminderMinutes),
            ),
          );
          projectCount++;

          for (final exportSubject in exportProject.subjects) {
            final subject = exportSubject.subject;
            await _db.into(_db.subjects).insertOnConflictUpdate(
              SubjectsCompanion(
                id: Value(subject.id),
                projectId: Value(subject.projectId),
                name: Value(subject.name),
                description: Value(subject.description),
                colorValue: Value(subject.colorValue),
                hierarchyMode: Value(subject.hierarchyMode),
                defaultDurationMinutes: Value(subject.defaultDurationMinutes),
                defaultBreakMinutes: Value(subject.defaultBreakMinutes),
                xpTotal: Value(subject.xpTotal),
                createdAt: Value(subject.createdAt),
                completenessMode: Value(subject.completenessMode),
                targetHours: Value(subject.targetHours),
                targetWeeklyHours: Value(subject.targetWeeklyHours),
              ),
            );
            subjectCount++;

            for (final topic in exportSubject.topics) {
              await _db.into(_db.topics).insertOnConflictUpdate(
                TopicsCompanion(
                  id: Value(topic.id),
                  subjectId: Value(topic.subjectId),
                  name: Value(topic.name),
                  order: Value(topic.order),
                ),
              );
            }

            for (final chapter in exportSubject.chapters) {
              await _db.into(_db.chapters).insertOnConflictUpdate(
                ChaptersCompanion(
                  id: Value(chapter.id),
                  topicId: Value(chapter.topicId),
                  name: Value(chapter.name),
                  order: Value(chapter.order),
                ),
              );
            }

            for (final session in exportSubject.sessions) {
              await _db.into(_db.studySessions).insertOnConflictUpdate(
                StudySessionsCompanion(
                  id: Value(session.id),
                  subjectId: Value(session.subjectId),
                  topicId: Value(session.topicId),
                  chapterId: Value(session.chapterId),
                  startedAt: Value(session.startedAt),
                  endedAt: Value(session.endedAt),
                  plannedDurationMinutes: Value(session.plannedDurationMinutes),
                  actualDurationMinutes: Value(session.actualDurationMinutes),
                  pomodorosCompleted: Value(session.pomodorosCompleted),
                  confidenceRating: Value(session.confidenceRating),
                  notes: Value(session.notes),
                  xpEarned: Value(session.xpEarned),
                  sourceId: Value(session.sourceId),
                  startPage: Value(session.startPage),
                  endPage: Value(session.endPage),
                  isFreeTimer: Value(session.isFreeTimer),
                ),
              );
              sessionCount++;
            }

            for (final source in exportSubject.sources) {
              await _db.into(_db.sources).insertOnConflictUpdate(
                SourcesCompanion(
                  id: Value(source.id),
                  subjectId: Value(source.subjectId),
                  topicId: Value(source.topicId),
                  chapterId: Value(source.chapterId),
                  type: Value(source.type),
                  title: Value(source.title),
                  filePath: Value(source.filePath),
                  url: Value(source.url),
                  currentPage: Value(source.currentPage),
                  totalPages: Value(source.totalPages),
                  progressPercent: Value(source.progressPercent),
                  notes: Value(source.notes),
                  addedAt: Value(source.addedAt),
                ),
              );
              sourceCount++;
            }

            for (final skillLabel in exportSubject.skillLabels) {
              await _db.into(_db.skillLabels).insertOnConflictUpdate(
                SkillLabelsCompanion(
                  id: Value(skillLabel.id),
                  subjectId: Value(skillLabel.subjectId),
                  topicId: Value(skillLabel.topicId),
                  chapterId: Value(skillLabel.chapterId),
                  label: Value(skillLabel.label),
                  updatedAt: Value(skillLabel.updatedAt),
                ),
              );
            }

            for (final milestone in exportSubject.milestones) {
              await _db.into(_db.subjectMilestones).insertOnConflictUpdate(
                SubjectMilestonesCompanion(
                  id: Value(milestone.id),
                  subjectId: Value(milestone.subjectId),
                  title: Value(milestone.title),
                  isCompleted: Value(milestone.isCompleted),
                  sortOrder: Value(milestone.sortOrder),
                  completedAt: Value(milestone.completedAt),
                ),
              );
            }
          }
        }

        for (final achievement in document.achievements) {
          await _db.into(_db.achievements).insertOnConflictUpdate(
            AchievementsCompanion(
              key: Value(achievement.key),
              unlockedAt: Value(achievement.unlockedAt),
              progress: Value(achievement.progress),
            ),
          );
        }

        await _db.into(_db.userStatsTable).insertOnConflictUpdate(
          UserStatsTableCompanion(
            id: const Value('default_stats'),
            totalXp: Value(document.userStats.totalXp),
            currentLevel: Value(document.userStats.currentLevel),
            currentStreak: Value(document.userStats.currentStreak),
            longestStreak: Value(document.userStats.longestStreak),
            lastStudyDate: Value(document.userStats.lastStudyDate),
            totalStudyMinutes: Value(document.userStats.totalStudyMinutes),
            freezeTokens: Value(document.userStats.freezeTokens),
          ),
        );
      });
    } catch (e, st) {
      debugPrint('Error importing data: $e');
      debugPrint(st.toString());
      errors.add(e.toString());
      projectCount = 0;
      subjectCount = 0;
      sessionCount = 0;
      sourceCount = 0;
    }

    return ImportResult(
      projectCount: projectCount,
      subjectCount: subjectCount,
      sessionCount: sessionCount,
      sourceCount: sourceCount,
      errors: errors,
    );
  }

  Future<void> _clearAllData() async {
    // Delete in FK order
    await _db.delete(_db.skillLabels).go();
    await _db.delete(_db.subjectMilestones).go();
    await _db.delete(_db.sources).go();
    await _db.delete(_db.studySessions).go();
    await _db.delete(_db.chapters).go();
    await _db.delete(_db.topics).go();
    await _db.delete(_db.subjects).go();
    await _db.delete(_db.projects).go();
    await _db.delete(_db.achievements).go();
    await _db.delete(_db.pendingSyncOps).go();
    await _db.delete(_db.userStatsTable).go();
  }
}
