import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';
import { parsePagination } from '../types/index.js';

const router = Router();

const chapterSchema = z.object({
  topicId: z.string().uuid(),
  name: z.string().min(1).max(100),
  order: z.number().int().min(0).default(0),
});

const updateChapterSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  order: z.number().int().min(0).optional(),
});

router.get('/', async (req, res, next) => {
  try {
    const topicId = String(req.query.topicId ?? '');
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where = {
      topicId,
      topic: { subject: { project: { userId: req.user.userId } } },
    };

    const [chapters, total] = await Promise.all([
      prisma.chapter.findMany({
        where,
        orderBy: { order: 'asc' },
        skip,
        take,
      }),
      prisma.chapter.count({ where }),
    ]);

    res.json({
      data: chapters,
      pagination: { page, limit, total, hasMore: skip + take < total },
    });
  } catch (error: any) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const chapter = await prisma.chapter.findFirst({
      where: {
        id,
        topic: { subject: { project: { userId: req.user.userId } } },
      },
    });

    if (!chapter) {
      return res.status(404).json({ error: 'Chapter not found' });
    }

    res.json({ data: chapter });
  } catch (error: any) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const data = chapterSchema.parse(req.body);

    // Verify topic ownership (via subject->project) before creating chapter
    const topic = await prisma.topic.findFirst({
      where: {
        id: data.topicId,
        subject: { project: { userId: req.user.userId } },
      },
    });

    if (!topic) {
      return res.status(404).json({ error: 'Topic not found' });
    }

    const chapter = await prisma.chapter.create({ data });
    res.status(201).json({ data: chapter });
  } catch (error: any) {
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const data = updateChapterSchema.parse(req.body);
    const result = await prisma.chapter.updateMany({
      where: {
        id,
        topic: { subject: { project: { userId: req.user.userId } } },
      },
      data,
    });

    if (result.count === 0) {
      return res.status(404).json({ error: 'Chapter not found' });
    }

    const updated = await prisma.chapter.findUnique({ where: { id } });
    res.json({ data: updated });
  } catch (error: any) {
    next(error);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const result = await prisma.chapter.deleteMany({
      where: {
        id,
        topic: { subject: { project: { userId: req.user.userId } } },
      },
    });

    if (result.count === 0) {
      return res.status(404).json({ error: 'Chapter not found' });
    }

    res.status(204).send();
  } catch (error: any) {
    next(error);
  }
});

export default router;
