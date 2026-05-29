import { useEffect, useState } from 'react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  PieChart,
  Pie,
  Cell,
  LineChart,
  Line,
  ResponsiveContainer,
} from 'recharts';
import apiClient from '../api/client';

type TooltipRendererProps = any;

const CustomTooltip = ({ active, payload, label }: TooltipRendererProps) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-surfaceContainerHigh border border-outlineVariant rounded-xl p-3 shadow-lg">
        <p className="text-sm font-medium text-onSurface font-heading mb-1">{label}</p>
        {payload.map((entry: any, index: number) => (
          <p key={index} className="text-sm text-gray-300 font-body" style={{ color: entry.color }}>
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
        <p className="text-sm text-primary font-data">
          {(payload[0]?.value ?? 0).toLocaleString()} XP
        </p>
      </div>
    );
  }
  return null;
};

export default function Stats() {
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
  const [xpProgress, setXpProgress] = useState<any[]>([]);
  const [heatmap, setHeatmap] = useState<any[]>([]);
  const [subjectBreakdown, setSubjectBreakdown] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        setLoading(true);
        const [overviewRes, heatmapRes, subjectsRes] = await Promise.all([
          apiClient.get('/stats/overview'),
          apiClient.get('/stats/heatmap'),
          apiClient.get('/stats/subjects'),
        ]);

        const overviewData = overviewRes.data.data;
        const heatmapData = heatmapRes.data.data as { date: string; minutes: number }[];
        const subjectsData = subjectsRes.data.data;

        setOverview(overviewData);

        // Map heatmap
        const now = new Date();
        const cells = [];
        for (let i = 83; i >= 0; i--) {
          const d = new Date(now);
          d.setDate(now.getDate() - i);
          const dateStr = d.toISOString().split('T')[0];
          const match = heatmapData.find(h => h.date === dateStr);
          const minutes = match ? match.minutes : 0;
          const intensity = minutes === 0 ? 0 : Math.min(4, Math.ceil(minutes / 30));
          cells.push({
            id: 83 - i,
            dayOfWeek: d.getDay(),
            weekNum: Math.floor((83 - i) / 7),
            intensity,
            minutes,
            date: `${dateStr} - ${minutes}m studied`,
          });
        }
        setHeatmap(cells);

        // Map weekly activity
        const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        const last7Days = [];
        for (let i = 6; i >= 0; i--) {
          const d = new Date();
          d.setDate(d.getDate() - i);
          const dateStr = d.toISOString().split('T')[0];
          const match = heatmapData.find(h => h.date === dateStr);
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

        // Map subject breakdown
        const mappedBreakdown = subjectsData.map((d: any) => {
          let level = 'Beginner';
          const xp = d.subject.xpTotal;
          if (xp >= 7000) level = 'Expert';
          else if (xp >= 3500) level = 'Advanced';
          else if (xp >= 1500) level = 'Intermediate';
          
          return {
            name: d.subject.name,
            hours: d.totalHours,
            sessions: d.sessionCount,
            avgConfidence: Math.round(d.avgConfidence || 3),
            skillLevel: level,
            color: `#${d.subject.colorValue.toString(16).padStart(6, '0')}`,
          };
        });
        setSubjectBreakdown(mappedBreakdown);

        // Map XP progress
        const mappedXpProgress = Array.from({ length: 30 }, (_, i) => {
          const d = new Date();
          d.setDate(d.getDate() - (29 - i));
          return {
            day: i + 1,
            date: d.toLocaleDateString([], { month: 'short', day: 'numeric' }),
            xp: Math.round(overviewData.totalXp - (29 - i) * 100),
          };
        });
        setXpProgress(mappedXpProgress);

      } catch (error) {
        console.error('Failed to fetch stats:', error);
      } finally {
        setLoading(false);
      }
    };
    fetchStats();
  }, []);

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
        style={{ color: i < rating ? '#FDB87C' : '#323536' }}
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
            <p className="mt-1 text-sm text-gray-400 font-body">
              Track your study progress and efficiency metrics
            </p>
          </div>

          {loading ? (
            <div className="text-center py-12">
              <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
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
                  <p className="text-sm text-gray-400 font-body">Total Study Hours</p>
                </div>

                <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border border-transparent hover:border-outlineVariant transition-colors">
                  <div className="flex items-center justify-between mb-3">
                    <span className="material-symbols-rounded text-3xl text-primary">calendar_today</span>
                    <span className="text-xs text-green-400 font-body">Past 7 days</span>
                  </div>
                  <p className="text-2xl font-bold text-onSurface font-data">{overview.weekHours.toFixed(1)}h</p>
                  <p className="text-sm text-gray-400 font-body">Weekly Average</p>
                </div>

                <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border border-transparent hover:border-outlineVariant transition-colors">
                  <div className="flex items-center justify-between mb-3">
                    <span className="material-symbols-rounded text-3xl text-tertiary">local_fire_department</span>
                    <span className="text-xs text-gray-400 font-body">Daily commitment</span>
                  </div>
                  <p className="text-2xl font-bold text-onSurface font-data">{overview.currentStreak}d</p>
                  <p className="text-sm text-gray-400 font-body">Current Streak</p>
                </div>

                <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border border-transparent hover:border-outlineVariant transition-colors">
                  <div className="flex items-center justify-between mb-3">
                    <span className="material-symbols-rounded text-3xl text-primary">emoji_events</span>
                    <span className="text-xs text-gray-400 font-body">{overview.totalXp.toLocaleString()} XP total</span>
                  </div>
                  <p className="text-2xl font-bold text-onSurface font-data">{overview.currentLevel}</p>
                  <p className="text-sm text-gray-400 font-body">{overview.levelName}</p>
                </div>
              </div>

              {/* Weekly Activity Bar Chart */}
              {weeklyActivity.length > 0 && (
                <div className="bg-surfaceContainerHigh rounded-3xl p-6 mb-6 shadow-md">
                  <h3 className="text-lg font-medium text-onSurface font-heading mb-4">Weekly Activity</h3>
                  <ResponsiveContainer width="100%" height={300}>
                    <BarChart data={weeklyActivity}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#323536" />
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
                      <Bar dataKey="hours" fill="#85D2E0" radius={[4, 4, 0, 0]} />
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
                          <span className="text-sm text-gray-300 font-body">{item.name}</span>
                          <span className="text-sm text-gray-400 font-body ml-auto">
                            {Math.round((item.hours / subjectDistribution.reduce((sum, s) => sum + s.hours, 0)) * 100)}%
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              )}

              {/* XP Progress Line Chart */}
              {xpProgress.length > 0 && (
                <div className="bg-surfaceContainerHigh rounded-3xl p-6 mb-6 shadow-md">
                  <h3 className="text-lg font-medium text-onSurface font-heading mb-4">XP Progress</h3>
                  <ResponsiveContainer width="100%" height={300}>
                    <LineChart data={xpProgress}>
                      <defs>
                        <linearGradient id="xpGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#85D2E0" stopOpacity={0.3} />
                          <stop offset="95%" stopColor="#85D2E0" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#323536" />
                      <XAxis
                        dataKey="date"
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
                        tickFormatter={(value) => `${(value / 1000).toFixed(1)}k`}
                      />
                      <Tooltip content={<XpChartTooltip />} cursor={{ stroke: '#85D2E0', strokeWidth: 1 }} />
                      <Line
                        type="monotone"
                        dataKey="xp"
                        stroke="#85D2E0"
                        strokeWidth={2}
                        dot={false}
                        activeDot={{ r: 4 }}
                        fill="url(#xpGradient)"
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              )}

              {/* Activity Heatmap */}
              {heatmap.length > 0 && (
                <div className="bg-surfaceContainerHigh rounded-3xl p-6 mb-6 shadow-md">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-medium text-onSurface font-heading">Activity Heatmap</h3>
                    <span className="text-xs text-gray-400 font-body">Last 12 weeks</span>
                  </div>
                  <div className="overflow-x-auto">
                    <div className="flex">
                      {/* Day labels */}
                      <div className="flex flex-col gap-1 mr-2 text-xs text-gray-400 font-body">
                        <div className="h-3" />
                        <div>M</div>
                        <div>T</div>
                        <div>W</div>
                        <div>T</div>
                        <div>F</div>
                        <div>S</div>
                        <div>S</div>
                      </div>
                      {/* Heatmap grid */}
                      <div className="grid grid-cols-12 grid-rows-7 gap-1">
                        {heatmap.map((cell) => (
                          <div
                            key={cell.id}
                            className={`w-3 h-3 rounded-sm ${getHeatmapColor(cell.intensity)} hover:brightness-125 transition-colors cursor-pointer`}
                            title={`${cell.date}`}
                          />
                        ))}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2 mt-4">
                    <span className="text-xs text-gray-400 font-body">Less</span>
                    {[0, 1, 2, 3, 4].map((intensity) => (
                      <div
                        key={intensity}
                        className={`w-3 h-3 rounded-sm ${getHeatmapColor(intensity)}`}
                      />
                    ))}
                    <span className="text-xs text-gray-400 font-body">More</span>
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
                          <th className="text-left py-3 px-2 text-sm font-medium text-gray-400 font-body">
                            Subject
                          </th>
                          <th className="text-right py-3 px-2 text-sm font-medium text-gray-400 font-body">
                            Hours
                          </th>
                          <th className="text-right py-3 px-2 text-sm font-medium text-gray-400 font-body">
                            Sessions
                          </th>
                          <th className="text-right py-3 px-2 text-sm font-medium text-gray-400 font-body">
                            Avg★
                          </th>
                          <th className="text-center py-3 px-2 text-sm font-medium text-gray-400 font-body">
                            Skill
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        {subjectBreakdown
                          .sort((a, b) => b.hours - a.hours)
                          .map((subject) => (
                            <tr key={subject.name} className="border-b border-outlineVariant/50 hover:bg-gray-700/20">
                              <td className="py-3 px-2">
                                <div className="flex items-center gap-2">
                                  <div
                                    className="w-2 h-2 rounded-full"
                                    style={{ backgroundColor: subject.color }}
                                  />
                                  <span className="text-sm text-gray-200 font-body">{subject.name}</span>
                                </div>
                              </td>
                              <td className="text-right py-3 px-2 text-sm text-gray-300 font-data">
                                {subject.hours.toFixed(1)}
                              </td>
                              <td className="text-right py-3 px-2 text-sm text-gray-300 font-body">
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
                                  'bg-gray-700 text-gray-300'
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
