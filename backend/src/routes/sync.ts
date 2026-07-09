import { Router } from 'express';
import { z, ZodError } from 'zod';
import { SyncService } from '../services/syncService.js';
import { prisma } from '../db.js';

// S3 fix: Per-user mutex to prevent concurrent sync operations. The in-process
// Map serializes concurrent requests within a single API instance (fast path).
// On top of that, a Postgres transaction-level advisory lock serializes sync
// across replicas/instances, so horizontal scaling can't let two instances run
// sync/full for the same user at once. The advisory lock auto-releases when the
// surrounding transaction commits or rolls back.
const userSyncLocks = new Map<string, Promise<void>>();

function withUserLock<T>(userId: string, fn: () => Promise<T>): Promise<T> {
  const existing = userSyncLocks.get(userId) ?? Promise.resolve();
  const newLock = existing
    .then(() =>
      // Acquire a DB-level advisory lock for cross-instance safety, then run
      // the operation, then release by committing the lock transaction.
      prisma.$transaction(async (tx) => {
        // Stable 32-bit key derived from the userId (crc32-style via md5 prefix).
        const keyResult = await tx.$queryRaw`SELECT ('x' || substr(md5(${userId}::text), 1, 8))::bit(32)::int AS k`;
        const row = (Array.isArray(keyResult) ? keyResult[0] : null) as
          | { k?: number }
          | null;
        const key = row?.k ?? 0;
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(${key})`;
        return fn();
      })
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

// Validate the `since` query param (ISO 8601 datetime). Returns the raw string
// on success or a 400-error message string on failure.
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
