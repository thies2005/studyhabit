import { prisma } from '../db.js';
import {
  SyncPushPayload,
  SyncPullResponse,
  SyncProject,
  SyncSubject,
  SyncTopic,
  SyncChapter,
  SyncSession,
  SyncSource,
  SyncSkillLabel,
  SyncAchievement,
  SyncUserStats,
} from '../types/index.js';
import { z } from 'zod';
import { AchievementService } from './achievementService.js';

// Define Zod schemas for each entity type to validate and strip unknown fields
const projectSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().uuid(),
  name: z.string(),
  icon: z.string(),
  colorValue: z.number(),
  defaultWorkDuration: z.number(),
  defaultBreakDuration: z.number(),
  defaultLongBreakDuration: z.number(),
  defaultLongBreakEvery: z.number(),
  studyReminderMinutes: z.number(),
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
  completenessMode: z.enum(['none', 'hoursGoal', 'milestones', 'weeklyHoursGoal']),
  targetHours: z.number().nullable(),
  targetWeeklyHours: z.number().nullable(),
  xpTotal: z.number(),
  createdAt: z.string().or(z.date()),
  updatedAt: z.string().or(z.date()),
});

const topicSchema = z.object({
  id: z.string().uuid(),
  subjectId: z.string().uuid(),
  name: z.string(),
  order: z.number(),
  createdAt: z.string().or(z.date()).optional(),
  updatedAt: z.string().or(z.date()),
});

const chapterSchema = z.object({
  id: z.string().uuid(),
  topicId: z.string().uuid(),
  name: z.string(),
  order: z.number(),
  createdAt: z.string().or(z.date()).optional(),
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
  sourceId: z.string().nullable(),
  startPage: z.number().nullable(),
  endPage: z.number().nullable(),
  isFreeTimer: z.boolean(),
  createdAt: z.string().or(z.date()).optional(),
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
  createdAt: z.string().or(z.date()).optional(),
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
  createdAt: z.string().or(z.date()).optional(),
  updatedAt: z.string().or(z.date()),
});

const subjectMilestoneSchema = z.object({
  id: z.string().uuid(),
  subjectId: z.string().uuid(),
  title: z.string(),
  isCompleted: z.boolean(),
  sortOrder: z.number(),
  completedAt: z.string().or(z.date()).nullable(),
  createdAt: z.string().or(z.date()).optional(),
  updatedAt: z.string().or(z.date()),
});

const userSettingsSchema = z.object({
  settings: z.record(z.unknown()),
  updatedAt: z.string().or(z.date()),
});

interface ConflictResult {
  accepted: boolean;
  reason?: string;
}

interface TimestampedEntity {
  updatedAt: string | Date;
}

function lastWriteWins(incoming: TimestampedEntity, existing: TimestampedEntity | null | undefined): ConflictResult {
  if (!existing) return { accepted: true };
  if (new Date(incoming.updatedAt) > new Date(existing.updatedAt)) {
    return { accepted: true };
  }
  return { accepted: false, reason: 'server_newer' };
}

export class SyncService {
  static async fullPull(userId: string, since: string): Promise<SyncPullResponse> {
    const whereClause = { updatedAt: { gt: new Date(since) } };

    // 1. Get all IDs for scoping (not just updated ones)
    const userProjects = await prisma.project.findMany({ where: { userId }, select: { id: true } });
    const allProjectIds = userProjects.map(p => p.id);
    
    const userSubjects = allProjectIds.length 
      ? await prisma.subject.findMany({ where: { projectId: { in: allProjectIds } }, select: { id: true } })
      : [];
    const allSubjectIds = userSubjects.map(s => s.id);
    
    const userTopics = allSubjectIds.length
      ? await prisma.topic.findMany({ where: { subjectId: { in: allSubjectIds } }, select: { id: true } })
      : [];
    const allTopicIds = userTopics.map(t => t.id);

    // 2. Fetch actually updated records
    const projects = await prisma.project.findMany({
      where: { userId, ...whereClause },
    });

    const subjects = allProjectIds.length
      ? (await prisma.subject.findMany({
          where: { projectId: { in: allProjectIds }, ...whereClause },
        })) as any as SyncSubject[]
      : [];

    const [topics, sessions, sources, skillLabels] = await Promise.all([
      allSubjectIds.length
        ? prisma.topic.findMany({
            where: { subjectId: { in: allSubjectIds }, ...whereClause },
          })
        : [],
      allSubjectIds.length
        ? prisma.studySession.findMany({
            where: { subjectId: { in: allSubjectIds }, ...whereClause },
          })
        : [],
      allSubjectIds.length
        ? prisma.source.findMany({
            where: { subjectId: { in: allSubjectIds }, ...whereClause },
          })
        : [],
      allSubjectIds.length
        ? prisma.skillLabel.findMany({
            where: { subjectId: { in: allSubjectIds }, ...whereClause },
          })
        : [],
    ]);

    const chapters = allTopicIds.length
      ? await prisma.chapter.findMany({
          where: { topicId: { in: allTopicIds }, ...whereClause },
        })
      : [];

    const [achievements, userStats, subjectMilestones] = await Promise.all([
      prisma.achievement.findMany({
        where: { userId, ...whereClause },
      }),
      prisma.userStats.findUnique({ where: { userId } }),
      allSubjectIds.length
        ? prisma.subjectMilestone.findMany({
            where: { subjectId: { in: allSubjectIds }, ...whereClause },
          })
        : [],
    ]);

    const userSettings = await prisma.userSettings.findUnique({ where: { userId } });
    let userSettingsPayload;
    if (userSettings && new Date(userSettings.updatedAt) > new Date(since)) {
      userSettingsPayload = {
        settings: userSettings.settings,
        updatedAt: userSettings.updatedAt,
      };
    }

    return {
      serverTime: new Date().toISOString(),
      projects,
      subjects,
      topics,
      chapters,
      sessions,
      sources: sources as any as SyncSource[],
      skillLabels: skillLabels as any as SyncSkillLabel[],
      achievements,
      userStats,
      subjectMilestones,
      userSettings: userSettingsPayload,
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

          // Verify that the userId in payload matches authenticated user
          if (validated.userId !== userId) {
            errors.push({ entity: 'project', id: validated.id, error: 'forbidden' });
            continue;
          }

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
        } catch (e: unknown) {
          const message = e instanceof Error ? e.message : String(e);
          errors.push({ entity: 'project', id: item.id, error: message });
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
        } catch (e: unknown) {
          errors.push({ entity: 'subject', id: item.id, error: e instanceof Error ? e.message : String(e) });
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
        } catch (e: unknown) {
          errors.push({ entity: 'topic', id: item.id, error: e instanceof Error ? e.message : String(e) });
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
        } catch (e: unknown) {
          errors.push({ entity: 'chapter', id: item.id, error: e instanceof Error ? e.message : String(e) });
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
        } catch (e: unknown) {
          const message = e instanceof Error ? e.message : String(e);
          errors.push({ entity: 'session', id: (item as any).id, error: message });
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
        } catch (e: unknown) {
          errors.push({ entity: 'source', id: item.id, error: e instanceof Error ? e.message : String(e) });
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
        } catch (e: unknown) {
          errors.push({ entity: 'skillLabel', id: item.id, error: e instanceof Error ? e.message : String(e) });
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
        } catch (e: unknown) {
          errors.push({ entity: 'achievement', id: item.key, error: e instanceof Error ? e.message : String(e) });
        }
      }
      applied.achievements = a;
    }

    if (payload.userStats) {
      try {
        // Validate and strip unknown fields
        const validated = userStatsSchema.parse(payload.userStats);

        // Verify that the userId in payload matches authenticated user
        if (validated.userId !== userId) {
          errors.push({ entity: 'userStats', id: userId, error: 'forbidden' });
        } else {
          const existing = await prisma.userStats.findUnique({
            where: { userId },
          });
          if (existing) {
            const updates: {
              totalXp?: number;
              currentLevel?: number;
              currentStreak?: number;
              longestStreak?: number;
              lastStudyDate?: Date;
              totalStudyMinutes?: number;
              freezeTokens?: number;
            } = {};
            if (validated.totalXp > existing.totalXp) {
              updates.totalXp = validated.totalXp;
            }
            if (validated.currentLevel > existing.currentLevel) {
              updates.currentLevel = validated.currentLevel;
            }
            if (validated.currentStreak > existing.currentStreak) {
              updates.currentStreak = validated.currentStreak;
              updates.longestStreak = Math.max(
                existing.longestStreak,
                validated.currentStreak
              );
            }
            if (validated.lastStudyDate && (!existing.lastStudyDate || new Date(validated.lastStudyDate) > existing.lastStudyDate)) {
              updates.lastStudyDate = new Date(validated.lastStudyDate);
            }
            if (validated.totalStudyMinutes > existing.totalStudyMinutes) {
              updates.totalStudyMinutes = validated.totalStudyMinutes;
            }
            if (validated.freezeTokens > existing.freezeTokens) {
              updates.freezeTokens = validated.freezeTokens;
            }
            if (Object.keys(updates).length > 0) {
              await prisma.userStats.update({ where: { userId }, data: updates });
              applied.userStats = 1;
            } else {
              conflicts.userStats = 1;
            }
          } else {
            // C2: Create initial stats for new users
            await prisma.userStats.create({
              data: {
                userId,
                totalXp: validated.totalXp,
                currentLevel: validated.currentLevel,
                currentStreak: validated.currentStreak,
                longestStreak: validated.longestStreak,
                lastStudyDate: validated.lastStudyDate ? new Date(validated.lastStudyDate) : null,
                totalStudyMinutes: validated.totalStudyMinutes,
                freezeTokens: validated.freezeTokens,
              }
            });
            applied.userStats = 1;
          }
        }
      } catch (e: unknown) {
        errors.push({ entity: 'userStats', id: userId, error: e instanceof Error ? e.message : String(e) });
      }
    }

    if (payload.userSettings) {
      try {
        const validated = userSettingsSchema.parse(payload.userSettings);
        const existing = await prisma.userSettings.findUnique({
          where: { userId },
        });

        const incoming = { updatedAt: validated.updatedAt };
        const current = existing ? { updatedAt: existing.updatedAt } : null;
        
        const result = lastWriteWins(incoming, current);
        if (result.accepted) {
          await prisma.userSettings.upsert({
            where: { userId },
            create: {
              userId,
              settings: validated.settings as any,
            },
            update: {
              settings: validated.settings as any,
            },
          });
          applied.userSettings = 1;
        } else {
          conflicts.userSettings = 1;
        }
      } catch (e: unknown) {
        errors.push({ entity: 'userSettings', id: userId, error: e instanceof Error ? e.message : String(e) });
      }
    }

    if (payload.subjectMilestones?.length) {
      let a = 0;
      let c = 0;
      for (const item of payload.subjectMilestones) {
        try {
          const validated = subjectMilestoneSchema.parse(item);

          const owned = await SyncService.verifySubjectOwnership(validated.subjectId, userId);
          if (!owned) {
            errors.push({ entity: 'subjectMilestone', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.subjectMilestone.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.subjectMilestone.upsert({
            where: { id: validated.id },
            create: validated,
            update: validated,
          });
          a++;
        } catch (e: unknown) {
          errors.push({ entity: 'subjectMilestone', id: item.id, error: e instanceof Error ? e.message : String(e) });
        }
      }
      applied.subjectMilestones = a;
      conflicts.subjectMilestones = c;
    }

    if (
      (applied.sessions ?? 0) > 0 ||
      (applied.skillLabels ?? 0) > 0 ||
      (applied.sources ?? 0) > 0 ||
      (applied.userStats ?? 0) > 0 ||
      (applied.userSettings ?? 0) > 0 ||
      (applied.subjectMilestones ?? 0) > 0
    ) {
      try {
        await AchievementService.checkAndUnlock(userId);
      } catch (e: unknown) {
        errors.push({
          entity: 'achievement',
          id: 'server_check',
          error: e instanceof Error ? e.message : String(e),
        });
      }
    }

    return { applied, conflicts, errors };
  }
}
