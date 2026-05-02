import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';
import { XpService } from '../services/xpService.js';

const router = Router();

const daysQuerySchema = z.object({
  days: z.coerce.number().int().min(1).max(365).default(84),
});

router.get('/overview', async (req, res, next) => {
  try {
    const userStats = await prisma.userStats.findUnique({
      where: { userId: req.user.userId },
    });

    if (!userStats) {
      return res.status(404).json({ error: 'User stats not found' });
    }

    const totalHours = userStats.totalStudyMinutes / 60;
    const levelName = XpService.levelName(userStats.currentLevel);

    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);

    const weekSessions = await prisma.studySession.findMany({
      where: {
        subject: { project: { userId: req.user.userId } },
        startedAt: { gte: oneWeekAgo },
      },
    });

    const weekMinutes = weekSessions.reduce(
      (sum: number, s: any) => sum + s.actualDurationMinutes,
      0
    );

    res.json({
      data: {
        totalHours,
        weekHours: weekMinutes / 60,
        currentStreak: userStats.currentStreak,
        totalXp: userStats.totalXp,
        currentLevel: userStats.currentLevel,
        levelName,
      },
    });
  } catch (error: any) {
    next(error);
  }
});

router.get('/heatmap', async (req, res, next) => {
  try {
    const { days } = daysQuerySchema.parse(req.query);
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const sessions = await prisma.studySession.findMany({
      where: {
        subject: { project: { userId: req.user.userId } },
        startedAt: { gte: startDate },
      },
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
  } catch (error: any) {
    next(error);
  }
});

router.get('/subjects', async (req, res, next) => {
  try {
    const { days } = daysQuerySchema.parse({ days: req.query.days || 30 });
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const sessions = await prisma.studySession.findMany({
      where: {
        subject: { project: { userId: req.user.userId } },
        startedAt: { gte: startDate },
      },
      include: { subject: true },
    });

    const subjectMap = new Map();

    for (const session of sessions) {
      const subjectId = session.subjectId;
      if (!subjectMap.has(subjectId)) {
        subjectMap.set(subjectId, {
          subject: session.subject,
          totalMinutes: 0,
          sessionCount: 0,
          confidenceSum: 0,
          confidenceCount: 0,
        });
      }

      const data = subjectMap.get(subjectId);
      data.totalMinutes += session.actualDurationMinutes;
      data.sessionCount += 1;
      if (session.confidenceRating) {
        data.confidenceSum += session.confidenceRating;
        data.confidenceCount += 1;
      }
    }

    const breakdown = Array.from(subjectMap.values()).map((d: any) => ({
      subject: d.subject,
      totalHours: d.totalMinutes / 60,
      sessionCount: d.sessionCount,
      avgConfidence: d.confidenceCount
        ? d.confidenceSum / d.confidenceCount
        : null,
    }));

    res.json({ data: breakdown });
  } catch (error: any) {
    next(error);
  }
});

export default router;
