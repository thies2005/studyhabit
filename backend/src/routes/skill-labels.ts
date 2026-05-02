import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index.js';
import { XpService } from '../services/xpService.js';
import { AchievementService } from '../services/achievementService.js';
import { parsePagination } from '../types/index.js';

const router = Router();

const SKILL_LEVELS = ['beginner', 'intermediate', 'advanced', 'expert'] as const;
const skillLabelSchema = z.object({
  subjectId: z.string().uuid(),
  topicId: z.string().uuid().optional(),
  chapterId: z.string().uuid().optional(),
  label: z.enum(SKILL_LEVELS).default('beginner'),
});

const updateSkillLabelSchema = z.object({
  label: z.enum(SKILL_LEVELS).optional(),
});

// Helper function to determine if skill level increased
function isSkillIncrease(oldLabel: string, newLabel: string): boolean {
  const oldIndex = SKILL_LEVELS.indexOf(oldLabel as any);
  const newIndex = SKILL_LEVELS.indexOf(newLabel as any);
  return newIndex > oldIndex;
}

router.get('/', async (req, res, next) => {
  try {
    const subjectId = String(req.query.subjectId ?? '');
    const { skip, take, page, limit } = parsePagination(req.query as any);
    const where = {
      subjectId,
      subject: { project: { userId: req.user.userId } },
    };

    const [skillLabels, total] = await Promise.all([
      prisma.skillLabel.findMany({
        where,
        orderBy: { updatedAt: 'desc' },
        skip,
        take,
      }),
      prisma.skillLabel.count({ where }),
    ]);

    res.json({
      data: skillLabels,
      pagination: { page, limit, total, hasMore: skip + take < total },
    });
  } catch (error: any) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const skillLabel = await prisma.skillLabel.findFirst({
      where: {
        id,
        subject: { project: { userId: req.user.userId } },
      },
    });

    if (!skillLabel) {
      return res.status(404).json({ error: 'SkillLabel not found' });
    }

    res.json({ data: skillLabel });
  } catch (error: any) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const data = skillLabelSchema.parse(req.body);

    // Verify subject ownership before creating skill label
    const subject = await prisma.subject.findFirst({
      where: { id: data.subjectId, project: { userId: req.user.userId } },
    });

    if (!subject) {
      return res.status(404).json({ error: 'Subject not found' });
    }

    // If topicId is provided, verify it belongs to the subject
    if (data.topicId) {
      const topic = await prisma.topic.findFirst({
        where: { id: data.topicId, subjectId: data.subjectId },
      });
      if (!topic) {
        return res.status(404).json({ error: 'Topic not found or does not belong to subject' });
      }
    }

    // If chapterId is provided, verify it belongs to the topic
    if (data.chapterId) {
      const chapter = await prisma.chapter.findFirst({
        where: {
          id: data.chapterId,
          topicId: data.topicId ?? undefined,
        },
      });
      if (!chapter) {
        return res.status(404).json({ error: 'Chapter not found or does not belong to topic' });
      }
    }

    const skillLabel = await prisma.skillLabel.create({ data });

    // Check if this is an upward skill change from the previous label
    // Note: On creation, we assume "beginner" was the previous state
    if (data.label !== 'beginner') {
      await XpService.addXpAndMinutes(req.user.userId, 100, 0);
      await AchievementService.checkAndUnlock(req.user.userId);
    }

    res.status(201).json({ data: skillLabel });
  } catch (error: any) {
    next(error);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const data = updateSkillLabelSchema.parse(req.body);

    if (!data.label) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    // Get existing skill label
    const existing = await prisma.skillLabel.findFirst({
      where: {
        id,
        subject: { project: { userId: req.user.userId } },
      },
    });

    if (!existing) {
      return res.status(404).json({ error: 'SkillLabel not found' });
    }

    // Check if skill level increased
    const skillIncreased = isSkillIncrease(existing.label, data.label);

    // Update the skill label
    const result = await prisma.skillLabel.updateMany({
      where: {
        id,
        subject: { project: { userId: req.user.userId } },
      },
      data: { label: data.label },
    });

    if (result.count === 0) {
      return res.status(404).json({ error: 'SkillLabel not found' });
    }

    const updated = await prisma.skillLabel.findUnique({ where: { id } });

    // Award XP if skill level increased
    if (skillIncreased) {
      await XpService.addXpAndMinutes(req.user.userId, 100, 0);
      await AchievementService.checkAndUnlock(req.user.userId);
    }

    res.json({ data: updated });
  } catch (error: any) {
    next(error);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id);
    const result = await prisma.skillLabel.deleteMany({
      where: {
        id,
        subject: { project: { userId: req.user.userId } },
      },
    });

    if (result.count === 0) {
      return res.status(404).json({ error: 'SkillLabel not found' });
    }

    res.status(204).send();
  } catch (error: any) {
    next(error);
  }
});

export default router;
