import { useEffect, useState } from 'react';

interface Achievement {
  id: string;
  key: string;
  unlockedAt: string | null;
  progress: number;
}

const achievementIcons: Record<string, string> = {
  streak_3: 'local_fire_department',
  streak_7: 'whatshot',
  streak_30: 'bolt',
  streak_100: 'military_tech',
  pomodoro_10: 'timer',
  pomodoro_100: 'alarm_on',
  pomodoro_500: 'av_timer',
  hours_10: 'schedule',
  hours_100: 'history_edu',
  subject_5h: 'auto_stories',
  subject_10h: 'menu_book',
  first_pdf: 'picture_as_pdf',
  confidence_5: 'star',
  skill_advanced: 'trending_up',
  all_badges: 'emoji_events',
};

const achievementColors: Record<string, string> = {
  streak_3: '#FDB87C',
  streak_7: '#FDB87C',
  streak_30: '#FDB87C',
  streak_100: '#FFD700',
  pomodoro_10: '#85D2E0',
  pomodoro_100: '#85D2E0',
  pomodoro_500: '#85D2E0',
  hours_10: '#006874',
  hours_100: '#006874',
  subject_5h: '#85D2E0',
  subject_10h: '#85D2E0',
  first_pdf: '#EF4444',
  confidence_5: '#FDB87C',
  skill_advanced: '#006874',
  all_badges: '#FFD700',
};

const achievementDescriptions: Record<string, { title: string; description: string }> = {
  streak_3: {
    title: 'Consistent Learner',
    description: 'Study for 3 consecutive days. Consistency is the key to mastery.',
  },
  streak_7: {
    title: 'Week Warrior',
    description: 'Maintain a 7-day study streak. You\'re building great habits!',
  },
  streak_30: {
    title: 'Monthly Master',
    description: 'Study for 30 consecutive days. Your dedication is inspiring!',
  },
  streak_100: {
    title: 'Centurion',
    description: 'Achieve a 100-day study streak. You are unstoppable!',
  },
  pomodoro_10: {
    title: 'Pomodoro Pioneer',
    description: 'Complete 10 pomodoro sessions using the timer.',
  },
  pomodoro_100: {
    title: 'Pomodoro Pro',
    description: 'Complete 100 pomodoro sessions. You\'re a time management expert!',
  },
  pomodoro_500: {
    title: 'Pomodoro Legend',
    description: 'Complete 500 pomodoro sessions. Legendary focus!',
  },
  hours_10: {
    title: 'Dedicated Student',
    description: 'Study for a total of 10 hours across all subjects.',
  },
  hours_100: {
    title: 'Century Scholar',
    description: 'Accumulate 100 hours of total study time.',
  },
  subject_5h: {
    title: 'Subject Specialist',
    description: 'Study 5 hours in a single subject.',
  },
  subject_10h: {
    title: 'Subject Master',
    description: 'Study 10 hours in a single subject.',
  },
  first_pdf: {
    title: 'Resource Gatherer',
    description: 'Add your first PDF study resource to a subject.',
  },
  confidence_5: {
    title: 'Confidence Boost',
    description: 'Rate a study session with 5 stars for confidence.',
  },
  skill_advanced: {
    title: 'Skill Advancer',
    description: 'Reach the Advanced skill level in any subject.',
  },
  all_badges: {
    title: 'Badge Collector',
    description: 'Unlock all achievement badges. You are a true StudyTracker master!',
  },
};

const levelNames: Record<number, string> = {
  1: 'Novice',
  2: 'Apprentice',
  3: 'Scholar',
  4: 'Adept',
  5: 'Expert',
  6: 'Master',
  7: 'Grandmaster',
};

function getXpForLevel(level: number): number {
  if (level === 1) return 0;
  if (level === 2) return 500;
  if (level === 3) return 1500;
  if (level === 4) return 3500;
  if (level === 5) return 7000;
  let xp = 7000;
  for (let i = 6; i <= level; i++) {
    xp = Math.round(xp * 1.5 / 100) * 100;
  }
  return xp;
}

// Mock data for demo purposes
const mockAchievements: Achievement[] = [
  { id: '1', key: 'streak_7', unlockedAt: '2024-10-01', progress: 1 },
  { id: '2', key: 'pomodoro_10', unlockedAt: '2024-09-28', progress: 1 },
  { id: '3', key: 'hours_10', unlockedAt: '2024-09-25', progress: 1 },
  { id: '4', key: 'subject_5h', unlockedAt: '2024-09-20', progress: 1 },
  { id: '5', key: 'first_pdf', unlockedAt: '2024-09-15', progress: 1 },
  { id: '6', key: 'confidence_5', unlockedAt: '2024-09-12', progress: 1 },
  { id: '7', key: 'streak_30', unlockedAt: null, progress: 0.23 },
  { id: '8', key: 'pomodoro_100', unlockedAt: null, progress: 0.12 },
  { id: '9', key: 'hours_100', unlockedAt: null, progress: 0.42 },
  { id: '10', key: 'streak_3', unlockedAt: '2024-08-25', progress: 1 },
  { id: '11', key: 'subject_10h', unlockedAt: null, progress: 0.65 },
  { id: '12', key: 'skill_advanced', unlockedAt: null, progress: 0.35 },
  { id: '13', key: 'streak_100', unlockedAt: null, progress: 0.12 },
  { id: '14', key: 'pomodoro_500', unlockedAt: null, progress: 0.02 },
  { id: '15', key: 'all_badges', unlockedAt: null, progress: 0.40 },
];

export default function Achievements() {
  const [achievements, setAchievements] = useState<Achievement[]>([]);
  const currentLevel = 4;
  const totalXp = 12450;
  const [loading, setLoading] = useState(false);
  const [selectedAchievement, setSelectedAchievement] = useState<Achievement | null>(null);

  useEffect(() => {
    // Mock API call - replace with actual fetch when backend is ready
    const fetchAchievements = async () => {
      setLoading(true);
      // Simulate API delay
      await new Promise(resolve => setTimeout(resolve, 500));
      setAchievements(mockAchievements);
      setLoading(false);
    };
    fetchAchievements();
  }, []);

  const getXpInCurrentLevel = () => {
    const levelXp = getXpForLevel(currentLevel);
    return totalXp - levelXp;
  };

  const getXpToNextLevel = () => {
    const levelXp = getXpForLevel(currentLevel);
    const nextLevelXp = getXpForLevel(currentLevel + 1);
    return nextLevelXp - levelXp;
  };

  const getProgressPercentage = () => {
    const xpInLevel = getXpInCurrentLevel();
    const xpNeeded = getXpToNextLevel();
    return (xpInLevel / xpNeeded) * 100;
  };

  const getAchievementName = (key: string) => {
    return achievementDescriptions[key]?.title || key
      .split('_')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  };

  return (
    <div className="min-h-screen bg-background">
      <main className="p-6">
        <div className="max-w-7xl mx-auto">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-onSurface font-heading">Achievements</h1>
            <p className="mt-1 text-sm text-gray-400 font-body">
              Track your progress and unlock badges as you learn
            </p>
          </div>

          {loading ? (
            <div className="text-center py-12">
              <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            </div>
          ) : (
            <>
              {/* Level Card */}
              <div className="bg-surfaceHigh rounded-2xl p-6 mb-8">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <div className="flex items-center gap-3 mb-2">
                      <h2 className="text-4xl font-bold text-onSurface font-heading">
                        Level {currentLevel}
                      </h2>
                      <span className="px-3 py-1 bg-primary/20 text-primary text-sm font-medium rounded-full font-body">
                        {levelNames[currentLevel] || 'Unknown'}
                      </span>
                    </div>
                    <p className="text-sm text-gray-400 font-body">
                      Total XP: <span className="text-primary font-data">{totalXp.toLocaleString()}</span>
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm text-gray-400 font-body mb-1">XP Progress</p>
                    <p className="text-sm font-medium text-onSurface font-data">
                      {getXpInCurrentLevel().toLocaleString()} / {getXpToNextLevel().toLocaleString()} XP
                    </p>
                  </div>
                </div>
                <div className="w-full bg-gray-700 rounded-full h-3">
                  <div
                    className="bg-tertiary h-3 rounded-full transition-all"
                    style={{ width: `${getProgressPercentage()}%` }}
                  />
                </div>
              </div>

              {/* Achievement Stats */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
                <div className="bg-surfaceHigh rounded-xl p-4 flex items-center gap-4">
                  <div className="w-12 h-12 rounded-full bg-primary/20 flex items-center justify-center">
                    <span className="material-icons text-primary text-2xl">emoji_events</span>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-onSurface font-data">
                      {achievements.filter(a => a.unlockedAt).length}
                    </p>
                    <p className="text-sm text-gray-400 font-body">Unlocked</p>
                  </div>
                </div>

                <div className="bg-surfaceHigh rounded-xl p-4 flex items-center gap-4">
                  <div className="w-12 h-12 rounded-full bg-gray-700 flex items-center justify-center">
                    <span className="material-icons text-gray-400 text-2xl">lock</span>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-onSurface font-data">
                      {achievements.filter(a => !a.unlockedAt).length}
                    </p>
                    <p className="text-sm text-gray-400 font-body">Locked</p>
                  </div>
                </div>

                <div className="bg-surfaceHigh rounded-xl p-4 flex items-center gap-4">
                  <div className="w-12 h-12 rounded-full bg-tertiary/20 flex items-center justify-center">
                    <span className="material-icons text-tertiary text-2xl">bolt</span>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-onSurface font-data">
                      {Math.round(achievements.reduce((sum, a) => sum + a.progress, 0) / achievements.length * 100)}%
                    </p>
                    <p className="text-sm text-gray-400 font-body">Complete</p>
                  </div>
                </div>
              </div>

              {/* Achievements Grid */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                {achievements.map((achievement) => {
                  const isUnlocked = !!achievement.unlockedAt;
                  const icon = achievementIcons[achievement.key] || 'emoji_events';
                  const color = achievementColors[achievement.key] || '#85D2E0';
                  const name = getAchievementName(achievement.key);
                  const description = achievementDescriptions[achievement.key]?.description || '';

                  return (
                    <div
                      key={achievement.id}
                      className={`bg-surfaceHigh rounded-2xl p-6 transition-all hover:brightness-110 cursor-pointer ${
                        isUnlocked ? '' : 'grayscale opacity-70'
                      }`}
                      onClick={() => setSelectedAchievement(achievement)}
                    >
                      <div className="flex items-center justify-between mb-4">
                        <div
                          className="w-16 h-16 rounded-2xl flex items-center justify-center"
                          style={{
                            backgroundColor: isUnlocked ? `${color}20` : '#323536',
                          }}
                        >
                          <span
                            className="material-icons text-4xl"
                            style={{
                              color: isUnlocked ? color : '#6B7280',
                            }}
                          >
                            {icon}
                          </span>
                        </div>
                        {isUnlocked && (
                          <span className="px-2 py-1 text-xs font-medium bg-green-500/20 text-green-400 rounded-full font-body">
                            ✓
                          </span>
                        )}
                      </div>

                      <h3 className="text-base font-bold text-onSurface font-heading mb-1">
                        {name}
                      </h3>

                      <p className="text-sm text-gray-400 font-body mb-4 line-clamp-2">
                        {description}
                      </p>

                      {isUnlocked ? (
                        <p className="text-xs text-gray-500 font-body flex items-center gap-1">
                          <span className="material-icons text-sm">event</span>
                          {new Date(achievement.unlockedAt!).toLocaleDateString()}
                        </p>
                      ) : (
                        <div>
                          <div className="w-full bg-gray-700 rounded-full h-2 mb-2">
                            <div
                              className="bg-primary h-2 rounded-full transition-all"
                              style={{ width: `${achievement.progress * 100}%` }}
                            />
                          </div>
                          <p className="text-xs text-gray-400 font-body">
                            {Math.round(achievement.progress * 100)}% complete
                          </p>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </>
          )}
        </div>
      </main>

      {/* Achievement Detail Modal */}
      {selectedAchievement && (
        <div
          className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4"
          onClick={() => setSelectedAchievement(null)}
        >
          <div
            className="bg-surfaceHigh rounded-2xl p-8 max-w-md w-full"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-start justify-between mb-6">
              <div className="flex items-center gap-4">
                <div
                  className="w-20 h-20 rounded-2xl flex items-center justify-center"
                  style={{
                    backgroundColor: selectedAchievement.unlockedAt
                      ? `${achievementColors[selectedAchievement.key] || '#85D2E0'}20`
                      : '#323536',
                  }}
                >
                  <span
                    className="material-icons text-5xl"
                    style={{
                      color: selectedAchievement.unlockedAt
                        ? achievementColors[selectedAchievement.key] || '#85D2E0'
                        : '#6B7280',
                    }}
                  >
                    {achievementIcons[selectedAchievement.key] || 'emoji_events'}
                  </span>
                </div>
                <div>
                  <h3 className="text-xl font-bold text-onSurface font-heading mb-1">
                    {getAchievementName(selectedAchievement.key)}
                  </h3>
                  {selectedAchievement.unlockedAt && (
                    <span className="px-2 py-1 text-xs font-medium bg-green-500/20 text-green-400 rounded-full font-body">
                      Unlocked
                    </span>
                  )}
                </div>
              </div>
              <button
                onClick={() => setSelectedAchievement(null)}
                className="text-gray-400 hover:text-gray-200"
              >
                <span className="material-icons">close</span>
              </button>
            </div>

            <p className="text-base text-gray-300 font-body mb-6">
              {achievementDescriptions[selectedAchievement.key]?.description || ''}
            </p>

            <div className="mb-6">
              <div className="flex justify-between text-sm text-gray-400 font-body mb-2">
                <span>Progress</span>
                <span>{Math.round(selectedAchievement.progress * 100)}%</span>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-3">
                <div
                  className={`h-3 rounded-full transition-all ${
                    selectedAchievement.unlockedAt
                      ? 'bg-green-500'
                      : 'bg-primary'
                  }`}
                  style={{ width: `${selectedAchievement.progress * 100}%` }}
                />
              </div>
            </div>

            {selectedAchievement.unlockedAt && (
              <div className="flex items-center gap-2 text-sm text-gray-400 font-body">
                <span className="material-icons">event</span>
                Unlocked on {new Date(selectedAchievement.unlockedAt!).toLocaleDateString()}
              </div>
            )}

            <button
              onClick={() => setSelectedAchievement(null)}
              className="w-full mt-6 bg-primary/20 text-primary py-3 rounded-xl text-sm font-medium hover:bg-primary/30 transition-colors font-body"
            >
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
