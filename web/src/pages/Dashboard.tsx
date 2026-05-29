import { Link, useNavigate } from 'react-router-dom';
import type { StatsOverview, SessionWithSubject } from '../types';
import { useApi } from '../api/hooks';

// Level names from spec
const LEVEL_NAMES = ['Novice', 'Apprentice', 'Scholar', 'Adept', 'Expert', 'Master', 'Grandmaster'];

// Calculate XP threshold for level (from spec)
const calculateLevelThreshold = (level: number): number => {
  if (level === 1) return 0;
  if (level === 2) return 500;
  if (level === 3) return 1500;
  if (level === 4) return 3500;
  if (level === 5) return 7000;
  // Level 6+ formula
  let threshold = 7000;
  for (let i = 6; i <= level; i++) {
    threshold = Math.round(threshold * 1.5 / 100) * 100;
  }
  return threshold;
};

// Calculate progress within current level
const calculateLevelProgress = (currentLevel: number, totalXp: number): number => {
  if (currentLevel >= 7) return 1; // Grandmaster is max level
  const currentLevelThreshold = calculateLevelThreshold(currentLevel);
  const nextLevelThreshold = calculateLevelThreshold(currentLevel + 1);
  const xpInCurrentLevel = totalXp - currentLevelThreshold;
  const xpNeededForNextLevel = nextLevelThreshold - currentLevelThreshold;
  return xpNeededForNextLevel > 0 ? xpInCurrentLevel / xpNeededForNextLevel : 1;
};

const getLevelName = (level: number): string => {
  return LEVEL_NAMES[Math.min(level - 1, LEVEL_NAMES.length - 1)] || 'Grandmaster';
};

export default function Dashboard() {
  const navigate = useNavigate();

  // Fetch stats overview
  const { data: stats, loading: statsLoading, error: statsError, refetch: refetchStats } = useApi<StatsOverview>('/stats/overview');

  // Fetch sessions for today and recent sessions
  const { data: sessions, loading: sessionsLoading, error: sessionsError, refetch: refetchSessions } = useApi<SessionWithSubject[]>('/sessions?limit=3');

  const loading = (statsLoading && !stats) || (sessionsLoading && !sessions);
  // Only treat statsError as fatal if it's not a 404
  const isStatsNotFound = statsError?.includes('404') || statsError?.includes('not found') || false;
  const isFatalError = (statsError && !isStatsNotFound) || sessionsError;

  const defaultStats: StatsOverview = {
    totalHours: 0, weekHours: 0, currentStreak: 0, currentLevel: 1, 
    levelName: 'Beginner', totalXp: 0, totalStudyMinutes: 0, longestStreak: 0, freezeTokens: 0
  };

  const currentStats = stats || defaultStats;

  const handleRetry = () => {
    refetchStats();
    refetchSessions();
  };

  const formatColor = (colorValue: number) => {
    return `#${colorValue.toString(16).padStart(6, '0')}`;
  };

  // Calculate today's hours from sessions
  const todayHours = sessions?.reduce((total, session) => {
    const sessionDate = new Date(session.startedAt);
    const today = new Date();
    return sessionDate.toDateString() === today.toDateString()
      ? total + (session.actualDurationMinutes / 60)
      : total;
  }, 0) || 0;

  return (
    <div className="px-4 py-6 sm:px-0">
      {/* Loading State */}
      {loading && (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
        </div>
      )}

      {/* Error State */}
      {isFatalError && (
        <div className="bg-red-500/20 border border-red-500/30 rounded-2xl p-6 mb-6">
          <p className="text-red-400 mb-4">Failed to load dashboard data. Please check your connection.</p>
          <button
            onClick={handleRetry}
            className="px-4 py-2 bg-primary hover:bg-primary-container rounded-lg text-background font-medium transition-colors"
          >
            Retry
          </button>
        </div>
      )}

      {/* Content */}
      {!loading && !isFatalError && (
        <>
          {/* Header Section */}
          <div className="mb-8">
            <div className="flex items-center justify-between flex-wrap gap-4">
              <div>
                <h2 className="text-2xl font-bold text-onSurface font-heading">Welcome back!</h2>
                <p className="mt-1 text-sm text-gray-400 font-body">
                  Today: {todayHours.toFixed(1)}h studied
                </p>
              </div>
              <div className="flex items-center gap-3">
                <span className="px-3 py-1 bg-tertiary/20 text-tertiary rounded-full text-sm font-medium font-body flex items-center gap-2">
                  <span className="material-symbols-rounded text-sm">local_fire_department</span>
                  {currentStats.currentStreak} day streak
                </span>
                <span className="px-3 py-1 bg-primary/20 text-primary rounded-full text-sm font-medium font-body">
                  Level {currentStats.currentLevel} — {getLevelName(currentStats.currentLevel)}
                </span>
              </div>
            </div>

            {/* XP Bar */}
            <div className="mt-4">
              <div className="text-3xl font-bold text-onSurface mt-2 font-heading">{currentStats.currentLevel}</div>
              <div className="text-xs text-primary mt-1 font-medium">{currentStats.levelName}</div>
            </div>
            <div className="ml-4 flex-grow">
              <div className="flex justify-between text-xs text-gray-400 mb-1">
                <span>{currentStats.totalXp} XP</span>
                <span>{calculateLevelThreshold(currentStats.currentLevel + 1) - currentStats.totalXp} XP to Level {currentStats.currentLevel + 1}</span>
              </div>
              <div className="w-full bg-surface-container rounded-full h-2">
                <div 
                  className="bg-primary h-2 rounded-full transition-all duration-1000 ease-out" 
                  style={{ width: `${Math.max(5, calculateLevelProgress(currentStats.currentLevel, currentStats.totalXp) * 100)}%` }}
                ></div>
              </div>
            </div>
          </div>

          {/* Start Session FAB */}
          <div className="flex justify-center mb-8">
            <Link
              to="/subjects"
              className="flex items-center gap-2 px-8 py-4 bg-primary hover:bg-primary-container text-white rounded-2xl text-lg font-medium font-body shadow-lg hover:shadow-xl transition-all transform hover:scale-105"
            >
              <span className="material-symbols-rounded">play_arrow</span>
              Start Session
            </Link>
          </div>

          {/* Empty State */}
          {!loading && sessions && sessions.length === 0 && (
            <div className="bg-surfaceContainerHigh rounded-3xl p-12 mb-8 text-center shadow-lg border border-outlineVariant border-opacity-50">
              <span className="material-symbols-rounded text-6xl text-primary mb-4">school</span>
              <h3 className="text-3xl font-bold text-onSurface font-heading mb-2 tracking-tight">
                Let's start learning!
              </h3>
              <p className="text-gray-400 font-body mb-6">
                Tap the button below to begin your first session
              </p>
              <Link
                to="/subjects"
                className="inline-flex items-center gap-2 px-8 py-4 bg-primary hover:bg-primary-container text-background hover:text-primary-onContainer rounded-full font-heading font-bold transition-all duration-300 hover:scale-105 active:scale-95 shadow-lg"
              >
                <span className="material-symbols-rounded text-xl">play_arrow</span>
                Start Your First Session
              </Link>
            </div>
          )}

          {/* Overview Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border border-transparent hover:border-outlineVariant transition-colors">
              <div className="flex items-center space-x-3">
                <span className="text-3xl">⏱</span>
                <div>
                  <p className="text-sm text-gray-400 font-body">Total Hours</p>
                  <p className="text-2xl font-bold text-onSurface font-data">
                    {currentStats.totalHours.toFixed(1)}h
                  </p>
                </div>
              </div>
            </div>
            <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border border-transparent hover:border-outlineVariant transition-colors">
              <div className="flex items-center space-x-3">
                <span className="text-3xl">📅</span>
                <div>
                  <p className="text-sm text-gray-400 font-body">This Week</p>
                  <p className="text-2xl font-bold text-onSurface font-data">
                    {currentStats.weekHours.toFixed(1)}h
                  </p>
                </div>
              </div>
            </div>
            <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border border-transparent hover:border-outlineVariant transition-colors">
              <div className="flex items-center space-x-3">
                <span className="text-3xl">🔥</span>
                <div>
                  <p className="text-sm text-gray-400 font-body">Streak</p>
                  <p className="text-2xl font-bold text-onSurface font-data">
                    {currentStats.currentStreak}d
                  </p>
                </div>
              </div>
            </div>
            <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border border-transparent hover:border-outlineVariant transition-colors">
              <div className="flex items-center space-x-3">
                <span className="text-3xl">⭐</span>
                <div>
                  <p className="text-sm text-gray-400 font-body">Level</p>
                  <p className="text-2xl font-bold text-onSurface font-data">
                    {getLevelName(currentStats.currentLevel)}
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Recent Sessions */}
          {sessions && sessions.length > 0 && (
            <div className="bg-surfaceContainerHigh rounded-3xl shadow-lg mb-6 border border-outlineVariant border-opacity-30 overflow-hidden">
              <div className="px-6 py-5 border-b border-surfaceContainerHighest">
                <div className="flex justify-between items-center">
                  <h3 className="text-lg font-medium text-onSurface font-heading">Recent Sessions</h3>
                  <Link to="/subjects" className="text-sm text-primary hover:text-primary-container transition-colors font-body">
                    View All
                  </Link>
                </div>
              </div>
              <div className="p-6">
                <div className="space-y-3">
                  {sessions.map((session) => (
                    <div
                      key={session.id}
                      className="flex items-center justify-between p-4 bg-surfaceContainer hover:bg-surfaceContainerHighest rounded-2xl transition-all duration-300 cursor-pointer mb-2 last:mb-0"
                      onClick={() => navigate(`/subjects/${session.subjectId}`)}
                    >
                      <div className="flex items-center space-x-3">
                        <div
                          className="w-3 h-3 rounded-full"
                          style={{ backgroundColor: formatColor(session.subject.colorValue) }}
                        ></div>
                        <div>
                          <p className="text-sm font-medium text-onSurface font-body">
                            {session.subject.name}
                          </p>
                          <p className="text-xs text-gray-400 font-body">
                            {new Date(session.startedAt).toLocaleDateString()} at {new Date(session.startedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                          </p>
                        </div>
                      </div>
                      <div className="flex items-center space-x-4">
                        <span className="px-3 py-1 text-xs font-bold bg-tertiary/20 text-tertiary rounded-full font-heading tracking-wide">
                          +{session.xpEarned} XP
                        </span>
                        <span className="text-sm text-gray-400 font-body">{session.actualDurationMinutes} min</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Streak Card */}
          {currentStats.currentStreak > 0 && (
            <div className="bg-gradient-to-r from-tertiary-container to-error-container rounded-3xl p-8 text-white mb-6 shadow-xl relative overflow-hidden">
              <div className="absolute top-0 right-0 -mr-8 -mt-8 opacity-20 pointer-events-none">
                <span className="material-symbols-rounded text-[150px]">local_fire_department</span>
              </div>
              <div className="flex items-center justify-between relative z-10">
                <div className="flex items-center space-x-4">
                  <span className="text-4xl">🔥</span>
                  <div>
                    <p className="text-3xl font-bold font-heading">{currentStats.currentStreak} Day Streak</p>
                    <p className="text-sm opacity-90 font-body">
                      {currentStats.longestStreak > currentStats.currentStreak
                        ? `Personal best: ${currentStats.longestStreak} days`
                        : "You're on fire!"}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
