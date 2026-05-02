import { prisma } from '../index.js';

interface AchievementThreshold {
  key: string;
  check: (stats: AchievementContext) => boolean;
  progress: (stats: AchievementContext) => number;
}

interface AchievementContext {
  totalSessions: number;
  totalPomodoros: number;
  totalMinutes: number;
  currentStreak: number;
  subjectHours: Record<string, number>;
  hasPdf: boolean;
  maxConfidence: number;
  hasAdvancedSkill: boolean;
  unlockedKeys: Set<string>;
}

const ACHIEVEMENT_THRESHOLDS: AchievementThreshold[] = [
  {
    key: 'streak_3',
    check: (s) => s.currentStreak >= 3,
    progress: (s) => Math.min(s.currentStreak / 3, 1),
  },
  {
    key: 'streak_7',
    check: (s) => s.currentStreak >= 7,
    progress: (s) => Math.min(s.currentStreak / 7, 1),
  },
  {
    key: 'streak_30',
    check: (s) => s.currentStreak >= 30,
    progress: (s) => Math.min(s.currentStreak / 30, 1),
  },
  {
    key: 'streak_100',
    check: (s) => s.currentStreak >= 100,
    progress: (s) => Math.min(s.currentStreak / 100, 1),
  },
  {
    key: 'pomodoro_10',
    check: (s) => s.totalPomodoros >= 10,
    progress: (s) => Math.min(s.totalPomodoros / 10, 1),
  },
  {
    key: 'pomodoro_100',
    check: (s) => s.totalPomodoros >= 100,
    progress: (s) => Math.min(s.totalPomodoros / 100, 1),
  },
  {
    key: 'pomodoro_500',
    check: (s) => s.totalPomodoros >= 500,
    progress: (s) => Math.min(s.totalPomodoros / 500, 1),
  },
  {
    key: 'hours_10',
    check: (s) => s.totalMinutes >= 600,
    progress: (s) => Math.min(s.totalMinutes / 600, 1),
  },
  {
    key: 'hours_100',
    check: (s) => s.totalMinutes >= 6000,
    progress: (s) => Math.min(s.totalMinutes / 6000, 1),
  },
  {
    key: 'subject_5h',
    check: (s) => Object.values(s.subjectHours).some((h) => h >= 300),
    progress: (s) => Math.min(Math.max(...Object.values(s.subjectHours), 0) / 300, 1),
  },
  {
    key: 'subject_10h',
    check: (s) => Object.values(s.subjectHours).some((h) => h >= 600),
    progress: (s) => Math.min(Math.max(...Object.values(s.subjectHours), 0) / 600, 1),
  },
  {
    key: 'first_pdf',
    check: (s) => s.hasPdf,
    progress: (s) => s.hasPdf ? 1 : 0,
  },
  {
    key: 'confidence_5',
    check: (s) => s.maxConfidence >= 5,
    progress: (s) => Math.min(s.maxConfidence / 5, 1),
  },
  {
    key: 'skill_advanced',
    check: (s) => s.hasAdvancedSkill,
    progress: (s) => s.hasAdvancedSkill ? 1 : 0,
  },
  {
    key: 'all_badges',
    check: (s) => {
      const allOtherKeys = ACHIEVEMENT_THRESHOLDS
        .filter((a) => a.key !== 'all_badges')
        .map((a) => a.key);
      return allOtherKeys.every((k) => s.unlockedKeys.has(k));
    },
    progress: (s) => {
      const allOtherKeys = ACHIEVEMENT_THRESHOLDS
        .filter((a) => a.key !== 'all_badges')
        .map((a) => a.key);
      const unlocked = allOtherKeys.filter((k) => s.unlockedKeys.has(k)).length;
      return unlocked / allOtherKeys.length;
    },
  },
];

export class AchievementService {
  static async checkAndUnlock(userId: string): Promise<string[]> {
    const context = await AchievementService.buildContext(userId);
    const newlyUnlocked: string[] = [];

    for (const threshold of ACHIEVEMENT_THRESHOLDS) {
      const existing = await prisma.achievement.findUnique({
        where: { userId_key: { userId, key: threshold.key } },
      });

      const progress = threshold.progress(context);
      const shouldUnlock = !existing?.unlockedAt && threshold.check(context);

      if (shouldUnlock) {
        await prisma.achievement.upsert({
          where: { userId_key: { userId, key: threshold.key } },
          create: {
            userId,
            key: threshold.key,
            unlockedAt: new Date(),
            progress: 1.0,
          },
          update: {
            unlockedAt: new Date(),
            progress: 1.0,
          },
        });
        newlyUnlocked.push(threshold.key);
        context.unlockedKeys.add(threshold.key);
      } else if (!existing || progress > (existing?.progress ?? 0)) {
        await prisma.achievement.upsert({
          where: { userId_key: { userId, key: threshold.key } },
          create: { userId, key: threshold.key, progress },
          update: { progress },
        });
      }
    }

    return newlyUnlocked;
  }

  private static async buildContext(userId: string): Promise<AchievementContext> {
    const [userStats, sessionAgg, sourceAgg, skillAgg, unlockedAchievements] =
      await Promise.all([
        prisma.userStats.findUnique({ where: { userId } }),
        prisma.studySession.aggregate({
          _count: true,
          _sum: { pomodorosCompleted: true, actualDurationMinutes: true, confidenceRating: true },
          where: { subject: { project: { userId } } },
        }),
        prisma.source.findFirst({
          where: { type: 'pdf', subject: { project: { userId } } },
          select: { id: true },
        }),
        prisma.skillLabel.findFirst({
          where: {
            label: { in: ['advanced', 'expert'] },
            subject: { project: { userId } },
          },
          select: { id: true },
        }),
        prisma.achievement.findMany({
          where: { userId, unlockedAt: { not: null } },
          select: { key: true },
        }),
      ]);

    const subjectHours = await AchievementService.getSubjectHours(userId);

    return {
      totalSessions: sessionAgg._count,
      totalPomodoros: sessionAgg._sum.pomodorosCompleted ?? 0,
      totalMinutes: userStats?.totalStudyMinutes ?? 0,
      currentStreak: userStats?.currentStreak ?? 0,
      subjectHours,
      hasPdf: !!sourceAgg,
      maxConfidence: sessionAgg._sum.confidenceRating ?? 0,
      hasAdvancedSkill: !!skillAgg,
      unlockedKeys: new Set(unlockedAchievements.map((a) => a.key)),
    };
  }

  private static async getSubjectHours(userId: string): Promise<Record<string, number>> {
    const subjectIds = await prisma.subject.findMany({
      where: { project: { userId } },
      select: { id: true },
    });

    if (subjectIds.length === 0) return {};

    const aggregations = await prisma.studySession.groupBy({
      by: ['subjectId'],
      _sum: { actualDurationMinutes: true },
      where: {
        subjectId: { in: subjectIds.map((s) => s.id) },
      },
    });

    const result: Record<string, number> = {};
    for (const agg of aggregations) {
      result[agg.subjectId] = agg._sum.actualDurationMinutes ?? 0;
    }
    return result;
  }
}
