import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../models/achievement.dart';
import '../models/chapter.dart';
import '../models/model_mapper.dart';
import '../models/project.dart';
import '../models/skill_label.dart';
import '../models/source.dart';
import '../models/study_session.dart' as session;
import '../models/subject.dart';
import '../models/topic.dart';
import '../models/user_stats.dart';

class ExportDocument {
  const ExportDocument({
    required this.exportVersion,
    required this.exportedAt,
    required this.userStats,
    required this.projects,
    required this.achievements,
  });

  final int exportVersion;
  final String exportedAt;
  final UserStats userStats;
  final List<ExportProject> projects;
  final List<Achievement> achievements;

  Map<String, dynamic> toJson() {
    return {
      'exportVersion': exportVersion,
      'exportedAt': exportedAt,
      'userStats': userStats.toJson(),
      'projects': projects.map((p) => p.toJson()).toList(),
      'achievements': achievements.map((a) => a.toJson()).toList(),
    };
  }

  factory ExportDocument.fromJson(Map<String, dynamic> json) {
    return ExportDocument(
      exportVersion: json['exportVersion'] as int,
      exportedAt: json['exportedAt'] as String,
      userStats: UserStats.fromJson(json['userStats'] as Map<String, dynamic>),
      projects: (json['projects'] as List)
          .map((p) => ExportProject.fromJson(p as Map<String, dynamic>))
          .toList(),
      achievements: (json['achievements'] as List)
          .map((a) => Achievement.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExportProject {
  const ExportProject({required this.project, required this.subjects});

  final Project project;
  final List<ExportSubject> subjects;

  Map<String, dynamic> toJson() {
    return {
      'project': project.toJson(),
      'subjects': subjects.map((s) => s.toJson()).toList(),
    };
  }

  factory ExportProject.fromJson(Map<String, dynamic> json) {
    return ExportProject(
      project: Project.fromJson(json['project'] as Map<String, dynamic>),
      subjects: (json['subjects'] as List)
          .map((s) => ExportSubject.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExportSubject {
  const ExportSubject({
    required this.subject,
    required this.topics,
    required this.chapters,
    required this.sessions,
    required this.sources,
    required this.skillLabels,
  });

  final Subject subject;
  final List<Topic> topics;
  final List<Chapter> chapters;
  final List<session.StudySession> sessions;
  final List<Source> sources;
  final List<SkillLabel> skillLabels;

  Map<String, dynamic> toJson() {
    return {
      'subject': subject.toJson(),
      'topics': topics.map((t) => t.toJson()).toList(),
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'sources': sources.map((s) => s.toJson()).toList(),
      'skillLabels': skillLabels.map((l) => l.toJson()).toList(),
    };
  }

  factory ExportSubject.fromJson(Map<String, dynamic> json) {
    return ExportSubject(
      subject: Subject.fromJson(json['subject'] as Map<String, dynamic>),
      topics: (json['topics'] as List)
          .map((t) => Topic.fromJson(t as Map<String, dynamic>))
          .toList(),
      chapters: (json['chapters'] as List)
          .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
          .toList(),
      sessions: (json['sessions'] as List)
          .map((s) => session.StudySession.fromJson(s as Map<String, dynamic>))
          .toList(),
      sources: (json['sources'] as List)
          .map((s) => Source.fromJson(s as Map<String, dynamic>))
          .toList(),
      skillLabels: (json['skillLabels'] as List)
          .map((l) => SkillLabel.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExportService {
  ExportService(this._db);

  final AppDatabase _db;

  Future<File> exportToJson() async {
    try {
      // Query all data
      final projectRows = _db.select(_db.projects)
        ..where((t) => t.isArchived.equals(false));

      final projects = await projectRows.get();
      final subjectRows = await _db.select(_db.subjects).get();
      final topicRows = await _db.select(_db.topics).get();
      final chapterRows = await _db.select(_db.chapters).get();
      final sessionRows = await _db.select(_db.studySessions).get();
      final sourceRows = await _db.select(_db.sources).get();
      final skillLabelRows = await _db.select(_db.skillLabels).get();
      final achievementRows = await _db.select(_db.achievements).get();
      final statsRow = await _db.select(_db.userStatsTable).getSingleOrNull();

      // Map to domain models
      final projectModels = projects.map((row) => mapProject(row)).toList();
      final subjectModels = subjectRows.map((row) => mapSubject(row)).toList();
      final topicModels = topicRows.map((row) => mapTopic(row)).toList();
      final chapterModels = chapterRows.map((row) => mapChapter(row)).toList();
      final sessionModels = sessionRows
          .map((row) => mapStudySession(row))
          .toList();
      final sourceModels = sourceRows.map((row) => mapSource(row)).toList();
      final skillLabelModels = skillLabelRows
          .map((row) => mapSkillLabel(row))
          .toList();
      final achievementModels = achievementRows
          .map((row) => mapAchievement(row))
          .toList();
      final userStats = mapUserStats(statsRow);

      // Build export structure
      final exportProjects = <ExportProject>[];
      for (final project in projectModels) {
        final projectSubjects = subjectModels
            .where((s) => s.projectId == project.id)
            .toList();

        final exportSubjects = <ExportSubject>[];
        for (final subject in projectSubjects) {
          final subjectTopics = topicModels
              .where((t) => t.subjectId == subject.id)
              .toList();
          final subjectChapters = chapterModels
              .where((c) => subjectTopics.any((t) => t.id == c.topicId))
              .toList();
          final subjectSessions = sessionModels
              .where((s) => s.subjectId == subject.id)
              .toList();
          final subjectSources = sourceModels
              .where((s) => s.subjectId == subject.id)
              .toList();
          final subjectSkillLabels = skillLabelModels
              .where((l) => l.subjectId == subject.id)
              .toList();

          exportSubjects.add(
            ExportSubject(
              subject: subject,
              topics: subjectTopics,
              chapters: subjectChapters,
              sessions: subjectSessions,
              sources: subjectSources,
              skillLabels: subjectSkillLabels,
            ),
          );
        }

        exportProjects.add(
          ExportProject(project: project, subjects: exportSubjects),
        );
      }

      final document = ExportDocument(
        exportVersion: 1,
        exportedAt: DateTime.now().toIso8601String(),
        userStats: userStats,
        projects: exportProjects,
        achievements: achievementModels,
      );

      // Write to file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final filePath = '${tempDir.path}/studytracker_$timestamp.json';

      final file = File(filePath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(document.toJson()),
      );

      return file;
    } catch (e) {
      debugPrint('Error exporting data: $e');
      rethrow;
    }
  }
}
