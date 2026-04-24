import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'achievement.dart' as domain;
import 'chapter.dart' as domain;
import 'project.dart' as domain;
import 'skill_label.dart' as domain;
import 'source.dart' as domain;
import 'study_session.dart' as domain;
import 'subject.dart' as domain;
import 'subject_milestone.dart' as domain;
import 'topic.dart' as domain;
import 'user_stats.dart' as domain;

domain.Project mapProject(ProjectRow row) {
  return domain.Project(
    id: row.id,
    name: row.name,
    icon: row.icon,
    colorValue: row.colorValue,
    createdAt: row.createdAt,
    lastOpenedAt: row.lastOpenedAt,
    isArchived: row.isArchived,
    defaultWorkDuration: row.defaultWorkDuration,
    defaultBreakDuration: row.defaultBreakDuration,
    defaultLongBreakDuration: row.defaultLongBreakDuration,
    defaultLongBreakEvery: row.defaultLongBreakEvery,
    studyReminderMinutes: row.studyReminderMinutes,
  );
}

domain.Subject mapSubject(SubjectRow row) {
  return domain.Subject(
    id: row.id,
    projectId: row.projectId,
    name: row.name,
    description: row.description,
    colorValue: row.colorValue,
    hierarchyMode: row.hierarchyMode,
    defaultDurationMinutes: row.defaultDurationMinutes,
    defaultBreakMinutes: row.defaultBreakMinutes,
    xpTotal: row.xpTotal,
    createdAt: row.createdAt,
    completenessMode: row.completenessMode,
    targetHours: row.targetHours,
    targetWeeklyHours: row.targetWeeklyHours,
  );
}

domain.Topic mapTopic(TopicRow row) {
  return domain.Topic(
    id: row.id,
    subjectId: row.subjectId,
    name: row.name,
    order: row.order,
  );
}

domain.Chapter mapChapter(ChapterRow row) {
  return domain.Chapter(
    id: row.id,
    topicId: row.topicId,
    name: row.name,
    order: row.order,
  );
}

domain.StudySession mapStudySession(StudySessionRow row) {
  return domain.StudySession(
    id: row.id,
    subjectId: row.subjectId,
    topicId: row.topicId,
    chapterId: row.chapterId,
    startedAt: row.startedAt,
    endedAt: row.endedAt,
    plannedDurationMinutes: row.plannedDurationMinutes,
    actualDurationMinutes: row.actualDurationMinutes,
    pomodorosCompleted: row.pomodorosCompleted,
    confidenceRating: row.confidenceRating,
    notes: row.notes,
    xpEarned: row.xpEarned,
    sourceId: row.sourceId,
    startPage: row.startPage,
    endPage: row.endPage,
  );
}

domain.SkillLabel mapSkillLabel(SkillLabelRow row) {
  return domain.SkillLabel(
    id: row.id,
    subjectId: row.subjectId,
    topicId: row.topicId,
    chapterId: row.chapterId,
    label: row.label,
    updatedAt: row.updatedAt,
  );
}

domain.Source mapSource(SourceRow row) {
  return domain.Source(
    id: row.id,
    subjectId: row.subjectId,
    topicId: row.topicId,
    chapterId: row.chapterId,
    type: row.type,
    title: row.title,
    filePath: row.filePath,
    url: row.url,
    currentPage: row.currentPage,
    totalPages: row.totalPages,
    progressPercent: row.progressPercent,
    notes: row.notes,
    addedAt: row.addedAt,
  );
}

domain.Achievement mapAchievement(AchievementRow row) {
  return domain.Achievement(
    key: row.key,
    unlockedAt: row.unlockedAt,
    progress: row.progress,
  );
}

domain.UserStats mapUserStats(UserStatsRow? row) {
  if (row == null) {
    return const domain.UserStats(
      totalXp: 0,
      currentLevel: 1,
      currentStreak: 0,
      longestStreak: 0,
      lastStudyDate: null,
      totalStudyMinutes: 0,
      freezeTokens: 0,
    );
  }
  return domain.UserStats(
    totalXp: row.totalXp,
    currentLevel: row.currentLevel,
    currentStreak: row.currentStreak,
    longestStreak: row.longestStreak,
    lastStudyDate: row.lastStudyDate,
    totalStudyMinutes: row.totalStudyMinutes,
    freezeTokens: row.freezeTokens,
  );
}

UserStatsTableCompanion toUserStatsCompanion(domain.UserStats stats) {
  return UserStatsTableCompanion(
    id: const Value('default_stats'),
    totalXp: Value(stats.totalXp),
    currentLevel: Value(stats.currentLevel),
    currentStreak: Value(stats.currentStreak),
    longestStreak: Value(stats.longestStreak),
    lastStudyDate: Value(stats.lastStudyDate),
    totalStudyMinutes: Value(stats.totalStudyMinutes),
    freezeTokens: Value(stats.freezeTokens),
  );
}

domain.SubjectMilestone mapSubjectMilestone(SubjectMilestoneRow row) {
  return domain.SubjectMilestone(
    id: row.id,
    subjectId: row.subjectId,
    title: row.title,
    isCompleted: row.isCompleted,
    sortOrder: row.sortOrder,
    completedAt: row.completedAt,
  );
}
