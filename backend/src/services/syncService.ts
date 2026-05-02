import { prisma } from '../index.js';
import { SyncPushPayload, SyncPullResponse } from '../types/index.js';
import { z } from 'zod';

// Define Zod schemas for each entity type to validate and strip unknown fields
const projectSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().uuid(),
  name: z.string(),
  icon: z.string(),
  colorValue: z.number(),
  createdAt: z.string().or(z.date()),
  lastOpenedAt: z.string().or(z.date()),
  isArchived: z.boolean(),
  updatedAt: z.string().or(z.date()),
});

const subjectSchema = z.object({
  id: z.string().uuid(),
  projectId: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  colorValue: z.number(),
  hierarchyMode: z.enum(['flat', 'twoLevel', 'threeLevel']),
  defaultDurationMinutes: z.number(),
  defaultBreakMinutes: z.number(),
  xpTotal: z.number(),
  createdAt: z.string().or(z.date()),
  updatedAt: z.string().or(z.date()),
});

const topicSchema = z.object({
  id: z.string().uuid(),
  subjectId: z.string().uuid(),
  name: z.string(),
  order: z.number(),
  createdAt: z.string().or(z.date()),
  updatedAt: z.string().or(z.date()),
});

const chapterSchema = z.object({
  id: z.string().uuid(),
  topicId: z.string().uuid(),
  name: z.string(),
  order: z.number(),
  createdAt: z.string().or(z.date()),
  updatedAt: z.string().or(z.date()),
});

const sessionSchema = z.object({
  id: z.string().uuid(),
  subjectId: z.string().uuid(),
  topicId: z.string().uuid().nullable(),
  chapterId: z.string().uuid().nullable(),
  startedAt: z.string().or(z.date()),
  endedAt: z.string().or(z.date()).nullable(),
  plannedDurationMinutes: z.number(),
  actualDurationMinutes: z.number(),
  pomodorosCompleted: z.number(),
  confidenceRating: z.number().nullable(),
  notes: z.string().nullable(),
  xpEarned: z.number(),
  createdAt: z.string().or(z.date()),
  updatedAt: z.string().or(z.date()),
});

const sourceSchema = z.object({
  id: z.string().uuid(),
  subjectId: z.string().uuid(),
  topicId: z.string().uuid().nullable(),
  chapterId: z.string().uuid().nullable(),
  type: z.enum(['pdf', 'url', 'videoUrl']),
  title: z.string(),
  filePath: z.string().nullable(),
  url: z.string().nullable(),
  currentPage: z.number().nullable(),
  totalPages: z.number().nullable(),
  progressPercent: z.number().nullable(),
  notes: z.string().nullable(),
  addedAt: z.string().or(z.date()),
  updatedAt: z.string().or(z.date()),
});

const skillLabelSchema = z.object({
  id: z.string().uuid(),
  subjectId: z.string().uuid(),
  topicId: z.string().uuid().nullable(),
  chapterId: z.string().uuid().nullable(),
  label: z.enum(['beginner', 'intermediate', 'advanced', 'expert']),
  updatedAt: z.string().or(z.date()),
});

const achievementSchema = z.object({
  id: z.string().uuid().optional(),
  key: z.string(),
  unlockedAt: z.string().or(z.date()).nullable(),
  progress: z.number(),
  createdAt: z.string().or(z.date()),
  updatedAt: z.string().or(z.date()),
});

const userStatsSchema = z.object({
  id: z.string().uuid().optional(),
  userId: z.string().uuid(),
  totalXp: z.number(),
  currentLevel: z.number(),
  currentStreak: z.number(),
  longestStreak: z.number(),
  lastStudyDate: z.string().or(z.date()).nullable(),
  totalStudyMinutes: z.number(),
  freezeTokens: z.number(),
  createdAt: z.string().or(z.date()),
  updatedAt: z.string().or(z.date()),
});

interface ConflictResult {
  accepted: boolean;
  reason?: string;
}

function lastWriteWins(incoming: any, existing: any): ConflictResult {
  if (!existing) return { accepted: true };
  if (new Date(incoming.updatedAt) > new Date(existing.updatedAt)) {
    return { accepted: true };
  }
  return { accepted: false, reason: 'server_newer' };
}

export class SyncService {
  static async fullPull(userId: string, since?: string): Promise<SyncPullResponse> {
    const whereClause = since
      ? { updatedAt: { gt: new Date(since) } }
      : {};

    const projects = await prisma.project.findMany({
      where: { userId, ...whereClause },
    });

    const projectIds = projects.map((p) => p.id);

    const subjects = projectIds.length
      ? await prisma.subject.findMany({
          where: { projectId: { in: projectIds }, ...whereClause },
        })
      : [];

    const subjectIds = subjects.map((s) => s.id);

    const [topics, sessions, sources, skillLabels] = await Promise.all([
      subjectIds.length
        ? prisma.topic.findMany({
            where: { subjectId: { in: subjectIds }, ...whereClause },
          })
        : [],
      subjectIds.length
        ? prisma.studySession.findMany({
            where: { subjectId: { in: subjectIds }, ...whereClause },
          })
        : [],
      subjectIds.length
        ? prisma.source.findMany({
            where: { subjectId: { in: subjectIds }, ...whereClause },
          })
        : [],
      subjectIds.length
        ? prisma.skillLabel.findMany({
            where: { subjectId: { in: subjectIds }, ...whereClause },
          })
        : [],
    ]);

    const topicIds = topics.map((t) => t.id);

    const chapters = topicIds.length
      ? await prisma.chapter.findMany({
          where: { topicId: { in: topicIds }, ...whereClause },
        })
      : [];

    const [achievements, userStats] = await Promise.all([
      prisma.achievement.findMany({
        where: { userId, ...whereClause },
      }),
      prisma.userStats.findUnique({ where: { userId } }),
    ]);

    return {
      serverTime: new Date().toISOString(),
      projects,
      subjects,
      topics,
      chapters,
      sessions,
      sources,
      skillLabels,
      achievements,
      userStats,
    };
  }

  private static async verifySubjectOwnership(subjectId: string, userId: string): Promise<boolean> {
    const subject = await prisma.subject.findUnique({
      where: { id: subjectId },
      include: { project: true },
    });
    return !!subject && subject.project.userId === userId;
  }

  private static async verifyTopicOwnership(topicId: string, userId: string): Promise<boolean> {
    const topic = await prisma.topic.findUnique({
      where: { id: topicId },
      include: { subject: { include: { project: true } } },
    });
    return !!topic && topic.subject.project.userId === userId;
  }

  static async pushChanges(
    userId: string,
    payload: SyncPushPayload
  ): Promise<{
    applied: Record<string, number>;
    conflicts: Record<string, number>;
    errors: Array<{ entity: string; id: string; error: string }>;
  }> {
    const applied: Record<string, number> = {};
    const conflicts: Record<string, number> = {};
    const errors: Array<{ entity: string; id: string; error: string }> = [];

    // Note: Per-item try/catch is intentional for sync — one bad record
    // should not roll back the entire batch. If atomic per-entity-type
    // is needed, wrap each section in prisma.$transaction().

    if (payload.projects?.length) {
      let a = 0;
      let c = 0;
      for (const item of payload.projects) {
        try {
          // Validate and strip unknown fields
          const validated = projectSchema.parse(item);

          const existing = await prisma.project.findUnique({
            where: { id: validated.id },
          });

          if (existing && existing.userId !== userId) {
            errors.push({ entity: 'project', id: validated.id, error: 'forbidden' });
            continue;
          }

          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.project.upsert({
            where: { id: validated.id },
            create: { ...validated, userId },
            update: validated,
          });
          a++;
        } catch (e: any) {
          errors.push({ entity: 'project', id: item.id, error: e.message });
        }
      }
      applied.projects = a;
      conflicts.projects = c;
    }

    if (payload.subjects?.length) {
      let a = 0;
      let c = 0;
      for (const item of payload.subjects) {
        try {
          // Validate and strip unknown fields
          const validated = subjectSchema.parse(item);

          const project = await prisma.project.findUnique({
            where: { id: validated.projectId },
          });
          if (!project || project.userId !== userId) {
            errors.push({ entity: 'subject', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.subject.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.subject.upsert({
            where: { id: validated.id },
            create: validated,
            update: validated,
          });
          a++;
        } catch (e: any) {
          errors.push({ entity: 'subject', id: item.id, error: e.message });
        }
      }
      applied.subjects = a;
      conflicts.subjects = c;
    }

    if (payload.topics?.length) {
      let a = 0;
      let c = 0;
      for (const item of payload.topics) {
        try {
          // Validate and strip unknown fields
          const validated = topicSchema.parse(item);

          const owned = await SyncService.verifySubjectOwnership(validated.subjectId, userId);
          if (!owned) {
            errors.push({ entity: 'topic', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.topic.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.topic.upsert({
            where: { id: validated.id },
            create: validated,
            update: validated,
          });
          a++;
        } catch (e: any) {
          errors.push({ entity: 'topic', id: item.id, error: e.message });
        }
      }
      applied.topics = a;
      conflicts.topics = c;
    }

    if (payload.chapters?.length) {
      let a = 0;
      let c = 0;
      for (const item of payload.chapters) {
        try {
          // Validate and strip unknown fields
          const validated = chapterSchema.parse(item);

          const owned = await SyncService.verifyTopicOwnership(validated.topicId, userId);
          if (!owned) {
            errors.push({ entity: 'chapter', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.chapter.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.chapter.upsert({
            where: { id: validated.id },
            create: validated,
            update: validated,
          });
          a++;
        } catch (e: any) {
          errors.push({ entity: 'chapter', id: item.id, error: e.message });
        }
      }
      applied.chapters = a;
      conflicts.chapters = c;
    }

    if (payload.sessions?.length) {
      let a = 0;
      let c = 0;
      for (const item of payload.sessions) {
        try {
          // Validate and strip unknown fields
          const validated = sessionSchema.parse(item);

          const owned = await SyncService.verifySubjectOwnership(validated.subjectId, userId);
          if (!owned) {
            errors.push({ entity: 'session', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.studySession.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.studySession.upsert({
            where: { id: validated.id },
            create: validated,
            update: validated,
          });
          a++;
        } catch (e: any) {
          errors.push({ entity: 'session', id: item.id, error: e.message });
        }
      }
      applied.sessions = a;
      conflicts.sessions = c;
    }

    if (payload.sources?.length) {
      let a = 0;
      let c = 0;
      for (const item of payload.sources) {
        try {
          // Validate and strip unknown fields
          const validated = sourceSchema.parse(item);

          const owned = await SyncService.verifySubjectOwnership(validated.subjectId, userId);
          if (!owned) {
            errors.push({ entity: 'source', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.source.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.source.upsert({
            where: { id: validated.id },
            create: validated,
            update: validated,
          });
          a++;
        } catch (e: any) {
          errors.push({ entity: 'source', id: item.id, error: e.message });
        }
      }
      applied.sources = a;
      conflicts.sources = c;
    }

    if (payload.skillLabels?.length) {
      let a = 0;
      let c = 0;
      for (const item of payload.skillLabels) {
        try {
          // Validate and strip unknown fields
          const validated = skillLabelSchema.parse(item);

          const owned = await SyncService.verifySubjectOwnership(validated.subjectId, userId);
          if (!owned) {
            errors.push({ entity: 'skillLabel', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.skillLabel.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.skillLabel.upsert({
            where: { id: validated.id },
            create: validated,
            update: validated,
          });
          a++;
        } catch (e: any) {
          errors.push({ entity: 'skillLabel', id: item.id, error: e.message });
        }
      }
      applied.skillLabels = a;
      conflicts.skillLabels = c;
    }

    if (payload.achievements?.length) {
      let a = 0;
      for (const item of payload.achievements) {
        try {
          // Validate and strip unknown fields
          const validated = achievementSchema.parse(item);

          if (validated.unlockedAt) {
            errors.push({ entity: 'achievement', id: validated.key, error: 'unlock_not_allowed_via_sync' });
            continue;
          }

          const existing = await prisma.achievement.findUnique({
            where: { userId_key: { userId, key: validated.key } },
          });
          if (existing && validated.progress <= existing.progress) continue;

          await prisma.achievement.upsert({
            where: { userId_key: { userId, key: validated.key } },
            create: { ...validated, userId, unlockedAt: null },
            update: {
              ...(validated.progress > (existing?.progress ?? 0)
                ? { progress: validated.progress }
                : {}),
            },
          });
          a++;
        } catch (e: any) {
          errors.push({ entity: 'achievement', id: item.key, error: e.message });
        }
      }
      applied.achievements = a;
    }

    if (payload.userStats) {
      try {
        // Validate and strip unknown fields
        const validated = userStatsSchema.parse(payload.userStats);

        const existing = await prisma.userStats.findUnique({
          where: { userId },
        });
        if (existing) {
          const incomingUpdated = validated.updatedAt
            ? new Date(validated.updatedAt)
            : new Date(0);
          if (incomingUpdated <= existing.updatedAt) {
            conflicts.userStats = 1;
          } else {
            const updates: any = {};
            if (validated.totalXp > existing.totalXp) {
              updates.totalXp = validated.totalXp;
            }
            if (validated.currentStreak > existing.currentStreak) {
              updates.currentStreak = validated.currentStreak;
              updates.longestStreak = Math.max(
                existing.longestStreak,
                validated.currentStreak
              );
            }
            if (validated.totalStudyMinutes > existing.totalStudyMinutes) {
              updates.totalStudyMinutes = validated.totalStudyMinutes;
            }
            if (Object.keys(updates).length > 0) {
              await prisma.userStats.update({ where: { userId }, data: updates });
              applied.userStats = 1;
            } else {
              conflicts.userStats = 1;
            }
          }
        }
      } catch (e: any) {
        errors.push({ entity: 'userStats', id: userId, error: e.message });
      }
    }

    return { applied, conflicts, errors };
  }
}
