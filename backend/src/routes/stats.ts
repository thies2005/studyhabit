import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../db.js';
import { XpService } from '../services/xpService.js';

const router = Router();

const daysQuerySchema = z.object({
  days: z.coerce.number().int().min(1).max(365).default(84),
  projectId: z.string().uuid().optional(),
});

const statsQuerySchema = z.object({
  projectId: z.string().uuid().optional(),
});

async function verifyProjectOwnership(userId: string, projectId?: string): Promise<boolean> {
  if (!projectId) return true;
  const project = await prisma.project.findFirst({
    where: { id: projectId, userId, isDeleted: false },
  });
  return !!project;
}

router.get('/overview', async (req, res, next) => {
  try {
    const { projectId } = statsQuerySchema.parse(req.query);
    if (projectId) {
      const owned = await verifyProjectOwnership(req.user.userId, projectId);
      if (!owned) {
        return res.status(404).json({ error: 'Project not found' });
      }
    }

    const userStats = await prisma.userStats.findUnique({
      where: { userId: req.user.userId },
    });

    if (!userStats) {
      return res.status(404).json({ error: 'User stats not found' });
    }

    const totalHours = Number((userStats.totalStudyMinutes / 60).toFixed(1));
    const levelName = XpService.levelName(userStats.currentLevel);

    const subjectFilter = {
      isDeleted: false,
      project: {
        userId: req.user.userId,
        isDeleted: false,
        ...(projectId ? { id: projectId } : {}),
      },
    };

    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);

    const [todaySessions, weekSessions] = await Promise.all([
      prisma.studySession.findMany({
        where: {
          isDeleted: false,
          startedAt: { gte: startOfToday },
          subject: subjectFilter,
        },
        select: { actualDurationMinutes: true },
      }),
      prisma.studySession.findMany({
        where: {
          isDeleted: false,
          startedAt: { gte: oneWeekAgo },
          subject: subjectFilter,
        },
        select: { actualDurationMinutes: true },
      }),
    ]);

    const todayMinutes = todaySessions.reduce((sum, s) => sum + s.actualDurationMinutes, 0);
    const weekMinutes = weekSessions.reduce((sum, s) => sum + s.actualDurationMinutes, 0);

    res.json({
      data: {
        totalHours,
        todayHours: Number((todayMinutes / 60).toFixed(1)),
        weekHours: Number((weekMinutes / 60).toFixed(1)),
        currentStreak: userStats.currentStreak,
        totalXp: userStats.totalXp,
        currentLevel: userStats.currentLevel,
        levelName,
        longestStreak: userStats.longestStreak,
        freezeTokens: userStats.freezeTokens,
      },
    });
  } catch (error: unknown) {
    next(error);
  }
});

router.get('/heatmap', async (req, res, next) => {
  try {
    const { days, projectId } = daysQuerySchema.parse(req.query);
    if (projectId) {
      const owned = await verifyProjectOwnership(req.user.userId, projectId);
      if (!owned) {
        return res.status(404).json({ error: 'Project not found' });
      }
    }

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const sessions = await prisma.studySession.findMany({
      where: {
        isDeleted: false,
        startedAt: { gte: startDate },
        subject: {
          isDeleted: false,
          project: {
            userId: req.user.userId,
            isDeleted: false,
            ...(projectId ? { id: projectId } : {}),
          },
        },
      },
      select: { startedAt: true, actualDurationMinutes: true },
    });

    const grouped = new Map<string, number>();
    for (const s of sessions) {
      const dateKey = s.startedAt.toISOString().split('T')[0];
      grouped.set(dateKey, (grouped.get(dateKey) ?? 0) + s.actualDurationMinutes);
    }

    const heatmapData = Array.from(grouped.entries()).map(([date, minutes]) => ({
      date,
      minutes,
    }));

    res.json({ data: heatmapData });
  } catch (error: unknown) {
    next(error);
  }
});

router.get('/subjects', async (req, res, next) => {
  try {
    const { days, projectId } = daysQuerySchema.parse({
      days: req.query.days || 30,
      projectId: req.query.projectId,
    });
    if (projectId) {
      const owned = await verifyProjectOwnership(req.user.userId, projectId);
      if (!owned) {
        return res.status(404).json({ error: 'Project not found' });
      }
    }

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const [sessions, userSubjects] = await Promise.all([
      prisma.studySession.findMany({
        where: {
          isDeleted: false,
          startedAt: { gte: startDate },
          subject: {
            isDeleted: false,
            project: {
              userId: req.user.userId,
              isDeleted: false,
              ...(projectId ? { id: projectId } : {}),
            },
          },
        },
        include: { subject: true },
      }),
      prisma.subject.findMany({
        where: {
          isDeleted: false,
          project: {
            userId: req.user.userId,
            isDeleted: false,
            ...(projectId ? { id: projectId } : {}),
          },
        },
        include: {
          skillLabels: {
            where: {
              isDeleted: false,
              topicId: null,
              chapterId: null,
            },
            orderBy: { updatedAt: 'desc' },
            take: 1,
          },
        },
      }),
    ]);

    const subjectMap = new Map<string, {
      subject: any;
      totalMinutes: number;
      sessionCount: number;
      confidenceSum: number;
      confidenceCount: number;
      skillLevel: string;
    }>();

    for (const sub of userSubjects) {
      subjectMap.set(sub.id, {
        subject: sub,
        totalMinutes: 0,
        sessionCount: 0,
        confidenceSum: 0,
        confidenceCount: 0,
        skillLevel: sub.skillLabels[0]?.label ?? 'beginner',
      });
    }

    for (const session of sessions) {
      const subjectId = session.subjectId;
      if (!subjectMap.has(subjectId)) {
        subjectMap.set(subjectId, {
          subject: session.subject,
          totalMinutes: 0,
          sessionCount: 0,
          confidenceSum: 0,
          confidenceCount: 0,
          skillLevel: 'beginner',
        });
      }

      const data = subjectMap.get(subjectId)!;
      data.totalMinutes += session.actualDurationMinutes;
      data.sessionCount += 1;
      if (session.confidenceRating) {
        data.confidenceSum += session.confidenceRating;
        data.confidenceCount += 1;
      }
    }

    const breakdown = Array.from(subjectMap.values())
      .filter((d) => d.totalMinutes > 0 || !projectId)
      .map((d) => ({
        subject: d.subject,
        totalHours: Number((d.totalMinutes / 60).toFixed(1)),
        sessionCount: d.sessionCount,
        avgConfidence: d.confidenceCount
          ? Number((d.confidenceSum / d.confidenceCount).toFixed(1))
          : null,
        skillLevel: d.skillLevel,
      }));

    res.json({ data: breakdown });
  } catch (error: unknown) {
    next(error);
  }
});

router.get('/xp-history', async (req, res, next) => {
  try {
    const { days, projectId } = daysQuerySchema.parse({
      days: req.query.days || 30,
      projectId: req.query.projectId,
    });
    if (projectId) {
      const owned = await verifyProjectOwnership(req.user.userId, projectId);
      if (!owned) {
        return res.status(404).json({ error: 'Project not found' });
      }
    }

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const sessions = await prisma.studySession.findMany({
      where: {
        isDeleted: false,
        startedAt: { gte: startDate },
        subject: {
          isDeleted: false,
          project: {
            userId: req.user.userId,
            isDeleted: false,
            ...(projectId ? { id: projectId } : {}),
          },
        },
      },
      orderBy: { startedAt: 'asc' },
      select: { startedAt: true, xpEarned: true },
    });

    const dailyXp = new Map<string, number>();
    for (const s of sessions) {
      const day = s.startedAt.toISOString().split('T')[0];
      dailyXp.set(day, (dailyXp.get(day) ?? 0) + s.xpEarned);
    }

    let cumulativeXp = 0;
    const points: Array<{ date: string; dailyXp: number; cumulativeXp: number }> = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const dateKey = d.toISOString().split('T')[0];
      const gained = dailyXp.get(dateKey) ?? 0;
      cumulativeXp += gained;
      points.push({ date: dateKey, dailyXp: gained, cumulativeXp });
    }

    res.json({ data: points });
  } catch (error: unknown) {
    next(error);
  }
});

export default router;
