import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';
import { parsePagination } from '../types/index.js';

const router = Router();

const topicSchema = z.object({
  subjectId: z.string().uuid(),
  name: z.string().min(1).max(100),
  order: z.number().int().min(0).default(0),
});

const updateTopicSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  order: z.number().int().min(0).optional(),
});

router.get('/', async (req, res, next) => {
  try {
    const subjectId = String(req.query.subjectId ?? '');
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where = {
      subjectId,
      subject: { project: { userId: req.user.userId } },
    };

    const [topics, total] = await Promise.all([
      prisma.topic.findMany({
        where,
        orderBy: { order: 'asc' },
        skip,
        take,
        include: { chapters: { orderBy: { order: 'asc' } } },
      }),
      prisma.topic.count({ where }),
    ]);

    res.json({
      data: topics,
      pagination: { page, limit, total, hasMore: skip + take < total },
    });
  } catch (error: any) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const topic = await prisma.topic.findFirst({
      where: {
        id,
        subject: { project: { userId: req.user.userId } },
      },
      include: { chapters: { orderBy: { order: 'asc' } } },
    });

    if (!topic) {
      return res.status(404).json({ error: 'Topic not found' });
    }

    res.json({ data: topic });
  } catch (error: any) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const data = topicSchema.parse(req.body);

    // Verify subject ownership before creating topic
    const subject = await prisma.subject.findFirst({
      where: { id: data.subjectId, project: { userId: req.user.userId } },
    });

    if (!subject) {
      return res.status(404).json({ error: 'Subject not found' });
    }

    const topic = await prisma.topic.create({ data });
    res.status(201).json({ data: topic });
  } catch (error: any) {
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const data = updateTopicSchema.parse(req.body);
    const result = await prisma.topic.updateMany({
      where: {
        id,
        subject: { project: { userId: req.user.userId } },
      },
      data,
    });

    if (result.count === 0) {
      return res.status(404).json({ error: 'Topic not found' });
    }

    const updated = await prisma.topic.findUnique({
      where: { id },
      include: { chapters: { orderBy: { order: 'asc' } } },
    });

    res.json({ data: updated });
  } catch (error: any) {
    next(error);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const result = await prisma.topic.deleteMany({
      where: {
        id,
        subject: { project: { userId: req.user.userId } },
      },
    });

    if (result.count === 0) {
      return res.status(404).json({ error: 'Topic not found' });
    }

    res.status(204).send();
  } catch (error: any) {
    next(error);
  }
});

export default router;
