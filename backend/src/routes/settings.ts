import { Router } from 'express';
import { prisma } from '../db.js';
import { z, ZodError } from 'zod';

const router = Router();

const settingsSchema = z.record(z.unknown());

router.get('/', async (req, res, next) => {
  try {
    const userSettings = await prisma.userSettings.findUnique({
      where: { userId: req.user.userId },
    });
    res.json({ data: userSettings?.settings ?? {} });
  } catch (error) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const settings = settingsSchema.parse(req.body);
    const updated = await prisma.userSettings.upsert({
      where: { userId: req.user.userId },
      create: { userId: req.user.userId, settings: settings as any },
      update: { settings: settings as any },
    });
    res.json({ data: updated.settings });
  } catch (error) {
    if (error instanceof ZodError) {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

export default router;
