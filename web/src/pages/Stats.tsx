import { useEffect, useState, useCallback } from 'react';
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
} from 'recharts';
import apiClient from '../api/client';
import { useProject } from '../contexts/ProjectContext';

type TooltipRendererProps = any;

const CustomTooltip = ({ active, payload, label }: TooltipRendererProps) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-surfaceContainerHigh border border-outlineVariant rounded-xl p-3 shadow-lg">
        <p className="text-sm font-medium text-onSurface font-heading mb-1">{label}</p>
        {payload.map((entry: any, index: number) => (
          <p key={index} className="text-sm text-onSurfaceVariant font-body" style={{ color: entry.color }}>
            {entry.name}: {entry.value}
          </p>
        ))}
      </div>
    );
  }
  return null;
};

const WeeklyChartTooltip = ({ active, payload, label }: TooltipRendererProps) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-surfaceContainerHigh border border-outlineVariant rounded-xl p-3 shadow-lg">
        <p className="text-sm font-medium text-onSurface font-heading mb-1">{label}</p>
        <p className="text-sm text-primary font-body">
          {payload[0]?.payload?.minutes ?? 0} minutes
        </p>
      </div>
    );
  }
  return null;
};

const XpChartTooltip = ({ active, payload, label }: TooltipRendererProps) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-surfaceContainerHigh border border-outlineVariant rounded-xl p-3 shadow-lg">
        <p className="text-sm font-medium text-onSurface font-heading mb-1">{label}</p>
        <p className="text-sm text-primary font-body">
          {payload[0]?.value?.toLocaleString()} XP total
        </p>
        {payload[0]?.payload?.dailyXp > 0 && (
          <p className="text-xs text-tertiary font-body mt-0.5">
            +{payload[0]?.payload?.dailyXp} XP earned
          </p>
        )}
      </div>
    );
  }
  return null;
};

export default function Stats() {
  const { currentProjectId } = useProject();
  const [overview, setOverview] = useState({
    totalHours: 0,
    weekHours: 0,
    currentStreak: 0,
    totalXp: 0,
    currentLevel: 1,
    levelName: 'Novice',
  });
  const [weeklyActivity, setWeeklyActivity] = useState<any[]>([]);
  const [subjectDistribution, setSubjectDistribution] = useState<any[]>([]);
  const [heatmap, setHeatmap] = useState<any[]>([]);
  const [subjectBreakdown, setSubjectBreakdown] = useState<any[]>([]);
  const [xpHistory, setXpHistory] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  const fetchStats = useCallback(async () => {
    try {
      setLoading(true);
      setError(false);
      const queryParam = currentProjectId ? `?projectId=${currentProjectId}` : '';
      const [overviewRes, heatmapRes, subjectsRes, xpRes] = await Promise.all([
        apiClient.get(`/stats/overview${queryParam}`),
        apiClient.get(`/stats/heatmap${queryParam}`),
        apiClient.get(`/stats/subjects${queryParam}`),
        apiClient.get(`/stats/xp-history${queryParam ? queryParam + '&days=30' : '?days=30'}`),
      ]);

      const overviewData = overviewRes.data.data;
      const heatmapData = heatmapRes.data.data as { date: string; minutes: number }[];
      const subjectsData = subjectsRes.data.data;
      const xpData = xpRes.data.data;

      setOverview(overviewData);
      setXpHistory(xpData || []);

      // Map heatmap: 12 weeks Monday through Sunday
      const today = new Date();
      const todayDayOfWeek = (today.getDay() + 6) % 7; // 0 = Mon, 6 = Sun
      const startMonday = new Date(today);
      startMonday.setDate(today.getDate() - todayDayOfWeek - (11 * 7));
      startMonday.setHours(0, 0, 0, 0);

      const cells = [];
      for (let w = 0; w < 12; w++) {
        for (let d = 0; d < 7; d++) {
          const cellDate = new Date(startMonday);
          cellDate.setDate(startMonday.getDate() + (w * 7 + d));
          const dateStr = cellDate.toISOString().split('T')[0];
          const isFuture = cellDate > today;
          const match = heatmapData.find((h) => h.date === dateStr);
          const minutes = (!isFuture && match) ? match.minutes : 0;
          const intensity = isFuture ? -1 : (minutes === 0 ? 0 : Math.min(4, Math.ceil(minutes / 30)));
          cells.push({
            id: `${w}-${d}`,
            dateStr,
            dayOfWeek: d,
            weekNum: w,
            intensity,
            minutes,
            isFuture,
            tooltip: isFuture ? '' : `${dateStr} - ${minutes}m studied`,
          });
        }
      }
      setHeatmap(cells);

      // Map weekly activity
      const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      const last7Days = [];
      for (let i = 6; i >= 0; i--) {
        const d = new Date();
        d.setDate(d.getDate() - i);
        const dateStr = d.toISOString().split('T')[0];
        const match = heatmapData.find((h) => h.date === dateStr);
        const minutes = match ? match.minutes : 0;
        last7Days.push({
          day: weekdays[d.getDay()],
          hours: Number((minutes / 60).toFixed(2)),
          minutes,
        });
      }
      setWeeklyActivity(last7Days);

      // Map subject distribution
      const mappedDistribution = subjectsData.map((d: any) => ({
        name: d.subject.name,
        hours: Number(d.totalHours.toFixed(1)),
        value: Number(d.totalHours.toFixed(1)),
        color: `#${d.subject.colorValue.toString(16).padStart(6, '0')}`,
      }));
      setSubjectDistribution(mappedDistribution);

      // Map subject breakdown using skill level from server
      const mappedBreakdown = subjectsData.map((d: any) => ({
        name: d.subject.name,
        hours: d.totalHours,
        sessions: d.sessionCount,
        avgConfidence: Math.round(d.avgConfidence || 3),
        skillLevel: d.skillLevel ? d.skillLevel.charAt(0).toUpperCase() + d.skillLevel.slice(1) : 'Beginner',
        color: `#${d.subject.colorValue.toString(16).padStart(6, '0')}`,
      }));
      setSubjectBreakdown(mappedBreakdown);
    } catch (err) {
      console.error('Failed to fetch stats:', err);
      setError(true);
    } finally {
      setLoading(false);
    }
  }, [currentProjectId]);

  useEffect(() => {
    fetchStats();
  }, [fetchStats]);

  const getHeatmapColor = (intensity: number) => {
    switch (intensity) {
      case 0: return 'bg-surfaceContainerLowest';
      case 1: return 'bg-primary/20';
      case 2: return 'bg-primary/40';
      case 3: return 'bg-primary/60';
      case 4: return 'bg-primary';
      default: return 'bg-surfaceContainerLowest';
    }
  };

  const renderStars = (rating: number) => {
    return Array.from({ length: 5 }, (_, i) => (
      <span
        key={i}
        className="material-symbols-rounded text-sm"
        style={{ color: i < rating ? '#FDB87C' : 'var(--color-outline-variant, #323536)' }}
      >
        star
      </span>
    ));
  };

  return (
    <div className="min-h-screen bg-background">
      <main className="p-6">
        <div className="max-w-7xl mx-auto">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-onSurface font-heading">Performance Insights</h1>
            <p className="mt-1 text-sm text-onSurfaceVariant font-body">
              Track your study progress and efficiency metrics
            </p>
          </div>

          {loading ? (
            <div className="text-center py-12">
              <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            </div>
          ) : error ? (
            <div className="bg-surfaceContainerHigh rounded-3xl p-8 text-center max-w-md mx-auto">
              <span className="material-symbols-rounded text-5xl text-onSurfaceVariant block mb-3" aria-hidden="true">
                error
              </span>
              <h2 className="text-lg font-medium text-onSurface font-heading mb-2">
                Couldn&apos;t load your stats
              </h2>
              <p className="text-sm text-onSurfaceVariant font-body mb-4">
                Something went wrong while fetching your performance data. Please try again.
              </p>
              <button
                type="button"
                onClick={() => window.location.reload()}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary text-onPrimary text-sm font-medium hover:bg-primary/90 transition-colors"
              >
                <span className="material-symbols-rounded text-base" aria-hidden="true">refresh</span>
                Retry
              </button>
            </div>
          ) : (
            <>
              {/* Overview Cards */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border border-transparent hover:border-outlineVariant transition-colors">
                  <div className="flex items-center justify-between mb-3">
                    <span className="material-symbols-rounded text-3xl text-primary">schedule</span>
                    <span className="text-xs text-green-400 font-body">Active study time</span>
                  </div>
                  <p className="text-2xl font-bold text-onSurface font-data">{overview.totalHours.toFixed(1)}h</p>
                  <p className="text-sm text-onSurfaceVariant font-body">Total Study Hours</p>
                </div>

                <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border border-transparent hover:border-outlineVariant transition-colors">
                  <div className="flex items-center justify-between mb-3">
                    <span className="material-symbols-rounded text-3xl text-primary">calendar_today</span>
                    <span className="text-xs text-green-400 font-body">Past 7 days</span>
                  </div>
                  <p className="text-2xl font-bold text-onSurface font-data">{overview.weekHours.toFixed(1)}h</p>
                  <p className="text-sm text-onSurfaceVariant font-body">Weekly Average</p>
                </div>

                <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border border-transparent hover:border-outlineVariant transition-colors">
                  <div className="flex items-center justify-between mb-3">
                    <span className="material-symbols-rounded text-3xl text-tertiary">local_fire_department</span>
                    <span className="text-xs text-onSurfaceVariant font-body">Daily commitment</span>
                  </div>
                  <p className="text-2xl font-bold text-onSurface font-data">{overview.currentStreak}d</p>
                  <p className="text-sm text-onSurfaceVariant font-body">Current Streak</p>
                </div>

                <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border border-transparent hover:border-outlineVariant transition-colors">
                  <div className="flex items-center justify-between mb-3">
                    <span className="material-symbols-rounded text-3xl text-primary">emoji_events</span>
                    <span className="text-xs text-onSurfaceVariant font-body">{overview.totalXp.toLocaleString()} XP total</span>
                  </div>
                  <p className="text-2xl font-bold text-onSurface font-data">{overview.currentLevel}</p>
                  <p className="text-sm text-onSurfaceVariant font-body">{overview.levelName}</p>
                </div>
              </div>

              {/* Weekly Activity Bar Chart */}
              {weeklyActivity.length > 0 && (
                <div className="bg-surfaceContainerHigh rounded-3xl p-6 mb-6 shadow-md">
                  <h3 className="text-lg font-medium text-onSurface font-heading mb-4">Weekly Activity</h3>
                  <ResponsiveContainer width="100%" height={300}>
                    <BarChart data={weeklyActivity}>
                      <CartesianGrid strokeDasharray="3 3" stroke="var(--color-outline-variant, #323536)" />
                      <XAxis
                        dataKey="day"
                        stroke="#9CA3AF"
                        fontSize={12}
                        tickLine={false}
                        axisLine={false}
                      />
                      <YAxis
                        stroke="#9CA3AF"
                        fontSize={12}
                        tickLine={false}
                        axisLine={false}
                        tickFormatter={(value) => `${value}h`}
                      />
                      <Tooltip content={<WeeklyChartTooltip />} cursor={{ fill: 'rgba(133, 210, 224, 0.1)' }} />
                      <Bar dataKey="hours" fill="var(--color-primary, #85D2E0)" radius={[4, 4, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}

              {/* Subject Distribution Pie Chart */}
              {subjectDistribution.length > 0 && (
                <div className="bg-surfaceContainerHigh rounded-3xl p-6 mb-6 shadow-md">
                  <h3 className="text-lg font-medium text-onSurface font-heading mb-4">Subject Distribution</h3>
                  <div className="flex flex-col md:flex-row items-center gap-6">
                    <div className="flex-1 w-full">
                      <ResponsiveContainer width="100%" height={300}>
                        <PieChart>
                          <Pie
                            data={subjectDistribution}
                            cx="50%"
                            cy="50%"
                            innerRadius={60}
                            outerRadius={100}
                            paddingAngle={2}
                            dataKey="value"
                          >
                            {subjectDistribution.map((entry, index) => (
                              <Cell key={`cell-${index}`} fill={entry.color} />
                            ))}
                          </Pie>
                          <Tooltip content={<CustomTooltip />} />
                        </PieChart>
                      </ResponsiveContainer>
                    </div>
                    <div className="flex-1 space-y-3">
                      {subjectDistribution.map((item) => (
                        <div key={item.name} className="flex items-center gap-3">
                          <div
                            className="w-3 h-3 rounded-full"
                            style={{ backgroundColor: item.color }}
                          />
                          <span className="text-sm text-onSurfaceVariant font-body">{item.name}</span>
                          <span className="text-sm text-onSurfaceVariant font-body ml-auto">
                            {Math.round((item.hours / subjectDistribution.reduce((sum, s) => sum + s.hours, 0)) * 100)}%
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              )}

              {/* XP Progress Chart */}
              <div className="bg-surfaceContainerHigh rounded-3xl p-6 mb-6 shadow-md">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-lg font-medium text-onSurface font-heading">XP Progress</h3>
                  <span className="text-xs text-onSurfaceVariant font-body">Last 30 days</span>
                </div>
                {xpHistory.length > 0 && xpHistory.some((p: any) => p.cumulativeXp > 0 || p.dailyXp > 0) ? (
                  <ResponsiveContainer width="100%" height={300}>
                    <AreaChart data={xpHistory}>
                      <defs>
                        <linearGradient id="xpGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="var(--color-primary, #85D2E0)" stopOpacity={0.6}/>
                          <stop offset="95%" stopColor="var(--color-primary, #85D2E0)" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="var(--color-outline-variant, #323536)" />
                      <XAxis
                        dataKey="date"
                        stroke="#9CA3AF"
                        fontSize={12}
                        tickLine={false}
                        axisLine={false}
                        tickFormatter={(d) => {
                          const parts = d.split('-');
                          return `${parts[1]}/${parts[2]}`;
                        }}
                      />
                      <YAxis
                        stroke="#9CA3AF"
                        fontSize={12}
                        tickLine={false}
                        axisLine={false}
                        tickFormatter={(value) => `${value}`}
                      />
                      <Tooltip content={<XpChartTooltip />} cursor={{ stroke: 'var(--color-primary, #85D2E0)', strokeWidth: 1 }} />
                      <Area
                        type="monotone"
                        dataKey="cumulativeXp"
                        stroke="var(--color-primary, #85D2E0)"
                        strokeWidth={2}
                        fillOpacity={1}
                        fill="url(#xpGradient)"
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                ) : (
                  <div className="flex flex-col items-center justify-center py-10 text-center">
                    <span className="material-symbols-rounded text-5xl text-onSurfaceVariant mb-3" aria-hidden="true">
                      trending_up
                    </span>
                    <p className="text-sm text-onSurfaceVariant font-body max-w-sm">
                      Start logging study sessions to build your XP history and track your progress over time.
                    </p>
                    <p className="text-xs text-onSurfaceVariant font-body mt-2">
                      Current total: {overview.totalXp.toLocaleString()} XP · Level {overview.currentLevel} ({overview.levelName})
                    </p>
                  </div>
                )}
              </div>

              {/* Activity Heatmap */}
              {heatmap.length > 0 && (
                <div className="bg-surfaceContainerHigh rounded-3xl p-6 mb-6 shadow-md">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-medium text-onSurface font-heading">Activity Heatmap</h3>
                    <span className="text-xs text-onSurfaceVariant font-body">Last 12 weeks</span>
                  </div>
                  <div className="overflow-x-auto">
                    <div className="flex items-start">
                      {/* Day labels (M to S, 7 days) */}
                      <div className="flex flex-col gap-1 mr-2 text-[10px] text-onSurfaceVariant font-body select-none">
                        <div className="h-4 sm:h-5 flex items-center">M</div>
                        <div className="h-4 sm:h-5 flex items-center">T</div>
                        <div className="h-4 sm:h-5 flex items-center">W</div>
                        <div className="h-4 sm:h-5 flex items-center">T</div>
                        <div className="h-4 sm:h-5 flex items-center">F</div>
                        <div className="h-4 sm:h-5 flex items-center">S</div>
                        <div className="h-4 sm:h-5 flex items-center">S</div>
                      </div>
                      {/* Heatmap grid (7 rows x 12 cols, column-flow) */}
                      <div className="grid grid-rows-7 grid-flow-col gap-1" role="grid" aria-label="12-week study activity calendar">
                        {heatmap.map((cell) => (
                          <div
                            key={cell.id}
                            role={cell.isFuture ? undefined : "gridcell"}
                            tabIndex={cell.isFuture ? -1 : 0}
                            aria-label={cell.tooltip || undefined}
                            className={`w-4 h-4 sm:w-5 sm:h-5 rounded-sm ${cell.isFuture ? 'opacity-0 pointer-events-none' : getHeatmapColor(cell.intensity)} hover:brightness-125 focus:brightness-125 focus:outline-none focus:ring-2 focus:ring-primary transition-colors cursor-pointer`}
                            title={cell.tooltip}
                          />
                        ))}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2 mt-4">
                    <span className="text-xs text-onSurfaceVariant font-body">Less</span>
                    {[0, 1, 2, 3, 4].map((intensity) => (
                      <div
                        key={intensity}
                        className={`w-4 h-4 sm:w-5 sm:h-5 rounded-sm ${getHeatmapColor(intensity)}`}
                      />
                    ))}
                    <span className="text-xs text-onSurfaceVariant font-body">More</span>
                  </div>
                </div>
              )}

              {/* Subject Breakdown Table */}
              {subjectBreakdown.length > 0 && (
                <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md">
                  <h3 className="text-lg font-medium text-onSurface font-heading mb-4">Subject Breakdown</h3>
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-outlineVariant">
                          <th className="text-left py-3 px-2 text-sm font-medium text-onSurfaceVariant font-body">
                            Subject
                          </th>
                          <th className="text-right py-3 px-2 text-sm font-medium text-onSurfaceVariant font-body">
                            Hours
                          </th>
                          <th className="text-right py-3 px-2 text-sm font-medium text-onSurfaceVariant font-body">
                            Sessions
                          </th>
                          <th className="text-right py-3 px-2 text-sm font-medium text-onSurfaceVariant font-body">
                            Avg★
                          </th>
                          <th className="text-center py-3 px-2 text-sm font-medium text-onSurfaceVariant font-body">
                            Skill
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        {subjectBreakdown
                          .sort((a, b) => b.hours - a.hours)
                          .map((subject) => (
                            <tr key={subject.name} className="border-b border-outlineVariant/50 hover:bg-surfaceContainerHighest/50">
                              <td className="py-3 px-2">
                                <div className="flex items-center gap-2">
                                  <div
                                    className="w-2 h-2 rounded-full"
                                    style={{ backgroundColor: subject.color }}
                                  />
                                  <span className="text-sm text-onSurface font-body">{subject.name}</span>
                                </div>
                              </td>
                              <td className="text-right py-3 px-2 text-sm text-onSurfaceVariant font-data">
                                {subject.hours.toFixed(1)}
                              </td>
                              <td className="text-right py-3 px-2 text-sm text-onSurfaceVariant font-body">
                                {subject.sessions}
                              </td>
                              <td className="text-right py-3 px-2">
                                <div className="flex justify-end gap-0.5">
                                  {renderStars(subject.avgConfidence)}
                                </div>
                              </td>
                              <td className="text-center py-3 px-2">
                                <span className={`px-2 py-1 text-xs rounded-full font-body ${
                                  subject.skillLevel === 'Expert' ? 'bg-tertiary/20 text-tertiary' :
                                  subject.skillLevel === 'Advanced' ? 'bg-primary/20 text-primary' :
                                  'bg-surfaceContainerHighest text-onSurfaceVariant'
                                }`}>
                                  {subject.skillLevel}
                                </span>
                              </td>
                            </tr>
                          ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </main>
    </div>
  );
}
