import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { PrismaClient } from '@prisma/client';
import { config } from './config.js';
import { errorHandler } from './middleware/errorHandler.js';
import { authMiddleware } from './middleware/auth.js';
import { authLimiter, apiLimiter, syncLimiter } from './middleware/rateLimit.js';
import authRoutes from './routes/auth.js';
import syncRoutes from './routes/sync.js';
import projectRoutes from './routes/projects.js';
import subjectRoutes, { createProjectSubjectRoutes } from './routes/subjects.js';
import sessionRoutes from './routes/sessions.js';
import sourceRoutes from './routes/sources.js';
import statsRoutes from './routes/stats.js';
import achievementRoutes from './routes/achievements.js';
import topicRoutes from './routes/topics.js';
import chapterRoutes from './routes/chapters.js';
import skillLabelRoutes from './routes/skill-labels.js';
import { AuthService } from './services/authService.js';
import docsRoutes from './routes/docs.js';

export const prisma = new PrismaClient();

const app = express();

app.set('trust proxy', 1);

app.use(helmet());

app.use(cors({
  origin: config.CORS_ORIGIN === '*' ? true : config.CORS_ORIGIN.split(','),
  credentials: true,
}));

app.use(morgan(config.NODE_ENV === 'production' ? 'combined' : 'dev'));

app.use(express.json({ limit: '1mb' }));

app.use('/api/v1/docs', docsRoutes);

app.get('/health', async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
    });
  } catch {
    res.status(503).json({ status: 'degraded', timestamp: new Date().toISOString() });
  }
});

app.use('/api/v1/auth', authLimiter, authRoutes);

app.use('/api/v1/sync', apiLimiter, syncLimiter, authMiddleware, syncRoutes);

app.use('/api/v1/projects', apiLimiter, authMiddleware, projectRoutes);
app.use('/api/v1/projects/:projectId/subjects', apiLimiter, authMiddleware, createProjectSubjectRoutes());
app.use('/api/v1/subjects', apiLimiter, authMiddleware, subjectRoutes);
app.use('/api/v1/topics', apiLimiter, authMiddleware, topicRoutes);
app.use('/api/v1/chapters', apiLimiter, authMiddleware, chapterRoutes);
app.use('/api/v1/skill-labels', apiLimiter, authMiddleware, skillLabelRoutes);
app.use('/api/v1/sessions', apiLimiter, authMiddleware, sessionRoutes);
app.use('/api/v1/sources', apiLimiter, authMiddleware, sourceRoutes);
app.use('/api/v1/stats', apiLimiter, authMiddleware, statsRoutes);
app.use('/api/v1/achievements', apiLimiter, authMiddleware, achievementRoutes);

app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use(errorHandler);

setInterval(() => {
  AuthService.cleanupExpiredTokens().catch(() => {});
}, 60 * 60 * 1000);

process.on('uncaughtException', async (err) => {
  console.error('Uncaught exception:', err);
  await prisma.$disconnect();
  process.exit(1);
});

process.on('unhandledRejection', async (reason) => {
  console.error('Unhandled rejection:', reason);
  await prisma.$disconnect();
  process.exit(1);
});

const server = app.listen(config.PORT, () => {
  console.log(`StudyTracker API v1.0 running on port ${config.PORT}`);
  console.log(`Environment: ${config.NODE_ENV}`);
});

process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close();
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close();
  await prisma.$disconnect();
  process.exit(0);
});

export default app;
