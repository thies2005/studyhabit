import { Router } from 'express';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import { prisma } from '../index.js';
import { AuthService } from '../services/authService.js';

const router = Router();

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

const refreshSchema = z.object({
  refreshToken: z.string(),
});

// Register
router.post('/register', async (req: any, res: any) => {
  try {
    const { email, password } = registerSchema.parse(req.body);

    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ error: 'Email already registered' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
      },
    });

    // Initialize user stats
    await prisma.userStats.create({
      data: {
        userId: user.id,
      },
    });

    const { accessToken, refreshToken } = AuthService.generateTokens(user.id);

    res.status(201).json({
      data: {
        user: { id: user.id, email: user.email },
        accessToken,
        refreshToken,
      },
    });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Login
router.post('/login', async (req: any, res: any) => {
  try {
    const { email, password } = loginSchema.parse(req.body);

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const validPassword = await bcrypt.compare(password, user.passwordHash);
    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const { accessToken, refreshToken } = AuthService.generateTokens(user.id);

    res.json({
      data: {
        user: { id: user.id, email: user.email },
        accessToken,
        refreshToken,
      },
    });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Refresh token
router.post('/refresh', async (req: any, res: any) => {
  try {
    const { refreshToken } = refreshSchema.parse(req.body);

    const userId = await AuthService.verifyRefreshToken(refreshToken);
    if (!userId) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    const { accessToken, refreshToken: newRefreshToken } =
      AuthService.generateTokens(userId);

    res.json({
      data: { accessToken, refreshToken: newRefreshToken },
    });
  } catch (error: any) {
    res.status(401).json({ error: error.message });
  }
});

// POST /logout
router.post('/logout', async (req: any, res: any) => {
  // In a stateless JWT setup, logout is handled client-side by deleting tokens.
  // For a full implementation, add refresh token blacklisting here.
  res.json({ data: { message: 'Logged out successfully' } });
});

export default router;
