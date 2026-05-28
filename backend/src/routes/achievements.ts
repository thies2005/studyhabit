import { Router } from 'express';
import { prisma } from '../db.js';
import { AchievementService } from '../services/achievementService.js';
import { parsePagination } from '../types/index.js';

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where = { userId: req.user.userId };
    const [achievements, total] = await Promise.all([
      prisma.achievement.findMany({
        where,
        orderBy: { unlockedAt: 'desc' },
        skip,
        take,
      }),
      prisma.achievement.count({ where }),
    ]);
    res.json({
      data: achievements,
      pagination: { page, limit, total, hasMore: skip + take < total },
    });
  } catch (error: unknown) {
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
  } catch (error: unknown) {
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
  } catch (error: unknown) {
    next(error);
  }
});

export default router;
