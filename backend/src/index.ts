import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { PrismaClient } from '@prisma/client';
import { config } from './config.js';
import { errorHandler } from './middleware/errorHandler.js';
import { authMiddleware } from './middleware/auth.js';
import authRoutes from './routes/auth.js';
import projectRoutes from './routes/projects.js';
import subjectRoutes from './routes/subjects.js';
import sessionRoutes from './routes/sessions.js';
import sourceRoutes from './routes/sources.js';
import statsRoutes from './routes/stats.js';
import achievementRoutes from './routes/achievements.js';

export const prisma = new PrismaClient();

const app = express();

// Security middleware
app.use(helmet());

// CORS
app.use(cors());

// Logging
app.use(morgan('dev'));

// Body parsing
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/projects', authMiddleware, projectRoutes);
app.use('/api/v1/subjects', authMiddleware, subjectRoutes);
app.use('/api/v1/sessions', authMiddleware, sessionRoutes);
app.use('/api/v1/sources', authMiddleware, sourceRoutes);
app.use('/api/v1/stats', authMiddleware, statsRoutes);
app.use('/api/v1/achievements', authMiddleware, achievementRoutes);

// Error handling (must be last)
app.use(errorHandler);

app.listen(config.PORT, () => {
  console.log(`StudyTracker API running on port ${config.PORT}`);
  console.log(`Environment: ${config.NODE_ENV}`);
});
