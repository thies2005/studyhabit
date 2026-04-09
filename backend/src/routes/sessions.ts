import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';
import { XpService } from '../services/xpService.js';

const router = Router();

const sessionSchema = z.object({
  subjectId: z.string().uuid(),
  topicId: z.string().uuid().optional(),
  chapterId: z.string().uuid().optional(),
  plannedDurationMinutes: z.number().int().min(5),
  actualDurationMinutes: z.number().int().min(0),
  pomodorosCompleted: z.number().int().min(0),
  confidenceRating: z.number().int().min(1).max(5).optional(),
  notes: z.string().optional(),
});

const updateSessionSchema = sessionSchema.partial();

// Get sessions by subject
router.get('/', async (req: any, res: any) => {
  try {
    const { subjectId } = req.query;
    const sessions = await prisma.studySession.findMany({
      where: {
        subjectId: subjectId as string,
        subject: { project: { userId: req.user.userId } },
      },
      orderBy: { startedAt: 'desc' },
    });
    res.json({ data: sessions });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Get single session
router.get('/:id', async (req: any, res: any) => {
  try {
    const session = await prisma.studySession.findFirst({
      where: {
        id: req.params.id,
        subject: { project: { userId: req.user.userId } },
      },
    });
    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }
    res.json({ data: session });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Create session
router.post('/', async (req: any, res: any) => {
  try {
    const data = sessionSchema.parse(req.body);

    // Verify subject belongs to user
    const subject = await prisma.subject.findFirst({
      where: {
        id: data.subjectId,
        project: { userId: req.user.userId },
      },
    });

    if (!subject) {
      return res.status(404).json({ error: 'Subject not found' });
    }

    // Calculate XP
    const xpEarned = XpService.xpForSession(
      data.actualDurationMinutes,
      data.pomodorosCompleted
    );

    const session = await prisma.studySession.create({
      data: {
        ...data,
        xpEarned,
      },
    });

    // Update subject XP
    await prisma.subject.update({
      where: { id: data.subjectId },
      data: { xpTotal: { increment: xpEarned } },
    });

    // Update user stats
    await XpService.addXpToUser(req.user.userId, xpEarned);

    res.status(201).json({ data: session });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Update session
router.patch('/:id', async (req: any, res: any) => {
  try {
    const data = updateSessionSchema.parse(req.body);

    // Verify session belongs to user
    const existing = await prisma.studySession.findFirst({
      where: {
        id: req.params.id,
        subject: { project: { userId: req.user.userId } },
      },
    });

    if (!existing) {
      return res.status(404).json({ error: 'Session not found' });
    }

    const session = await prisma.studySession.update({
      where: { id: req.params.id },
      data,
    });

    res.json({ data: session });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Delete session
router.delete('/:id', async (req: any, res: any) => {
  try {
    const session = await prisma.studySession.deleteMany({
      where: {
        id: req.params.id,
        subject: { project: { userId: req.user.userId } },
      },
    });

    if (session.count === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }

    res.status(204).send();
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
