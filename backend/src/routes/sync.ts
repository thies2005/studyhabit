import { Router } from 'express';
import { z, ZodError } from 'zod';
import { SyncService } from '../services/syncService.js';
import { prisma } from '../db.js';

// S3 fix: Per-user mutex to prevent concurrent sync operations
const userSyncLocks = new Map<string, Promise<void>>();

function withUserLock<T>(userId: string, fn: () => Promise<T>): Promise<T> {
  const existing = userSyncLocks.get(userId) ?? Promise.resolve();
  const newLock = existing.then(() => fn()).finally(() => {
    // Clean up only if we're still the latest lock
    if (userSyncLocks.get(userId) === newLock) {
      userSyncLocks.delete(userId);
    }
  });
  userSyncLocks.set(userId, newLock.then(() => {}));
  return newLock;
}

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
  userSettings: z.object({
    settings: z.record(z.unknown()),
    updatedAt: z.string().or(z.date()),
  }).optional(),
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
      userSettings?: { settings: unknown; updatedAt: string | Date };
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
    const since = req.query.since ? String(req.query.since) : undefined;
    if (!since) {
      return res.status(400).json({ error: 'Missing "since" query parameter for sync pull' });
    }

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
      userSettings?: { settings: unknown; updatedAt: string | Date };
    };

    // S3 fix: Serialize concurrent syncs for the same user
    const result = await withUserLock(req.user.userId, async () => {
      const pushResult = await SyncService.pushChanges(req.user.userId, payload as any);
      const pullData = await SyncService.fullPull(req.user.userId, since);
      return { push: pushResult, pull: pullData };
    });

    res.json({ data: result });
  } catch (error: unknown) {
    if (error instanceof ZodError) {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

router.post('/erase', async (req, res, next) => {
  try {
    const userId = req.user.userId;
    // Prisma cascades deletes so deleting Projects deletes Subjects, Topics, Chapters, Sessions, Sources, SkillLabels, Milestones
    await prisma.$transaction([
      prisma.project.deleteMany({ where: { userId } }),
      prisma.achievement.deleteMany({ where: { userId } }),
      prisma.userStats.deleteMany({ where: { userId } }),
      prisma.userSettings.deleteMany({ where: { userId } }),
    ]);
    res.json({ success: true });
  } catch (error: unknown) {
    next(error);
  }
});

export default router;
