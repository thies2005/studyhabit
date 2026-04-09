import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';

const router = Router();

// Get all achievements
router.get('/', async (req: any, res: any) => {
  try {
    const achievements = await prisma.achievement.findMany({
      where: { userId: req.user.userId },
      orderBy: { unlockedAt: 'desc' },
    });
    res.json({ data: achievements });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Get single achievement
router.get('/:key', async (req: any, res: any) => {
  try {
    const achievement = await prisma.achievement.findFirst({
      where: {
        key: req.params.key,
        userId: req.user.userId,
      },
    });

    if (!achievement) {
      return res.status(404).json({ error: 'Achievement not found' });
    }

    res.json({ data: achievement });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Unlock achievement
router.post('/:key/unlock', async (req: any, res: any) => {
  try {
    const achievement = await prisma.achievement.upsert({
      where: {
        userId_key: {
          userId: req.user.userId,
          key: req.params.key,
        },
      },
      update: {
        unlockedAt: new Date(),
        progress: 1.0,
      },
      create: {
        userId: req.user.userId,
        key: req.params.key,
        unlockedAt: new Date(),
        progress: 1.0,
      },
    });

    res.json({ data: achievement });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Update progress
router.patch('/:key/progress', async (req: any, res: any) => {
  try {
    const { progress } = req.body;
    const numProgress = parseFloat(progress);

    if (isNaN(numProgress) || numProgress < 0 || numProgress > 1) {
      return res.status(400).json({ error: 'Invalid progress value' });
    }

    const achievement = await prisma.achievement.upsert({
      where: {
        userId_key: {
          userId: req.user.userId,
          key: req.params.key,
        },
      },
      update: { progress: numProgress },
      create: {
        userId: req.user.userId,
        key: req.params.key,
        progress: numProgress,
      },
    });

    res.json({ data: achievement });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

export default router;
