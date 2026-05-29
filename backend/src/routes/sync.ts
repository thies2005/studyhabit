import { Router } from 'express';
import { z, ZodError } from 'zod';
import { SyncService } from '../services/syncService.js';

const router = Router();

const pushSchema = z.object({
  projects: z.array(z.record(z.unknown())).max(1000).optional(),
  subjects: z.array(z.record(z.unknown())).max(1000).optional(),
  topics: z.array(z.record(z.unknown())).max(1000).optional(),
  chapters: z.array(z.record(z.unknown())).max(1000).optional(),
  sessions: z.array(z.record(z.unknown())).max(1000).optional(),
  sources: z.array(z.record(z.unknown())).max(1000).optional(),
  skillLabels: z.array(z.record(z.unknown())).max(1000).optional(),
  achievements: z.array(z.record(z.unknown())).max(1000).optional(),
  userStats: z.record(z.unknown()).optional(),
  subjectMilestones: z.array(z.record(z.unknown())).max(1000).optional(),
});

router.post('/push', async (req, res, next) => {
  try {
    const payload = pushSchema.parse(req.body) as unknown as {
      projects?: unknown[];
      subjects?: unknown[];
      topics?: unknown[];
      chapters?: unknown[];
      sessions?: unknown[];
      sources?: unknown[];
      skillLabels?: unknown[];
      achievements?: unknown[];
      userStats?: unknown;
      subjectMilestones?: unknown[];
    };
    const result = await SyncService.pushChanges(req.user.userId, payload as any);
    res.json({ data: result });
  } catch (error: unknown) {
    if (error instanceof ZodError) {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

router.get('/pull', async (req, res, next) => {
  try {
    const since = req.query.since ? String(req.query.since) : undefined;
    if (!since) {
      return res.status(400).json({ error: 'Missing "since" query parameter for sync pull' });
    }
    const data = await SyncService.fullPull(req.user.userId, since);
    res.json({ data });
  } catch (error: unknown) {
    next(error);
  }
});

router.post('/full', async (req, res, next) => {
  try {
    const payload = pushSchema.parse(req.body) as unknown as {
      projects?: unknown[];
      subjects?: unknown[];
      topics?: unknown[];
      chapters?: unknown[];
      sessions?: unknown[];
      sources?: unknown[];
      skillLabels?: unknown[];
      achievements?: unknown[];
      userStats?: unknown;
      subjectMilestones?: unknown[];
    };

    const pushResult = await SyncService.pushChanges(req.user.userId, payload as any);

    const since = req.query.since ? String(req.query.since) : undefined;
    if (!since) {
      return res.status(400).json({ error: 'Missing "since" query parameter for sync pull' });
    }
    const pullData = await SyncService.fullPull(req.user.userId, since);

    res.json({
      data: {
        push: pushResult,
        pull: pullData,
      },
    });
  } catch (error: unknown) {
    if (error instanceof ZodError) {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

export default router;
