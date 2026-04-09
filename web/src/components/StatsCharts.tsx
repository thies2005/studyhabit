import type { StatsOverview, WeeklyActivityData } from '../types';

export function OverviewCards({ stats }: { stats: StatsOverview }) {
  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm">
        <p className="text-sm text-gray-500">Total Hours</p>
        <p className="text-2xl font-bold">{stats?.totalHours?.toFixed(1) || '0'}h</p>
      </div>
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm">
        <p className="text-sm text-gray-500">This Week</p>
        <p className="text-2xl font-bold">{stats?.weekHours?.toFixed(1) || '0'}h</p>
      </div>
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm">
        <p className="text-sm text-gray-500">Streak 🔥</p>
        <p className="text-2xl font-bold">{stats?.currentStreak || 0}d</p>
      </div>
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm">
        <p className="text-sm text-gray-500">Level</p>
        <p className="text-2xl font-bold">{stats?.levelName || 'Novice'}</p>
      </div>
    </div>
  );
}

export function WeeklyBarChart({ data }: { data: WeeklyActivityData[] }) {
  return (
    <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-sm">
      <h3 className="text-lg font-semibold mb-4">Weekly Activity</h3>
      <div className="flex items-end gap-2 h-40">
        {data?.map((day, i) => (
          <div key={i} className="flex-1 flex flex-col items-center gap-1">
            <div
              className="w-full bg-primary/80 rounded-t"
              style={{ height: `${Math.max((day.hours / Math.max(...data.map(d => d.hours), 1)) * 100, 4)}%` }}
            />
            <span className="text-xs text-gray-500">{day.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
