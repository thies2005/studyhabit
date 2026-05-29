import { z } from 'zod';

const envSchema = z.object({
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  PORT: z.coerce.number().default(3001),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  JWT_ACCESS_EXPIRY: z.string().default('15m'),
  JWT_REFRESH_EXPIRY: z.string().default('7d'),
  MAX_DEVICES_PER_USER: z.coerce.number().default(5),
  CORS_ORIGIN: z.string().default('http://localhost:3000'),
  RATE_LIMIT_WINDOW_MS: z.coerce.number().default(15 * 60 * 1000),
  RATE_LIMIT_MAX: z.coerce.number().default(100),
}).refine((data) => data.JWT_SECRET !== data.JWT_REFRESH_SECRET, {
  message: 'JWT_SECRET and JWT_REFRESH_SECRET must be different',
  path: ['JWT_REFRESH_SECRET'],
});

export const config = envSchema.parse(process.env);
export type Config = z.infer<typeof envSchema>;
