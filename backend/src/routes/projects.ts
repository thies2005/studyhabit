import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../db.js';
import { parsePagination } from '../types/index.js';

const router = Router();

const projectSchema = z.object({
  name: z.string().min(1).max(100),
  icon: z.string().default('📚'),
  colorValue: z.number().transform(v => v & 0xFFFFFF),
});

const updateProjectSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  icon: z.string().optional(),
  colorValue: z.number().transform(v => v & 0xFFFFFF).optional(),
  isArchived: z.boolean().optional(),
  lastOpenedAt: z.string().datetime().optional(),
});

router.get('/', async (req, res, next) => {
  try {
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where = { userId: req.user.userId, isArchived: false, isDeleted: false };
    const [projects, total] = await Promise.all([
      prisma.project.findMany({
        where,
        orderBy: { lastOpenedAt: 'desc' },
        skip,
        take,
      }),
      prisma.project.count({ where }),
    ]);
    res.json({
      data: projects,
      pagination: { page, limit, total, hasMore: skip + take < total },
    });
  } catch (error: unknown) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const project = await prisma.project.findFirst({
      where: { id, userId: req.user.userId, isDeleted: false },
    });
    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }
    res.json({ data: project });
  } catch (error: unknown) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const data = projectSchema.parse(req.body);
    const project = await prisma.project.create({
      data: { ...data, userId: req.user.userId },
    });
    res.status(201).json({ data: project });
  } catch (error: unknown) {
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const data = updateProjectSchema.parse(req.body);
    const project = await prisma.project.updateMany({
      where: { id, userId: req.user.userId, isDeleted: false },
      data,
    });

    if (project.count === 0) {
      return res.status(404).json({ error: 'Project not found' });
    }

    const updated = await prisma.project.findUnique({ where: { id } });

    res.json({ data: updated });
  } catch (error: unknown) {
    next(error);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const project = await prisma.project.updateMany({
      where: { id, userId: req.user.userId },
      data: { isDeleted: true, updatedAt: new Date() },
    });

    if (project.count === 0) {
      return res.status(404).json({ error: 'Project not found' });
    }

    res.status(204).send();
  } catch (error: unknown) {
    next(error);
  }
});

export default router;
