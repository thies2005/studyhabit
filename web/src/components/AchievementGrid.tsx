interface Achievement {
  key: string;
  name: string;
  description: string;
  unlockedAt: string | null;
  progress: number;
}

const achievementIcons: Record<string, string> = {
  streak_3: '🔥', streak_7: '🔥', streak_30: '⚡', streak_100: '🎖️',
  pomodoro_10: '⏱️', pomodoro_100: '⏰', pomodoro_500: '🕐',
  hours_10: '📅', hours_100: '📖',
  subject_5h: '📚', subject_10h: '📘',
  first_pdf: '📄', confidence_5: '⭐', skill_advanced: '📈', all_badges: '🏆',
};

export function AchievementGrid({ achievements }: { achievements: Achievement[] }) {
  return (
    <div className="grid grid-cols-3 gap-4">
      {achievements.map((achievement) => {
        const isUnlocked = !!achievement.unlockedAt;
        return (
          <div
            key={achievement.key}
            className={`rounded-xl p-4 shadow-sm text-center ${
              isUnlocked
                ? 'bg-white dark:bg-gray-800'
                : 'bg-gray-100 dark:bg-gray-800/50 grayscale'
            }`}
          >
            <div className="text-3xl mb-2">
              {achievementIcons[achievement.key] || '🏅'}
            </div>
            <p className="font-medium text-sm">{achievement.name}</p>
            {!isUnlocked && (
              <div className="mt-2">
                <div className="h-1.5 bg-gray-200 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-primary rounded-full"
                    style={{ width: `${achievement.progress * 100}%` }}
                  />
                </div>
                <p className="text-xs text-gray-500 mt-1">
                  {Math.round(achievement.progress * 100)}%
                </p>
              </div>
            )}
            {isUnlocked && (
              <p className="text-xs text-green-600 mt-1">
                ✓ {new Date(achievement.unlockedAt!).toLocaleDateString()}
              </p>
            )}
          </div>
        );
      })}
    </div>
  );
}
