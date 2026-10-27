import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../db.js';
import { XpService } from '../services/xpService.js';
import { AchievementService } from '../services/achievementService.js';
import { parsePagination } from '../types/index.js';
import { Prisma } from '@prisma/client';

const router = Router();

const sessionSchema = z.object({
  subjectId: z.string().uuid(),
  topicId: z.string().uuid().nullable().optional(),
  chapterId: z.string().uuid().nullable().optional(),
  startedAt: z.string().datetime().optional(),
  endedAt: z.string().datetime().nullable().optional(),
  plannedDurationMinutes: z.number().int().min(0),
  actualDurationMinutes: z.number().int().min(0),
  pomodorosCompleted: z.number().int().min(0),
  confidenceRating: z.number().int().min(1).max(5).nullable().optional(),
  notes: z.string().max(5000).nullable().optional(),
  sourceId: z.string().uuid().nullable().optional(),
  startPage: z.number().int().min(0).nullable().optional(),
  endPage: z.number().int().min(0).nullable().optional(),
  isFreeTimer: z.boolean().optional(),
});

const updateSessionSchema = z.object({
  topicId: z.string().uuid().nullable().optional(),
  chapterId: z.string().uuid().nullable().optional(),
  startedAt: z.string().datetime().optional(),
  endedAt: z.string().datetime().nullable().optional(),
  plannedDurationMinutes: z.number().int().min(0).optional(),
  actualDurationMinutes: z.number().int().min(0).optional(),
  pomodorosCompleted: z.number().int().min(0).optional(),
  confidenceRating: z.number().int().min(1).max(5).nullable().optional(),
  notes: z.string().max(5000).nullable().optional(),
  sourceId: z.string().uuid().nullable().optional(),
  startPage: z.number().int().min(0).nullable().optional(),
  endPage: z.number().int().min(0).nullable().optional(),
  isFreeTimer: z.boolean().optional(),
});

async function verifyHierarchyOwnership(
  tx: Prisma.TransactionClient,
  userId: string,
  subjectId: string,
  topicId?: string | null,
  chapterId?: string | null
): Promise<{ valid: boolean; error?: string; status?: number }> {
  const subject = await tx.subject.findFirst({
    where: { id: subjectId, project: { userId, isDeleted: false }, isDeleted: false },
  });
  if (!subject) {
    return { valid: false, error: 'Subject not found', status: 404 };
  }
  if (topicId) {
    const topic = await tx.topic.findFirst({
      where: { id: topicId, subjectId, isDeleted: false },
    });
    if (!topic) {
      return { valid: false, error: 'Topic does not belong to this subject', status: 400 };
    }
    if (chapterId) {
      const chapter = await tx.chapter.findFirst({
        where: { id: chapterId, topicId, isDeleted: false },
      });
      if (!chapter) {
        return { valid: false, error: 'Chapter does not belong to this topic', status: 400 };
      }
    }
  } else if (chapterId) {
    return { valid: false, error: 'Cannot specify chapterId without topicId', status: 400 };
  }
  return { valid: true };
}

async function recalculateUserLastStudyDate(tx: Prisma.TransactionClient, userId: string): Promise<void> {
  const latestSession = await tx.studySession.findFirst({
    where: {
      subject: { project: { userId, isDeleted: false }, isDeleted: false },
      isDeleted: false,
    },
    orderBy: { startedAt: 'desc' },
  });

  const lastStudyDate = latestSession ? new Date(latestSession.startedAt) : null;
  if (lastStudyDate) {
    lastStudyDate.setUTCHours(0, 0, 0, 0);
  }

  await tx.userStats.update({
    where: { userId },
    data: {
      lastStudyDate,
      currentStreak: latestSession ? undefined : 0,
      updatedAt: new Date(),
    },
  });
}

router.get('/', async (req, res, next) => {
  try {
    const subjectId = req.query.subjectId ? String(req.query.subjectId) : undefined;
    const projectId = req.query.projectId ? String(req.query.projectId) : undefined;
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where: any = {
      subject: { project: { userId: req.user.userId, isDeleted: false }, isDeleted: false },
      isDeleted: false,
    };
    if (subjectId) {
      where.subjectId = subjectId;
    }
    if (projectId) {
      where.subject = { ...where.subject, projectId };
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
      where: {
        id,
        subject: { project: { userId: req.user.userId, isDeleted: false }, isDeleted: false },
        isDeleted: false,
      },
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

    const xpEarned = XpService.xpForSession(
      data.actualDurationMinutes,
      data.pomodorosCompleted,
      data.confidenceRating ?? undefined
    );

    const { session, newAchievements } = await prisma.$transaction(async (tx) => {
      const check = await verifyHierarchyOwnership(
        tx,
        req.user.userId,
        data.subjectId,
        data.topicId,
        data.chapterId
      );
      if (!check.valid) {
        throw new Error(`STATUS_${check.status || 400}:${check.error}`);
      }

      const session = await tx.studySession.create({
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
          sourceId: data.sourceId,
          startPage: data.startPage,
          endPage: data.endPage,
          isFreeTimer: data.isFreeTimer ?? false,
          updatedAt: new Date(),
        },
      });

      await tx.subject.update({
        where: { id: data.subjectId },
        data: { xpTotal: { increment: xpEarned } },
      });

      await XpService.addXpAndMinutes(
        req.user.userId,
        xpEarned,
        data.actualDurationMinutes,
        tx
      );

      const userStats = await tx.userStats.findUnique({
        where: { userId: req.user.userId },
      });
      if (userStats) {
        const sessionDate = new Date(session.startedAt);
        sessionDate.setUTCHours(0, 0, 0, 0);

        const lastStudyDate = userStats.lastStudyDate ? new Date(userStats.lastStudyDate) : null;
        if (lastStudyDate) {
          lastStudyDate.setUTCHours(0, 0, 0, 0);
        }

        const daysDiff = lastStudyDate
          ? Math.round((sessionDate.getTime() - lastStudyDate.getTime()) / (1000 * 60 * 60 * 24))
          : null;

        let newStreak: number;
        let newLastStudyDate: Date;

        if (daysDiff === null) {
          newStreak = 1;
          newLastStudyDate = sessionDate;
        } else if (daysDiff === 0 || daysDiff < 0) {
          newStreak = userStats.currentStreak;
          newLastStudyDate = lastStudyDate ?? sessionDate;
        } else if (daysDiff === 1) {
          newStreak = userStats.currentStreak + 1;
          newLastStudyDate = sessionDate;
        } else {
          newStreak = 1;
          newLastStudyDate = sessionDate;
        }

        const oldStreak = userStats.currentStreak;
        const longestStreak = Math.max(newStreak, userStats.longestStreak);

        if (newStreak > oldStreak) {
          const streakXp = XpService.xpForStreakMilestones(oldStreak, newStreak);
          if (streakXp > 0) {
            await XpService.addXpAndMinutes(req.user.userId, streakXp, 0, tx);
          }
        }

        await tx.userStats.update({
          where: { userId: req.user.userId },
          data: {
            currentStreak: newStreak,
            longestStreak,
            lastStudyDate: newLastStudyDate,
            updatedAt: new Date(),
          },
        });
      }

      const newAchievements = await AchievementService.checkAndUnlock(
        req.user.userId,
        tx,
        typeof (req.body as any)?.timezoneOffsetMinutes === 'number'
          ? (req.body as any).timezoneOffsetMinutes
          : undefined
      );

      return { session, newAchievements };
    });

    res.status(201).json({ data: { ...session, newAchievements } });
  } catch (error: unknown) {
    if (error instanceof Error && error.message.startsWith('STATUS_')) {
      const colonIdx = error.message.indexOf(':');
      const status = parseInt(error.message.substring(7, colonIdx), 10);
      const message = error.message.substring(colonIdx + 1);
      return res.status(status).json({ error: message });
    }
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const data = updateSessionSchema.parse(req.body);

    const session = await prisma.$transaction(async (tx) => {
      const existing = await tx.studySession.findFirst({
        where: {
          id,
          subject: { project: { userId: req.user.userId, isDeleted: false }, isDeleted: false },
          isDeleted: false,
        },
      });

      if (!existing) {
        throw new Error('STATUS_404:Session not found');
      }

      const newTopicId = data.topicId !== undefined ? data.topicId : existing.topicId;
      const newChapterId = data.chapterId !== undefined ? data.chapterId : existing.chapterId;

      if (data.topicId !== undefined || data.chapterId !== undefined) {
        const check = await verifyHierarchyOwnership(
          tx,
          req.user.userId,
          existing.subjectId,
          newTopicId,
          newChapterId
        );
        if (!check.valid) {
          throw new Error(`STATUS_${check.status || 400}:${check.error}`);
        }
      }

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
        sourceId?: string | null;
        startPage?: number | null;
        endPage?: number | null;
        isFreeTimer?: boolean;
        xpEarned?: number;
        updatedAt?: Date;
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
      if (data.sourceId !== undefined) updateData.sourceId = data.sourceId;
      if (data.startPage !== undefined) updateData.startPage = data.startPage;
      if (data.endPage !== undefined) updateData.endPage = data.endPage;
      if (data.isFreeTimer !== undefined) updateData.isFreeTimer = data.isFreeTimer;

      const xpChanged = data.pomodorosCompleted !== undefined ||
        data.confidenceRating !== undefined ||
        data.actualDurationMinutes !== undefined;

      if (xpChanged) {
        const newXpEarned = XpService.xpForSession(
          data.actualDurationMinutes ?? existing.actualDurationMinutes,
          data.pomodorosCompleted ?? existing.pomodorosCompleted,
          (data.confidenceRating !== undefined ? data.confidenceRating : existing.confidenceRating) ?? undefined
        );
        updateData.xpEarned = newXpEarned;
      }

      updateData.updatedAt = new Date();

      const updated = await tx.studySession.update({
        where: { id },
        data: updateData,
      });

      const finalDuration = updateData.actualDurationMinutes ?? existing.actualDurationMinutes;
      const durationDelta = finalDuration - existing.actualDurationMinutes;
      const xpDelta = (updateData.xpEarned ?? existing.xpEarned) - existing.xpEarned;

      if (xpDelta !== 0 || durationDelta !== 0) {
        if (xpDelta !== 0) {
          const sub = await tx.subject.findUnique({ where: { id: existing.subjectId } });
          await tx.subject.update({
            where: { id: existing.subjectId },
            data: { xpTotal: Math.max(0, (sub?.xpTotal ?? 0) + xpDelta) },
          });
        }
        await XpService.addXpAndMinutes(req.user.userId, xpDelta, durationDelta, tx);
      }

      if (data.startedAt !== undefined) {
        await recalculateUserLastStudyDate(tx, req.user.userId);
      }

      return updated;
    });

    res.json({ data: session });
  } catch (error: unknown) {
    if (error instanceof Error && error.message.startsWith('STATUS_')) {
      const colonIdx = error.message.indexOf(':');
      const status = parseInt(error.message.substring(7, colonIdx), 10);
      const message = error.message.substring(colonIdx + 1);
      return res.status(status).json({ error: message });
    }
    next(error);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);

    await prisma.$transaction(async (tx) => {
      const existing = await tx.studySession.findFirst({
        where: {
          id,
          subject: { project: { userId: req.user.userId, isDeleted: false }, isDeleted: false },
          isDeleted: false,
        },
      });

      if (!existing) {
        throw new Error('STATUS_404:Session not found');
      }

      await tx.studySession.update({
        where: { id },
        data: { isDeleted: true, updatedAt: new Date() },
      });

      const sub = await tx.subject.findUnique({ where: { id: existing.subjectId } });
      await tx.subject.update({
        where: { id: existing.subjectId },
        data: { xpTotal: Math.max(0, (sub?.xpTotal ?? 0) - existing.xpEarned) },
      });

      await XpService.addXpAndMinutes(
        req.user.userId,
        -existing.xpEarned,
        -existing.actualDurationMinutes,
        tx
      );

      await recalculateUserLastStudyDate(tx, req.user.userId);
    });

    res.status(204).send();
  } catch (error: unknown) {
    if (error instanceof Error && error.message.startsWith('STATUS_')) {
      const colonIdx = error.message.indexOf(':');
      const status = parseInt(error.message.substring(7, colonIdx), 10);
      const message = error.message.substring(colonIdx + 1);
      return res.status(status).json({ error: message });
    }
    next(error);
  }
});

export default router;
