import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { prisma } from '../index.js';

export class AuthService {
  static generateTokens(userId: string) {
    const accessToken = jwt.sign({ userId }, config.JWT_SECRET, {
      expiresIn: '15m',
    });

    const refreshToken = jwt.sign({ userId }, config.JWT_REFRESH_SECRET, {
      expiresIn: '7d',
    });

    return { accessToken, refreshToken };
  }

  static verifyRefreshToken(refreshToken: string): string | null {
    try {
      const decoded = jwt.verify(
        refreshToken,
        config.JWT_REFRESH_SECRET
      ) as any;
      return decoded.userId;
    } catch {
      return null;
    }
  }
}
