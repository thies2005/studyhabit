import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';
import { XpService } from '../services/xpService.js';

const router = Router();

// Get overview stats
router.get('/overview', async (req: any, res: any) => {
  try {
    const userStats = await prisma.userStats.findUnique({
      where: { userId: req.user.userId },
    });

    if (!userStats) {
      return res.status(404).json({ error: 'User stats not found' });
    }

    const totalHours = userStats.totalStudyMinutes / 60;
    const levelName = XpService.levelName(userStats.currentLevel);

    // Get this week's study minutes
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
    const weekHours = weekMinutes / 60;

    res.json({
      data: {
        totalHours,
        weekHours,
        currentStreak: userStats.currentStreak,
        totalXp: userStats.totalXp,
        currentLevel: userStats.currentLevel,
        levelName,
      },
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Get heatmap data
router.get('/heatmap', async (req: any, res: any) => {
  try {
    const days = parseInt(req.query.days as string) || 84;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const sessions = await prisma.studySession.findMany({
      where: {
        subject: { project: { userId: req.user.userId } },
        startedAt: { gte: startDate },
      },
    });

    // Group by date
    const heatmapData = sessions.map((s: any) => ({
      date: s.startedAt,
      minutes: s.actualDurationMinutes,
    }));

    res.json({ data: heatmapData });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Get subject breakdown
router.get('/subjects', async (req: any, res: any) => {
  try {
    const days = parseInt(req.query.days as string) || 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const sessions = await prisma.studySession.findMany({
      where: {
        subject: { project: { userId: req.user.userId } },
        startedAt: { gte: startDate },
      },
      include: { subject: true },
    });

    // Aggregate by subject
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

    const breakdown = Array.from(subjectMap.values()).map((d) => ({
      subject: d.subject,
      totalHours: d.totalMinutes / 60,
      sessionCount: d.sessionCount,
      avgConfidence: d.confidenceCount
        ? d.confidenceSum / d.confidenceCount
        : null,
    }));

    res.json({ data: breakdown });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
