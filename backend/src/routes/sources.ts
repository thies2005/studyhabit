import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';

const router = Router();

const sourceSchema = z.object({
  subjectId: z.string().uuid(),
  topicId: z.string().uuid().optional(),
  chapterId: z.string().uuid().optional(),
  type: z.enum(['pdf', 'url', 'videoUrl']),
  title: z.string().min(1).max(200),
  filePath: z.string().optional(),
  url: z.string().url().optional(),
  totalPages: z.number().int().optional(),
  notes: z.string().optional(),
});

const updateSourceSchema = sourceSchema.partial();

// Get sources by subject
router.get('/', async (req: any, res: any) => {
  try {
    const { subjectId } = req.query;
    const sources = await prisma.source.findMany({
      where: {
        subjectId: subjectId as string,
        subject: { project: { userId: req.user.userId } },
      },
      orderBy: { addedAt: 'desc' },
    });
    res.json({ data: sources });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Get single source
router.get('/:id', async (req: any, res: any) => {
  try {
    const source = await prisma.source.findFirst({
      where: {
        id: req.params.id,
        subject: { project: { userId: req.user.userId } },
      },
    });
    if (!source) {
      return res.status(404).json({ error: 'Source not found' });
    }
    res.json({ data: source });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Create source
router.post('/', async (req: any, res: any) => {
  try {
    const data = sourceSchema.parse(req.body);

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

    const source = await prisma.source.create({
      data,
    });

    res.status(201).json({ data: source });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Update source
router.patch('/:id', async (req: any, res: any) => {
  try {
    const data = updateSourceSchema.parse(req.body);

    // Verify source belongs to user
    const existing = await prisma.source.findFirst({
      where: {
        id: req.params.id,
        subject: { project: { userId: req.user.userId } },
      },
    });

    if (!existing) {
      return res.status(404).json({ error: 'Source not found' });
    }

    const source = await prisma.source.update({
      where: { id: req.params.id },
      data,
    });

    res.json({ data: source });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Delete source
router.delete('/:id', async (req: any, res: any) => {
  try {
    const source = await prisma.source.deleteMany({
      where: {
        id: req.params.id,
        subject: { project: { userId: req.user.userId } },
      },
    });

    if (source.count === 0) {
      return res.status(404).json({ error: 'Source not found' });
    }

    res.status(204).send();
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
