import { Router } from 'express';
import { prisma } from '../db.js';

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const userId = req.user.userId;

    const [
      userStats,
      projects,
      subjects,
      topics,
      chapters,
      sessions,
      sources,
      skillLabels,
      milestones,
      achievements,
      settingsRow
    ] = await Promise.all([
      prisma.userStats.findUnique({ where: { userId } }),
      prisma.project.findMany({ where: { userId } }),
      prisma.subject.findMany({ where: { project: { userId } } }),
      prisma.topic.findMany({ where: { subject: { project: { userId } } } }),
      prisma.chapter.findMany({ where: { topic: { subject: { project: { userId } } } } }),
      prisma.studySession.findMany({ where: { subject: { project: { userId } } } }),
      prisma.source.findMany({ where: { subject: { project: { userId } } } }),
      prisma.skillLabel.findMany({ where: { subject: { project: { userId } } } }),
      prisma.subjectMilestone.findMany({ where: { subject: { project: { userId } } } }),
      prisma.achievement.findMany({ where: { userId } }),
      prisma.userSettings.findUnique({ where: { userId } }),
    ]);

    const exportProjects = projects.map(project => {
      const projectSubjects = subjects.filter(s => s.projectId === project.id).map(subject => {
        const subjectTopics = topics.filter(t => t.subjectId === subject.id);
        const subjectChapters = chapters.filter(c => subjectTopics.some(t => t.id === c.topicId));
        const subjectSessions = sessions.filter(s => s.subjectId === subject.id);
        const subjectSources = sources.filter(s => s.subjectId === subject.id);
        const subjectSkillLabels = skillLabels.filter(s => s.subjectId === subject.id);
        const subjectMilestones = milestones.filter(s => s.subjectId === subject.id);

        return {
          subject,
          topics: subjectTopics,
          chapters: subjectChapters,
          sessions: subjectSessions,
          sources: subjectSources,
          skillLabels: subjectSkillLabels,
          milestones: subjectMilestones,
        };
      });

      return {
        project,
        subjects: projectSubjects,
      };
    });

    const exportDoc = {
      exportVersion: 2,
      exportedAt: new Date().toISOString(),
      userStats: userStats || {
        id: 'default_stats',
        userId,
        totalXp: 0,
        currentLevel: 1,
        currentStreak: 0,
        longestStreak: 0,
        lastStudyDate: null,
        totalStudyMinutes: 0,
        freezeTokens: 0,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      projects: exportProjects,
      achievements,
      settings: settingsRow?.settings || null,
    };

    res.json(exportDoc);
  } catch (error) {
    next(error);
  }
});

export default router;
