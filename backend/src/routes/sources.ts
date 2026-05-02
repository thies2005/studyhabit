import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';
import { XpService } from '../services/xpService.js';
import { parsePagination } from '../types/index.js';

const router = Router();

const sourceSchema = z.object({
  subjectId: z.string().uuid(),
  topicId: z.string().uuid().optional(),
  chapterId: z.string().uuid().optional(),
  type: z.enum(['pdf', 'url', 'videoUrl']),
  title: z.string().min(1).max(200),
  filePath: z.string().optional(),
  url: z.string().refine(
    (val) => val.startsWith('http://') || val.startsWith('https://'),
    { message: 'URL must use http or https scheme' }
  ).optional(),
  totalPages: z.number().int().optional(),
  notes: z.string().optional(),
});

const updateSourceSchema = z.object({
  topicId: z.string().uuid().optional(),
  chapterId: z.string().uuid().optional(),
  title: z.string().min(1).max(200).optional(),
  currentPage: z.number().int().optional(),
  totalPages: z.number().int().optional(),
  progressPercent: z.number().min(0).max(100).optional(),
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
    const [sources, total] = await Promise.all([
      prisma.source.findMany({
        where,
        orderBy: { addedAt: 'desc' },
        skip,
        take,
      }),
      prisma.source.count({ where }),
    ]);
    res.json({
      data: sources,
      pagination: { page, limit, total, hasMore: skip + take < total },
    });
  } catch (error: any) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const source = await prisma.source.findFirst({
      where: { id, subject: { project: { userId: req.user.userId } } },
    });
    if (!source) {
      return res.status(404).json({ error: 'Source not found' });
    }
    res.json({ data: source });
  } catch (error: any) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const data = sourceSchema.parse(req.body);

    const subject = await prisma.subject.findFirst({
      where: { id: data.subjectId, project: { userId: req.user.userId } },
    });

    if (!subject) {
      return res.status(404).json({ error: 'Subject not found' });
    }

    const source = await prisma.source.create({ data });

    await XpService.addXpAndMinutes(req.user.userId, 5, 0);

    res.status(201).json({ data: source });
  } catch (error: any) {
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const data = updateSourceSchema.parse(req.body);

    const existing = await prisma.source.findFirst({
      where: { id, subject: { project: { userId: req.user.userId } } },
    });

    if (!existing) {
      return res.status(404).json({ error: 'Source not found' });
    }

    const source = await prisma.source.update({
      where: { id },
      data,
    });

    res.json({ data: source });
  } catch (error: any) {
    next(error);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const result = await prisma.source.deleteMany({
      where: { id, subject: { project: { userId: req.user.userId } } },
    });

    if (result.count === 0) {
      return res.status(404).json({ error: 'Source not found' });
    }

    res.status(204).send();
  } catch (error: any) {
    next(error);
  }
});

export default router;
