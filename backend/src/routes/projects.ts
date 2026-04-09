import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';

const router = Router();

const projectSchema = z.object({
  name: z.string().min(1).max(100),
  icon: z.string().default('📚'),
  colorValue: z.number(),
});

const updateProjectSchema = projectSchema.partial();

// Get all projects for user
router.get('/', async (req: any, res: any) => {
  try {
    const projects = await prisma.project.findMany({
      where: { userId: req.user.userId, isArchived: false },
      orderBy: { lastOpenedAt: 'desc' },
    });
    res.json({ data: projects });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Get single project
router.get('/:id', async (req: any, res: any) => {
  try {
    const project = await prisma.project.findFirst({
      where: {
        id: req.params.id,
        userId: req.user.userId,
      },
    });
    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }
    res.json({ data: project });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Create project
router.post('/', async (req: any, res: any) => {
  try {
    const data = projectSchema.parse(req.body);
    const project = await prisma.project.create({
      data: {
        ...data,
        userId: req.user.userId,
      },
    });
    res.status(201).json({ data: project });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Update project
router.patch('/:id', async (req: any, res: any) => {
  try {
    const data = updateProjectSchema.parse(req.body);
    const project = await prisma.project.updateMany({
      where: {
        id: req.params.id,
        userId: req.user.userId,
      },
      data,
    });

    if (project.count === 0) {
      return res.status(404).json({ error: 'Project not found' });
    }

    const updated = await prisma.project.findUnique({
      where: { id: req.params.id },
    });

    res.json({ data: updated });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Delete project
router.delete('/:id', async (req: any, res: any) => {
  try {
    const project = await prisma.project.deleteMany({
      where: {
        id: req.params.id,
        userId: req.user.userId,
      },
    });

    if (project.count === 0) {
      return res.status(404).json({ error: 'Project not found' });
    }

    res.status(204).send();
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
