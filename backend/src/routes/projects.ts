import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';
import { parsePagination } from '../types/index.js';

const router = Router();

const projectSchema = z.object({
  name: z.string().min(1).max(100),
  icon: z.string().default('📚'),
  colorValue: z.number(),
});

const updateProjectSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  icon: z.string().optional(),
  colorValue: z.number().optional(),
  isArchived: z.boolean().optional(),
  lastOpenedAt: z.string().datetime().optional(),
});

router.get('/', async (req, res, next) => {
  try {
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where = { userId: req.user.userId, isArchived: false };
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
  } catch (error: any) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const project = await prisma.project.findFirst({
      where: { id, userId: req.user.userId },
    });
    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }
    res.json({ data: project });
  } catch (error: any) {
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
  } catch (error: any) {
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const data = updateProjectSchema.parse(req.body);
    const project = await prisma.project.updateMany({
      where: { id, userId: req.user.userId },
      data,
    });

    if (project.count === 0) {
      return res.status(404).json({ error: 'Project not found' });
    }

    const updated = await prisma.project.findUnique({ where: { id } });

    res.json({ data: updated });
  } catch (error: any) {
    next(error);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const project = await prisma.project.deleteMany({
      where: { id, userId: req.user.userId },
    });

    if (project.count === 0) {
      return res.status(404).json({ error: 'Project not found' });
    }

    res.status(204).send();
  } catch (error: any) {
    next(error);
  }
});

export default router;
