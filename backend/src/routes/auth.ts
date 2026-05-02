import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { prisma } from '../index.js';
import { AuthService } from '../services/authService.js';
import { authMiddleware } from '../middleware/auth.js';

const router = Router();

const sensitiveLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  message: { error: 'Too many attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  deviceName: z.string().max(100).optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
  deviceName: z.string().max(100).optional(),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
  deviceName: z.string().max(100).optional(),
});

const changePasswordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: z.string().min(8),
});

router.post('/register', async (req, res, next) => {
  try {
    const { email, password, deviceName } = registerSchema.parse(req.body);

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    const user = await AuthService.register(email, password);

    const tokens = AuthService.generateTokens(user.id);
    await AuthService.storeRefreshToken(user.id, tokens.refreshToken, {
      deviceName,
      ipAddress: req.ip,
    });

    res.status(201).json({
      data: {
        user: { id: user.id, email: user.email, createdAt: user.createdAt },
        ...tokens,
      },
    });
  } catch (error: any) {
    if (error.name === 'ZodError') {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

router.post('/login', async (req, res, next) => {
  try {
    const { email, password, deviceName } = loginSchema.parse(req.body);

    const user = await AuthService.login(email, password);
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const tokens = AuthService.generateTokens(user.id);
    await AuthService.storeRefreshToken(user.id, tokens.refreshToken, {
      deviceName,
      ipAddress: req.ip,
    });

    res.json({
      data: {
        user: { id: user.id, email: user.email, createdAt: user.createdAt },
        ...tokens,
      },
    });
  } catch (error: any) {
    if (error.name === 'ZodError') {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

router.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken, deviceName } = refreshSchema.parse(req.body);

    const userId = await AuthService.verifyRefreshToken(refreshToken);
    if (!userId) {
      return res.status(401).json({ error: 'Invalid or expired refresh token' });
    }

    const tokens = await AuthService.rotateRefreshToken(refreshToken, userId, {
      deviceName,
      ipAddress: req.ip,
    });

    res.json({ data: tokens });
  } catch (error: any) {
    if (error.name === 'ZodError') {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

router.post('/logout', async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      await AuthService.revokeRefreshToken(refreshToken);
    }
    res.json({ data: { message: 'Logged out successfully' } });
  } catch {
    res.json({ data: { message: 'Logged out' } });
  }
});

router.post('/logout-all', authMiddleware, async (req, res, next) => {
  try {
    const count = await AuthService.revokeAllUserTokens(req.user.userId);
    res.json({ data: { message: `Revoked ${count} sessions` } });
  } catch (error: any) {
    next(error);
  }
});

router.get('/me', authMiddleware, async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.userId },
      select: { id: true, email: true, createdAt: true, updatedAt: true },
    });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const stats = await prisma.userStats.findUnique({
      where: { userId: req.user.userId },
    });

    res.json({ data: { ...user, stats } });
  } catch (error: any) {
    next(error);
  }
});

router.patch('/password', sensitiveLimiter, authMiddleware, async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = changePasswordSchema.parse(req.body);

    const result = await AuthService.changePassword(
      req.user.userId,
      currentPassword,
      newPassword
    );

    if (!result.success) {
      return res.status(400).json({ error: result.error });
    }

    res.json({ data: { message: 'Password updated successfully' } });
  } catch (error: any) {
    if (error.name === 'ZodError') {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

router.delete('/account', sensitiveLimiter, authMiddleware, async (req, res, next) => {
  try {
    const { password } = req.body;
    if (!password) {
      return res.status(400).json({ error: 'Password required to delete account' });
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.userId },
    });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const bcrypt = await import('bcryptjs');
    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      return res.status(401).json({ error: 'Incorrect password' });
    }

    await AuthService.deleteAccount(req.user.userId);
    res.json({ data: { message: 'Account deleted successfully' } });
  } catch (error: any) {
    next(error);
  }
});

router.get('/devices', authMiddleware, async (req, res, next) => {
  try {
    const devices = await AuthService.getActiveDevices(req.user.userId);
    res.json({ data: devices });
  } catch (error: any) {
    next(error);
  }
});

router.delete('/devices/:tokenId', authMiddleware, async (req, res, next) => {
  try {
    const tokenId = String(req.params.tokenId);
    const revoked = await AuthService.revokeDevice(req.user.userId, tokenId);
    if (!revoked) {
      return res.status(404).json({ error: 'Device session not found' });
    }
    res.json({ data: { message: 'Device revoked' } });
  } catch (error: any) {
    next(error);
  }
});

export default router;
