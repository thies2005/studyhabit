import { useState } from 'react';

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

export default function Settings() {
  // Theme settings
  const [seedColor, setSeedColor] = useState('#006874');
  const [fontScale, setFontScale] = useState<'small' | 'normal' | 'large'>('normal');

  // Pomodoro settings
  const [workDuration, setWorkDuration] = useState(25);
  const [shortBreak, setShortBreak] = useState(5);
  const [longBreak, setLongBreak] = useState(15);
  const [longBreakEvery, setLongBreakEvery] = useState(4);
  const [autoStartBreaks, setAutoStartBreaks] = useState(false);
  const [vibrationOnComplete, setVibrationOnComplete] = useState(true);

  // Notifications
  const [enableNotifications, setEnableNotifications] = useState(true);

  // Streak settings
  const [gracePeriod, setGracePeriod] = useState(2);
  const freezeTokens = 3;

  // Data management
  const [showDeleteConfirm1, setShowDeleteConfirm1] = useState(false);
  const [showDeleteConfirm2, setShowDeleteConfirm2] = useState(false);
  const [deleteConfirmText, setDeleteConfirmText] = useState('');

  const handleExport = () => {
    // Mock export - would actually generate and download JSON
    const data = {
      exportVersion: 1,
      exportedAt: new Date().toISOString(),
      userStats: { totalXp: 12450, currentLevel: 4 },
      projects: [],
      achievements: [],
    };

    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `studytracker_export_${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleImport = () => {
    // Mock import - would actually show file picker
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    input.onchange = (e: Event) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (file) {
        // Process imported file
      }
    };
    input.click();
  };

  const handleClearData = () => {
    // Mock clear - would actually clear all data
    setShowDeleteConfirm2(false);
    setDeleteConfirmText('');
    setShowDeleteConfirm1(false);
  };

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

            {/* Export */}
            <button
              onClick={handleExport}
              className="w-full mb-3 flex items-center justify-center gap-2 px-4 py-3 bg-primary/20 text-primary rounded-xl text-sm font-medium hover:bg-primary/30 transition-colors font-body"
            >
              <span className="material-icons">upload</span>
              Export All Data
            </button>

            {/* Import */}
            <button
              onClick={handleImport}
              className="w-full mb-3 flex items-center justify-center gap-2 px-4 py-3 bg-primary/20 text-primary rounded-xl text-sm font-medium hover:bg-primary/30 transition-colors font-body"
            >
              <span className="material-icons">download</span>
              Import Data
            </button>

            {/* Clear All Data */}
            {!showDeleteConfirm1 ? (
              <button
                onClick={() => setShowDeleteConfirm1(true)}
                className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-red-500/20 text-red-400 rounded-xl text-sm font-medium hover:bg-red-500/30 transition-colors font-body"
              >
                <span className="material-icons">delete_forever</span>
                Clear All Data
              </button>
            ) : showDeleteConfirm1 && !showDeleteConfirm2 ? (
              <div className="w-full p-4 bg-red-500/10 border border-red-500/30 rounded-xl">
                <p className="text-sm text-red-400 font-body mb-4">
                  Are you sure? This action cannot be undone.
                </p>
                <div className="flex gap-2">
                  <button
                    onClick={() => setShowDeleteConfirm1(false)}
                    className="flex-1 px-4 py-2 bg-surface text-gray-300 rounded-lg text-sm font-medium hover:bg-gray-700 transition-colors font-body"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={() => setShowDeleteConfirm2(true)}
                    className="flex-1 px-4 py-2 bg-red-500 text-white rounded-lg text-sm font-medium hover:bg-red-600 transition-colors font-body"
                  >
                    Yes, Delete
                  </button>
                </div>
              </div>
            ) : (
              <div className="w-full p-4 bg-red-500/10 border border-red-500/30 rounded-xl">
                <p className="text-sm text-red-400 font-body mb-3">
                  Type "DELETE" to confirm:
                </p>
                <input
                  type="text"
                  value={deleteConfirmText}
                  onChange={(e) => setDeleteConfirmText(e.target.value)}
                  placeholder="DELETE"
                  className="w-full mb-3 px-4 py-2 bg-surface text-onSurface rounded-lg text-sm font-body focus:outline-none focus:ring-2 focus:ring-red-500"
                />
                <div className="flex gap-2">
                  <button
                    onClick={() => {
                      setShowDeleteConfirm2(false);
                      setDeleteConfirmText('');
                    }}
                    className="flex-1 px-4 py-2 bg-surface text-gray-300 rounded-lg text-sm font-medium hover:bg-gray-700 transition-colors font-body"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleClearData}
                    disabled={deleteConfirmText !== 'DELETE'}
                    className={`flex-1 px-4 py-2 bg-red-500 text-white rounded-lg text-sm font-medium transition-colors font-body ${
                      deleteConfirmText !== 'DELETE' ? 'opacity-50 cursor-not-allowed' : 'hover:bg-red-600'
                    }`}
                  >
                    Confirm Delete
                  </button>
                </div>
              </div>
            )}
          </div>

          {/* Connect to Server Card (Disabled) */}
          <div className="bg-surfaceHigh rounded-2xl p-6 opacity-50">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-xl bg-gray-700 flex items-center justify-center">
                  <span className="material-icons text-gray-400 text-2xl">cloud_sync</span>
                </div>
                <div>
                  <h3 className="text-base font-semibold text-onSurface font-heading">
                    Connect to Server
                  </h3>
                  <p className="text-sm text-gray-400 font-body">
                    Sync across devices
                  </p>
                </div>
              </div>
              <span className="px-3 py-1 bg-gray-700 text-gray-400 text-xs font-medium rounded-full font-body">
                Coming Soon
              </span>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
