import React, { useState, useEffect, useRef, useCallback } from 'react';
import Modal from './Modal';
import apiClient from '../api/client';
import type { Subject } from '../types';

interface PomodoroTimerModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialSubjectId?: string;
  onSessionLogged?: () => void;
}

type TimerMode = 'pomodoro' | 'free';
type PomodoroPhase = 'work' | 'shortBreak' | 'longBreak';

function playChime() {
  try {
    const AudioContextClass = window.AudioContext || (window as any).webkitAudioContext;
    if (!AudioContextClass) return;
    const ctx = new AudioContextClass();
    const now = ctx.currentTime;
    
    // Play a friendly two-tone chime
    const osc1 = ctx.createOscillator();
    const osc2 = ctx.createOscillator();
    const gain = ctx.createGain();

    osc1.type = 'sine';
    osc1.frequency.setValueAtTime(587.33, now); // D5
    osc1.frequency.setValueAtTime(880, now + 0.15); // A5

    osc2.type = 'triangle';
    osc2.frequency.setValueAtTime(293.66, now); // D4
    osc2.frequency.setValueAtTime(440, now + 0.15); // A4

    gain.gain.setValueAtTime(0.3, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.8);

    osc1.connect(gain);
    osc2.connect(gain);
    gain.connect(ctx.destination);

    osc1.start(now);
    osc2.start(now);
    osc1.stop(now + 0.8);
    osc2.stop(now + 0.8);
  } catch {
    // Audio playback not allowed or not supported
  }
}

export default function PomodoroTimerModal({
  isOpen,
  onClose,
  initialSubjectId,
  onSessionLogged,
}: PomodoroTimerModalProps) {
  // Subjects list
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [selectedSubjectId, setSelectedSubjectId] = useState<string>(initialSubjectId || '');
  const [loadingSubjects, setLoadingSubjects] = useState(false);

  // Settings
  const [workDuration, setWorkDuration] = useState(25);
  const [shortBreak, setShortBreak] = useState(5);
  const [longBreak, setLongBreak] = useState(15);
  const [longBreakEvery, setLongBreakEvery] = useState(4);
  const [autoStartBreaks, setAutoStartBreaks] = useState(false);
  const [vibration, setVibration] = useState(true);

  // Timer states
  const [mode, setMode] = useState<TimerMode>('pomodoro');
  const [phase, setPhase] = useState<PomodoroPhase>('work');
  const [isRunning, setIsRunning] = useState(false);
  const [timeLeft, setTimeLeft] = useState(25 * 60);
  const [freeSeconds, setFreeSeconds] = useState(0);
  const [pomodorosCompleted, setPomodorosCompleted] = useState(0);
  const [totalWorkSeconds, setTotalWorkSeconds] = useState(0);

  // Start timestamp
  const sessionStartTimeRef = useRef<Date | null>(null);

  // Log / Review modal view
  const [isLoggingView, setIsLoggingView] = useState(false);
  const [confidence, setConfidence] = useState<number | null>(null);
  const [notes, setNotes] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [logError, setLogError] = useState<string | null>(null);

  // Fetch subjects and settings on mount / open
  useEffect(() => {
    if (!isOpen) return;

    setLoadingSubjects(true);
    apiClient.get('/subjects')
      .then((res) => {
        const subs = res.data.data || [];
        setSubjects(subs);
        if (initialSubjectId && subs.some((s: Subject) => s.id === initialSubjectId)) {
          setSelectedSubjectId(initialSubjectId);
        } else if (subs.length > 0 && !selectedSubjectId) {
          setSelectedSubjectId(subs[0].id);
        }
      })
      .catch((e) => console.error('Failed to load subjects', e))
      .finally(() => setLoadingSubjects(false));

    apiClient.get('/settings')
      .then((res) => {
        const data = res.data.data;
        if (data) {
          const w = data['pomodoro.workDuration'] ?? 25;
          const sb = data['pomodoro.shortBreak'] ?? 5;
          const lb = data['pomodoro.longBreak'] ?? 15;
          const lbe = data['pomodoro.longBreakEvery'] ?? 4;
          const asb = data['pomodoro.autoStartBreaks'] ?? false;
          const vib = data['pomodoro.vibration'] ?? true;

          setWorkDuration(w);
          setShortBreak(sb);
          setLongBreak(lb);
          setLongBreakEvery(lbe);
          setAutoStartBreaks(asb);
          setVibration(vib);

          // If timer not started yet, set initial timeLeft to configured work duration
          if (!sessionStartTimeRef.current) {
            setTimeLeft(w * 60);
          }
        }
      })
      .catch((e) => console.error('Failed to load settings', e));
  }, [isOpen, initialSubjectId]);

  // Adjust duration if subject changes and has specific defaultDurationMinutes
  const handleSubjectChange = (newSubjectId: string) => {
    setSelectedSubjectId(newSubjectId);
    if (!isRunning && mode === 'pomodoro' && phase === 'work') {
      const sub = subjects.find(s => s.id === newSubjectId);
      if (sub?.defaultDurationMinutes) {
        setTimeLeft(sub.defaultDurationMinutes * 60);
      }
    }
  };

  // Get current phase total seconds
  const getCurrentPhaseTotalSeconds = useCallback(() => {
    if (phase === 'work') {
      const sub = subjects.find(s => s.id === selectedSubjectId);
      return (sub?.defaultDurationMinutes || workDuration) * 60;
    }
    if (phase === 'shortBreak') return shortBreak * 60;
    return longBreak * 60;
  }, [phase, subjects, selectedSubjectId, workDuration, shortBreak, longBreak]);

  // Handle phase advance
  const handlePhaseAdvance = useCallback(() => {
    playChime();
    if (vibration && navigator.vibrate) {
      navigator.vibrate([200, 100, 200]);
    }

    if (phase === 'work') {
      const newCompleted = pomodorosCompleted + 1;
      setPomodorosCompleted(newCompleted);
      const nextPhase: PomodoroPhase = (newCompleted % longBreakEvery === 0) ? 'longBreak' : 'shortBreak';
      setPhase(nextPhase);
      const nextDuration = nextPhase === 'longBreak' ? longBreak * 60 : shortBreak * 60;
      setTimeLeft(nextDuration);
      setIsRunning(autoStartBreaks);
    } else {
      setPhase('work');
      const sub = subjects.find(s => s.id === selectedSubjectId);
      const workSec = (sub?.defaultDurationMinutes || workDuration) * 60;
      setTimeLeft(workSec);
      setIsRunning(autoStartBreaks);
    }
  }, [phase, pomodorosCompleted, longBreakEvery, longBreak, shortBreak, autoStartBreaks, subjects, selectedSubjectId, workDuration, vibration]);

  // Timer Tick Interval
  useEffect(() => {
    if (!isRunning) return;

    if (!sessionStartTimeRef.current) {
      sessionStartTimeRef.current = new Date();
    }

    const interval = setInterval(() => {
      if (mode === 'pomodoro') {
        setTimeLeft((prev) => {
          if (prev <= 1) {
            handlePhaseAdvance();
            return 0;
          }
          if (phase === 'work') {
            setTotalWorkSeconds((sec) => sec + 1);
          }
          return prev - 1;
        });
      } else {
        // Free stopwatch
        setFreeSeconds((prev) => {
          const next = prev + 1;
          setTotalWorkSeconds(next);
          return next;
        });
      }
    }, 1000);

    return () => clearInterval(interval);
  }, [isRunning, mode, phase, handlePhaseAdvance]);

  // Toggle start/pause
  const togglePlayPause = () => {
    if (!isRunning && !sessionStartTimeRef.current) {
      sessionStartTimeRef.current = new Date();
    }
    setIsRunning(!isRunning);
  };

  // Reset timer
  const handleReset = () => {
    setIsRunning(false);
    if (mode === 'pomodoro') {
      setTimeLeft(getCurrentPhaseTotalSeconds());
    } else {
      setFreeSeconds(0);
    }
  };

  // Switch phase manually
  const switchPhaseManually = (newPhase: PomodoroPhase) => {
    setIsRunning(false);
    setPhase(newPhase);
    if (newPhase === 'work') {
      const sub = subjects.find(s => s.id === selectedSubjectId);
      setTimeLeft((sub?.defaultDurationMinutes || workDuration) * 60);
    } else if (newPhase === 'shortBreak') {
      setTimeLeft(shortBreak * 60);
    } else {
      setTimeLeft(longBreak * 60);
    }
  };

  // Switch mode
  const switchMode = (newMode: TimerMode) => {
    setIsRunning(false);
    setMode(newMode);
    if (newMode === 'pomodoro') {
      setPhase('work');
      setTimeLeft(getCurrentPhaseTotalSeconds());
    } else {
      setFreeSeconds(0);
    }
  };

  // Formatting helpers
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const formatFreeTime = (seconds: number) => {
    const hrs = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    if (hrs > 0) {
      return `${hrs.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  // Open Log / Complete View
  const handleOpenLogView = () => {
    setIsRunning(false);
    setIsLoggingView(true);
  };

  // Save session via POST /sessions
  const handleSaveSession = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedSubjectId) {
      setLogError('Please select a subject to log this session.');
      return;
    }

    const calculatedMinutes = Math.max(1, Math.round(totalWorkSeconds / 60));
    const plannedMinutes = mode === 'pomodoro' ? Math.max(workDuration, calculatedMinutes) : calculatedMinutes;
    const startedAt = sessionStartTimeRef.current
      ? sessionStartTimeRef.current.toISOString()
      : new Date(Date.now() - calculatedMinutes * 60 * 1000).toISOString();
    const endedAt = new Date().toISOString();

    try {
      setIsSubmitting(true);
      setLogError(null);

      await apiClient.post('/sessions', {
        subjectId: selectedSubjectId,
        startedAt,
        endedAt,
        plannedDurationMinutes: plannedMinutes,
        actualDurationMinutes: calculatedMinutes,
        pomodorosCompleted: mode === 'pomodoro' ? Math.max(pomodorosCompleted, 1) : 0,
        confidenceRating: confidence,
        notes: notes.trim() || null,
        isFreeTimer: mode === 'free',
      });

      // Reset and trigger refresh
      setIsLoggingView(false);
      setIsRunning(false);
      sessionStartTimeRef.current = null;
      setPomodorosCompleted(0);
      setTotalWorkSeconds(0);
      setFreeSeconds(0);
      setNotes('');
      setConfidence(null);

      if (onSessionLogged) {
        onSessionLogged();
      }
      onClose();
    } catch (err: any) {
      console.error('Failed to log session:', err);
      setLogError(err.response?.data?.error || err.message || 'Failed to log session.');
    } finally {
      setIsSubmitting(false);
    }
  };

  // SVG Ring Progress Calculations
  const radius = 110;
  const circumference = 2 * Math.PI * radius;
  const currentTotalSeconds = getCurrentPhaseTotalSeconds();
  const progressRatio = mode === 'pomodoro'
    ? Math.max(0, Math.min(1, (currentTotalSeconds - timeLeft) / (currentTotalSeconds || 1)))
    : ((freeSeconds % 60) / 60);
  const strokeDashoffset = circumference - progressRatio * circumference;

  const currentSubject = subjects.find(s => s.id === selectedSubjectId);

  if (!isOpen) return null;

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Study Timer" maxWidthClass="max-w-xl">
      {/* Header */}
      <div className="px-6 py-4 border-b border-outlineVariant flex justify-between items-center bg-surfaceContainer">
        <div className="flex items-center gap-3">
          <span className="material-symbols-rounded text-primary text-2xl" aria-hidden="true">
            {mode === 'pomodoro' ? 'timer' : 'hourglass_top'}
          </span>
          <h2 className="text-xl font-bold text-onSurface font-heading">
            {isLoggingView ? 'Log Study Session' : 'Study Timer'}
          </h2>
        </div>
        <button
          onClick={onClose}
          aria-label="Close timer"
          className="w-11 h-11 rounded-full flex items-center justify-center text-onSurfaceVariant hover:bg-surface hover:text-onSurface transition-colors"
        >
          <span className="material-symbols-rounded text-xl" aria-hidden="true">close</span>
        </button>
      </div>

      {!isLoggingView ? (
        <div className="p-6 flex flex-col items-center">
          {/* Top Controls: Subject Picker & Mode Switcher */}
          <div className="w-full flex flex-col sm:flex-row items-center justify-between gap-3 mb-6">
            {/* Subject Selector */}
            <div className="w-full sm:w-64">
              <label htmlFor="timer-subject-select" className="sr-only">Select Subject</label>
              <select
                id="timer-subject-select"
                value={selectedSubjectId}
                disabled={isRunning || loadingSubjects}
                onChange={(e) => handleSubjectChange(e.target.value)}
                className="w-full px-3 py-2 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface text-sm font-medium focus:outline-none transition-colors"
              >
                {subjects.map((sub) => (
                  <option key={sub.id} value={sub.id}>
                    {sub.name}
                  </option>
                ))}
              </select>
            </div>

            {/* Mode Switcher */}
            <div className="flex bg-surface p-1 rounded-xl border border-outlineVariant" role="tablist" aria-label="Timer mode">
              <button
                type="button"
                role="tab"
                aria-selected={mode === 'pomodoro'}
                onClick={() => switchMode('pomodoro')}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  mode === 'pomodoro'
                    ? 'bg-primary text-background shadow-sm'
                    : 'text-onSurfaceVariant hover:text-onSurface'
                }`}
              >
                Pomodoro
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={mode === 'free'}
                onClick={() => switchMode('free')}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  mode === 'free'
                    ? 'bg-primary text-background shadow-sm'
                    : 'text-onSurfaceVariant hover:text-onSurface'
                }`}
              >
                Free Stopwatch
              </button>
            </div>
          </div>

          {/* Pomodoro Phase Selector (Work, Short Break, Long Break) */}
          {mode === 'pomodoro' && (
            <div className="flex gap-2 mb-6" role="tablist" aria-label="Pomodoro phase">
              <button
                type="button"
                role="tab"
                aria-selected={phase === 'work'}
                onClick={() => switchPhaseManually('work')}
                className={`px-3.5 py-1.5 rounded-full text-xs font-medium transition-all ${
                  phase === 'work'
                    ? 'bg-primary/20 text-primary border border-primary/40'
                    : 'bg-surface text-onSurfaceVariant hover:text-onSurface border border-outlineVariant'
                }`}
              >
                Focus ({currentSubject?.defaultDurationMinutes || workDuration}m)
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={phase === 'shortBreak'}
                onClick={() => switchPhaseManually('shortBreak')}
                className={`px-3.5 py-1.5 rounded-full text-xs font-medium transition-all ${
                  phase === 'shortBreak'
                    ? 'bg-secondary/20 text-secondary border border-secondary/40'
                    : 'bg-surface text-onSurfaceVariant hover:text-onSurface border border-outlineVariant'
                }`}
              >
                Short Break ({shortBreak}m)
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={phase === 'longBreak'}
                onClick={() => switchPhaseManually('longBreak')}
                className={`px-3.5 py-1.5 rounded-full text-xs font-medium transition-all ${
                  phase === 'longBreak'
                    ? 'bg-tertiary/20 text-tertiary border border-tertiary/40'
                    : 'bg-surface text-onSurfaceVariant hover:text-onSurface border border-outlineVariant'
                }`}
              >
                Long Break ({longBreak}m)
              </button>
            </div>
          )}

          {/* Circular Countdown Ring */}
          <div className="relative flex items-center justify-center my-4">
            <svg width="260" height="260" className="transform -rotate-90">
              {/* Background Track */}
              <circle
                cx="130"
                cy="130"
                r={radius}
                stroke="currentColor"
                strokeWidth="10"
                fill="transparent"
                className="text-surfaceContainerHighest"
              />
              {/* Animated Progress Ring */}
              <circle
                cx="130"
                cy="130"
                r={radius}
                stroke="currentColor"
                strokeWidth="10"
                strokeDasharray={circumference}
                strokeDashoffset={strokeDashoffset}
                strokeLinecap="round"
                fill="transparent"
                className={`transition-all duration-1000 ease-linear ${
                  phase === 'work' ? 'text-primary' : phase === 'shortBreak' ? 'text-secondary' : 'text-tertiary'
                }`}
              />
            </svg>

            {/* Inner Content */}
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
              <span className="text-4xl sm:text-5xl font-bold font-data text-onSurface tracking-tight">
                {mode === 'pomodoro' ? formatTime(timeLeft) : formatFreeTime(freeSeconds)}
              </span>
              <span className="mt-1 text-xs uppercase tracking-wider font-semibold font-body text-onSurfaceVariant">
                {mode === 'free'
                  ? (isRunning ? 'Stopwatch Active' : 'Paused')
                  : phase === 'work'
                  ? 'Focus Interval'
                  : phase === 'shortBreak'
                  ? 'Short Break'
                  : 'Long Break'}
              </span>
              {mode === 'pomodoro' && pomodorosCompleted > 0 && (
                <div className="flex items-center gap-1 mt-2" aria-label={`${pomodorosCompleted} pomodoros completed`}>
                  {Array.from({ length: pomodorosCompleted }).map((_, i) => (
                    <span key={i} className="w-2 h-2 rounded-full bg-primary" />
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Action Controls: Play/Pause, Reset, Complete */}
          <div className="flex items-center gap-4 mt-6">
            <button
              type="button"
              onClick={handleReset}
              aria-label="Reset timer"
              title="Reset"
              className="w-12 h-12 rounded-full bg-surface border border-outlineVariant text-onSurfaceVariant hover:text-onSurface hover:bg-surfaceContainerHighest flex items-center justify-center transition-all"
            >
              <span className="material-symbols-rounded text-2xl" aria-hidden="true">restart_alt</span>
            </button>

            <button
              type="button"
              onClick={togglePlayPause}
              aria-label={isRunning ? 'Pause timer' : 'Start timer'}
              className="w-16 h-16 rounded-full bg-primary text-background hover:bg-primary-container hover:text-primary-onContainer flex items-center justify-center shadow-lg transition-transform hover:scale-105"
            >
              <span className="material-symbols-rounded text-4xl" aria-hidden="true">
                {isRunning ? 'pause' : 'play_arrow'}
              </span>
            </button>

            <button
              type="button"
              onClick={handleOpenLogView}
              aria-label="Complete and log session"
              title="Complete and Log Session"
              className="w-12 h-12 rounded-full bg-surface border border-outlineVariant text-primary hover:bg-primary/10 flex items-center justify-center transition-all"
            >
              <span className="material-symbols-rounded text-2xl" aria-hidden="true">done_all</span>
            </button>
          </div>

          <div className="mt-6 text-center">
            <p className="text-xs text-onSurfaceVariant font-body">
              Total Focus Time Tracked: <span className="font-semibold text-onSurface">{Math.floor(totalWorkSeconds / 60)} min {totalWorkSeconds % 60}s</span>
            </p>
          </div>
        </div>
      ) : (
        /* Log / Complete Session Form */
        <form onSubmit={handleSaveSession} className="p-6 space-y-5 max-h-[75vh] overflow-y-auto">
          {logError && (
            <div role="alert" className="p-3 bg-red-500/10 border border-red-500/30 rounded-xl text-sm text-red-400 font-body">
              {logError}
            </div>
          )}

          <div className="bg-surfaceContainerHigh p-4 rounded-2xl flex items-center justify-between border border-outlineVariant">
            <div>
              <p className="text-xs text-onSurfaceVariant font-body">Subject</p>
              <p className="text-base font-bold text-onSurface font-heading">
                {currentSubject?.name || 'Selected Subject'}
              </p>
            </div>
            <div className="text-right">
              <p className="text-xs text-onSurfaceVariant font-body">Duration</p>
              <p className="text-lg font-bold text-primary font-data">
                {Math.max(1, Math.round(totalWorkSeconds / 60))} min
              </p>
            </div>
          </div>

          {/* Confidence Rating (1–5 Stars) */}
          <div>
            <label className="block text-sm font-medium text-onSurfaceVariant mb-2 font-body">
              How confident do you feel with this session?
            </label>
            <div className="flex items-center space-x-2">
              {[1, 2, 3, 4, 5].map((star) => (
                <button
                  key={star}
                  type="button"
                  onClick={() => setConfidence(star === confidence ? null : star)}
                  aria-label={`Rate confidence ${star} out of 5 stars`}
                  aria-pressed={confidence === star}
                  className="focus:outline-none transition-transform hover:scale-125 p-1 rounded-md"
                >
                  <span className={`material-symbols-rounded text-2xl ${
                    confidence && star <= confidence ? 'text-yellow-500' : 'text-outlineVariant'
                  }`}>
                    star
                  </span>
                </button>
              ))}
              <span className="text-xs text-onSurfaceVariant ml-2 font-body">
                {confidence ? `${confidence} / 5 stars` : 'Not rated'}
              </span>
            </div>
          </div>

          {/* Notes */}
          <div>
            <label className="block text-sm font-medium text-onSurfaceVariant mb-2 font-body">
              Session Takeaways & Notes (Optional)
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="What did you accomplish during this session?"
              rows={3}
              className="w-full px-4 py-3 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors placeholder:text-outline resize-none"
            />
          </div>

          {/* Footer Actions */}
          <div className="flex gap-3 pt-4 border-t border-outlineVariant">
            <button
              type="button"
              onClick={() => setIsLoggingView(false)}
              disabled={isSubmitting}
              className="flex-1 py-3 bg-surface hover:bg-surfaceContainerHighest text-onSurfaceVariant hover:text-onSurface font-bold rounded-xl transition-colors font-body text-sm"
            >
              Back to Timer
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="flex-1 py-3 bg-primary hover:bg-primary-container text-background hover:text-primary-onContainer font-bold rounded-xl transition-colors font-body text-sm flex items-center justify-center gap-2"
            >
              {isSubmitting ? (
                <>
                  <div className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
                  <span>Saving...</span>
                </>
              ) : (
                <span>Log & Save Session</span>
              )}
            </button>
          </div>
        </form>
      )}
    </Modal>
  );
}
