import { Router } from 'express';
import { prisma } from '../db.js';
import { z, ZodError } from 'zod';

const router = Router();

// Settings are an opaque client-owned JSON blob. Bound it to prevent abuse:
// at most 200 top-level keys, and a 64 KB JSON payload, so a single save can't
// store ~1 MB of arbitrary data (the express.json limit). Values may be any
// JSON type the client needs.
const MAX_SETTINGS_KEYS = 200;
const MAX_SETTINGS_BYTES = 64 * 1024;

const ALLOWED_PREFIXES = ['theme.', 'pomodoro.', 'notifications.', 'streak.', 'goal.'];
const ALLOWED_EXACT = new Set(['active_timer_type', 'pomodoro_state_json', 'free_timer_state_json']);
const FORBIDDEN_KEYS = new Set(['__proto__', 'constructor', 'prototype']);

export function isAllowedSettingsKey(key: string): boolean {
  if (FORBIDDEN_KEYS.has(key)) return false;
  if (ALLOWED_EXACT.has(key)) return true;
  return ALLOWED_PREFIXES.some((prefix) => key.startsWith(prefix));
}

const settingsSchema = z
  .record(z.unknown())
  .refine((obj) => Object.keys(obj).length <= MAX_SETTINGS_KEYS, {
    message: `Settings may have at most ${MAX_SETTINGS_KEYS} keys`,
  })
  .refine((obj) => Buffer.byteLength(JSON.stringify(obj)) <= MAX_SETTINGS_BYTES, {
    message: `Settings payload must be at most ${MAX_SETTINGS_BYTES} bytes`,
  })
  .refine(
    (obj) => Object.keys(obj).every(isAllowedSettingsKey),
    {
      message: 'Settings contains invalid or forbidden key',
    }
  );

router.get('/', async (req, res, next) => {
  try {
    const userSettings = await prisma.userSettings.findUnique({
      where: { userId: req.user.userId },
    });
    res.json({ data: userSettings?.settings ?? {} });
  } catch (error) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const incoming = settingsSchema.parse(req.body);
    const existing = await prisma.userSettings.findUnique({
      where: { userId: req.user.userId },
    });
    const merged = {
      ...((existing?.settings as Record<string, unknown>) ?? {}),
      ...incoming,
    };
    const updated = await prisma.userSettings.upsert({
      where: { userId: req.user.userId },
      create: { userId: req.user.userId, settings: merged as any, updatedAt: new Date() },
      update: { settings: merged as any, updatedAt: new Date() },
    });
    res.json({ data: updated.settings });
  } catch (error) {
    if (error instanceof ZodError) {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

export default router;
