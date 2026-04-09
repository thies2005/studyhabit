import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import apiClient from '../api/client';
import type { UserStats, Subject } from '../types';

export default function Dashboard() {
  const [stats, setStats] = useState<UserStats | null>(null);
  const [subjects, setSubjects] = useState<Subject[]>([]);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      const [statsRes, subjectsRes] = await Promise.all([
        apiClient.get('/stats/overview'),
        apiClient.get('/subjects'),
      ]);

      setStats(statsRes.data.data);
      setSubjects(subjectsRes.data.data);
    } catch (error) {
      console.error('Failed to fetch dashboard data', error);
    }
  };

  const formatColor = (colorValue: number) => {
    return `#${colorValue.toString(16).padStart(6, '0')}`;
  };

  return (
    <div className="px-4 py-6 sm:px-0">
      <div className="mb-8">
        <h2 className="text-2xl font-bold text-gray-900 dark:text-white">Welcome back, Alex.</h2>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
          ⭐ You've completed 85% of your weekly focus goal.
        </p>
      </div>

      {stats && (
        <>
          {/* Level Card */}
          <div className="bg-white dark:bg-[#323536] rounded-2xl p-6 mb-6 shadow-lg">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-3xl font-bold text-gray-900 dark:text-white">
                  Level {stats.currentLevel}
                </h3>
                <p className="text-lg text-[#FDB87C] font-medium">Zen Master</p>
              </div>
              <div className="text-right">
                <p className="text-sm text-gray-500 dark:text-gray-400 mb-1">XP Progress</p>
                <p className="text-sm font-medium text-gray-900 dark:text-white">
                  {stats.totalXp.toLocaleString()} / 15,000 XP
                </p>
              </div>
            </div>
            <div className="w-full bg-gray-200 dark:bg-[#101415] rounded-full h-3">
              <div
                className="bg-[#FDB87C] h-3 rounded-full transition-all"
                style={{ width: `${(stats.totalXp / 15000) * 100}%` }}
              ></div>
            </div>
          </div>

          {/* 4 Stat Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            <div className="bg-white dark:bg-[#323536] rounded-2xl p-6 shadow-lg">
              <div className="flex items-center space-x-3">
                <span className="text-3xl">⏱</span>
                <div>
                  <p className="text-sm text-gray-500 dark:text-gray-400">Deep Work</p>
                  <p className="text-2xl font-bold text-gray-900 dark:text-white">
                    {(stats.totalStudyMinutes / 60).toFixed(0)}h
                  </p>
                </div>
              </div>
            </div>
            <div className="bg-white dark:bg-[#323536] rounded-2xl p-6 shadow-lg">
              <div className="flex items-center space-x-3">
                <span className="text-3xl">⚡</span>
                <div>
                  <p className="text-sm text-gray-500 dark:text-gray-400">Efficiency</p>
                  <p className="text-2xl font-bold text-gray-900 dark:text-white">94%</p>
                </div>
              </div>
            </div>
            <div className="bg-white dark:bg-[#323536] rounded-2xl p-6 shadow-lg">
              <div className="flex items-center space-x-3">
                <span className="text-3xl">📊</span>
                <div>
                  <p className="text-sm text-gray-500 dark:text-gray-400">Sessions</p>
                  <p className="text-2xl font-bold text-gray-900 dark:text-white">128</p>
                </div>
              </div>
            </div>
            <div className="bg-white dark:bg-[#323536] rounded-2xl p-6 shadow-lg">
              <div className="flex items-center space-x-3">
                <span className="text-3xl">🌍</span>
                <div>
                  <p className="text-sm text-gray-500 dark:text-gray-400">Global Rank</p>
                  <p className="text-2xl font-bold text-gray-900 dark:text-white">#402</p>
                </div>
              </div>
            </div>
          </div>

          {/* Recent Sessions */}
          <div className="bg-white dark:bg-[#323536] rounded-2xl shadow-lg mb-6">
            <div className="px-6 py-5 border-b border-gray-200 dark:border-[#1C2021]">
              <div className="flex justify-between items-center">
                <h3 className="text-lg font-medium text-gray-900 dark:text-white">Recent Sessions</h3>
                <Link to="/subjects" className="text-sm text-[#85D2E0] hover:text-[#006874]">
                  View All
                </Link>
              </div>
            </div>
            <div className="p-6">
              <div className="space-y-3">
                {subjects.length === 0 ? (
                  <p className="text-gray-500 dark:text-gray-400 text-center py-8">
                    No subjects yet. Create your first subject to get started!
                  </p>
                ) : (
                  subjects.slice(0, 5).map((subject) => (
                    <div
                      key={subject.id}
                      className="flex items-center justify-between p-3 bg-gray-50 dark:bg-[#1C2021] rounded-lg hover:bg-gray-100 dark:hover:bg-[#323536] transition-colors cursor-pointer"
                      onClick={() => window.location.href = `/subjects/${subject.id}`}
                    >
                      <div className="flex items-center space-x-3">
                        <div
                          className="w-3 h-3 rounded-full"
                          style={{ backgroundColor: formatColor(subject.colorValue) }}
                        ></div>
                        <div>
                          <p className="text-sm font-medium text-gray-900 dark:text-white">
                            {subject.name}
                          </p>
                          <p className="text-xs text-gray-500 dark:text-gray-400">
                            Today, 2:30 PM
                          </p>
                        </div>
                      </div>
                      <div className="flex items-center space-x-3">
                        <span className="px-2 py-1 text-xs font-medium bg-[#FDB87C] text-black rounded">
                          +50 XP
                        </span>
                        <span className="text-sm text-gray-500 dark:text-gray-400">25 min</span>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>

          {/* Streak Card */}
          <div className="bg-gradient-to-r from-orange-500 to-red-500 rounded-2xl p-6 text-white mb-6 shadow-lg">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4">
                <span className="text-4xl">🔥</span>
                <div>
                  <p className="text-3xl font-bold">{stats.currentStreak} Days Strong</p>
                  <p className="text-sm opacity-90">3 days to reaching 'Unstoppable'</p>
                </div>
              </div>
              <div className="text-right">
                <div className="w-24 bg-white/20 rounded-full h-2 mb-2">
                  <div className="bg-white h-2 rounded-full" style={{ width: '85%' }}></div>
                </div>
                <p className="text-sm opacity-90">85% to milestone</p>
              </div>
            </div>
          </div>

          {/* Daily Objectives */}
          <div className="bg-white dark:bg-[#323536] rounded-2xl p-6 mb-6 shadow-lg">
            <div className="flex items-center space-x-2 mb-4">
              <span className="text-xl">✅</span>
              <h3 className="text-lg font-medium text-gray-900 dark:text-white">Daily Objectives</h3>
            </div>
            <div className="space-y-3">
              {[
                '2 Hour Deep Work Block',
                'Read 20 pages',
                'Complete 4 Pomodoro sessions',
              ].map((objective, index) => (
                <label key={index} className="flex items-center space-x-3 cursor-pointer">
                  <input type="checkbox" className="w-4 h-4 text-[#85D2E0] rounded focus:ring-[#85D2E0]" />
                  <span className="text-sm text-gray-700 dark:text-gray-300">{objective}</span>
                </label>
              ))}
            </div>
          </div>

          {/* Study Tip */}
          <div className="bg-white dark:bg-[#323536] rounded-2xl p-6 shadow-lg border-l-4 border-[#FDB87C]">
            <div className="flex items-start space-x-3">
              <span className="text-2xl">💡</span>
              <div>
                <h4 className="text-lg font-medium text-gray-900 dark:text-white mb-2">
                  The Feynman Technique
                </h4>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  Teach what you've learned to someone else. If you can't explain it simply,
                  you don't understand it well enough. This technique helps identify gaps in your
                  knowledge and reinforces learning through active recall.
                </p>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
