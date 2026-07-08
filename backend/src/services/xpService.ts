import { Prisma } from '@prisma/client';
import { prisma } from '../db.js';

export class XpService {
  static calculateLevel(totalXp: number): number {
    if (totalXp < 500) return 1;
    if (totalXp < 1500) return 2;
    if (totalXp < 3500) return 3;
    if (totalXp < 7000) return 4;
    if (totalXp < 10500) return 5;

    let level = 6;
    let threshold = 10500;
    while (totalXp >= Math.round((threshold * 1.5) / 100) * 100) {
      threshold = Math.round((threshold * 1.5) / 100) * 100;
      level++;
    }
    return level;
  }

  static xpToNextLevel(totalXp: number): number {
    const currentLevel = this.calculateLevel(totalXp);
    const thresholds = [0, 500, 1500, 3500, 7000, 10500];

    if (currentLevel < thresholds.length) {
      return thresholds[currentLevel] - totalXp;
    }

    let threshold = 10500;
    let level = 6;
    while (level < currentLevel) {
      threshold = Math.round((threshold * 1.5) / 100) * 100;
      level++;
    }
    const nextThreshold = Math.round((threshold * 1.5) / 100) * 100;
    return nextThreshold - totalXp;
  }

  static levelName(level: number): string {
    const names = [
      'Novice',
      'Apprentice',
      'Scholar',
      'Adept',
      'Expert',
      'Master',
      'Grandmaster',
    ];
    return names[Math.min(level - 1, names.length - 1)];
  }

  static xpForSession(minutes: number, pomodoros: number, confidenceRating?: number): number {
    let xp = 0;

    xp += pomodoros * 50;

    if (minutes >= 50) {
      xp += 120;
    }

    if (confidenceRating && confidenceRating >= 1) {
      xp += 10;
    }

    return xp;
  }

  static xpForStreak(streak: number): number {
    if (streak >= 100) return 500;
    if (streak >= 30) return 500;
    if (streak >= 7) return 500;
    return 0;
  }

  static xpForStreakMilestones(oldStreak: number, newStreak: number): number {
    // Only award XP for milestones that were JUST crossed
    // (old < threshold AND new >= threshold)
    const milestones = [7, 30, 100];
    let xp = 0;

    for (const milestone of milestones) {
      if (oldStreak < milestone && newStreak >= milestone) {
        xp += 500;
      }
    }

    return xp;
  }

  static async addXpAndMinutes(
    userId: string,
    xp: number,
    studyMinutes: number,
    tx?: Prisma.TransactionClient
  ): Promise<void> {
    const client = tx ?? prisma;
    const userStats = await client.userStats.findUnique({
      where: { userId },
    });

    if (!userStats) {
      await client.userStats.create({
        data: { userId, totalXp: xp, totalStudyMinutes: studyMinutes },
      });
    } else {
      const newTotalXp = userStats.totalXp + xp;
      const newLevel = this.calculateLevel(newTotalXp);

      await client.userStats.update({
        where: { userId },
        data: {
          totalXp: newTotalXp,
          currentLevel: newLevel,
          totalStudyMinutes: { increment: studyMinutes },
        },
      });
    }
  }
}
