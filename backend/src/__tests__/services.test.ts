import test from 'node:test';
import assert from 'node:assert/strict';
import { z } from 'zod';
import { XpService } from '../services/xpService.js';
import { AuthService } from '../services/authService.js';

test('XpService.calculateLevel progressions', () => {
  assert.equal(XpService.calculateLevel(0), 1);
  assert.equal(XpService.calculateLevel(250), 1);
  assert.equal(XpService.calculateLevel(499), 1);
  assert.equal(XpService.calculateLevel(500), 2);
  assert.equal(XpService.calculateLevel(1499), 2);
  assert.equal(XpService.calculateLevel(1500), 3);
  assert.equal(XpService.calculateLevel(3499), 3);
  assert.equal(XpService.calculateLevel(3500), 4);
  assert.equal(XpService.calculateLevel(6999), 4);
  assert.equal(XpService.calculateLevel(7000), 5);
  assert.equal(XpService.calculateLevel(10499), 5);
  assert.equal(XpService.calculateLevel(10500), 6);
  assert.ok(XpService.calculateLevel(20000) >= 6);
});

test('XpService.xpToNextLevel calculations', () => {
  assert.equal(XpService.xpToNextLevel(0), 500);
  assert.equal(XpService.xpToNextLevel(250), 250);
  assert.equal(XpService.xpToNextLevel(500), 1000);
  assert.equal(XpService.xpToNextLevel(1500), 2000);
});

test('XpService.levelName mapping', () => {
  assert.equal(XpService.levelName(1), 'Novice');
  assert.equal(XpService.levelName(2), 'Apprentice');
  assert.equal(XpService.levelName(3), 'Scholar');
  assert.equal(XpService.levelName(4), 'Adept');
  assert.equal(XpService.levelName(5), 'Expert');
  assert.equal(XpService.levelName(6), 'Master');
  assert.equal(XpService.levelName(7), 'Grandmaster');
  assert.equal(XpService.levelName(100), 'Grandmaster');
});

test('XpService.xpForSession calculations', () => {
  // Only pomodoros
  assert.equal(XpService.xpForSession(25, 1), 50);
  assert.equal(XpService.xpForSession(25, 2), 100);

  // 50+ minutes bonus (+120)
  assert.equal(XpService.xpForSession(50, 0), 120);
  assert.equal(XpService.xpForSession(55, 2), 100 + 120);

  // Confidence rating bonus (+10)
  assert.equal(XpService.xpForSession(25, 0, 4), 10);
  assert.equal(XpService.xpForSession(50, 2, 5), 100 + 120 + 10);

  // Zero duration and pomodoros
  assert.equal(XpService.xpForSession(0, 0), 0);
});

test('XpService.xpForStreak and streak milestones', () => {
  assert.equal(XpService.xpForStreak(1), 0);
  assert.equal(XpService.xpForStreak(7), 500);
  assert.equal(XpService.xpForStreak(30), 500);
  assert.equal(XpService.xpForStreak(100), 500);

  // Milestones: only award when boundary is crossed
  assert.equal(XpService.xpForStreakMilestones(6, 7), 500);
  assert.equal(XpService.xpForStreakMilestones(7, 8), 0);
  assert.equal(XpService.xpForStreakMilestones(29, 30), 500);
  assert.equal(XpService.xpForStreakMilestones(30, 31), 0);
  assert.equal(XpService.xpForStreakMilestones(99, 100), 500);

  // Multi-milestone jump
  assert.equal(XpService.xpForStreakMilestones(5, 35), 1000);

  // Reset or backwards streak
  assert.equal(XpService.xpForStreakMilestones(15, 1), 0);
});

test('AuthService.parseDuration handles units', () => {
  assert.equal(AuthService.parseDuration('15m'), 15 * 60 * 1000);
  assert.equal(AuthService.parseDuration('2h'), 2 * 60 * 60 * 1000);
  assert.equal(AuthService.parseDuration('7d'), 7 * 24 * 60 * 60 * 1000);
  assert.equal(AuthService.parseDuration('30s'), 30 * 1000);
  assert.throws(() => AuthService.parseDuration('invalid'));
});

test('AuthService.hashToken produces deterministic sha256', () => {
  const token = 'sample-secret-refresh-token';
  const hash1 = AuthService.hashToken(token);
  const hash2 = AuthService.hashToken(token);
  assert.equal(hash1, hash2);
  assert.equal(hash1.length, 64);
});

test('Schema validations: project, subject, and session schemas', () => {
  const projectSchema = z.object({
    name: z.string().min(1).max(100),
    icon: z.string().default('📚'),
    colorValue: z.number().transform((v) => v & 0xFFFFFF),
  });

  const parsedProject = projectSchema.parse({
    name: 'Computer Science',
    colorValue: 0xFF4285F4,
  });
  assert.equal(parsedProject.name, 'Computer Science');
  assert.equal(parsedProject.icon, '📚');
  assert.equal(parsedProject.colorValue, 0x4285F4);

  const sessionSchema = z.object({
    subjectId: z.string().uuid(),
    plannedDurationMinutes: z.number().int().min(0),
    actualDurationMinutes: z.number().int().min(0),
    pomodorosCompleted: z.number().int().min(0),
    confidenceRating: z.number().int().min(1).max(5).nullable().optional(),
  });

  assert.ok(
    sessionSchema.parse({
      subjectId: '11111111-1111-1111-1111-111111111111',
      plannedDurationMinutes: 25,
      actualDurationMinutes: 30,
      pomodorosCompleted: 1,
      confidenceRating: 4,
    })
  );

  // Confidence rating < 1 or > 5 must fail
  assert.throws(() =>
    sessionSchema.parse({
      subjectId: '11111111-1111-1111-1111-111111111111',
      plannedDurationMinutes: 25,
      actualDurationMinutes: 30,
      pomodorosCompleted: 1,
      confidenceRating: 6,
    })
  );
  assert.throws(() =>
    sessionSchema.parse({
      subjectId: '11111111-1111-1111-1111-111111111111',
      plannedDurationMinutes: 25,
      actualDurationMinutes: 30,
      pomodorosCompleted: 1,
      confidenceRating: 0,
    })
  );
});
