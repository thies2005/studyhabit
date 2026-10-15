import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../db.js';
import { XpService } from '../services/xpService.js';
import { parsePagination } from '../types/index.js';
import { Prisma } from '@prisma/client';

const router = Router();

const sourceSchema = z.object({
  subjectId: z.string().uuid(),
  topicId: z.string().uuid().nullable().optional(),
  chapterId: z.string().uuid().nullable().optional(),
  type: z.enum(['pdf', 'url', 'videoUrl']),
  title: z.string().min(1).max(255),
  filePath: z.string().max(1000).nullable().optional(),
  url: z.string().max(2000).refine(
    (val) => !val || val.startsWith('http://') || val.startsWith('https://'),
    { message: 'URL must use http or https scheme' }
  ).nullable().optional(),
  totalPages: z.number().int().min(0).nullable().optional(),
  notes: z.string().max(5000).nullable().optional(),
});

const updateSourceSchema = z.object({
  topicId: z.string().uuid().nullable().optional(),
  chapterId: z.string().uuid().nullable().optional(),
  title: z.string().min(1).max(255).optional(),
  currentPage: z.number().int().min(0).nullable().optional(),
  totalPages: z.number().int().min(0).nullable().optional(),
  progressPercent: z.number().min(0).max(100).nullable().optional(),
  notes: z.string().max(5000).nullable().optional(),
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

router.get('/', async (req, res, next) => {
  try {
    const subjectId = String(req.query.subjectId ?? '');
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where: any = {
      subject: { project: { userId: req.user.userId, isDeleted: false }, isDeleted: false },
      isDeleted: false,
    };
    if (subjectId) {
      where.subjectId = subjectId;
    }
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
  } catch (error: unknown) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const source = await prisma.source.findFirst({
      where: {
        id,
        subject: { project: { userId: req.user.userId, isDeleted: false }, isDeleted: false },
        isDeleted: false,
      },
    });
    if (!source) {
      return res.status(404).json({ error: 'Source not found' });
    }
    res.json({ data: source });
  } catch (error: unknown) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const data = sourceSchema.parse(req.body);

    const source = await prisma.$transaction(async (tx) => {
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

      const source = await tx.source.create({ data: { ...data, updatedAt: new Date() } });
      await XpService.addXpAndMinutes(req.user.userId, 5, 0, tx);
      return source;
    });

    res.status(201).json({ data: source });
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
    const data = updateSourceSchema.parse(req.body);

    const source = await prisma.$transaction(async (tx) => {
      const existing = await tx.source.findFirst({
        where: {
          id,
          subject: { project: { userId: req.user.userId, isDeleted: false }, isDeleted: false },
          isDeleted: false,
        },
      });

      if (!existing) {
        throw new Error('STATUS_404:Source not found');
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

      return tx.source.update({
        where: { id },
        data: { ...data, updatedAt: new Date() },
      });
    });

    res.json({ data: source });
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
    const result = await prisma.source.updateMany({
      where: {
        id,
        subject: { project: { userId: req.user.userId, isDeleted: false }, isDeleted: false },
        isDeleted: false,
      },
      data: { isDeleted: true, updatedAt: new Date() },
    });

    if (result.count === 0) {
      return res.status(404).json({ error: 'Source not found' });
    }

    res.status(204).send();
  } catch (error: unknown) {
    next(error);
  }
});

export default router;
