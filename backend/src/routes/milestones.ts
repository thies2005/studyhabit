import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../db.js';

const router = Router();

const milestoneSchema = z.object({
  id: z.string().uuid().optional(),
  subjectId: z.string().uuid(),
  title: z.string().min(1).max(200),
  isCompleted: z.boolean().default(false),
  sortOrder: z.number().default(0),
  completedAt: z.string().datetime().nullable().optional(),
});

const updateMilestoneSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  isCompleted: z.boolean().optional(),
  sortOrder: z.number().optional(),
  completedAt: z.string().datetime().nullable().optional(),
});

// Helper to verify subject ownership
async function verifySubjectOwnership(subjectId: string, userId: string): Promise<boolean> {
  const subject = await prisma.subject.findUnique({
    where: { id: subjectId },
    include: { project: true },
  });
  return !!subject && subject.project.userId === userId;
}

router.get('/', async (req, res, next) => {
  try {
    const subjectId = req.query.subjectId ? String(req.query.subjectId) : undefined;
    if (!subjectId) {
      return res.status(400).json({ error: 'Missing subjectId query parameter' });
    }

    const owned = await verifySubjectOwnership(subjectId, req.user.userId);
    if (!owned) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const milestones = await prisma.subjectMilestone.findMany({
      where: { subjectId },
      orderBy: { sortOrder: 'asc' },
    });

    res.json({ data: milestones });
  } catch (error: unknown) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const data = milestoneSchema.parse(req.body);
    
    const owned = await verifySubjectOwnership(data.subjectId, req.user.userId);
    if (!owned) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const completedAt = data.isCompleted ? (data.completedAt ? new Date(data.completedAt) : new Date()) : null;

    const milestone = await prisma.subjectMilestone.create({
      data: {
        id: data.id,
        subjectId: data.subjectId,
        title: data.title,
        isCompleted: data.isCompleted,
        sortOrder: data.sortOrder,
        completedAt,
      },
    });

    res.status(201).json({ data: milestone });
  } catch (error: unknown) {
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const data = updateMilestoneSchema.parse(req.body);

    const existing = await prisma.subjectMilestone.findUnique({
      where: { id },
      include: { subject: { include: { project: true } } },
    });

    if (!existing || existing.subject.project.userId !== req.user.userId) {
      return res.status(404).json({ error: 'Milestone not found' });
    }

    const updateData: any = { ...data };
    if (data.isCompleted !== undefined) {
      if (data.isCompleted) {
        updateData.completedAt = data.completedAt ? new Date(data.completedAt) : new Date();
      } else {
        updateData.completedAt = null;
      }
    }

    const updated = await prisma.subjectMilestone.update({
      where: { id },
      data: updateData,
    });

    res.json({ data: updated });
  } catch (error: unknown) {
    next(error);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);

    const existing = await prisma.subjectMilestone.findUnique({
      where: { id },
      include: { subject: { include: { project: true } } },
    });

    if (!existing || existing.subject.project.userId !== req.user.userId) {
      return res.status(404).json({ error: 'Milestone not found' });
    }

    await prisma.subjectMilestone.delete({ where: { id } });

    res.status(204).send();
  } catch (error: unknown) {
    next(error);
  }
});

export default router;
