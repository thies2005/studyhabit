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
  colorValue: z.number().transform(v => v & 0xFFFFFF),
  defaultWorkDuration: z.number(),
  defaultBreakDuration: z.number(),
  defaultLongBreakDuration: z.number(),
  defaultLongBreakEvery: z.number(),
  studyReminderMinutes: z.number(),
  createdAt: z.string().or(z.date()),
  lastOpenedAt: z.string().or(z.date()),
  isArchived: z.boolean(),
  isDeleted: z.boolean().optional(),
  updatedAt: z.string().or(z.date()),
});

const subjectSchema = z.object({
  id: z.string().uuid(),
  projectId: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  colorValue: z.number().transform(v => v & 0xFFFFFF),
  hierarchyMode: z.enum(['flat', 'twoLevel', 'threeLevel']),
  defaultDurationMinutes: z.number(),
  defaultBreakMinutes: z.number(),
  completenessMode: z.enum(['none', 'hoursGoal', 'milestones', 'weeklyHoursGoal']),
  targetHours: z.number().nullable(),
  targetWeeklyHours: z.number().nullable(),
  xpTotal: z.number(),
  createdAt: z.string().or(z.date()),
  isDeleted: z.boolean().optional(),
  updatedAt: z.string().or(z.date()),
});

const topicSchema = z.object({
  id: z.string().uuid(),
  subjectId: z.string().uuid(),
  name: z.string(),
  order: z.number(),
  createdAt: z.string().or(z.date()).optional(),
  isDeleted: z.boolean().optional(),
  updatedAt: z.string().or(z.date()),
});

const chapterSchema = z.object({
  id: z.string().uuid(),
  topicId: z.string().uuid(),
  name: z.string(),
  order: z.number(),
  createdAt: z.string().or(z.date()).optional(),
  isDeleted: z.boolean().optional(),
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
  isDeleted: z.boolean().optional(),
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
  isDeleted: z.boolean().optional(),
  updatedAt: z.string().or(z.date()),
});

const skillLabelSchema = z.object({
  id: z.string().uuid(),
  subjectId: z.string().uuid(),
  topicId: z.string().uuid().nullable(),
  chapterId: z.string().uuid().nullable(),
  label: z.enum(['beginner', 'intermediate', 'advanced', 'expert']),
  isDeleted: z.boolean().optional(),
  updatedAt: z.string().or(z.date()),
});

const achievementSchema = z.object({
  id: z.string().uuid().optional(),
  key: z.string(),
  unlockedAt: z.string().or(z.date()).nullable(),
  progress: z.number(),
  createdAt: z.string().or(z.date()).optional(),
  isDeleted: z.boolean().optional(),
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
  isDeleted: z.boolean().optional(),
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
  isDeleted: z.boolean().optional(),
  updatedAt: z.string().or(z.date()),
});

const userSettingsSchema = z.object({
  settings: z.record(z.unknown()),
  isDeleted: z.boolean().optional(),
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
      prisma.userStats.findFirst({ where: { userId, ...whereClause } }),
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

  // Removed slow verifySubjectOwnership and verifyTopicOwnership


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

    // Pre-fetch all owned IDs to prevent N+1 queries (M2 fix)
    const userProjects = await prisma.project.findMany({ where: { userId }, select: { id: true } });
    const allProjectIds = new Set(userProjects.map(p => p.id));
    const userSubjects = allProjectIds.size > 0 
      ? await prisma.subject.findMany({ where: { projectId: { in: Array.from(allProjectIds) } }, select: { id: true } })
      : [];
    const allSubjectIds = new Set(userSubjects.map(s => s.id));
    const userTopics = allSubjectIds.size > 0
      ? await prisma.topic.findMany({ where: { subjectId: { in: Array.from(allSubjectIds) } }, select: { id: true } })
      : [];
    const allTopicIds = new Set(userTopics.map(t => t.id));

    // Execute the entire push within a single transaction to prevent race conditions (M4 fix)
    await prisma.$transaction(async (tx) => {

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

          const existing = await tx.project.findUnique({
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

          const dataToSave = { ...validated, updatedAt: new Date(validated.updatedAt) };
          await tx.project.upsert({
            where: { id: validated.id },
            create: { ...dataToSave, userId },
            update: dataToSave,
          });
          allProjectIds.add(validated.id);
          a++;
        } catch (e: any) {
          console.error('[SyncService] Project validation failed:', e.message, item);
          errors.push({ entity: 'project', id: item.id || 'unknown', error: e.message });
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

          if (!allProjectIds.has(validated.projectId)) {
            errors.push({ entity: 'subject', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await tx.subject.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          const dataToSave = { ...validated, updatedAt: new Date(validated.updatedAt) };
          await tx.subject.upsert({
            where: { id: validated.id },
            create: dataToSave,
            update: dataToSave,
          });
          allSubjectIds.add(validated.id);
          a++;
        } catch (e: any) {
          console.error('[SyncService] Subject validation failed:', e.message, item);
          errors.push({ entity: 'subject', id: item.id || 'unknown', error: e.message });
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

          const owned = allSubjectIds.has(validated.subjectId);
          if (!owned) {
            errors.push({ entity: 'topic', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await tx.topic.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          const dataToSave = { ...validated, updatedAt: new Date(validated.updatedAt) };
          await tx.topic.upsert({
            where: { id: validated.id },
            create: dataToSave,
            update: dataToSave,
          });
          allTopicIds.add(validated.id);
          a++;
        } catch (e: any) {
          console.error('[SyncService] Topic validation failed:', e.message, item);
          errors.push({ entity: 'topic', id: item.id || 'unknown', error: e.message });
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

          const owned = allTopicIds.has(validated.topicId);
          if (!owned) {
            errors.push({ entity: 'chapter', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await tx.chapter.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          const dataToSave = { ...validated, updatedAt: new Date(validated.updatedAt) };
          await tx.chapter.upsert({
            where: { id: validated.id },
            create: dataToSave,
            update: dataToSave,
          });
          a++;
        } catch (e: any) {
          console.error('[SyncService] Chapter validation failed:', e.message, item);
          errors.push({ entity: 'chapter', id: item.id || 'unknown', error: e.message });
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

          const owned = allSubjectIds.has(validated.subjectId);
          if (!owned) {
            errors.push({ entity: 'session', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await tx.studySession.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          const dataToSave = { ...validated, updatedAt: new Date(validated.updatedAt) };
          await tx.studySession.upsert({
            where: { id: validated.id },
            create: dataToSave,
            update: dataToSave,
          });
          a++;
        } catch (e: any) {
          console.error('[SyncService] Session validation failed:', e.message, item);
          errors.push({ entity: 'session', id: (item as any).id || 'unknown', error: e.message });
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

          const owned = allSubjectIds.has(validated.subjectId);
          if (!owned) {
            errors.push({ entity: 'source', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await tx.source.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          const dataToSave = { ...validated, updatedAt: new Date(validated.updatedAt) };
          await tx.source.upsert({
            where: { id: validated.id },
            create: dataToSave,
            update: dataToSave,
          });
          a++;
        } catch (e: any) {
          console.error('[SyncService] Source validation failed:', e.message, item);
          errors.push({ entity: 'source', id: item.id || 'unknown', error: e.message });
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

          const owned = allSubjectIds.has(validated.subjectId);
          if (!owned) {
            errors.push({ entity: 'skillLabel', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await tx.skillLabel.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          const dataToSave = { ...validated, updatedAt: new Date(validated.updatedAt) };
          await tx.skillLabel.upsert({
            where: { id: validated.id },
            create: dataToSave,
            update: dataToSave,
          });
          a++;
        } catch (e: any) {
          console.error('[SyncService] SkillLabel validation failed:', e.message, item);
          errors.push({ entity: 'skillLabel', id: item.id || 'unknown', error: e.message });
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

          const existing = await tx.achievement.findUnique({
            where: { userId_key: { userId, key: validated.key } },
          });

          // S6 fix: Allow unlock sync — keep earliest unlockedAt
          const incomingUnlock = validated.unlockedAt ? new Date(validated.unlockedAt) : null;
          let finalUnlockedAt: Date | null = null;
          if (existing?.unlockedAt && incomingUnlock) {
            // Both unlocked — keep earliest
            finalUnlockedAt = existing.unlockedAt < incomingUnlock ? existing.unlockedAt : incomingUnlock;
          } else {
            finalUnlockedAt = existing?.unlockedAt ?? incomingUnlock;
          }

          const newProgress = Math.max(validated.progress, existing?.progress ?? 0);

          // Skip if no meaningful change
          if (existing && newProgress === existing.progress && 
              ((finalUnlockedAt === null && existing.unlockedAt === null) ||
               (finalUnlockedAt?.getTime() === existing.unlockedAt?.getTime()))) {
            continue;
          }

          await tx.achievement.upsert({
            where: { userId_key: { userId, key: validated.key } },
            create: {
              key: validated.key,
              userId,
              progress: newProgress,
              unlockedAt: finalUnlockedAt,
              updatedAt: new Date(validated.updatedAt),
            },
            update: {
              progress: newProgress,
              unlockedAt: finalUnlockedAt,
              updatedAt: new Date(validated.updatedAt),
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
          const existing = await tx.userStats.findUnique({
            where: { userId },
          });
          if (existing) {
            // Use last-write-wins: accept all stats if client is newer
            const result = lastWriteWins(validated, existing);
            if (result.accepted) {
              await tx.userStats.update({
                where: { userId },
                data: {
                  totalXp: validated.totalXp,
                  currentLevel: validated.currentLevel,
                  currentStreak: validated.currentStreak,
                  longestStreak: validated.longestStreak,
                  lastStudyDate: validated.lastStudyDate ? new Date(validated.lastStudyDate) : null,
                  totalStudyMinutes: validated.totalStudyMinutes,
                  freezeTokens: validated.freezeTokens,
                  updatedAt: new Date(validated.updatedAt),
                },
              });
              applied.userStats = 1;
            } else {
              conflicts.userStats = 1;
            }
          } else {
            // C2: Create initial stats for new users
            await tx.userStats.create({
              data: {
                userId,
                totalXp: validated.totalXp,
                currentLevel: validated.currentLevel,
                currentStreak: validated.currentStreak,
                longestStreak: validated.longestStreak,
                lastStudyDate: validated.lastStudyDate ? new Date(validated.lastStudyDate) : null,
                totalStudyMinutes: validated.totalStudyMinutes,
                freezeTokens: validated.freezeTokens,
                updatedAt: new Date(validated.updatedAt),
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
        const existing = await tx.userSettings.findUnique({
          where: { userId },
        });

        const incoming = { updatedAt: validated.updatedAt };
        const current = existing ? { updatedAt: existing.updatedAt } : null;
        
        const result = lastWriteWins(incoming, current);
        if (result.accepted) {
          await tx.userSettings.upsert({
            where: { userId },
            create: {
              userId,
              settings: validated.settings as any,
              updatedAt: new Date(validated.updatedAt),
            },
            update: {
              settings: validated.settings as any,
              updatedAt: new Date(validated.updatedAt),
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

          const owned = allSubjectIds.has(validated.subjectId);
          if (!owned) {
            errors.push({ entity: 'subjectMilestone', id: validated.id, error: 'forbidden' });
            continue;
          }

          const existing = await tx.subjectMilestone.findUnique({
            where: { id: validated.id },
          });
          const result = lastWriteWins(validated, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          const dataToSave = { ...validated, updatedAt: new Date(validated.updatedAt) };
          await tx.subjectMilestone.upsert({
            where: { id: validated.id },
            create: dataToSave,
            update: dataToSave,
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
        await AchievementService.checkAndUnlock(userId, tx);
      } catch (e: unknown) {
        errors.push({
          entity: 'achievement',
          id: 'server_check',
          error: e instanceof Error ? e.message : String(e),
        });
      }
    }

    }, { timeout: 30000 }); // End of transaction

    console.log(`[SyncService] Push completed for user ${userId}. Applied:`, applied, 'Conflicts:', conflicts, 'Errors:', errors.length);
    if (errors.length > 0) {
      console.warn(`[SyncService] Push had ${errors.length} errors:`, errors);
    }

    return { applied, conflicts, errors };
  }
}
