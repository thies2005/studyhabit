import { Router } from 'express';
import { z } from 'zod';
import { SyncService } from '../services/syncService.js';

const router = Router();

const pushSchema = z.object({
  projects: z.array(z.record(z.unknown())).optional(),
  subjects: z.array(z.record(z.unknown())).optional(),
  topics: z.array(z.record(z.unknown())).optional(),
  chapters: z.array(z.record(z.unknown())).optional(),
  sessions: z.array(z.record(z.unknown())).optional(),
  sources: z.array(z.record(z.unknown())).optional(),
  skillLabels: z.array(z.record(z.unknown())).optional(),
  achievements: z.array(z.record(z.unknown())).optional(),
  userStats: z.record(z.unknown()).optional(),
});

router.post('/push', async (req, res, next) => {
  try {
    const payload = pushSchema.parse(req.body);
    const result = await SyncService.pushChanges(req.user.userId, payload);
    res.json({ data: result });
  } catch (error: any) {
    if (error.name === 'ZodError') {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

router.get('/pull', async (req, res, next) => {
  try {
    const since = req.query.since ? String(req.query.since) : undefined;
    const data = await SyncService.fullPull(req.user.userId, since);
    res.json({ data });
  } catch (error: any) {
    next(error);
  }
});

router.post('/full', async (req, res, next) => {
  try {
    const payload = pushSchema.parse(req.body);

    const pushResult = await SyncService.pushChanges(req.user.userId, payload);

    const since = req.query.since ? String(req.query.since) : undefined;
    const pullData = await SyncService.fullPull(req.user.userId, since);

    res.json({
      data: {
        push: pushResult,
        pull: pullData,
      },
    });
  } catch (error: any) {
    if (error.name === 'ZodError') {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

export default router;
