import { Router } from 'express';
import { prisma } from '../index.js';

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const achievements = await prisma.achievement.findMany({
      where: { userId: req.user.userId },
      orderBy: { unlockedAt: 'desc' },
    });
    res.json({ data: achievements });
  } catch (error: any) {
    next(error);
  }
});

router.get('/:key', async (req, res, next) => {
  try {
    const key = String(req.params.key);
    const achievement = await prisma.achievement.findFirst({
      where: { key, userId: req.user.userId },
    });

    if (!achievement) {
      return res.status(404).json({ error: 'Achievement not found' });
    }

    res.json({ data: achievement });
  } catch (error: any) {
    next(error);
  }
});

router.post('/:key/unlock', async (req, res, next) => {
  try {
    const key = String(req.params.key);
    const achievement = await prisma.achievement.upsert({
      where: { userId_key: { userId: req.user.userId, key } },
      update: { unlockedAt: new Date(), progress: 1.0 },
      create: {
        userId: req.user.userId,
        key,
        unlockedAt: new Date(),
        progress: 1.0,
      },
    });

    res.json({ data: achievement });
  } catch (error: any) {
    next(error);
  }
});

router.patch('/:key/progress', async (req, res, next) => {
  try {
    const key = String(req.params.key);
    const { progress } = req.body;
    const numProgress = parseFloat(progress);

    if (isNaN(numProgress) || numProgress < 0 || numProgress > 1) {
      return res.status(400).json({ error: 'Invalid progress value' });
    }

    const achievement = await prisma.achievement.upsert({
      where: { userId_key: { userId: req.user.userId, key } },
      update: { progress: numProgress },
      create: { userId: req.user.userId, key, progress: numProgress },
    });

    res.json({ data: achievement });
  } catch (error: any) {
    next(error);
  }
});

export default router;
