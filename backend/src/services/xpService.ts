import { prisma } from '../index.js';

export class XpService {
  static calculateLevel(totalXp: number): number {
    if (totalXp < 500) return 1;
    if (totalXp < 1500) return 2;
    if (totalXp < 3500) return 3;
    if (totalXp < 7000) return 4;

    let level = 5;
    let threshold = 7000;
    while (totalXp >= threshold) {
      threshold = Math.round((threshold * 1.5) / 100) * 100;
      level++;
    }
    return level;
  }

  static xpToNextLevel(totalXp: number): number {
    const currentLevel = this.calculateLevel(totalXp);
    const thresholds = [0, 500, 1500, 3500, 7000];

    if (currentLevel <= 5) {
      return thresholds[currentLevel] - totalXp;
    }

    let threshold = 7000;
    let level = 5;
    while (level < currentLevel) {
      threshold = Math.round((threshold * 1.5) / 100) * 100;
      level++;
    }
    return threshold - totalXp;
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

  static xpForSession(minutes: number, pomodoros: number): number {
    let xp = 0;

    xp += pomodoros * 50;

    if (minutes >= 50) {
      xp += 120;
    }

    return xp;
  }

  static async addXpAndMinutes(
    userId: string,
    xp: number,
    studyMinutes: number
  ): Promise<void> {
    const userStats = await prisma.userStats.findUnique({
      where: { userId },
    });

    if (!userStats) {
      await prisma.userStats.create({
        data: { userId, totalXp: xp, totalStudyMinutes: studyMinutes },
      });
    } else {
      const newTotalXp = userStats.totalXp + xp;
      const newLevel = this.calculateLevel(newTotalXp);

      await prisma.userStats.update({
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
