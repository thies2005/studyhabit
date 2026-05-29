import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../db.js';
import { XpService } from '../services/xpService.js';
import { AchievementService } from '../services/achievementService.js';
import { parsePagination } from '../types/index.js';

const router = Router();

const sessionSchema = z.object({
  subjectId: z.string().uuid(),
  topicId: z.string().uuid().optional(),
  chapterId: z.string().uuid().optional(),
  startedAt: z.string().datetime().optional(),
  endedAt: z.string().datetime().optional(),
  plannedDurationMinutes: z.number().int().min(5),
  actualDurationMinutes: z.number().int().min(0),
  pomodorosCompleted: z.number().int().min(0),
  confidenceRating: z.number().int().min(1).max(5).optional(),
  notes: z.string().optional(),
});

const updateSessionSchema = z.object({
  topicId: z.string().uuid().optional(),
  chapterId: z.string().uuid().optional(),
  startedAt: z.string().datetime().optional(),
  endedAt: z.string().datetime().optional(),
  plannedDurationMinutes: z.number().int().min(5).optional(),
  actualDurationMinutes: z.number().int().min(0).optional(),
  pomodorosCompleted: z.number().int().min(0).optional(),
  confidenceRating: z.number().int().min(1).max(5).optional(),
  notes: z.string().optional(),
});

router.get('/', async (req, res, next) => {
  try {
    const subjectId = req.query.subjectId ? String(req.query.subjectId) : undefined;
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where: any = {
      subject: { project: { userId: req.user.userId } },
    };
    if (subjectId) {
      where.subjectId = subjectId;
    }
    
    const [sessions, total] = await Promise.all([
      prisma.studySession.findMany({
        where,
        orderBy: { startedAt: 'desc' },
        skip,
        take,
        include: {
          subject: {
            select: {
              id: true,
              name: true,
              colorValue: true,
            },
          },
        },
      }),
      prisma.studySession.count({ where }),
    ]);
    res.json({
      data: sessions,
      pagination: { page, limit, total, hasMore: skip + take < total },
    });
  } catch (error: unknown) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const session = await prisma.studySession.findFirst({
      where: { id, subject: { project: { userId: req.user.userId } } },
      include: {
        subject: {
          select: {
            id: true,
            name: true,
            colorValue: true,
          },
        },
      },
    });
    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }
    res.json({ data: session });
  } catch (error: unknown) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const data = sessionSchema.parse(req.body);

    const subject = await prisma.subject.findFirst({
      where: { id: data.subjectId, project: { userId: req.user.userId } },
    });

    if (!subject) {
      return res.status(404).json({ error: 'Subject not found' });
    }

    const xpEarned = XpService.xpForSession(
      data.actualDurationMinutes,
      data.pomodorosCompleted,
      data.confidenceRating
    );

    const session = await prisma.studySession.create({
      data: {
        subjectId: data.subjectId,
        topicId: data.topicId,
        chapterId: data.chapterId,
        startedAt: data.startedAt ? new Date(data.startedAt) : new Date(),
        endedAt: data.endedAt ? new Date(data.endedAt) : null,
        plannedDurationMinutes: data.plannedDurationMinutes,
        actualDurationMinutes: data.actualDurationMinutes,
        pomodorosCompleted: data.pomodorosCompleted,
        confidenceRating: data.confidenceRating,
        notes: data.notes,
        xpEarned,
      },
    });

    await prisma.subject.update({
      where: { id: data.subjectId },
      data: { xpTotal: { increment: xpEarned } },
    });

    await XpService.addXpAndMinutes(
      req.user.userId,
      xpEarned,
      data.actualDurationMinutes
    );

    // Update streak if this is a new study day
    const userStats = await prisma.userStats.findUnique({
      where: { userId: req.user.userId },
    });
    if (userStats) {
      const sessionDate = new Date(session.startedAt);
      const lastStudyDate = userStats.lastStudyDate ? new Date(userStats.lastStudyDate) : null;
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      sessionDate.setHours(0, 0, 0, 0);
      const isNewStudyDay = !lastStudyDate ||
        lastStudyDate.getTime() !== sessionDate.getTime();
      
      if (isNewStudyDay) {
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        const isConsecutive = lastStudyDate &&
          lastStudyDate.getTime() >= yesterday.getTime();

        const oldStreak = userStats.currentStreak;
        const newStreak = isConsecutive ? oldStreak + 1 : 1;
        const longestStreak = Math.max(newStreak, userStats.longestStreak);

        // Award XP only for milestones that were just crossed
        // (old < threshold AND new >= threshold)
        const streakXp = XpService.xpForStreakMilestones(oldStreak, newStreak);
        if (streakXp > 0) {
          await XpService.addXpAndMinutes(req.user.userId, streakXp, 0);
        }

        await prisma.userStats.update({
          where: { userId: req.user.userId },
          data: {
            currentStreak: newStreak,
            longestStreak,
            lastStudyDate: sessionDate,
          },
        });
      }
    }

    const newAchievements = await AchievementService.checkAndUnlock(req.user.userId);

    res.status(201).json({ data: { ...session, newAchievements } });
  } catch (error: unknown) {
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const data = updateSessionSchema.parse(req.body);

    const existing = await prisma.studySession.findFirst({
      where: { id, subject: { project: { userId: req.user.userId } } },
    });

    if (!existing) {
      return res.status(404).json({ error: 'Session not found' });
    }

    // Destructure data to exclude any fields that shouldn't be updated
    const updateData: {
      topicId?: string | null;
      chapterId?: string | null;
      startedAt?: Date;
      endedAt?: Date | null;
      plannedDurationMinutes?: number;
      actualDurationMinutes?: number;
      pomodorosCompleted?: number;
      confidenceRating?: number | null;
      notes?: string | null;
      xpEarned?: number;
    } = {};

    if (data.startedAt) updateData.startedAt = new Date(data.startedAt);
    if (data.endedAt !== undefined) {
      updateData.endedAt = data.endedAt ? new Date(data.endedAt) : null;
    }
    if (data.topicId !== undefined) updateData.topicId = data.topicId;
    if (data.chapterId !== undefined) updateData.chapterId = data.chapterId;
    if (data.plannedDurationMinutes !== undefined) updateData.plannedDurationMinutes = data.plannedDurationMinutes;
    if (data.actualDurationMinutes !== undefined) updateData.actualDurationMinutes = data.actualDurationMinutes;
    if (data.pomodorosCompleted !== undefined) updateData.pomodorosCompleted = data.pomodorosCompleted;
    if (data.confidenceRating !== undefined) updateData.confidenceRating = data.confidenceRating;
    if (data.notes !== undefined) updateData.notes = data.notes;

    // Recalculate XP if pomodorosCompleted, confidenceRating, or actualDurationMinutes changed
    const xpChanged = data.pomodorosCompleted !== undefined ||
      data.confidenceRating !== undefined ||
      data.actualDurationMinutes !== undefined;

    if (xpChanged) {
      const newXpEarned = XpService.xpForSession(
        data.actualDurationMinutes ?? existing.actualDurationMinutes,
        data.pomodorosCompleted ?? existing.pomodorosCompleted,
        data.confidenceRating ?? existing.confidenceRating ?? undefined
      );
      updateData.xpEarned = newXpEarned;
    }

    const session = await prisma.studySession.update({
      where: { id },
      data: updateData,
    });

    // If XP changed, update subject XP and user stats
    if (xpChanged) {
      const xpDelta = session.xpEarned - existing.xpEarned;
      if (xpDelta !== 0) {
        await prisma.subject.update({
          where: { id: session.subjectId },
          data: { xpTotal: { increment: xpDelta } },
        });
        await XpService.addXpAndMinutes(req.user.userId, xpDelta, 0);
      }
    }

    res.json({ data: session });
  } catch (error: unknown) {
    next(error);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const result = await prisma.studySession.deleteMany({
      where: { id, subject: { project: { userId: req.user.userId } } },
    });

    if (result.count === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }

    res.status(204).send();
  } catch (error: unknown) {
    next(error);
  }
});

export default router;
