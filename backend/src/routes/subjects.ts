import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../db.js';
import { parsePagination } from '../types/index.js';

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

// Schema for validating query parameters
const listSubjectsQuerySchema = z.object({
  projectId: z.string().uuid('Invalid or missing projectId').optional(),
});

router.get('/', async (req, res, next) => {
  try {
    const { projectId } = listSubjectsQuerySchema.parse(req.query);
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where = projectId ? { projectId, project: { userId: req.user.userId } } : { project: { userId: req.user.userId } };
    const [subjects, total] = await Promise.all([
      prisma.subject.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take,
        include: {
          sessions: {
            select: { actualDurationMinutes: true },
          },
        },
      }),
      prisma.subject.count({ where }),
    ]);
    const subjectsWithMinutes = subjects.map((sub: any) => {
      const totalMinutes = sub.sessions?.reduce((sum: number, s: any) => sum + (s.actualDurationMinutes || 0), 0) || 0;
      const { sessions, ...rest } = sub;
      return { ...rest, totalStudyMinutes: totalMinutes };
    });

    res.json({
      data: subjectsWithMinutes,
      pagination: { page, limit, total, hasMore: skip + take < total },
    });
  } catch (error: unknown) {
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
  } catch (error: unknown) {
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
  } catch (error: unknown) {
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
  } catch (error: unknown) {
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
  } catch (error: unknown) {
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
          include: {
            sessions: {
              select: { actualDurationMinutes: true },
            },
          },
        }),
        prisma.subject.count({ where: { projectId } }),
      ]);

      const subjectsWithMinutes = subjects.map((sub: any) => {
        const totalMinutes = sub.sessions?.reduce((sum: number, s: any) => sum + (s.actualDurationMinutes || 0), 0) || 0;
        const { sessions, ...rest } = sub;
        return { ...rest, totalStudyMinutes: totalMinutes };
      });

      res.json({
        data: subjectsWithMinutes,
        pagination: { page, limit, total, hasMore: skip + take < total },
      });
    } catch (error: unknown) {
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
    } catch (error: unknown) {
      next(error);
    }
  });

  return projectRouter;
}

export default router;
