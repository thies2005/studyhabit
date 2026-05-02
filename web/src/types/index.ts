export interface User {
  id: string;
  email: string;
}

export interface Project {
  id: string;
  userId: string;
  name: string;
  icon: string;
  colorValue: number;
  createdAt: string;
  lastOpenedAt: string;
  isArchived: boolean;
  updatedAt: string;
}

export interface Subject {
  id: string;
  projectId: string;
  name: string;
  description: string | null;
  colorValue: number;
  totalStudyHours?: number;
  hierarchyMode: 'flat' | 'twoLevel' | 'threeLevel';
  defaultDurationMinutes: number;
  defaultBreakMinutes: number;
  xpTotal: number;
  createdAt: string;
  updatedAt: string;
}

export interface StudySession {
  id: string;
  subjectId: string;
  topicId: string | null;
  chapterId: string | null;
  startedAt: string;
  endedAt: string | null;
  plannedDurationMinutes: number;
  actualDurationMinutes: number;
  pomodorosCompleted: number;
  confidenceRating: number | null;
  notes: string | null;
  xpEarned: number;
  createdAt: string;
  updatedAt: string;
}

export interface Achievement {
  id: string;
  userId: string;
  key: string;
  unlockedAt: string | null;
  progress: number;
  createdAt: string;
  updatedAt: string;
}

export interface UserStats {
  id: string;
  userId: string;
  totalXp: number;
  currentLevel: number;
  currentStreak: number;
  longestStreak: number;
  lastStudyDate: string | null;
  totalStudyMinutes: number;
  freezeTokens: number;
  createdAt: string;
  updatedAt: string;
}

export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface ApiError {
  error: string;
  details?: unknown[];
}

export interface Topic {
  id: string;
  subjectId: string;
  name: string;
  order: number;
  createdAt: string;
  updatedAt: string;
}

export interface Chapter {
  id: string;
  topicId: string;
  name: string;
  order: number;
  createdAt: string;
  updatedAt: string;
}

export interface Source {
  id: string;
  subjectId: string;
  topicId: string | null;
  chapterId: string | null;
  type: 'pdf' | 'url' | 'videoUrl';
  title: string;
  filePath: string | null;
  url: string | null;
  currentPage: number | null;
  totalPages: number | null;
  progressPercent: number | null;
  notes: string | null;
  addedAt: string;
  createdAt: string;
  updatedAt: string;
}

export interface SkillLabel {
  id: string;
  subjectId: string;
  topicId: string | null;
  chapterId: string | null;
  label: 'beginner' | 'intermediate' | 'advanced' | 'expert';
  updatedAt: string;
  createdAt: string;
  userId: string;
}

export interface StatsOverview {
  totalHours: number;
  weekHours: number;
  currentStreak: number;
  levelName: string;
  currentLevel: number;
  totalXp: number;
  totalStudyMinutes: number;
  longestStreak: number;
}

export interface SubjectBreakdown {
  subject: Subject;
  totalHours: number;
  sessionCount: number;
  avgConfidence: number;
  skillLevel: string;
}

export interface WeeklyActivityData {
  hours: number;
  label: string;
}

