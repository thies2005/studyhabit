import { Prisma, PrismaClient } from '@prisma/client';
import { prisma as globalPrisma } from '../db.js';

interface AchievementThreshold {
  key: string;
  check: (stats: AchievementContext) => boolean;
  progress: (stats: AchievementContext) => number;
}

interface AchievementContext {
  totalSessions: number;
  totalPomodoros: number;
  totalMinutes: number;
  totalHours: number;
  currentStreak: number;
  subjectsOver5h: number;
  subjectsOver10h: number;
  freeTimerCount: number;
  maxContinuousSession: number;
  longSession2h: number;
  longSession3h: number;
  longSession5h: number;
  ratedSessionsCount: number;
  hasSubjectWith3HighConfidence: boolean;
  hasPdf: boolean;
  pdfCount: number;
  hasAdvancedSkill: boolean;
  hasExpertSkill: boolean;
  sessionsAfter10pm: number;
  sessionsBefore7am: number;
  unlockedKeys: Set<string>;
}

const ACHIEVEMENT_THRESHOLDS: AchievementThreshold[] = [
  // Streaks (8)
  { key: 'streak_3', check: (s) => s.currentStreak >= 3, progress: (s) => Math.min(s.currentStreak / 3, 1) },
  { key: 'streak_7', check: (s) => s.currentStreak >= 7, progress: (s) => Math.min(s.currentStreak / 7, 1) },
  { key: 'streak_14', check: (s) => s.currentStreak >= 14, progress: (s) => Math.min(s.currentStreak / 14, 1) },
  { key: 'streak_30', check: (s) => s.currentStreak >= 30, progress: (s) => Math.min(s.currentStreak / 30, 1) },
  { key: 'streak_50', check: (s) => s.currentStreak >= 50, progress: (s) => Math.min(s.currentStreak / 50, 1) },
  { key: 'streak_100', check: (s) => s.currentStreak >= 100, progress: (s) => Math.min(s.currentStreak / 100, 1) },
  { key: 'streak_200', check: (s) => s.currentStreak >= 200, progress: (s) => Math.min(s.currentStreak / 200, 1) },
  { key: 'streak_365', check: (s) => s.currentStreak >= 365, progress: (s) => Math.min(s.currentStreak / 365, 1) },

  // Pomodoros (9)
  { key: 'pomodoro_10', check: (s) => s.totalPomodoros >= 10, progress: (s) => Math.min(s.totalPomodoros / 10, 1) },
  { key: 'pomodoro_25', check: (s) => s.totalPomodoros >= 25, progress: (s) => Math.min(s.totalPomodoros / 25, 1) },
  { key: 'pomodoro_50', check: (s) => s.totalPomodoros >= 50, progress: (s) => Math.min(s.totalPomodoros / 50, 1) },
  { key: 'pomodoro_100', check: (s) => s.totalPomodoros >= 100, progress: (s) => Math.min(s.totalPomodoros / 100, 1) },
  { key: 'pomodoro_250', check: (s) => s.totalPomodoros >= 250, progress: (s) => Math.min(s.totalPomodoros / 250, 1) },
  { key: 'pomodoro_500', check: (s) => s.totalPomodoros >= 500, progress: (s) => Math.min(s.totalPomodoros / 500, 1) },
  { key: 'pomodoro_1000', check: (s) => s.totalPomodoros >= 1000, progress: (s) => Math.min(s.totalPomodoros / 1000, 1) },
  { key: 'pomodoro_2500', check: (s) => s.totalPomodoros >= 2500, progress: (s) => Math.min(s.totalPomodoros / 2500, 1) },
  { key: 'pomodoro_5000', check: (s) => s.totalPomodoros >= 5000, progress: (s) => Math.min(s.totalPomodoros / 5000, 1) },

  // Hours (7)
  { key: 'hours_10', check: (s) => s.totalHours >= 10, progress: (s) => Math.min(s.totalHours / 10, 1) },
  { key: 'hours_25', check: (s) => s.totalHours >= 25, progress: (s) => Math.min(s.totalHours / 25, 1) },
  { key: 'hours_50', check: (s) => s.totalHours >= 50, progress: (s) => Math.min(s.totalHours / 50, 1) },
  { key: 'hours_100', check: (s) => s.totalHours >= 100, progress: (s) => Math.min(s.totalHours / 100, 1) },
  { key: 'hours_200', check: (s) => s.totalHours >= 200, progress: (s) => Math.min(s.totalHours / 200, 1) },
  { key: 'hours_500', check: (s) => s.totalHours >= 500, progress: (s) => Math.min(s.totalHours / 500, 1) },
  { key: 'hours_1000', check: (s) => s.totalHours >= 1000, progress: (s) => Math.min(s.totalHours / 1000, 1) },

  // Sessions (6)
  { key: 'sessions_5', check: (s) => s.totalSessions >= 5, progress: (s) => Math.min(s.totalSessions / 5, 1) },
  { key: 'sessions_20', check: (s) => s.totalSessions >= 20, progress: (s) => Math.min(s.totalSessions / 20, 1) },
  { key: 'sessions_50', check: (s) => s.totalSessions >= 50, progress: (s) => Math.min(s.totalSessions / 50, 1) },
  { key: 'sessions_100', check: (s) => s.totalSessions >= 100, progress: (s) => Math.min(s.totalSessions / 100, 1) },
  { key: 'sessions_250', check: (s) => s.totalSessions >= 250, progress: (s) => Math.min(s.totalSessions / 250, 1) },
  { key: 'sessions_500', check: (s) => s.totalSessions >= 500, progress: (s) => Math.min(s.totalSessions / 500, 1) },

  // Subject milestones (6)
  { key: 'subject_5h', check: (s) => s.subjectsOver5h >= 1, progress: (s) => Math.min(s.subjectsOver5h / 1, 1) },
  { key: 'subjects_2_5h', check: (s) => s.subjectsOver5h >= 2, progress: (s) => Math.min(s.subjectsOver5h / 2, 1) },
  { key: 'subjects_5_5h', check: (s) => s.subjectsOver5h >= 5, progress: (s) => Math.min(s.subjectsOver5h / 5, 1) },
  { key: 'subject_10h', check: (s) => s.subjectsOver10h >= 1, progress: (s) => Math.min(s.subjectsOver10h / 1, 1) },
  { key: 'subjects_3_10h', check: (s) => s.subjectsOver10h >= 3, progress: (s) => Math.min(s.subjectsOver10h / 3, 1) },
  { key: 'subjects_5_10h', check: (s) => s.subjectsOver10h >= 5, progress: (s) => Math.min(s.subjectsOver10h / 5, 1) },

  // Free timer (4)
  { key: 'free_timer_first', check: (s) => s.freeTimerCount >= 1, progress: (s) => s.freeTimerCount >= 1 ? 1 : 0 },
  { key: 'free_timer_10', check: (s) => s.freeTimerCount >= 10, progress: (s) => Math.min(s.freeTimerCount / 10, 1) },
  { key: 'free_timer_30m', check: (s) => s.maxContinuousSession >= 30, progress: (s) => s.maxContinuousSession >= 30 ? 1 : 0 },
  { key: 'free_timer_2h', check: (s) => s.maxContinuousSession >= 120, progress: (s) => s.maxContinuousSession >= 120 ? 1 : 0 },

  // Long sessions (3)
  { key: 'long_session_2h', check: (s) => s.longSession2h >= 1, progress: (s) => s.longSession2h >= 1 ? 1 : 0 },
  { key: 'long_session_3h', check: (s) => s.longSession3h >= 1, progress: (s) => s.longSession3h >= 1 ? 1 : 0 },
  { key: 'long_session_5h', check: (s) => s.longSession5h >= 1, progress: (s) => s.longSession5h >= 1 ? 1 : 0 },

  // Confidence (4)
  { key: 'confidence_5', check: (s) => s.ratedSessionsCount >= 1, progress: (s) => s.ratedSessionsCount >= 1 ? 1 : 0 },
  { key: 'confidence_10', check: (s) => s.ratedSessionsCount >= 10, progress: (s) => Math.min(s.ratedSessionsCount / 10, 1) },
  { key: 'confidence_50', check: (s) => s.ratedSessionsCount >= 50, progress: (s) => Math.min(s.ratedSessionsCount / 50, 1) },
  { key: 'all_5stars_3', check: (s) => s.hasSubjectWith3HighConfidence, progress: (s) => s.hasSubjectWith3HighConfidence ? 1 : 0 },

  // Sources (3)
  { key: 'first_pdf', check: (s) => s.hasPdf, progress: (s) => s.hasPdf ? 1 : 0 },
  { key: 'sources_5', check: (s) => s.pdfCount >= 5, progress: (s) => Math.min(s.pdfCount / 5, 1) },
  { key: 'sources_10', check: (s) => s.pdfCount >= 10, progress: (s) => Math.min(s.pdfCount / 10, 1) },

  // Skill (2)
  { key: 'skill_advanced', check: (s) => s.hasAdvancedSkill, progress: (s) => s.hasAdvancedSkill ? 1 : 0 },
  { key: 'skill_expert', check: (s) => s.hasExpertSkill, progress: (s) => s.hasExpertSkill ? 1 : 0 },

  // Night/Day (2)
  { key: 'night_owl', check: (s) => s.sessionsAfter10pm >= 1, progress: (s) => s.sessionsAfter10pm >= 1 ? 1 : 0 },
  { key: 'early_bird', check: (s) => s.sessionsBefore7am >= 1, progress: (s) => s.sessionsBefore7am >= 1 ? 1 : 0 },

  // All Badges (1)
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
  static async checkAndUnlock(userId: string, tx?: Prisma.TransactionClient): Promise<string[]> {
    const client = tx || globalPrisma;
    const context = await AchievementService.buildContext(userId, client);
    const newlyUnlocked: string[] = [];

    for (const threshold of ACHIEVEMENT_THRESHOLDS) {
      const existing = await client.achievement.findUnique({
        where: { userId_key: { userId, key: threshold.key } },
      });

      const progress = threshold.progress(context);
      const shouldUnlock = !existing?.unlockedAt && threshold.check(context);

      if (shouldUnlock) {
        await client.achievement.upsert({
          where: { userId_key: { userId, key: threshold.key } },
          create: {
            userId,
            key: threshold.key,
            unlockedAt: new Date(),
            progress: 1.0,
            updatedAt: new Date(),
          },
          update: {
            unlockedAt: new Date(),
            progress: 1.0,
            updatedAt: new Date(),
          },
        });
        newlyUnlocked.push(threshold.key);
        context.unlockedKeys.add(threshold.key);
      } else if (!existing || progress > (existing?.progress ?? 0)) {
        await client.achievement.upsert({
          where: { userId_key: { userId, key: threshold.key } },
          create: { userId, key: threshold.key, progress, updatedAt: new Date() },
          update: { progress, updatedAt: new Date() },
        });
      }
    }

    return newlyUnlocked;
  }

  private static async buildContext(userId: string, client: Prisma.TransactionClient | PrismaClient): Promise<AchievementContext> {
    const [userStats, sessions, sources, skills, unlockedAchievements] = await Promise.all([
      client.userStats.findUnique({ where: { userId } }),
      client.studySession.findMany({
        where: {
          isDeleted: false,
          subject: {
            isDeleted: false,
            project: { userId, isDeleted: false },
          },
        },
        select: {
          subjectId: true,
          actualDurationMinutes: true,
          pomodorosCompleted: true,
          confidenceRating: true,
          isFreeTimer: true,
          startedAt: true,
        },
      }),
      client.source.findMany({
        where: {
          type: 'pdf',
          isDeleted: false,
          subject: {
            isDeleted: false,
            project: { userId, isDeleted: false },
          },
        },
        select: { id: true },
      }),
      client.skillLabel.findMany({
        where: {
          isDeleted: false,
          subject: {
            isDeleted: false,
            project: { userId, isDeleted: false },
          },
        },
        select: { label: true },
      }),
      client.achievement.findMany({
        where: { userId, unlockedAt: { not: null } },
        select: { key: true },
      }),
    ]);

    const totalSessions = sessions.length;
    let totalPomodoros = 0;
    let totalMinutes = 0;
    let freeTimerCount = 0;
    let maxContinuousSession = 0;
    let longSession2h = 0;
    let longSession3h = 0;
    let longSession5h = 0;
    let ratedSessionsCount = 0;
    let sessionsBefore7am = 0;
    let sessionsAfter10pm = 0;

    const subjectsWithMinutes = new Map<string, number>();
    const subjectsWithHighConfidence = new Map<string, number>();

    for (const s of sessions) {
      totalPomodoros += s.pomodorosCompleted;
      totalMinutes += s.actualDurationMinutes;

      subjectsWithMinutes.set(
        s.subjectId,
        (subjectsWithMinutes.get(s.subjectId) ?? 0) + s.actualDurationMinutes
      );

      if (s.confidenceRating !== null && s.confidenceRating !== undefined && s.confidenceRating >= 5) {
        ratedSessionsCount++;
        subjectsWithHighConfidence.set(
          s.subjectId,
          (subjectsWithHighConfidence.get(s.subjectId) ?? 0) + 1
        );
      }

      if (s.isFreeTimer) {
        freeTimerCount++;
      }

      if (s.actualDurationMinutes > maxContinuousSession) {
        maxContinuousSession = s.actualDurationMinutes;
      }

      if (s.actualDurationMinutes >= 120) longSession2h++;
      if (s.actualDurationMinutes >= 180) longSession3h++;
      if (s.actualDurationMinutes >= 300) longSession5h++;

      const hour = s.startedAt.getUTCHours();
      if (hour < 7) sessionsBefore7am++;
      if (hour >= 22) sessionsAfter10pm++;
    }

    const subjectsOver5h = Array.from(subjectsWithMinutes.values()).filter((m) => m >= 300).length;
    const subjectsOver10h = Array.from(subjectsWithMinutes.values()).filter((m) => m >= 600).length;
    const hasSubjectWith3HighConfidence = Array.from(subjectsWithHighConfidence.values()).some((c) => c >= 3);

    return {
      totalSessions,
      totalPomodoros,
      totalMinutes,
      totalHours: totalMinutes / 60,
      currentStreak: userStats?.currentStreak ?? 0,
      subjectsOver5h,
      subjectsOver10h,
      freeTimerCount,
      maxContinuousSession,
      longSession2h,
      longSession3h,
      longSession5h,
      ratedSessionsCount,
      hasSubjectWith3HighConfidence,
      hasPdf: sources.length > 0,
      pdfCount: sources.length,
      hasAdvancedSkill: skills.some((s) => s.label === 'advanced' || s.label === 'expert'),
      hasExpertSkill: skills.some((s) => s.label === 'expert'),
      sessionsAfter10pm,
      sessionsBefore7am,
      unlockedKeys: new Set(unlockedAchievements.map((a: { key: string }) => a.key)),
    };
  }
}
