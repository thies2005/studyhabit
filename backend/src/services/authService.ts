import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../index.js';
import { config } from '../config.js';
import { TokenPair, DeviceInfo } from '../types/index.js';

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
    device?: DeviceInfo
  ): Promise<void> {
    const tokenHash = this.hashToken(refreshToken);
    const expiresAt = new Date(Date.now() + this.parseDuration(config.JWT_REFRESH_EXPIRY));

    const activeTokens = await prisma.refreshToken.count({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
    });

    if (activeTokens >= config.MAX_DEVICES_PER_USER) {
      const oldest = await prisma.refreshToken.findFirst({
        where: { userId, revokedAt: null },
        orderBy: { createdAt: 'asc' },
      });
      if (oldest) {
        await prisma.refreshToken.update({
          where: { id: oldest.id },
          data: { revokedAt: new Date() },
        });
      }
    }

    await prisma.refreshToken.create({
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
    currentIp?: string,
    currentDevice?: string
  ): Promise<{ userId: string; deviceMismatch: boolean } | null> {
    const tokenHash = this.hashToken(refreshToken);

    const record = await prisma.refreshToken.findUnique({
      where: { tokenHash },
    });

    if (!record) return null;
    if (record.revokedAt) return null;
    if (record.expiresAt < new Date()) {
      await prisma.refreshToken.update({
        where: { id: record.id },
        data: { revokedAt: new Date() },
      });
      return null;
    }

    const tokenAge = Date.now() - record.createdAt.getTime();
    const deviceMismatch =
      currentIp && record.ipAddress && currentIp !== record.ipAddress
        ? tokenAge < 5 * 60 * 1000
        : false;

    return { userId: record.userId, deviceMismatch };
  }

  static async rotateRefreshToken(
    oldRefreshToken: string,
    userId: string,
    device?: DeviceInfo
  ): Promise<TokenPair> {
    const oldHash = this.hashToken(oldRefreshToken);

    await prisma.refreshToken.updateMany({
      where: { tokenHash: oldHash },
      data: { revokedAt: new Date() },
    });

    const tokens = this.generateTokens(userId);
    await this.storeRefreshToken(userId, tokens.refreshToken, device);

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
    return prisma.$transaction(async (tx) => {
      const passwordHash = await bcrypt.hash(password, 12);

      const user = await tx.user.create({
        data: { email, passwordHash },
      });

      await tx.userStats.create({
        data: { userId: user.id },
      });

      return user;
    });
  }

  static async login(email: string, password: string) {
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) return null;

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) return null;

    return user;
  }

  static async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string
  ): Promise<{ success: boolean; error?: string }> {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return { success: false, error: 'User not found' };

    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) return { success: false, error: 'Current password is incorrect' };

    const newHash = await bcrypt.hash(newPassword, 12);
    await prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newHash },
    });

    return { success: true };
  }

  static async deleteAccount(userId: string): Promise<void> {
    await prisma.user.delete({ where: { id: userId } });
  }
}
