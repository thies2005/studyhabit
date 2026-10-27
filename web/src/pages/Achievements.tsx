import { useState } from 'react';
import type { Achievement, StatsOverview } from '../types';
import { useApi } from '../api/hooks';
import Modal from '../components/Modal';
import { getLevelName, getLevelProgress } from '../utils/xp';

interface AchievementInfo {
  name: string;
  description: string;
  icon: string;
  category: string;
  color: string;
}

const ACHIEVEMENTS_METADATA: Record<string, AchievementInfo> = {
  // Streaks
  streak_3: {
    name: 'Getting Warm',
    description: 'Maintain a 3-day study streak.',
    icon: 'local_fire_department',
    category: 'Streaks',
    color: '#FDB87C',
  },
  streak_7: {
    name: 'Weekly Warrior',
    description: 'Maintain a 7-day study streak.',
    icon: 'local_fire_department',
    category: 'Streaks',
    color: '#FDB87C',
  },
  streak_14: {
    name: 'Two Week Triumph',
    description: 'Maintain a 14-day study streak.',
    icon: 'local_fire_department',
    category: 'Streaks',
    color: '#FDB87C',
  },
  streak_30: {
    name: 'Monthly Master',
    description: 'Maintain a 30-day study streak.',
    icon: 'calendar_month',
    category: 'Streaks',
    color: '#FDB87C',
  },
  streak_50: {
    name: 'Half Century',
    description: 'Maintain a 50-day study streak.',
    icon: 'workspace_premium',
    category: 'Streaks',
    color: '#FFD700',
  },
  streak_100: {
    name: 'Century Club',
    description: 'Maintain a 100-day study streak.',
    icon: 'workspace_premium',
    category: 'Streaks',
    color: '#FFD700',
  },
  streak_200: {
    name: 'Bicentennial',
    description: 'Maintain a 200-day study streak.',
    icon: 'military_tech',
    category: 'Streaks',
    color: '#FFD700',
  },
  streak_365: {
    name: 'Orbital Period',
    description: 'Maintain a 365-day study streak.',
    icon: 'public',
    category: 'Streaks',
    color: '#FFD700',
  },

  // Pomodoros
  pomodoro_10: {
    name: 'Focus Novice',
    description: 'Complete 10 Pomodoro sessions.',
    icon: 'timer',
    category: 'Pomodoros',
    color: '#85D2E0',
  },
  pomodoro_25: {
    name: 'Focus Apprentice',
    description: 'Complete 25 Pomodoro sessions.',
    icon: 'timer',
    category: 'Pomodoros',
    color: '#85D2E0',
  },
  pomodoro_50: {
    name: 'Focus Adept',
    description: 'Complete 50 Pomodoro sessions.',
    icon: 'timer',
    category: 'Pomodoros',
    color: '#85D2E0',
  },
  pomodoro_100: {
    name: 'Focus Master',
    description: 'Complete 100 Pomodoro sessions.',
    icon: 'timer',
    category: 'Pomodoros',
    color: '#85D2E0',
  },
  pomodoro_250: {
    name: 'Focus Elite',
    description: 'Complete 250 Pomodoro sessions.',
    icon: 'timer',
    category: 'Pomodoros',
    color: '#85D2E0',
  },
  pomodoro_500: {
    name: 'Focus Legend',
    description: 'Complete 500 Pomodoro sessions.',
    icon: 'timer',
    category: 'Pomodoros',
    color: '#85D2E0',
  },
  pomodoro_1000: {
    name: 'Titan of Time',
    description: 'Complete 1000 Pomodoro sessions.',
    icon: 'timer',
    category: 'Pomodoros',
    color: '#85D2E0',
  },
  pomodoro_2500: {
    name: 'Time Lord',
    description: 'Complete 2500 Pomodoro sessions.',
    icon: 'timer',
    category: 'Pomodoros',
    color: '#85D2E0',
  },
  pomodoro_5000: {
    name: 'Eternal Focus',
    description: 'Complete 5000 Pomodoro sessions.',
    icon: 'all_inclusive',
    category: 'Pomodoros',
    color: '#85D2E0',
  },

  // Study Hours
  hours_10: {
    name: '10-Hour Club',
    description: 'Total study time reaches 10 hours.',
    icon: 'hourglass_top',
    category: 'Study Hours',
    color: '#006874',
  },
  hours_25: {
    name: '25-Hour Club',
    description: 'Total study time reaches 25 hours.',
    icon: 'hourglass_bottom',
    category: 'Study Hours',
    color: '#006874',
  },
  hours_50: {
    name: '50-Hour Club',
    description: 'Total study time reaches 50 hours.',
    icon: 'hourglass_full',
    category: 'Study Hours',
    color: '#006874',
  },
  hours_100: {
    name: '100-Hour Club',
    description: 'Total study time reaches 100 hours.',
    icon: 'watch_later',
    category: 'Study Hours',
    color: '#006874',
  },
  hours_200: {
    name: 'Double Century',
    description: 'Total study time reaches 200 hours.',
    icon: 'watch_later',
    category: 'Study Hours',
    color: '#006874',
  },
  hours_500: {
    name: 'Grind Master',
    description: 'Total study time reaches 500 hours.',
    icon: 'history_edu',
    category: 'Study Hours',
    color: '#006874',
  },
  hours_1000: {
    name: 'The Millenary',
    description: 'Total study time reaches 1000 hours.',
    icon: 'auto_awesome',
    category: 'Study Hours',
    color: '#FFD700',
  },

  // Sessions
  sessions_5: {
    name: 'Starter',
    description: 'Complete 5 study sessions.',
    icon: 'play_circle',
    category: 'Consistency',
    color: '#9ECAFF',
  },
  sessions_20: {
    name: 'Consistent',
    description: 'Complete 20 study sessions.',
    icon: 'play_circle',
    category: 'Consistency',
    color: '#9ECAFF',
  },
  sessions_50: {
    name: 'Regular',
    description: 'Complete 50 study sessions.',
    icon: 'play_circle',
    category: 'Consistency',
    color: '#9ECAFF',
  },
  sessions_100: {
    name: 'Dedicated',
    description: 'Complete 100 study sessions.',
    icon: 'play_circle',
    category: 'Consistency',
    color: '#9ECAFF',
  },
  sessions_250: {
    name: 'Reliable',
    description: 'Complete 250 study sessions.',
    icon: 'play_circle',
    category: 'Consistency',
    color: '#9ECAFF',
  },
  sessions_500: {
    name: 'Indomitable',
    description: 'Complete 500 study sessions.',
    icon: 'play_circle',
    category: 'Consistency',
    color: '#9ECAFF',
  },

  // Subject milestones
  subject_5h: {
    name: 'Specialist',
    description: 'Study one subject for at least 5 hours.',
    icon: 'school',
    category: 'Subject Mastery',
    color: '#80DC89',
  },
  subjects_2_5h: {
    name: 'Multitasker',
    description: 'Study two subjects for at least 5 hours each.',
    icon: 'school',
    category: 'Subject Mastery',
    color: '#80DC89',
  },
  subjects_5_5h: {
    name: 'Polymath',
    description: 'Study five subjects for at least 5 hours each.',
    icon: 'school',
    category: 'Subject Mastery',
    color: '#80DC89',
  },
  subject_10h: {
    name: 'Deep Diver',
    description: 'Study one subject for at least 10 hours.',
    icon: 'bolt',
    category: 'Subject Mastery',
    color: '#80DC89',
  },
  subjects_3_10h: {
    name: 'Broad Horizon',
    description: 'Study three subjects for at least 10 hours each.',
    icon: 'bolt',
    category: 'Subject Mastery',
    color: '#80DC89',
  },
  subjects_5_10h: {
    name: 'Master Scholar',
    description: 'Study five subjects for at least 10 hours each.',
    icon: 'bolt',
    category: 'Subject Mastery',
    color: '#80DC89',
  },

  // Free timer
  free_timer_first: {
    name: 'Freedom',
    description: 'Start your first non-Pomodoro session.',
    icon: 'speed',
    category: 'Flexibility',
    color: '#E8C16C',
  },
  free_timer_10: {
    name: 'Flow State',
    description: 'Complete 10 free timer sessions.',
    icon: 'speed',
    category: 'Flexibility',
    color: '#E8C16C',
  },
  free_timer_30m: {
    name: 'Quality Time',
    description: 'Complete a free timer session of 30 mins or more.',
    icon: 'speed',
    category: 'Flexibility',
    color: '#E8C16C',
  },
  free_timer_2h: {
    name: 'Marathoner',
    description: 'Complete a free timer session of 2 hours or more.',
    icon: 'speed',
    category: 'Flexibility',
    color: '#E8C16C',
  },

  // Long sessions
  long_session_2h: {
    name: 'The Grind',
    description: 'Log a session of at least 2 hours.',
    icon: 'fitness_center',
    category: 'Intensity',
    color: '#FFB4AB',
  },
  long_session_3h: {
    name: 'Endurance',
    description: 'Log a session of at least 3 hours.',
    icon: 'fitness_center',
    category: 'Intensity',
    color: '#FFB4AB',
  },
  long_session_5h: {
    name: 'Iron Mind',
    description: 'Log a session of at least 5 hours.',
    icon: 'fitness_center',
    category: 'Intensity',
    color: '#FFB4AB',
  },

  // Confidence
  confidence_5: {
    name: 'Honest Review',
    description: 'Rate your first session.',
    icon: 'star',
    category: 'Smart Study',
    color: '#D0BCFF',
  },
  confidence_10: {
    name: 'Self-Aware',
    description: 'Rate 10 sessions.',
    icon: 'star',
    category: 'Smart Study',
    color: '#D0BCFF',
  },
  confidence_50: {
    name: 'Reflective',
    description: 'Rate 50 sessions.',
    icon: 'star',
    category: 'Smart Study',
    color: '#D0BCFF',
  },
  all_5stars_3: {
    name: 'Peak Performance',
    description: 'Achieve 3 high-confidence ratings in any subjects.',
    icon: 'auto_awesome',
    category: 'Smart Study',
    color: '#D0BCFF',
  },

  // Sources
  first_pdf: {
    name: 'Digital Library',
    description: 'Add your first PDF source.',
    icon: 'picture_as_pdf',
    category: 'Sources',
    color: '#FFB1C8',
  },
  sources_5: {
    name: 'Collector',
    description: 'Add 5 PDF sources.',
    icon: 'picture_as_pdf',
    category: 'Sources',
    color: '#FFB1C8',
  },
  sources_10: {
    name: 'Archivist',
    description: 'Add 10 PDF sources.',
    icon: 'picture_as_pdf',
    category: 'Sources',
    color: '#FFB1C8',
  },

  // Skill
  skill_advanced: {
    name: 'Moving Up',
    description: 'Reach Advanced skill level in any subject.',
    icon: 'trending_up',
    category: 'Skill',
    color: '#89D6A1',
  },
  skill_expert: {
    name: 'Expert Opinion',
    description: 'Reach Expert skill level in any subject.',
    icon: 'workspace_premium',
    category: 'Skill',
    color: '#89D6A1',
  },

  // Night/Day
  night_owl: {
    name: 'Night Owl',
    description: 'Study after 10 PM.',
    icon: 'nightlight_round',
    category: 'Dedication',
    color: '#BFC2FF',
  },
  early_bird: {
    name: 'Early Bird',
    description: 'Study before 7 AM.',
    icon: 'wb_sunny',
    category: 'Dedication',
    color: '#BFC2FF',
  },

  // All Badges
  all_badges: {
    name: 'Completionist',
    description: 'Unlock all achievements.',
    icon: 'emoji_events',
    category: 'Mastery',
    color: '#FFD700',
  },
};

export default function Achievements() {
  const [selectedAchievement, setSelectedAchievement] = useState<Achievement | null>(null);
  const [selectedCategory, setSelectedCategory] = useState<string>('All');
  const { data: stats, loading: statsLoading } = useApi<StatsOverview>('/stats/overview');
  const { data: serverAchievements, loading: achievementsLoading } = useApi<Achievement[]>('/achievements');

  const totalXp = stats?.totalXp || 0;
  const loading = statsLoading || achievementsLoading;

  const serverMap = new Map((serverAchievements || []).map((a) => [a.key, a]));
  const achievements: Achievement[] = Object.keys(ACHIEVEMENTS_METADATA).map((key) => {
    const existing = serverMap.get(key);
    if (existing) return existing;
    return {
      id: key,
      userId: '',
      key,
      progress: 0,
      unlockedAt: null,
      createdAt: '',
      updatedAt: '',
    };
  });

  const getInfo = (key: string): AchievementInfo => {
    return ACHIEVEMENTS_METADATA[key] || {
      name: key
        .split('_')
        .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' '),
      description: 'Achievement reward.',
      icon: 'emoji_events',
      category: 'General',
      color: '#85D2E0',
    };
  };

  const categories = ['All', ...Array.from(new Set(Object.values(ACHIEVEMENTS_METADATA).map((a) => a.category)))];

  const filteredAchievements = selectedCategory === 'All'
    ? achievements
    : achievements.filter((a) => getInfo(a.key).category === selectedCategory);

  const progressInfo = getLevelProgress(totalXp);
  const currentLevel = progressInfo.currentLevel;
  const xpInCurrentLevel = progressInfo.xpInLevel;
  const xpNeeded = progressInfo.xpNeededForBand;
  const progressPercent = progressInfo.progressPercent;

  return (
    <div className="min-h-screen bg-background">
      <main className="p-6">
        <div className="max-w-7xl mx-auto">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-onSurface font-heading">Achievements</h1>
            <p className="mt-1 text-sm text-onSurfaceVariant font-body">
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
              <div className="bg-surfaceContainerHigh rounded-3xl p-8 mb-8 shadow-md">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <div className="flex items-center gap-3 mb-2">
                      <h2 className="text-4xl font-bold text-onSurface font-heading">
                        Level {currentLevel}
                      </h2>
                      <span className="px-3 py-1 bg-primary/20 text-primary text-sm font-medium rounded-full font-body">
                        {getLevelName(currentLevel)}
                      </span>
                    </div>
                    <p className="text-sm text-onSurfaceVariant font-body">
                      Total XP: <span className="text-primary font-data">{totalXp.toLocaleString()}</span>
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm text-onSurfaceVariant font-body mb-1">XP Progress</p>
                    <p className="text-sm font-medium text-onSurface font-data">
                      {Math.max(0, xpInCurrentLevel).toLocaleString()} / {Math.max(1, xpNeeded).toLocaleString()} XP
                    </p>
                  </div>
                </div>
                <div className="w-full bg-surfaceContainerHighest rounded-full h-3">
                  <div
                    className="bg-primary h-3 rounded-full transition-all"
                    style={{ width: `${Math.max(3, progressPercent)}%` }}
                  />
                </div>
              </div>

              {/* Achievement Stats */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
                <div className="bg-surfaceContainerHigh rounded-3xl p-6 flex items-center gap-4 shadow-sm hover:shadow-md transition-shadow">
                  <div className="w-12 h-12 rounded-full bg-primary/20 flex items-center justify-center">
                    <span className="material-symbols-rounded text-primary text-2xl">emoji_events</span>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-onSurface font-data">
                      {achievements.filter((a) => a.unlockedAt).length}
                    </p>
                    <p className="text-sm text-onSurfaceVariant font-body">Unlocked</p>
                  </div>
                </div>

                <div className="bg-surfaceContainerHigh rounded-3xl p-6 flex items-center gap-4 shadow-sm hover:shadow-md transition-shadow">
                  <div className="w-12 h-12 rounded-full bg-surfaceContainerHighest flex items-center justify-center">
                    <span className="material-symbols-rounded text-onSurfaceVariant text-2xl">lock</span>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-onSurface font-data">
                      {achievements.filter((a) => !a.unlockedAt).length}
                    </p>
                    <p className="text-sm text-onSurfaceVariant font-body">Locked</p>
                  </div>
                </div>

                <div className="bg-surfaceContainerHigh rounded-3xl p-6 flex items-center gap-4 shadow-sm hover:shadow-md transition-shadow">
                  <div className="w-12 h-12 rounded-full bg-tertiary/20 flex items-center justify-center">
                    <span className="material-symbols-rounded text-tertiary text-2xl">bolt</span>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-onSurface font-data">
                      {achievements.length > 0
                        ? `${Math.round((achievements.reduce((sum, a) => sum + a.progress, 0) / achievements.length) * 100)}%`
                        : '0%'}
                    </p>
                    <p className="text-sm text-onSurfaceVariant font-body">Complete</p>
                  </div>
                </div>
              </div>

              {/* Category Filter */}
              <div className="flex gap-2 overflow-x-auto pb-4 mb-6 scrollbar-none">
                {categories.map((cat) => (
                  <button
                    key={cat}
                    onClick={() => setSelectedCategory(cat)}
                    className={`px-4 py-2 rounded-full text-xs font-medium font-body transition-colors shrink-0 ${
                      selectedCategory === cat
                        ? 'bg-primary text-background font-bold'
                        : 'bg-surfaceContainerHigh text-onSurfaceVariant hover:bg-surfaceContainerHighest hover:text-onSurface'
                    }`}
                  >
                    {cat}
                  </button>
                ))}
              </div>

              {/* Achievements Grid */}
              {filteredAchievements.length === 0 ? (
                <div className="bg-surfaceContainerHigh rounded-3xl p-12 text-center shadow-md">
                  <div className="w-16 h-16 bg-surface/50 rounded-full flex items-center justify-center mx-auto mb-4">
                    <span className="material-symbols-rounded text-onSurfaceVariant text-3xl">emoji_events</span>
                  </div>
                  <h3 className="text-xl font-bold text-onSurface font-heading mb-2">No achievements found</h3>
                  <p className="text-onSurfaceVariant font-body">
                    Start studying and tracking your sessions to earn achievements!
                  </p>
                </div>
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                  {filteredAchievements.map((achievement) => {
                    const isUnlocked = !!achievement.unlockedAt;
                    const info = getInfo(achievement.key);

                    return (
                      <div
                        key={achievement.id}
                        role="button"
                        tabIndex={0}
                        aria-label={`${info.name}: ${isUnlocked ? 'Unlocked' : `${Math.round(achievement.progress * 100)}% complete`}`}
                        className={`bg-surfaceContainerHigh rounded-3xl p-6 transition-all hover:-translate-y-1 hover:shadow-xl cursor-pointer border border-transparent hover:border-outlineVariant focus:outline-none focus:ring-2 focus:ring-primary ${
                          isUnlocked ? 'shadow-md' : 'grayscale opacity-70 shadow-sm'
                        }`}
                        onClick={() => setSelectedAchievement(achievement)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter' || e.key === ' ') {
                            e.preventDefault();
                            setSelectedAchievement(achievement);
                          }
                        }}
                      >
                        <div className="flex items-center justify-between mb-4">
                          <div
                            className="w-16 h-16 rounded-2xl flex items-center justify-center"
                            style={{
                              backgroundColor: isUnlocked ? `${info.color}20` : 'rgba(46, 53, 57, 0.5)',
                            }}
                          >
                            <span
                              className="material-symbols-rounded text-4xl"
                              style={{
                                color: isUnlocked ? info.color : '#6B7280',
                              }}
                            >
                              {info.icon}
                            </span>
                          </div>
                          <div className="flex items-center gap-2">
                            <span className="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-full bg-surface text-onSurfaceVariant">
                              {info.category}
                            </span>
                            {isUnlocked && (
                              <span className="px-2 py-1 text-xs font-medium bg-green-500/20 text-green-400 rounded-full font-body">
                                ✓
                              </span>
                            )}
                          </div>
                        </div>

                        <h3 className="text-base font-bold text-onSurface font-heading mb-1">
                          {info.name}
                        </h3>

                        <p className="text-sm text-onSurfaceVariant font-body mb-4 line-clamp-2">
                          {info.description}
                        </p>

                        {isUnlocked ? (
                          <p className="text-xs text-onSurfaceVariant font-body flex items-center gap-1">
                            <span className="material-symbols-rounded text-sm">event</span>
                            {new Date(achievement.unlockedAt!).toLocaleDateString()}
                          </p>
                        ) : (
                          <div>
                            <div className="w-full bg-surfaceContainerHighest rounded-full h-2 mb-2">
                              <div
                                className="bg-primary h-2 rounded-full transition-all"
                                style={{ width: `${Math.round(achievement.progress * 100)}%` }}
                              />
                            </div>
                            <p className="text-xs text-onSurfaceVariant font-body">
                              {Math.round(achievement.progress * 100)}% complete
                            </p>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </>
          )}
        </div>
      </main>

      {/* Achievement Detail Modal */}
      {selectedAchievement && (
        <Modal
          isOpen={!!selectedAchievement}
          onClose={() => setSelectedAchievement(null)}
          title={getInfo(selectedAchievement.key).name}
        >
          <div className="p-8">
            <div className="flex items-start justify-between mb-6">
              <div className="flex items-center gap-4">
                <div
                  className="w-20 h-20 rounded-2xl flex items-center justify-center"
                  style={{
                    backgroundColor: selectedAchievement.unlockedAt
                      ? `${getInfo(selectedAchievement.key).color}20`
                      : 'rgba(46, 53, 57, 0.5)',
                  }}
                >
                  <span
                    className="material-symbols-rounded text-5xl"
                    style={{
                      color: selectedAchievement.unlockedAt
                        ? getInfo(selectedAchievement.key).color
                        : '#6B7280',
                    }}
                  >
                    {getInfo(selectedAchievement.key).icon}
                  </span>
                </div>
                <div>
                  <h3 className="text-xl font-bold text-onSurface font-heading mb-1">
                    {getInfo(selectedAchievement.key).name}
                  </h3>
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-surface text-onSurfaceVariant">
                      {getInfo(selectedAchievement.key).category}
                    </span>
                    {selectedAchievement.unlockedAt && (
                      <span className="px-2 py-1 text-xs font-medium bg-green-500/20 text-green-400 rounded-full font-body">
                        Unlocked
                      </span>
                    )}
                  </div>
                </div>
              </div>
              <button
                onClick={() => setSelectedAchievement(null)}
                aria-label="Close dialog"
                className="w-11 h-11 rounded-full flex items-center justify-center text-onSurfaceVariant hover:bg-surfaceContainerHighest hover:text-onSurface transition-colors"
              >
                <span className="material-symbols-rounded text-lg">close</span>
              </button>
            </div>

            <p className="text-base text-onSurfaceVariant font-body mb-6">
              {getInfo(selectedAchievement.key).description}
            </p>

            <div className="mb-6">
              <div className="flex justify-between text-sm text-onSurfaceVariant font-body mb-2">
                <span>Progress</span>
                <span>{Math.round(selectedAchievement.progress * 100)}%</span>
              </div>
              <div className="w-full bg-surfaceContainerHighest rounded-full h-3">
                <div
                  className={`h-3 rounded-full transition-all ${
                    selectedAchievement.unlockedAt
                      ? 'bg-green-500'
                      : 'bg-primary'
                  }`}
                  style={{ width: `${Math.round(selectedAchievement.progress * 100)}%` }}
                />
              </div>
            </div>

            {selectedAchievement.unlockedAt && (
              <div className="flex items-center gap-2 text-sm text-onSurfaceVariant font-body">
                <span className="material-symbols-rounded">event</span>
                Unlocked on {new Date(selectedAchievement.unlockedAt!).toLocaleDateString()}
              </div>
            )}

            <button
              type="button"
              onClick={() => setSelectedAchievement(null)}
              className="w-full mt-6 bg-primary hover:bg-primary-container text-white py-3 rounded-xl text-sm font-bold transition-colors font-body"
            >
              Close
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
}
