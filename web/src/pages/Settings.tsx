import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { useApi } from '../api/hooks';
import type { StatsOverview } from '../types';

const presetSeeds = [
  '#006874', // Deep Teal
  '#6750A4', // Purple
  '#0061A4', // Blue
  '#006E1C', // Green
  '#B3261E', // Red
  '#984061', // Pink
  '#AC3306', // Orange
  '#7B5800', // Brown
  '#386667', // Cyan
  '#343DFF', // Indigo
  '#1B6B46', // Forest
  '#4A4458', // Slate
];

const STORAGE_KEY = 'studytracker_settings';

interface SettingsState {
  seedColor: string;
  fontScale: 'small' | 'normal' | 'large';
  workDuration: number;
  shortBreak: number;
  longBreak: number;
  longBreakEvery: number;
  autoStartBreaks: boolean;
  vibrationOnComplete: boolean;
  enableNotifications: boolean;
  gracePeriod: number;
}

const loadSettings = (): SettingsState => {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      return JSON.parse(stored);
    }
  } catch (error) {
    console.error('Failed to load settings:', error);
  }
  return {
    seedColor: '#006874',
    fontScale: 'normal',
    workDuration: 25,
    shortBreak: 5,
    longBreak: 15,
    longBreakEvery: 4,
    autoStartBreaks: false,
    vibrationOnComplete: true,
    enableNotifications: true,
    gracePeriod: 2,
  };
};

const saveSettings = async (settings: SettingsState) => {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
    // Try to sync to backend if possible (fire and forget)
    const token = localStorage.getItem('access_token');
    if (token) {
      import('../api/client').then(({ default: apiClient }) => {
        apiClient.post('/settings', settings).catch(console.error);
      });
    }
  } catch (error) {
    console.error('Failed to save settings:', error);
  }
};

export default function Settings() {
  const { logout } = useAuth();
  const navigate = useNavigate();
  const { data: stats } = useApi<StatsOverview>('/stats/overview');

  const getEmailFromToken = () => {
    try {
      const token = localStorage.getItem('access_token');
      if (!token) return '';
      const base64Url = token.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(window.atob(base64).split('').map(function(c) {
          return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
      }).join(''));

      const payload = JSON.parse(jsonPayload);
      return payload.email || '';
    } catch (e) {
      return '';
    }
  };

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  // Theme settings
  const [seedColor, setSeedColor] = useState(() => loadSettings().seedColor);
  const [fontScale, setFontScale] = useState<'small' | 'normal' | 'large'>(() => loadSettings().fontScale);

  // Pomodoro settings
  const [workDuration, setWorkDuration] = useState(() => loadSettings().workDuration);
  const [shortBreak, setShortBreak] = useState(() => loadSettings().shortBreak);
  const [longBreak, setLongBreak] = useState(() => loadSettings().longBreak);
  const [longBreakEvery, setLongBreakEvery] = useState(() => loadSettings().longBreakEvery);
  const [autoStartBreaks, setAutoStartBreaks] = useState(() => loadSettings().autoStartBreaks);
  const [vibrationOnComplete, setVibrationOnComplete] = useState(() => loadSettings().vibrationOnComplete);

  // Notifications
  const [enableNotifications, setEnableNotifications] = useState(() => loadSettings().enableNotifications);

  // Streak settings
  const [gracePeriod, setGracePeriod] = useState(() => loadSettings().gracePeriod);
  const freezeTokens = stats?.freezeTokens ?? 0;

  // Save settings whenever they change
  useEffect(() => {
    saveSettings({
      seedColor,
      fontScale,
      workDuration,
      shortBreak,
      longBreak,
      longBreakEvery,
      autoStartBreaks,
      vibrationOnComplete,
      enableNotifications,
      gracePeriod,
    });
  }, [seedColor, fontScale, workDuration, shortBreak, longBreak, longBreakEvery,
      autoStartBreaks, vibrationOnComplete, enableNotifications, gracePeriod]);

  // Data management is mobile-only

  const renderFontScaleButton = (scale: 'small' | 'normal' | 'large', label: string) => (
    <button
      onClick={() => setFontScale(scale)}
      className={`px-4 py-2 rounded-lg text-sm font-medium font-body transition-all ${
        fontScale === scale
          ? 'bg-primary text-[#101415]'
          : 'bg-surface text-gray-400 hover:text-gray-300'
      }`}
    >
      {label}
    </button>
  );

  return (
    <div className="min-h-screen bg-background">
      <main className="p-6">
        <div className="max-w-4xl mx-auto">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-onSurface font-heading">Settings</h1>
            <p className="mt-1 text-sm text-gray-400 font-body">
              Customize your StudyTracker experience
            </p>
          </div>

          {/* Appearance Card */}
          <div className="bg-surfaceHigh rounded-2xl p-6 mb-6">
            <h3 className="text-lg font-medium text-onSurface font-heading mb-4 flex items-center gap-2">
              <span className="material-icons text-primary">palette</span>
              Appearance
            </h3>

            {/* Theme Mode */}
            <div className="mb-6">
              <label className="block text-sm font-medium text-gray-400 font-body mb-3">
                Theme Mode
              </label>
              <div className="px-4 py-2 bg-surface rounded-lg text-sm text-gray-300 font-body">
                Dark Mode (currently enabled)
              </div>
            </div>

            {/* Seed Color */}
            <div className="mb-6">
              <label className="block text-sm font-medium text-gray-400 font-body mb-3">
                Seed Color
              </label>
              <div className="flex flex-wrap gap-3">
                {presetSeeds.map((color) => (
                  <button
                    key={color}
                    onClick={() => setSeedColor(color)}
                    className={`w-10 h-10 rounded-full transition-all hover:scale-110 ${
                      seedColor === color ? 'ring-2 ring-white ring-offset-2 ring-offset-[#323536]' : ''
                    }`}
                    style={{ backgroundColor: color }}
                    title={color}
                  />
                ))}
              </div>
            </div>

            {/* Font Scale */}
            <div>
              <label className="block text-sm font-medium text-gray-400 font-body mb-3">
                Font Scale
              </label>
              <div className="flex gap-2">
                {renderFontScaleButton('small', 'Small (0.9x)')}
                {renderFontScaleButton('normal', 'Normal (1.0x)')}
                {renderFontScaleButton('large', 'Large (1.15x)')}
              </div>
            </div>
          </div>

          {/* Pomodoro Card */}
          <div className="bg-surfaceHigh rounded-2xl p-6 mb-6">
            <h3 className="text-lg font-medium text-onSurface font-heading mb-4 flex items-center gap-2">
              <span className="material-icons text-primary">timer</span>
              Pomodoro Timer
            </h3>

            {/* Work Duration */}
            <div className="mb-6">
              <div className="flex justify-between items-center mb-3">
                <label className="text-sm font-medium text-gray-400 font-body">
                  Work Duration
                </label>
                <span className="text-sm text-onSurface font-data">{workDuration} min</span>
              </div>
              <input
                type="range"
                min="5"
                max="90"
                value={workDuration}
                onChange={(e) => setWorkDuration(Number(e.target.value))}
                className="w-full h-2 bg-surface rounded-lg appearance-none cursor-pointer accent-primary"
              />
              <div className="flex justify-between text-xs text-gray-500 font-body mt-1">
                <span>5 min</span>
                <span>90 min</span>
              </div>
            </div>

            {/* Short Break */}
            <div className="mb-6">
              <div className="flex justify-between items-center mb-3">
                <label className="text-sm font-medium text-gray-400 font-body">
                  Short Break
                </label>
                <span className="text-sm text-onSurface font-data">{shortBreak} min</span>
              </div>
              <input
                type="range"
                min="1"
                max="30"
                value={shortBreak}
                onChange={(e) => setShortBreak(Number(e.target.value))}
                className="w-full h-2 bg-surface rounded-lg appearance-none cursor-pointer accent-primary"
              />
              <div className="flex justify-between text-xs text-gray-500 font-body mt-1">
                <span>1 min</span>
                <span>30 min</span>
              </div>
            </div>

            {/* Long Break */}
            <div className="mb-6">
              <div className="flex justify-between items-center mb-3">
                <label className="text-sm font-medium text-gray-400 font-body">
                  Long Break
                </label>
                <span className="text-sm text-onSurface font-data">{longBreak} min</span>
              </div>
              <input
                type="range"
                min="5"
                max="60"
                value={longBreak}
                onChange={(e) => setLongBreak(Number(e.target.value))}
                className="w-full h-2 bg-surface rounded-lg appearance-none cursor-pointer accent-primary"
              />
              <div className="flex justify-between text-xs text-gray-500 font-body mt-1">
                <span>5 min</span>
                <span>60 min</span>
              </div>
            </div>

            {/* Long Break Every */}
            <div className="mb-6">
              <div className="flex justify-between items-center mb-3">
                <label className="text-sm font-medium text-gray-400 font-body">
                  Long Break Every
                </label>
                <span className="text-sm text-onSurface font-data">{longBreakEvery} pomodoros</span>
              </div>
              <input
                type="range"
                min="2"
                max="8"
                value={longBreakEvery}
                onChange={(e) => setLongBreakEvery(Number(e.target.value))}
                className="w-full h-2 bg-surface rounded-lg appearance-none cursor-pointer accent-primary"
              />
              <div className="flex justify-between text-xs text-gray-500 font-body mt-1">
                <span>2 pomodoros</span>
                <span>8 pomodoros</span>
              </div>
            </div>

            {/* Auto-start Breaks */}
            <div className="flex items-center justify-between mb-4">
              <label className="text-sm font-medium text-gray-400 font-body">
                Auto-start Breaks
              </label>
              <button
                onClick={() => setAutoStartBreaks(!autoStartBreaks)}
                className={`w-12 h-6 rounded-full p-1 transition-colors ${
                  autoStartBreaks ? 'bg-primary' : 'bg-surface'
                }`}
              >
                <div
                  className={`w-4 h-4 rounded-full bg-white transition-transform ${
                    autoStartBreaks ? 'translate-x-6' : 'translate-x-0'
                  }`}
                />
              </button>
            </div>

            {/* Vibration on Complete */}
            <div className="flex items-center justify-between">
              <label className="text-sm font-medium text-gray-400 font-body">
                Vibration on Complete
              </label>
              <button
                onClick={() => setVibrationOnComplete(!vibrationOnComplete)}
                className={`w-12 h-6 rounded-full p-1 transition-colors ${
                  vibrationOnComplete ? 'bg-primary' : 'bg-surface'
                }`}
              >
                <div
                  className={`w-4 h-4 rounded-full bg-white transition-transform ${
                    vibrationOnComplete ? 'translate-x-6' : 'translate-x-0'
                  }`}
                />
              </button>
            </div>
          </div>

          {/* Notifications Card */}
          <div className="bg-surfaceHigh rounded-2xl p-6 mb-6">
            <h3 className="text-lg font-medium text-onSurface font-heading mb-4 flex items-center gap-2">
              <span className="material-icons text-primary">notifications</span>
              Notifications
            </h3>

            <div className="flex items-center justify-between">
              <label className="text-sm font-medium text-gray-400 font-body">
                Enable Notifications
              </label>
              <button
                onClick={() => setEnableNotifications(!enableNotifications)}
                className={`w-12 h-6 rounded-full p-1 transition-colors ${
                  enableNotifications ? 'bg-primary' : 'bg-surface'
                }`}
              >
                <div
                  className={`w-4 h-4 rounded-full bg-white transition-transform ${
                    enableNotifications ? 'translate-x-6' : 'translate-x-0'
                  }`}
                />
              </button>
            </div>
          </div>

          {/* Streak Card */}
          <div className="bg-surfaceHigh rounded-2xl p-6 mb-6">
            <h3 className="text-lg font-medium text-onSurface font-heading mb-4 flex items-center gap-2">
              <span className="material-icons text-tertiary">local_fire_department</span>
              Streak Settings
            </h3>

            {/* Grace Period */}
            <div className="mb-6">
              <div className="flex justify-between items-center mb-3">
                <label className="text-sm font-medium text-gray-400 font-body">
                  Grace Period
                </label>
                <span className="text-sm text-onSurface font-data">{gracePeriod}h</span>
              </div>
              <input
                type="range"
                min="0"
                max="4"
                step="0.5"
                value={gracePeriod}
                onChange={(e) => setGracePeriod(Number(e.target.value))}
                className="w-full h-2 bg-surface rounded-lg appearance-none cursor-pointer accent-tertiary"
              />
              <div className="flex justify-between text-xs text-gray-500 font-body mt-1">
                <span>0h</span>
                <span>4h</span>
              </div>
            </div>

            {/* Freeze Tokens */}
            <div className="flex items-center justify-between p-4 bg-surface rounded-xl">
              <div>
                <label className="text-sm font-medium text-gray-400 font-body">
                  Freeze Tokens Available
                </label>
                <p className="text-xs text-gray-500 font-body mt-1">
                  Use to protect your streak (max 1/week)
                </p>
              </div>
              <span className="px-3 py-1 bg-tertiary/20 text-tertiary text-sm font-medium rounded-full font-body">
                {freezeTokens} tokens
              </span>
            </div>
          </div>

          {/* Data Management Card */}
          <div className="bg-surfaceHigh rounded-2xl p-6 mb-6">
            <h3 className="text-lg font-medium text-onSurface font-heading mb-4 flex items-center gap-2">
              <span className="material-icons text-primary">storage</span>
              Data Management
            </h3>

            <div className="w-full flex items-start gap-3 p-4 bg-primary/10 border border-primary/20 rounded-xl">
              <span className="material-icons text-primary mt-0.5">info</span>
              <div>
                <h4 className="text-sm font-bold text-primary font-heading mb-1">Mobile App Required</h4>
                <p className="text-sm text-primary/80 font-body">
                  Features like data export, backup import, and local database management are exclusively available in the StudyTracker mobile application.
                </p>
              </div>
            </div>
          </div>

          {/* Sync Account Management */}
          <div className="bg-surfaceHigh rounded-2xl p-6">
            <h3 className="text-lg font-medium text-onSurface font-heading mb-4 flex items-center gap-2">
              <span className="material-icons text-primary">cloud_sync</span>
              Sync & Account
            </h3>
            
            <div className="p-4 bg-surface rounded-xl flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-green-500/20 flex items-center justify-center">
                  <span className="material-icons text-green-400">cloud_done</span>
                </div>
                <div>
                  <p className="text-sm font-bold text-onSurface font-heading">Cloud Sync Active</p>
                  <p className="text-xs text-gray-400 font-body">{getEmailFromToken()}</p>
                </div>
              </div>
              <span className="px-3 py-1 bg-green-500/20 text-green-400 text-xs font-medium rounded-full font-body">
                Connected
              </span>
            </div>

            <button
              onClick={handleLogout}
              className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-red-500/20 text-red-400 rounded-xl text-sm font-medium hover:bg-red-500/30 transition-colors font-body"
            >
              <span className="material-icons text-sm">logout</span>
              Disconnect & Sign Out
            </button>
          </div>
        </div>
      </main>
    </div>
  );
}
