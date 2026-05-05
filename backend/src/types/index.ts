import { Request } from 'express';
import { ZodIssue } from 'zod';

declare global {
  namespace Express {
    interface Request {
      user: {
        userId: string;
      };
    }
  }
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface DeviceInfo {
  deviceName?: string;
  deviceInfo?: string;
  ipAddress?: string;
}

// Entity types for sync (matching Prisma schema)
export interface SyncProject {
  id: string;
  userId: string;
  name: string;
  icon: string;
  colorValue: number;
  createdAt: string | Date;
  lastOpenedAt: string | Date;
  isArchived: boolean;
  updatedAt: string | Date;
}

export interface SyncSubject {
  id: string;
  projectId: string;
  name: string;
  description: string | null;
  colorValue: number;
  hierarchyMode: 'flat' | 'twoLevel' | 'threeLevel';
  defaultDurationMinutes: number;
  defaultBreakMinutes: number;
  xpTotal: number;
  createdAt: string | Date;
  updatedAt: string | Date;
}

export interface SyncTopic {
  id: string;
  subjectId: string;
  name: string;
  order: number;
  createdAt: string | Date;
  updatedAt: string | Date;
}

export interface SyncChapter {
  id: string;
  topicId: string;
  name: string;
  order: number;
  createdAt: string | Date;
  updatedAt: string | Date;
}

export interface SyncSession {
  id: string;
  subjectId: string;
  topicId: string | null;
  chapterId: string | null;
  startedAt: string | Date;
  endedAt: string | Date | null;
  plannedDurationMinutes: number;
  actualDurationMinutes: number;
  pomodorosCompleted: number;
  confidenceRating: number | null;
  notes: string | null;
  xpEarned: number;
  createdAt: string | Date;
  updatedAt: string | Date;
}

export interface SyncSource {
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
  addedAt: string | Date;
  updatedAt: string | Date;
}

export interface SyncSkillLabel {
  id: string;
  subjectId: string;
  topicId: string | null;
  chapterId: string | null;
  label: 'beginner' | 'intermediate' | 'advanced' | 'expert';
  updatedAt: string | Date;
}

export interface SyncAchievement {
  id?: string;
  key: string;
  unlockedAt: string | Date | null;
  progress: number;
  createdAt: string | Date;
  updatedAt: string | Date;
}

export interface SyncUserStats {
  id?: string;
  userId: string;
  totalXp: number;
  currentLevel: number;
  currentStreak: number;
  longestStreak: number;
  lastStudyDate: string | Date | null;
  totalStudyMinutes: number;
  freezeTokens: number;
  createdAt: string | Date;
  updatedAt: string | Date;
}

export interface SyncPushPayload {
  projects?: SyncProject[];
  subjects?: SyncSubject[];
  topics?: SyncTopic[];
  chapters?: SyncChapter[];
  sessions?: SyncSession[];
  sources?: SyncSource[];
  skillLabels?: SyncSkillLabel[];
  achievements?: SyncAchievement[];
  userStats?: SyncUserStats;
}

export interface SyncPullResponse {
  serverTime: string;
  projects: SyncProject[];
  subjects: SyncSubject[];
  topics: SyncTopic[];
  chapters: SyncChapter[];
  sessions: SyncSession[];
  sources: SyncSource[];
  skillLabels: SyncSkillLabel[];
  achievements: SyncAchievement[];
  userStats: SyncUserStats | null;
}

export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface ApiError {
  error: string;
  details?: ZodIssue[];
}

export interface PaginationQuery {
  page?: number;
  limit?: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    hasMore: boolean;
  };
}

export function parsePagination(query: Record<string, unknown>): { skip: number; take: number; page: number; limit: number } {
  const page = Math.max(1, Number(query.page) || 1);
  const limit = Math.min(200, Math.max(1, Number(query.limit) || 50));
  return { skip: (page - 1) * limit, take: limit, page, limit };
}
