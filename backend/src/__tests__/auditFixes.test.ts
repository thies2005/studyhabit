import test, { TestContext } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import express from 'express';
import bcrypt from 'bcryptjs';
import { prisma } from '../db.js';
import { errorHandler } from '../middleware/errorHandler.js';
import authRoutes, {
  registerSchema,
  loginSchema,
  changePasswordSchema,
  deleteAccountSchema,
} from '../routes/auth.js';
import settingsRoutes, {
  MAX_SETTINGS_KEYS,
  MAX_SETTINGS_BYTES,
  isAllowedSettingsKey,
} from '../routes/settings.js';
import { withUserLock, pushSchema } from '../routes/sync.js';
import { AuthService, RefreshTokenError } from '../services/authService.js';
import { SyncService, stripLegacyBlockerSettings } from '../services/syncService.js';

function stubProperty<T extends object, K extends keyof T>(
  t: TestContext,
  obj: T,
  key: K,
  replacement: T[K]
): void {
  const original = obj[key];
  const hadOwn = Object.prototype.hasOwnProperty.call(obj, key);
  const desc = Object.getOwnPropertyDescriptor(obj, key);
  Object.defineProperty(obj, key, {
    value: replacement,
    writable: true,
    enumerable: true,
    configurable: true,
  });
  t.after(() => {
    if (hadOwn && desc) {
      Object.defineProperty(obj, key, desc);
    } else {
      delete (obj as any)[key];
      if ((obj as any)[key] === undefined) {
        Object.defineProperty(obj, key, {
          value: original,
          writable: true,
          enumerable: true,
          configurable: true,
        });
      }
    }
  });
}

async function withTestServer(
  setupApp: (app: express.Express) => void,
  fn: (baseUrl: string) => Promise<void>
): Promise<void> {
  const app = express();
  app.use(express.json());
  setupApp(app);
  app.use(errorHandler);

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  if (!address || typeof address === 'string') {
    server.close();
    throw new Error('Failed to bind ephemeral port');
  }
  const baseUrl = `http://127.0.0.1:${address.port}`;
  try {
    await fn(baseUrl);
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((err) => (err ? reject(err) : resolve()))
    );
  }
}

test('registerSchema and loginSchema normalize email and enforce max length', () => {
  const reg = registerSchema.parse({
    email: '  Alice.Smith+Test@Example.COM  ',
    password: 'password123',
  });
  assert.equal(reg.email, 'alice.smith+test@example.com');

  const login = loginSchema.parse({
    email: '  BOB@EXAMPLE.ORG ',
    password: 'secret',
  });
  assert.equal(login.email, 'bob@example.org');

  const longEmail = `${'a'.repeat(245)}@example.com`; // 257 chars
  assert.throws(() => registerSchema.parse({ email: longEmail, password: 'password123' }));
  assert.throws(() => loginSchema.parse({ email: longEmail, password: 'secret' }));
});

test('changePasswordSchema enforces max(128) on currentPassword and newPassword', () => {
  assert.ok(
    changePasswordSchema.parse({
      currentPassword: 'a'.repeat(128),
      newPassword: 'b'.repeat(128),
    })
  );

  assert.throws(() =>
    changePasswordSchema.parse({
      currentPassword: 'a'.repeat(129),
      newPassword: 'validpassword',
    })
  );
  assert.throws(() =>
    changePasswordSchema.parse({
      currentPassword: 'valid',
      newPassword: 'b'.repeat(129),
    })
  );
});

test('deleteAccountSchema validates password presence and max length', () => {
  assert.deepEqual(deleteAccountSchema.parse({ password: 'secret' }), { password: 'secret' });
  assert.throws(() => deleteAccountSchema.parse({}));
  assert.throws(() => deleteAccountSchema.parse({ password: '' }));
  assert.throws(() => deleteAccountSchema.parse({ password: 'x'.repeat(129) }));
});

test('AuthService.register normalizes email and prevents case-variant duplicates', async (t) => {
  const createdEmails: string[] = [];
  let existingRow: { id: string; email: string } | null = null;

  stubProperty(t, prisma, '$transaction', (async (cb: any) => {
    const tx = {
      user: {
        findFirst: async (args: any) => {
          assert.equal(args.where.email.mode, 'insensitive');
          assert.equal(args.where.email.equals, 'user@example.com');
          return existingRow;
        },
        create: async ({ data }: any) => {
          createdEmails.push(data.email);
          return { id: 'u-1', email: data.email, createdAt: new Date() };
        },
      },
      userStats: {
        create: async () => ({ id: 'st-1' }),
      },
    };
    return cb(tx);
  }) as any);

  const user = await AuthService.register('  User@Example.COM ', 'Password123!');
  assert.equal(user.email, 'user@example.com');
  assert.deepEqual(createdEmails, ['user@example.com']);

  existingRow = { id: 'u-old', email: 'User@Example.com' };
  await assert.rejects(
    () => AuthService.register('user@example.com', 'Password123!'),
    (err: any) => err?.code === 'P2002'
  );
});

test('AuthService.login uses normalized case-insensitive lookup for pre-existing mixed-case accounts', async (t) => {
  const passwordHash = await bcrypt.hash('Password123!', 4);
  let capturedWhere: any;

  stubProperty(t, prisma, 'user', {
    ...prisma.user,
    findFirst: async (args: any) => {
      capturedWhere = args?.where;
      return {
        id: 'u-mixed',
        email: 'MixedCase@Example.COM',
        passwordHash,
        createdAt: new Date(),
        updatedAt: new Date(),
      } as any;
    },
  } as any);

  const user = await AuthService.login('  mixedcase@example.com ', 'Password123!');
  assert.ok(user);
  assert.equal(user.id, 'u-mixed');
  assert.deepEqual(capturedWhere, {
    email: { equals: 'mixedcase@example.com', mode: 'insensitive' },
  });
});

test('AuthService.changePassword updates hash and revokes tokens inside prisma.$transaction', async (t) => {
  const oldHash = await bcrypt.hash('OldPassword123!', 4);
  const ops: string[] = [];

  stubProperty(t, prisma, 'user', {
    ...prisma.user,
    findUnique: async () => ({
      id: 'u-1',
      email: 'u@example.com',
      passwordHash: oldHash,
    }) as any,
  } as any);

  stubProperty(t, prisma, '$transaction', (async (cb: any) => {
    const tx = {
      user: {
        update: async () => {
          ops.push('user.update');
          return {};
        },
      },
      refreshToken: {
        updateMany: async () => {
          ops.push('refreshToken.updateMany');
          return { count: 3 };
        },
      },
    };
    return cb(tx);
  }) as any);

  const res = await AuthService.changePassword('u-1', 'OldPassword123!', 'NewPassword123!');
  assert.deepEqual(res, { success: true, revokedSessions: 3 });
  assert.deepEqual(ops, ['user.update', 'refreshToken.updateMany']);
});

test('AuthService.verifyRefreshToken does not trigger deviceMismatch on IP change', async (t) => {
  stubProperty(t, prisma, 'refreshToken', {
    ...prisma.refreshToken,
    findUnique: async () => ({
      id: 'rt-1',
      userId: 'u-1',
      tokenHash: 'hash',
      ipAddress: '10.0.0.1',
      createdAt: new Date(), // < 5 minutes old
      expiresAt: new Date(Date.now() + 60_000),
      revokedAt: null,
    }) as any,
  } as any);

  const result = await AuthService.verifyRefreshToken('raw-token', '192.168.1.99', 'Pixel 8');
  assert.deepEqual(result, { userId: 'u-1' });
  assert.equal((result as any).deviceMismatch, undefined);
});

test('AuthService.rotateRefreshToken is atomic, preserves device metadata, and revokes on reuse', async (t) => {
  const createdTokens: any[] = [];
  const revokedUserUpdates: any[] = [];

  stubProperty(t, prisma, '$transaction', (async (cb: any) => {
    const tx = {
      refreshToken: {
        updateMany: async (args: any) => {
          if (args.where.tokenHash) {
            assert.equal(args.where.revokedAt, null);
            assert.ok(args.where.expiresAt.gt instanceof Date);
            return { count: 1 };
          }
          return { count: 0 };
        },
        findUnique: async () => ({
          deviceName: 'Android Pixel',
          deviceInfo: 'Android 15',
        }),
        count: async () => 1,
        create: async ({ data }: any) => {
          createdTokens.push(data);
          return data;
        },
      },
    };
    return cb(tx);
  }) as any);

  const tokens = await AuthService.rotateRefreshToken('old-token', 'u-1', {
    ipAddress: '203.0.113.5',
  });
  assert.ok(tokens.accessToken);
  assert.ok(tokens.refreshToken);
  assert.equal(createdTokens.length, 1);
  assert.equal(createdTokens[0].deviceName, 'Android Pixel');
  assert.equal(createdTokens[0].deviceInfo, 'Android 15');
  assert.equal(createdTokens[0].ipAddress, '203.0.113.5');

  // Now simulate token reuse (count === 0 and existing.revokedAt !== null)
  stubProperty(t, prisma, '$transaction', (async (cb: any) => {
    const tx = {
      refreshToken: {
        updateMany: async (args: any) => {
          if (args.where.tokenHash) return { count: 0 };
          revokedUserUpdates.push(args);
          return { count: 2 };
        },
        findUnique: async () => ({
          id: 'rt-reused',
          userId: 'u-1',
          revokedAt: new Date(Date.now() - 1000),
          expiresAt: new Date(Date.now() + 60_000),
        }),
      },
    };
    return cb(tx);
  }) as any);

  await assert.rejects(
    () => AuthService.rotateRefreshToken('reused-token', 'u-1'),
    (err: unknown) => err instanceof RefreshTokenError
  );
  assert.equal(revokedUserUpdates.length, 1);
  assert.equal(revokedUserUpdates[0].where.userId, 'u-1');
  assert.equal(revokedUserUpdates[0].where.revokedAt, null);
});

test('AuthService.storeRefreshToken filters active (unexpired) tokens when enforcing max devices', async (t) => {
  let capturedFindFirstWhere: any;
  let revokedOldestId: string | undefined;

  stubProperty(t, prisma, 'refreshToken', {
    ...prisma.refreshToken,
    count: async () => 5,
    findFirst: async (args: any) => {
      capturedFindFirstWhere = args.where;
      return { id: 'oldest-active-id' } as any;
    },
    update: async (args: any) => {
      revokedOldestId = args.where.id;
      return {} as any;
    },
    create: async () => ({} as any),
  } as any);

  await AuthService.storeRefreshToken('u-1', 'new-refresh-token', { deviceName: 'Phone' });
  assert.equal(capturedFindFirstWhere.userId, 'u-1');
  assert.equal(capturedFindFirstWhere.revokedAt, null);
  assert.ok(capturedFindFirstWhere.expiresAt?.gt instanceof Date);
  assert.equal(revokedOldestId, 'oldest-active-id');
});

test('auth routes: authMiddleware before sensitiveLimiter, DELETE /account validation, and POST /refresh IP change', async (t) => {
  await withTestServer(
    (app) => {
      app.use('/api/v1/auth', authRoutes);
    },
    async (baseUrl) => {
      // Unauthenticated calls (>5) must all return 401, never 429
      for (let i = 0; i < 7; i++) {
        const resPatch = await fetch(`${baseUrl}/api/v1/auth/password`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ currentPassword: 'x', newPassword: 'newpassword123' }),
        });
        assert.equal(resPatch.status, 401);

        const resDel = await fetch(`${baseUrl}/api/v1/auth/account`, {
          method: 'DELETE',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ password: 'x' }),
        });
        assert.equal(resDel.status, 401);
      }

      // Authenticated DELETE /account with malformed body returns 400
      const { accessToken } = AuthService.generateTokens('u-auth-test');
      const resBad1 = await fetch(`${baseUrl}/api/v1/auth/account`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({}),
      });
      assert.equal(resBad1.status, 400);

      const resBad2 = await fetch(`${baseUrl}/api/v1/auth/account`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({ password: 'p'.repeat(129) }),
      });
      assert.equal(resBad2.status, 400);

      // POST /refresh with mobile IP change succeeds without device_mismatch
      t.mock.method(AuthService, 'verifyRefreshToken', async () => ({ userId: 'u-auth-test' }));
      t.mock.method(AuthService, 'rotateRefreshToken', async () => ({
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
      }));

      const resRefresh = await fetch(`${baseUrl}/api/v1/auth/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Forwarded-For': '198.51.100.42',
        },
        body: JSON.stringify({ refreshToken: 'valid-refresh-token' }),
      });
      assert.equal(resRefresh.status, 200);
      const refreshJson = (await resRefresh.json()) as any;
      assert.equal(refreshJson.data.accessToken, 'new-access');
    }
  );
});

test('POST /settings enforces MAX_SETTINGS_KEYS and MAX_SETTINGS_BYTES on post-merge object', async (t) => {
  assert.equal(isAllowedSettingsKey('theme.mode'), true);
  assert.equal(isAllowedSettingsKey('pomodoro.work'), true);
  assert.equal(isAllowedSettingsKey('notifications.enabled'), true);
  assert.equal(isAllowedSettingsKey('streak.goal'), true);
  assert.equal(isAllowedSettingsKey('goal.daily'), true);
  assert.equal(isAllowedSettingsKey('blocker.packages'), false);

  const { accessToken } = AuthService.generateTokens('u-settings');
  let currentSettings: Record<string, unknown> = {};

  stubProperty(t, prisma, 'userSettings', {
    ...prisma.userSettings,
    findUnique: async () => ({
      userId: 'u-settings',
      settings: currentSettings,
    }) as any,
    upsert: async ({ update }: any) => ({
      userId: 'u-settings',
      settings: update.settings,
    }) as any,
  } as any);

  await withTestServer(
    (app) => {
      app.use('/api/v1/settings', (req, res, next) => {
        req.user = { userId: 'u-settings' };
        next();
      }, settingsRoutes);
    },
    async (baseUrl) => {
      // Pre-populate 199 keys; incoming adds 2 new keys -> post-merge 201 > MAX_SETTINGS_KEYS (200)
      currentSettings = {};
      for (let i = 0; i < MAX_SETTINGS_KEYS - 1; i++) {
        currentSettings[`theme.k${i}`] = i;
      }
      const resKeys = await fetch(`${baseUrl}/api/v1/settings`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({ 'theme.extra1': 1, 'theme.extra2': 2 }),
      });
      assert.equal(resKeys.status, 400);

      // Pre-populate ~60KB; incoming adds ~6KB -> post-merge > MAX_SETTINGS_BYTES (64KB)
      currentSettings = { 'theme.big1': 'x'.repeat(MAX_SETTINGS_BYTES - 4096) };
      const resBytes = await fetch(`${baseUrl}/api/v1/settings`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({ 'theme.big2': 'y'.repeat(6000) }),
      });
      assert.equal(resBytes.status, 400);
    }
  );
});

test('withUserLock recovers cleanly after a failed lock task', async () => {
  const userId = 'u-lock-recovery';
  const runner = async <R>(cb: (tx: any) => Promise<R>): Promise<R> => cb({} as any);

  const p1 = withUserLock(
    userId,
    async () => {
      await new Promise((r) => setTimeout(r, 10));
      throw new Error('sync boom');
    },
    runner
  );
  const p2 = withUserLock(
    userId,
    async () => 'recovered-ok',
    runner
  );

  await assert.rejects(() => p1, /sync boom/);
  assert.equal(await p2, 'recovered-ok');

  // Subsequent sequential lock after failure also succeeds
  const p3 = await withUserLock(userId, async () => 42, runner);
  assert.equal(p3, 42);
});

test('pushSchema accepts explicit null for optional fields', () => {
  const parsed = pushSchema.parse({
    projects: null,
    subjects: null,
    topics: null,
    chapters: null,
    sessions: null,
    sources: null,
    skillLabels: null,
    achievements: null,
    userStats: null,
    subjectMilestones: null,
    userSettings: null,
  });
  assert.equal(parsed.userStats, null);
  assert.equal(parsed.userSettings, null);
  assert.equal(parsed.projects, null);
});

test('SyncService.pushChanges strips blocker.* keys, rejects invalid timestamps, and verifies session.sourceId ownership', async () => {
  const userId = '11111111-1111-4111-8111-111111111111';
  const projectId = '22222222-2222-4222-8222-222222222222';
  const subjectId = '33333333-3333-4333-8333-333333333333';
  const ownedSourceId = '44444444-4444-4444-8444-444444444444';
  const foreignSourceId = '55555555-5555-4555-8555-555555555555';
  const badSessionId = '66666666-6666-4666-8666-666666666666';
  const goodSessionId = '77777777-7777-4777-8777-777777777777';
  const badProjectId = '88888888-8888-4888-8888-888888888888';

  let savedSettings: any = null;
  const savedSessions: any[] = [];

  const mockTx: any = {
    project: {
      findMany: async () => [{ id: projectId }],
      findUnique: async () => null,
      upsert: async () => ({}),
    },
    subject: {
      findMany: async () => [{ id: subjectId }],
    },
    topic: {
      findMany: async () => [],
    },
    chapter: {
      findMany: async () => [],
    },
    source: {
      findMany: async () => [],
      findUnique: async () => null,
      upsert: async () => ({}),
    },
    studySession: {
      findMany: async () => [],
      findUnique: async () => null,
      upsert: async ({ create }: any) => {
        savedSessions.push(create);
        return create;
      },
    },
    userSettings: {
      findUnique: async () => null,
      upsert: async ({ create }: any) => {
        savedSettings = create.settings;
        return create;
      },
    },
    achievement: {
      findMany: async () => [],
    },
    userStats: {
      findUnique: async () => null,
    },
    subjectMilestone: {
      findMany: async () => [],
    },
    skillLabel: {
      findMany: async () => [],
    },
  };

  // stripLegacyBlockerSettings pure check (including __proto__ preservation for FORBIDDEN_KEYS)
  const rawWithProto = JSON.parse(
    '{"settings":{"theme.mode":"dark","blocker.packages":["com.app"],"__proto__":"bad"},"updatedAt":"2026-11-13T10:00:00.000Z"}'
  );
  const strippedProto = stripLegacyBlockerSettings(rawWithProto) as any;
  assert.equal('blocker.packages' in strippedProto.settings, false);
  assert.equal(Object.prototype.hasOwnProperty.call(strippedProto.settings, '__proto__'), true);

  const nowIso = '2026-11-13T10:00:00.000Z';
  const result = await SyncService.pushChanges(
    userId,
    {
      projects: [
        {
          id: badProjectId,
          userId,
          name: 'Bad Timestamp Project',
          icon: '📚',
          colorValue: 0x112233,
          defaultWorkDuration: 25,
          defaultBreakDuration: 5,
          defaultLongBreakDuration: 15,
          defaultLongBreakEvery: 4,
          studyReminderMinutes: 30,
          createdAt: nowIso,
          lastOpenedAt: nowIso,
          isArchived: false,
          updatedAt: 'not-a-valid-timestamp',
        },
      ],
      sources: [
        {
          id: ownedSourceId,
          subjectId,
          topicId: null,
          chapterId: null,
          type: 'pdf',
          title: 'Owned Book',
          addedAt: nowIso,
          updatedAt: nowIso,
        },
      ],
      sessions: [
        {
          id: badSessionId,
          subjectId,
          topicId: null,
          chapterId: null,
          startedAt: nowIso,
          endedAt: nowIso,
          plannedDurationMinutes: 25,
          actualDurationMinutes: 25,
          pomodorosCompleted: 1,
          xpEarned: 50,
          sourceId: foreignSourceId,
          isFreeTimer: false,
          updatedAt: nowIso,
        },
        {
          id: goodSessionId,
          subjectId,
          topicId: null,
          chapterId: null,
          startedAt: nowIso,
          endedAt: nowIso,
          plannedDurationMinutes: 25,
          actualDurationMinutes: 25,
          pomodorosCompleted: 1,
          xpEarned: 50,
          sourceId: ownedSourceId,
          isFreeTimer: false,
          updatedAt: nowIso,
        },
      ],
      userSettings: {
        settings: {
          'theme.mode': 'dark',
          'blocker.enabled': true,
          'blocker.packages': ['com.instagram.android', 'com.zhiliaoapp.musically'],
        },
        updatedAt: nowIso,
      },
    } as any,
    mockTx
  );

  // Invalid timestamp project rejected cleanly at validation time
  assert.equal(result.applied.projects, 0);
  assert.ok(result.errors.some((e) => e.entity === 'project' && e.id === badProjectId));

  // Unowned session.sourceId rejected as forbidden; same-push owned sourceId accepted
  assert.equal(result.applied.sources, 1);
  assert.equal(result.applied.sessions, 1);
  assert.ok(
    result.errors.some((e) => e.entity === 'session' && e.id === badSessionId && e.error === 'forbidden')
  );
  assert.equal(savedSessions.length, 1);
  assert.equal(savedSessions[0].id, goodSessionId);
  assert.equal(savedSessions[0].sourceId, ownedSourceId);

  // blocker.* stripped and valid settings persisted
  assert.equal(result.applied.userSettings, 1);
  assert.deepEqual(savedSettings, { 'theme.mode': 'dark' });
});
