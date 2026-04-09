import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';

const router = Router();

const subjectSchema = z.object({
  projectId: z.string().uuid(),
  name: z.string().min(1).max(100),
  description: z.string().optional(),
  colorValue: z.number(),
  hierarchyMode: z.enum(['flat', 'twoLevel', 'threeLevel']),
  defaultDurationMinutes: z.number().int().min(5).max(90),
  defaultBreakMinutes: z.number().int().min(1).max(30),
});

const updateSubjectSchema = subjectSchema.partial();

// Get subjects by project
router.get('/', async (req: any, res: any) => {
  try {
    const { projectId } = req.query;
    const subjects = await prisma.subject.findMany({
      where: {
        projectId: projectId as string,
        project: { userId: req.user.userId },
      },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ data: subjects });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Get single subject
router.get('/:id', async (req: any, res: any) => {
  try {
    const subject = await prisma.subject.findFirst({
      where: {
        id: req.params.id,
        project: { userId: req.user.userId },
      },
      include: {
        topics: {
          include: {
            chapters: true,
          },
          orderBy: { order: 'asc' },
        },
      },
    });
    if (!subject) {
      return res.status(404).json({ error: 'Subject not found' });
    }
    res.json({ data: subject });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Create subject
router.post('/', async (req: any, res: any) => {
  try {
    const data = subjectSchema.parse(req.body);
    const subject = await prisma.subject.create({
      data,
    });
    res.status(201).json({ data: subject });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Update subject
router.patch('/:id', async (req: any, res: any) => {
  try {
    const data = updateSubjectSchema.parse(req.body);
    const subject = await prisma.subject.updateMany({
      where: {
        id: req.params.id,
        project: { userId: req.user.userId },
      },
      data,
    });

    if (subject.count === 0) {
      return res.status(404).json({ error: 'Subject not found' });
    }

    const updated = await prisma.subject.findUnique({
      where: { id: req.params.id },
    });

    res.json({ data: updated });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Delete subject
router.delete('/:id', async (req: any, res: any) => {
  try {
    const subject = await prisma.subject.deleteMany({
      where: {
        id: req.params.id,
        project: { userId: req.user.userId },
      },
    });

    if (subject.count === 0) {
      return res.status(404).json({ error: 'Subject not found' });
    }

    res.status(204).send();
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
