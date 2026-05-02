import { Router } from 'express';
import { prisma } from '../index.js';
import { AchievementService } from '../services/achievementService.js';

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

router.post('/check', async (req, res, next) => {
  try {
    const newlyUnlocked = await AchievementService.checkAndUnlock(req.user.userId);
    const all = await prisma.achievement.findMany({
      where: { userId: req.user.userId },
      orderBy: { unlockedAt: 'desc' },
    });
    res.json({ data: { achievements: all, newlyUnlocked } });
  } catch (error: any) {
    next(error);
  }
});

router.post('/:key/unlock', async (req, res, next) => {
  try {
    const key = String(req.params.key);
    const newlyUnlocked = await AchievementService.checkAndUnlock(req.user.userId);

    if (!newlyUnlocked.includes(key)) {
      return res.status(200).json({
        data: null,
        message: 'Achievement was already unlocked or conditions not met',
      });
    }

    const achievement = await prisma.achievement.findUnique({
      where: { userId_key: { userId: req.user.userId, key } },
    });

    res.json({ data: achievement });
  } catch (error: any) {
    next(error);
  }
});

export default router;
