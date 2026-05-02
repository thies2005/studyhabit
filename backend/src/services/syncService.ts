import { prisma } from '../index.js';
import { SyncPushPayload, SyncPullResponse } from '../types/index.js';

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
          const existing = await prisma.project.findUnique({
            where: { id: item.id },
          });

          if (existing && existing.userId !== userId) {
            errors.push({ entity: 'project', id: item.id, error: 'forbidden' });
            continue;
          }

          const result = lastWriteWins(item, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.project.upsert({
            where: { id: item.id },
            create: { ...item, userId },
            update: item,
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
          const project = await prisma.project.findUnique({
            where: { id: item.projectId },
          });
          if (!project || project.userId !== userId) {
            errors.push({ entity: 'subject', id: item.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.subject.findUnique({
            where: { id: item.id },
          });
          const result = lastWriteWins(item, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.subject.upsert({
            where: { id: item.id },
            create: item,
            update: item,
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
          const owned = await SyncService.verifySubjectOwnership(item.subjectId, userId);
          if (!owned) {
            errors.push({ entity: 'topic', id: item.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.topic.findUnique({
            where: { id: item.id },
          });
          const result = lastWriteWins(item, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.topic.upsert({
            where: { id: item.id },
            create: item,
            update: item,
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
          const owned = await SyncService.verifyTopicOwnership(item.topicId, userId);
          if (!owned) {
            errors.push({ entity: 'chapter', id: item.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.chapter.findUnique({
            where: { id: item.id },
          });
          const result = lastWriteWins(item, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.chapter.upsert({
            where: { id: item.id },
            create: item,
            update: item,
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
          const owned = await SyncService.verifySubjectOwnership(item.subjectId, userId);
          if (!owned) {
            errors.push({ entity: 'session', id: item.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.studySession.findUnique({
            where: { id: item.id },
          });
          const result = lastWriteWins(item, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.studySession.upsert({
            where: { id: item.id },
            create: item,
            update: item,
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
          const owned = await SyncService.verifySubjectOwnership(item.subjectId, userId);
          if (!owned) {
            errors.push({ entity: 'source', id: item.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.source.findUnique({
            where: { id: item.id },
          });
          const result = lastWriteWins(item, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.source.upsert({
            where: { id: item.id },
            create: item,
            update: item,
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
          const owned = await SyncService.verifySubjectOwnership(item.subjectId, userId);
          if (!owned) {
            errors.push({ entity: 'skillLabel', id: item.id, error: 'forbidden' });
            continue;
          }

          const existing = await prisma.skillLabel.findUnique({
            where: { id: item.id },
          });
          const result = lastWriteWins(item, existing);
          if (!result.accepted) {
            c++;
            continue;
          }

          await prisma.skillLabel.upsert({
            where: { id: item.id },
            create: item,
            update: item,
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
          if (item.unlockedAt) {
            errors.push({ entity: 'achievement', id: item.key, error: 'unlock_not_allowed_via_sync' });
            continue;
          }

          const existing = await prisma.achievement.findUnique({
            where: { userId_key: { userId, key: item.key } },
          });
          if (existing && item.progress <= existing.progress) continue;

          await prisma.achievement.upsert({
            where: { userId_key: { userId, key: item.key } },
            create: { ...item, userId, unlockedAt: null },
            update: {
              ...(item.progress > (existing?.progress ?? 0)
                ? { progress: item.progress }
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
        const existing = await prisma.userStats.findUnique({
          where: { userId },
        });
        if (existing) {
          const incomingUpdated = payload.userStats.updatedAt
            ? new Date(payload.userStats.updatedAt)
            : new Date(0);
          if (incomingUpdated <= existing.updatedAt) {
            conflicts.userStats = 1;
          } else {
            const updates: any = {};
            if (payload.userStats.totalXp > existing.totalXp) {
              updates.totalXp = payload.userStats.totalXp;
            }
            if (payload.userStats.currentStreak > existing.currentStreak) {
              updates.currentStreak = payload.userStats.currentStreak;
              updates.longestStreak = Math.max(
                existing.longestStreak,
                payload.userStats.currentStreak
              );
            }
            if (payload.userStats.totalStudyMinutes > existing.totalStudyMinutes) {
              updates.totalStudyMinutes = payload.userStats.totalStudyMinutes;
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
