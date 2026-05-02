import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';
import { parsePagination } from '../types/index.js';
import { XpService } from '../services/xpService.js';
import { AchievementService } from '../services/achievementService.js';

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

const updateSubjectSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  description: z.string().optional(),
  colorValue: z.number().optional(),
  hierarchyMode: z.enum(['flat', 'twoLevel', 'threeLevel']).optional(),
  defaultDurationMinutes: z.number().int().min(5).max(90).optional(),
  defaultBreakMinutes: z.number().int().min(1).max(30).optional(),
});

router.get('/', async (req, res, next) => {
  try {
    const projectId = String(req.query.projectId ?? '');
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where = { projectId, project: { userId: req.user.userId } };
    const [subjects, total] = await Promise.all([
      prisma.subject.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      prisma.subject.count({ where }),
    ]);
    res.json({
      data: subjects,
      pagination: { page, limit, total, hasMore: skip + take < total },
    });
  } catch (error: any) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const subject = await prisma.subject.findFirst({
      where: { id, project: { userId: req.user.userId } },
      include: {
        topics: { include: { chapters: true }, orderBy: { order: 'asc' } },
      },
    });
    if (!subject) {
      return res.status(404).json({ error: 'Subject not found' });
    }
    res.json({ data: subject });
  } catch (error: any) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const data = subjectSchema.parse(req.body);

    // Verify project ownership before creating subject
    const project = await prisma.project.findFirst({
      where: { id: data.projectId, userId: req.user.userId },
    });
    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }

    const subject = await prisma.subject.create({ data });
    res.status(201).json({ data: subject });
  } catch (error: any) {
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const data = updateSubjectSchema.parse(req.body);
    const result = await prisma.subject.updateMany({
      where: { id, project: { userId: req.user.userId } },
      data,
    });

    if (result.count === 0) {
      return res.status(404).json({ error: 'Subject not found' });
    }

    const updated = await prisma.subject.findUnique({ where: { id } });
    res.json({ data: updated });
  } catch (error: any) {
    next(error);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const result = await prisma.subject.deleteMany({
      where: { id, project: { userId: req.user.userId } },
    });

    if (result.count === 0) {
      return res.status(404).json({ error: 'Subject not found' });
    }

    res.status(204).send();
  } catch (error: any) {
    next(error);
  }
});

// Nested project routes - for backward compatibility and convenience
export function createProjectSubjectRoutes(): Router {
  const projectRouter = Router();

  // GET /api/v1/projects/:projectId/subjects - list subjects for a project
  projectRouter.get('/', async (req, res, next) => {
    try {
      const projectId = String((req.params as any).projectId);
      const { skip, take, page, limit } = parsePagination(req.query as any);

      // Verify project ownership
      const project = await prisma.project.findFirst({
        where: { id: projectId, userId: req.user.userId },
      });

      if (!project) {
        return res.status(404).json({ error: 'Project not found' });
      }

      const [subjects, total] = await Promise.all([
        prisma.subject.findMany({
          where: { projectId },
          orderBy: { createdAt: 'desc' },
          skip,
          take,
        }),
        prisma.subject.count({ where: { projectId } }),
      ]);

      res.json({
        data: subjects,
        pagination: { page, limit, total, hasMore: skip + take < total },
      });
    } catch (error: any) {
      next(error);
    }
  });

  // POST /api/v1/projects/:projectId/subjects - create subject under project
  projectRouter.post('/', async (req, res, next) => {
    try {
      const projectId = String((req.params as any).projectId);
      const data = subjectSchema.parse(req.body);

      // Verify project ownership before creating subject
      const project = await prisma.project.findFirst({
        where: { id: projectId, userId: req.user.userId },
      });
      if (!project) {
        return res.status(404).json({ error: 'Project not found' });
      }

      const subject = await prisma.subject.create({
        data: { ...data, projectId },
      });

      res.status(201).json({ data: subject });
    } catch (error: any) {
      next(error);
    }
  });

  return projectRouter;
}

export default router;
