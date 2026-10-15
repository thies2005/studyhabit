import { Router } from 'express';
import { z, ZodError } from 'zod';
import { SyncService } from '../services/syncService.js';
import { prisma } from '../db.js';
import { Prisma } from '@prisma/client';

const userSyncLocks = new Map<string, Promise<void>>();

function withUserLock<T>(userId: string, fn: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
  const existing = userSyncLocks.get(userId) ?? Promise.resolve();
  const newLock = existing
    .then(() =>
      prisma.$transaction(async (tx) => {
        // Stable 32-bit key derived from the userId (crc32-style via md5 prefix).
        const keyResult = await tx.$queryRaw`SELECT ('x' || substr(md5(${userId}::text), 1, 8))::bit(32)::int AS k`;
        const row = (Array.isArray(keyResult) ? keyResult[0] : null) as
          | { k?: number }
          | null;
        const key = row?.k ?? 0;
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(${key})`;
        return fn(tx);
      }, { timeout: 30000 })
    )
    .finally(() => {
      // Clean up only if we're still the latest lock
      if (userSyncLocks.get(userId) === newLock) {
        userSyncLocks.delete(userId);
      }
    });
  userSyncLocks.set(userId, newLock.then(() => {}));
  return newLock;
}

const router = Router();

function parseSince(raw: string | undefined): string | null {
  if (!raw) return null;
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return null;
  return raw;
}

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
    const payload = pushSchema.parse(req.body);
    const result = await withUserLock(req.user.userId, (tx) =>
      SyncService.pushChanges(req.user.userId, payload as any, tx)
    );
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
    const rawSince = req.query.since ? String(req.query.since) : undefined;
    const since = parseSince(rawSince);
    if (!since) {
      return res.status(400).json({
        error: 'Missing or invalid "since" query parameter (expected ISO 8601 datetime)',
      });
    }
    const data = await SyncService.fullPull(req.user.userId, since);
    res.json({ data });
  } catch (error: unknown) {
    next(error);
  }
});

router.post('/full', async (req, res, next) => {
  try {
    const rawSince = req.query.since ? String(req.query.since) : undefined;
    const since = parseSince(rawSince);
    if (!since) {
      return res.status(400).json({
        error: 'Missing or invalid "since" query parameter (expected ISO 8601 datetime)',
      });
    }

    const payload = pushSchema.parse(req.body);

    const result = await withUserLock(req.user.userId, async (tx) => {
      const pushResult = await SyncService.pushChanges(req.user.userId, payload as any, tx);
      const pullData = await SyncService.fullPull(req.user.userId, since, tx);
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
    await withUserLock(userId, async (tx) => {
      await tx.project.deleteMany({ where: { userId } });
      await tx.achievement.deleteMany({ where: { userId } });
      await tx.userStats.deleteMany({ where: { userId } });
      await tx.userSettings.deleteMany({ where: { userId } });
    });
    res.json({ success: true });
  } catch (error: unknown) {
    next(error);
  }
});

export default router;
