import { Request } from 'express';

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

export interface SyncPushPayload {
  projects?: any[];
  subjects?: any[];
  topics?: any[];
  chapters?: any[];
  sessions?: any[];
  sources?: any[];
  skillLabels?: any[];
  achievements?: any[];
  userStats?: any;
}

export interface SyncPullResponse {
  serverTime: string;
  projects: any[];
  subjects: any[];
  topics: any[];
  chapters: any[];
  sessions: any[];
  sources: any[];
  skillLabels: any[];
  achievements: any[];
  userStats: any;
}

export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface ApiError {
  error: string;
  details?: any[];
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
