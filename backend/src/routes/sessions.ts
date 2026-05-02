import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';
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
    const subjectId = String(req.query.subjectId ?? '');
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where = {
      subjectId,
      subject: { project: { userId: req.user.userId } },
    };
    const [sessions, total] = await Promise.all([
      prisma.studySession.findMany({
        where,
        orderBy: { startedAt: 'desc' },
        skip,
        take,
      }),
      prisma.studySession.count({ where }),
    ]);
    res.json({
      data: sessions,
      pagination: { page, limit, total, hasMore: skip + take < total },
    });
  } catch (error: any) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const session = await prisma.studySession.findFirst({
      where: { id, subject: { project: { userId: req.user.userId } } },
    });
    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }
    res.json({ data: session });
  } catch (error: any) {
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

    const newAchievements = await AchievementService.checkAndUnlock(req.user.userId);

    res.status(201).json({ data: { ...session, newAchievements } });
  } catch (error: any) {
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

    const updateData: any = { ...data };
    if (data.startedAt) updateData.startedAt = new Date(data.startedAt);
    if (data.endedAt) updateData.endedAt = new Date(data.endedAt);
    delete updateData.subjectId;

    const session = await prisma.studySession.update({
      where: { id },
      data: updateData,
    });

    res.json({ data: session });
  } catch (error: any) {
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
  } catch (error: any) {
    next(error);
  }
});

export default router;
