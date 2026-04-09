// Shared TypeScript types for the StudyTracker API

export interface User {
  id: string;
  email: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface Project {
  id: string;
  userId: string;
  name: string;
  icon: string;
  colorValue: number;
  createdAt: Date;
  lastOpenedAt: Date;
  isArchived: boolean;
  updatedAt: Date;
}

export interface Subject {
  id: string;
  projectId: string;
  name: string;
  description: string | null;
  colorValue: number;
  hierarchyMode: 'flat' | 'twoLevel' | 'threeLevel';
  defaultDurationMinutes: number;
  defaultBreakMinutes: number;
  xpTotal: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface Topic {
  id: string;
  subjectId: string;
  name: string;
  order: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface Chapter {
  id: string;
  topicId: string;
  name: string;
  order: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface StudySession {
  id: string;
  subjectId: string;
  topicId: string | null;
  chapterId: string | null;
  startedAt: Date;
  endedAt: Date | null;
  plannedDurationMinutes: number;
  actualDurationMinutes: number;
  pomodorosCompleted: number;
  confidenceRating: number | null;
  notes: string | null;
  xpEarned: number;
  createdAt: Date;
  updatedAt: Date;
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
  addedAt: Date;
  updatedAt: Date;
}

export interface SkillLabel {
  id: string;
  subjectId: string;
  topicId: string | null;
  chapterId: string | null;
  label: 'beginner' | 'intermediate' | 'advanced' | 'expert';
  updatedAt: Date;
}

export interface Achievement {
  id: string;
  userId: string;
  key: string;
  unlockedAt: Date | null;
  progress: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface UserStats {
  id: string;
  userId: string;
  totalXp: number;
  currentLevel: number;
  currentStreak: number;
  longestStreak: number;
  lastStudyDate: Date | null;
  totalStudyMinutes: number;
  freezeTokens: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface ApiError {
  error: string;
  details?: any[];
}
