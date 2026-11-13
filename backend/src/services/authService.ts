import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { Prisma } from '@prisma/client';
import { prisma } from '../db.js';
import { config } from '../config.js';
import { TokenPair, DeviceInfo } from '../types/index.js';

export class RefreshTokenError extends Error {
  constructor(message = 'Invalid or expired refresh token') {
    super(message);
    this.name = 'RefreshTokenError';
  }
}

export class AuthService {
  static parseDuration(duration: string): number {
    const match = duration.match(/^(\d+)([dhms])$/);
    if (!match) {
      throw new Error(`Invalid duration format: ${duration}`);
    }
    const value = parseInt(match[1], 10);
    const unit = match[2];
    const multipliers: Record<string, number> = {
      d: 24 * 60 * 60 * 1000,
      h: 60 * 60 * 1000,
      m: 60 * 1000,
      s: 1000,
    };
    return value * multipliers[unit];
  }

  static hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  static generateTokens(userId: string): TokenPair {
    const accessToken = jwt.sign(
      { userId },
      config.JWT_SECRET,
      { expiresIn: config.JWT_ACCESS_EXPIRY } as jwt.SignOptions
    );

    const refreshToken = crypto.randomBytes(64).toString('hex');

    return { accessToken, refreshToken };
  }

  static async storeRefreshToken(
    userId: string,
    refreshToken: string,
    device?: DeviceInfo,
    tx?: Prisma.TransactionClient
  ): Promise<void> {
    const client = tx ?? prisma;
    const tokenHash = this.hashToken(refreshToken);
    const now = new Date();
    const expiresAt = new Date(now.getTime() + this.parseDuration(config.JWT_REFRESH_EXPIRY));

    const activeTokens = await client.refreshToken.count({
      where: { userId, revokedAt: null, expiresAt: { gt: now } },
    });

    if (activeTokens >= config.MAX_DEVICES_PER_USER) {
      const oldest = await client.refreshToken.findFirst({
        where: { userId, revokedAt: null, expiresAt: { gt: now } },
        orderBy: { createdAt: 'asc' },
      });
      if (oldest) {
        await client.refreshToken.update({
          where: { id: oldest.id },
          data: { revokedAt: now },
        });
      }
    }

    await client.refreshToken.create({
      data: {
        userId,
        tokenHash,
        deviceName: device?.deviceName,
        deviceInfo: device?.deviceInfo,
        ipAddress: device?.ipAddress,
        expiresAt,
      },
    });
  }

  static async verifyRefreshToken(
    refreshToken: string,
    _currentIp?: string,
    _currentDevice?: string
  ): Promise<{ userId: string } | null> {
    const tokenHash = this.hashToken(refreshToken);

    const record = await prisma.refreshToken.findUnique({
      where: { tokenHash },
    });

    if (!record) return null;
    if (record.revokedAt) {
      console.warn(`[SECURITY] Refresh token reuse detected for user ${record.userId}. Revoking all sessions.`);
      await this.revokeAllUserTokens(record.userId);
      return null;
    }
    if (record.expiresAt < new Date()) {
      await prisma.refreshToken.update({
        where: { id: record.id },
        data: { revokedAt: new Date() },
      });
      return null;
    }

    return { userId: record.userId };
  }

  static async rotateRefreshToken(
    oldRefreshToken: string,
    userId: string,
    device?: DeviceInfo
  ): Promise<TokenPair> {
    const oldHash = this.hashToken(oldRefreshToken);

    const tokens = await prisma.$transaction(async (tx) => {
      const now = new Date();
      const revoked = await tx.refreshToken.updateMany({
        where: { tokenHash: oldHash, revokedAt: null, expiresAt: { gt: now } },
        data: { revokedAt: now },
      });

      if (revoked.count === 0) {
        const existing = await tx.refreshToken.findUnique({
          where: { tokenHash: oldHash },
        });
        if (existing?.revokedAt) {
          console.warn(
            `[SECURITY] Refresh token reuse detected for user ${existing.userId}. Revoking all sessions.`
          );
          await tx.refreshToken.updateMany({
            where: { userId: existing.userId, revokedAt: null },
            data: { revokedAt: now },
          });
        } else if (existing && existing.expiresAt <= now) {
          await tx.refreshToken.updateMany({
            where: { id: existing.id, revokedAt: null },
            data: { revokedAt: now },
          });
        }
        return null;
      }

      const previous = await tx.refreshToken.findUnique({
        where: { tokenHash: oldHash },
        select: { deviceName: true, deviceInfo: true },
      });

      const nextTokens = this.generateTokens(userId);
      const mergedDevice: DeviceInfo = {
        ...device,
        deviceName: device?.deviceName ?? previous?.deviceName ?? undefined,
        deviceInfo: device?.deviceInfo ?? previous?.deviceInfo ?? undefined,
      };

      await this.storeRefreshToken(userId, nextTokens.refreshToken, mergedDevice, tx);
      return nextTokens;
    });

    if (!tokens) {
      throw new RefreshTokenError();
    }

    return tokens;
  }

  static async revokeRefreshToken(refreshToken: string): Promise<void> {
    const tokenHash = this.hashToken(refreshToken);
    await prisma.refreshToken.updateMany({
      where: { tokenHash },
      data: { revokedAt: new Date() },
    });
  }

  static async revokeAllUserTokens(userId: string): Promise<number> {
    const result = await prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return result.count;
  }

  static async cleanupExpiredTokens(): Promise<number> {
    const result = await prisma.refreshToken.deleteMany({
      where: {
        OR: [
          { expiresAt: { lt: new Date() } },
          { revokedAt: { not: null } },
        ],
      },
    });
    return result.count;
  }

  static async getActiveDevices(userId: string) {
    return prisma.refreshToken.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      select: {
        id: true,
        deviceName: true,
        deviceInfo: true,
        ipAddress: true,
        createdAt: true,
        expiresAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  static async revokeDevice(userId: string, tokenId: string): Promise<boolean> {
    const result = await prisma.refreshToken.updateMany({
      where: { id: tokenId, userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return result.count > 0;
  }

  static async register(email: string, password: string) {
    const normalizedEmail = email.trim().toLowerCase();
    return prisma.$transaction(async (tx) => {
      const existing = await tx.user.findFirst({
        where: { email: { equals: normalizedEmail, mode: 'insensitive' } },
      });
      if (existing) {
        throw new Prisma.PrismaClientKnownRequestError(
          'An account with this email already exists',
          { code: 'P2002', clientVersion: Prisma.prismaVersion.client }
        );
      }

      const passwordHash = await bcrypt.hash(password, 12);

      const user = await tx.user.create({
        data: { email: normalizedEmail, passwordHash },
      });

      await tx.userStats.create({
        data: { userId: user.id },
      });

      return user;
    });
  }

  // A lazily-computed, valid bcrypt hash used to keep login timing uniform when
  // the email is unknown. The previous constant was 49 chars (bcrypt requires
  // 60), which made `bcrypt.compare` throw and turned unknown-email logins into
  // a 500 — a user-enumeration oracle by status code. Generating it lazily (and
  // caching) avoids paying the hash cost at module load on every cold start.
  private static dummyHashPromise: Promise<string> | null = null;
  private static getDummyHash(): Promise<string> {
    if (!this.dummyHashPromise) {
      this.dummyHashPromise = bcrypt.hash(crypto.randomBytes(16).toString('hex'), 12);
    }
    return this.dummyHashPromise;
  }

  static async login(email: string, password: string) {
    const normalizedEmail = email.trim().toLowerCase();
    const user = await prisma.user.findFirst({
      where: { email: { equals: normalizedEmail, mode: 'insensitive' } },
    });
    if (!user) {
      // Dummy bcrypt compare so unknown-email and wrong-password take the same
      // path (and return the same 401). Wrapped in try/catch as defense in
      // depth so a hashing failure can never surface as a 500 here.
      try {
        await bcrypt.compare(password, await this.getDummyHash());
      } catch {
        /* swallow: timing mitigation only; return null below */
      }
      return null;
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) return null;

    return user;
  }

  static async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string
  ): Promise<{ success: boolean; revokedSessions?: number; error?: string }> {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return { success: false, error: 'User not found' };

    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) return { success: false, error: 'Current password is incorrect' };

    const newHash = await bcrypt.hash(newPassword, 12);
    // Revoke all refresh tokens atomically with password update so other
    // devices/sessions must re-authenticate. Outstanding access JWTs remain
    // valid only until their short (15m) expiry.
    const revoked = await prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: { passwordHash: newHash },
      });

      const result = await tx.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });

      return result.count;
    });

    return { success: true, revokedSessions: revoked };
  }

  static async deleteAccount(userId: string): Promise<void> {
    await prisma.user.delete({ where: { id: userId } });
  }
}
