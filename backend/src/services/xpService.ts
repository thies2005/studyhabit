import { prisma } from '../index.js';

export class XpService {
  // Level thresholds: Level 1=0, Level 2=500, Level 3=1500, Level 4=3500, Level 5=7000
  // Level 6+: threshold(n) = round(threshold(n-1) * 1.5 / 100) * 100
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

    // Calculate for levels 6+
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

    // Complete 1 Pomodoro (25 min work block) = +50
    xp += pomodoros * 50;

    // Complete long session (50+ min actual) = +120
    if (minutes >= 50) {
      xp += 120;
    }

    return xp;
  }

  static async addXpToUser(userId: string, xp: number): Promise<void> {
    const userStats = await prisma.userStats.findUnique({
      where: { userId },
    });

    if (!userStats) {
      await prisma.userStats.create({
        data: { userId, totalXp: xp },
      });
    } else {
      const newTotalXp = userStats.totalXp + xp;
      const newLevel = this.calculateLevel(newTotalXp);

      await prisma.userStats.update({
        where: { userId },
        data: { totalXp: newTotalXp, currentLevel: newLevel },
      });
    }
  }
}
