export const LEVEL_NAMES = [
  'Novice',
  'Apprentice',
  'Scholar',
  'Adept',
  'Expert',
  'Master',
  'Grandmaster',
] as const;

export function calculateLevel(totalXp: number): number {
  if (totalXp < 500) return 1;
  if (totalXp < 1500) return 2;
  if (totalXp < 3500) return 3;
  if (totalXp < 7000) return 4;
  if (totalXp < 10500) return 5;

  let level = 6;
  let threshold = 10500;
  while (level < 100 && totalXp >= Math.round((threshold * 1.5) / 100) * 100) {
    threshold = Math.round((threshold * 1.5) / 100) * 100;
    level++;
  }
  return level;
}

export function levelThreshold(level: number): number {
  if (level <= 1) return 0;
  if (level === 2) return 500;
  if (level === 3) return 1500;
  if (level === 4) return 3500;
  if (level === 5) return 7000;
  let threshold = 10500;
  for (let l = 6; l < level; l++) {
    threshold = Math.round((threshold * 1.5) / 100) * 100;
  }
  return threshold;
}

export function getLevelName(level: number): string {
  return LEVEL_NAMES[Math.min(Math.max(1, level) - 1, LEVEL_NAMES.length - 1)];
}

export function getLevelProgress(totalXp: number) {
  const currentLevel = calculateLevel(totalXp);
  const currentFloor = levelThreshold(currentLevel);
  const nextCeiling = levelThreshold(currentLevel + 1);
  const xpInLevel = Math.max(0, totalXp - currentFloor);
  const xpNeededForBand = Math.max(1, nextCeiling - currentFloor);
  const xpToNextLevel = Math.max(0, nextCeiling - totalXp);
  const progressPercent = Math.min(100, Math.max(0, (xpInLevel / xpNeededForBand) * 100));
  return {
    currentLevel,
    levelName: getLevelName(currentLevel),
    xpInLevel,
    xpNeededForBand,
    xpToNextLevel,
    progressPercent,
  };
}
