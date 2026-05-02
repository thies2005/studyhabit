import rateLimit from 'express-rate-limit';
import { config } from '../config.js';

export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { error: 'Too many auth attempts, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

export const apiLimiter = rateLimit({
  windowMs: config.RATE_LIMIT_WINDOW_MS,
  max: config.RATE_LIMIT_MAX,
  message: { error: 'Too many requests, please slow down' },
  standardHeaders: true,
  legacyHeaders: false,
});

export const syncLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  message: { error: 'Sync rate limit exceeded, try again in a minute' },
  standardHeaders: true,
  legacyHeaders: false,
});
