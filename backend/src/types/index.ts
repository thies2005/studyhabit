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
