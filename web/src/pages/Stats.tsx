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

// Mock data for demo purposes
const weeklyActivityData = [
  { day: 'Mon', hours: 2.5, minutes: 150 },
  { day: 'Tue', hours: 3.2, minutes: 192 },
  { day: 'Wed', hours: 1.8, minutes: 108 },
  { day: 'Thu', hours: 4.5, minutes: 270 },
  { day: 'Fri', hours: 3.0, minutes: 180 },
  { day: 'Sat', hours: 1.2, minutes: 72 },
  { day: 'Sun', hours: 2.8, minutes: 168 },
];

const subjectDistributionData = [
  { name: 'Neuroscience', hours: 42, value: 42, color: '#85D2E0' },
  { name: 'Math', hours: 35, value: 35, color: '#FDB87C' },
  { name: 'Physics', hours: 28, value: 28, color: '#006874' },
  { name: 'Chemistry', hours: 20, value: 20, color: '#323536' },
];

const xpProgressData = Array.from({ length: 30 }, (_, i) => ({
  day: i + 1,
  date: `Oct ${i + 1}`,
  xp: Math.round(8000 + (i * 150) + Math.random() * 100),
}));

const heatmapData = Array.from({ length: 84 }, (_, i) => {
  const dayOfWeek = i % 7;
  const weekNum = Math.floor(i / 7);
  const intensity = Math.floor(Math.random() * 5);
  return {
    id: i,
    dayOfWeek,
    weekNum,
    intensity,
    minutes: intensity * 30 + Math.floor(Math.random() * 30),
    date: `Week ${weekNum + 1} - ${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dayOfWeek]}`,
  };
});

const subjectBreakdownData = [
  { name: 'Neuroscience', hours: 42, sessions: 28, avgConfidence: 4.2, skillLevel: 'Advanced', color: '#85D2E0' },
  { name: 'Math', hours: 35, sessions: 32, avgConfidence: 3.8, skillLevel: 'Intermediate', color: '#FDB87C' },
  { name: 'Physics', hours: 28, sessions: 24, avgConfidence: 4.5, skillLevel: 'Expert', color: '#006874' },
  { name: 'Chemistry', hours: 20, sessions: 18, avgConfidence: 3.5, skillLevel: 'Intermediate', color: '#323536' },
  { name: 'Biology', hours: 15, sessions: 12, avgConfidence: 4.0, skillLevel: 'Intermediate', color: '#5D9ECE' },
];

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type TooltipRendererProps = { active?: boolean; payload?: any[]; label?: string };

const CustomTooltip = ({ active, payload, label }: TooltipRendererProps) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-surfaceHigh border border-gray-700 rounded-lg p-3 shadow-lg">
        <p className="text-sm font-medium text-onSurface font-heading mb-1">{label}</p>
        {payload.map((entry, index: number) => (
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
      <div className="bg-surfaceHigh border border-gray-700 rounded-lg p-3 shadow-lg">
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
      <div className="bg-surfaceHigh border border-gray-700 rounded-lg p-3 shadow-lg">
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
  const totalHours = 140;
  const weekHours = 19;
  const currentStreak = 12;
  const totalXp = 12450;
  const currentLevel = 4;
  const levelName = 'Adept';
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // Mock API call - replace with actual fetch when backend is ready
    const fetchStats = async () => {
      setLoading(true);
      // Simulate API delay
      await new Promise(resolve => setTimeout(resolve, 500));
      setLoading(false);
    };
    fetchStats();
  }, []);

  const getHeatmapColor = (intensity: number) => {
    switch (intensity) {
      case 0: return 'bg-[#1C2021]';
      case 1: return 'bg-primary/20';
      case 2: return 'bg-primary/40';
      case 3: return 'bg-primary/60';
      case 4: return 'bg-primary';
      default: return 'bg-[#1C2021]';
    }
  };

  const renderStars = (rating: number) => {
    return Array.from({ length: 5 }, (_, i) => (
      <span
        key={i}
        className="material-icons text-sm"
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
                <div className="bg-surfaceHigh rounded-2xl p-6">
                  <div className="flex items-center justify-between mb-3">
                    <span className="material-icons text-3xl text-primary">schedule</span>
                    <span className="text-xs text-green-400 font-body">+12% vs last week</span>
                  </div>
                  <p className="text-2xl font-bold text-onSurface font-data">{totalHours.toFixed(1)}h</p>
                  <p className="text-sm text-gray-400 font-body">Total Study Hours</p>
                </div>

                <div className="bg-surfaceHigh rounded-2xl p-6">
                  <div className="flex items-center justify-between mb-3">
                    <span className="material-icons text-3xl text-primary">calendar_today</span>
                    <span className="text-xs text-green-400 font-body">+8% vs last week</span>
                  </div>
                  <p className="text-2xl font-bold text-onSurface font-data">{weekHours.toFixed(1)}h</p>
                  <p className="text-sm text-gray-400 font-body">Weekly Average</p>
                </div>

                <div className="bg-surfaceHigh rounded-2xl p-6">
                  <div className="flex items-center justify-between mb-3">
                    <span className="material-icons text-3xl text-tertiary">local_fire_department</span>
                    <span className="text-xs text-gray-400 font-body">Personal best: 28d</span>
                  </div>
                  <p className="text-2xl font-bold text-onSurface font-data">{currentStreak}d</p>
                  <p className="text-sm text-gray-400 font-body">Current Streak</p>
                </div>

                <div className="bg-surfaceHigh rounded-2xl p-6">
                  <div className="flex items-center justify-between mb-3">
                    <span className="material-icons text-3xl text-primary">emoji_events</span>
                    <span className="text-xs text-gray-400 font-body">{totalXp.toLocaleString()} / 15,000 XP</span>
                  </div>
                  <p className="text-2xl font-bold text-onSurface font-data">{currentLevel}</p>
                  <p className="text-sm text-gray-400 font-body">{levelName}</p>
                </div>
              </div>

              {/* Weekly Activity Bar Chart */}
              <div className="bg-surfaceHigh rounded-2xl p-6 mb-6">
                <h3 className="text-lg font-medium text-onSurface font-heading mb-4">Weekly Activity</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={weeklyActivityData}>
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

              {/* Subject Distribution Pie Chart */}
              <div className="bg-surfaceHigh rounded-2xl p-6 mb-6">
                <h3 className="text-lg font-medium text-onSurface font-heading mb-4">Subject Distribution</h3>
                <div className="flex flex-col md:flex-row items-center gap-6">
                  <div className="flex-1 w-full">
                    <ResponsiveContainer width="100%" height={300}>
                      <PieChart>
                        <Pie
                          data={subjectDistributionData}
                          cx="50%"
                          cy="50%"
                          innerRadius={60}
                          outerRadius={100}
                          paddingAngle={2}
                          dataKey="value"
                        >
                          {subjectDistributionData.map((entry, index) => (
                            <Cell key={`cell-${index}`} fill={entry.color} />
                          ))}
                        </Pie>
                        <Tooltip content={<CustomTooltip />} />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                  <div className="flex-1 space-y-3">
                    {subjectDistributionData.map((item) => (
                      <div key={item.name} className="flex items-center gap-3">
                        <div
                          className="w-3 h-3 rounded-full"
                          style={{ backgroundColor: item.color }}
                        />
                        <span className="text-sm text-gray-300 font-body">{item.name}</span>
                        <span className="text-sm text-gray-400 font-body ml-auto">
                          {Math.round((item.hours / subjectDistributionData.reduce((sum, s) => sum + s.hours, 0)) * 100)}%
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              {/* XP Progress Line Chart */}
              <div className="bg-surfaceHigh rounded-2xl p-6 mb-6">
                <h3 className="text-lg font-medium text-onSurface font-heading mb-4">XP Progress</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <LineChart data={xpProgressData}>
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

              {/* Activity Heatmap */}
              <div className="bg-surfaceHigh rounded-2xl p-6 mb-6">
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
                      {heatmapData.map((cell) => (
                        <div
                          key={cell.id}
                          className={`w-3 h-3 rounded-sm ${getHeatmapColor(cell.intensity)} hover:brightness-125 transition-colors cursor-pointer`}
                          title={`${cell.date}: ${cell.minutes} minutes`}
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

              {/* Subject Breakdown Table */}
              <div className="bg-surfaceHigh rounded-2xl p-6">
                <h3 className="text-lg font-medium text-onSurface font-heading mb-4">Subject Breakdown</h3>
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr className="border-b border-gray-700">
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
                      {subjectBreakdownData
                        .sort((a, b) => b.hours - a.hours)
                        .map((subject) => (
                          <tr key={subject.name} className="border-b border-gray-700/50 hover:bg-gray-700/20">
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
                              <span className="px-2 py-1 text-xs rounded-full font-body ${
                                subject.skillLevel === 'Expert' ? 'bg-tertiary/20 text-tertiary' :
                                subject.skillLevel === 'Advanced' ? 'bg-primary/20 text-primary' :
                                'bg-gray-700 text-gray-300'
                              }">
                                {subject.skillLevel}
                              </span>
                            </td>
                          </tr>
                        ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </>
          )}
        </div>
      </main>
    </div>
  );
}
