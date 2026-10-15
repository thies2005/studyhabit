# StudyHabit Master Audit & Native Kotlin Rewrite Specification

**Target Repository:** `studyhabit` (Commit `ed240d56b7faf43617cd58ac41bb03b65102f0be`)  
**Scope:** Web & Backend Security Audit + End-to-End Functionality Audit + UI/UX Consistency Audit + Flutter Archival & Full Native Kotlin (Jetpack Compose) Android Rewrite  
**Agent Operating Rules:** Follow `AGENT.md` strictly. Execute tasks in exact numerical order, apply the smallest effective source changes for Backend/Web, archive the Flutter layer cleanly without data loss, build the native Kotlin Android app module-by-module, and run the verification commands at the end of every stage before committing.

> **Note on Formatting:** This specification avoids internal anchor links for full compatibility with Canvas Markdown rendering. Follow the numbered stages sequentially from Stage 1 through Stage 4.

## Agent Execution Rules & Pre-Flight Checklist

1. **Sequential Execution:** Do not skip stages or combine unrelated changes into a single unverified step.
2. **Preserve Existing Contracts:** The PostgreSQL Prisma schema (`backend/prisma/schema.prisma`) and REST/Sync JSON wire format (`/api/v1/*`) remain backward-compatible so existing databases and self-hosted deployments upgrade without data loss.
3. **Verification Gates:** After each stage, run the stage's mandatory verification commands. If any check fails, fix the root cause before moving to the next stage.
4. **Conventional Commits:** Commit each completed stage using Conventional Commits (`fix(security): ...`, `fix(web): ...`, `chore(archive): ...`, `feat(android): ...`).

## Part 1: Security Audit Report (Web, Backend API, & Deployment)

This section documents confirmed security boundary violations discovered in `backend/`, `web/`, and deployment configurations. Every finding identifies the lower-trust principal, accepted input, intended control, crossed boundary, concrete impact, severity, and smallest effective source fix.

### Security Findings Summary

| ID | Severity | Surface | Vulnerability Title | Location |
| :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | **High** | Backend Sync | Cross-Tenant Record Takeover & Re-Parenting (IDOR) in `SyncService.pushChanges` | `backend/src/services/syncService.ts:253-575` |
| **SEC-02** | **High** | Web / Nginx | Complete Loss of `Content-Security-Policy` & Security Headers on `/index.html` | `web/nginx.conf:8-12, 34-37` |
| **SEC-03** | **Medium** | Backend API & Sync | Cross-Tenant Foreign Key Injection (`topicId` / `chapterId`) in Sessions, Sources & Sync | `backend/src/routes/sessions.ts`, `sources.ts`, `syncService.ts` |
| **SEC-04** | **Medium** | Backend Sync | Validation Bypass & Stored `javascript:` URI Injection via Sync Endpoints | `backend/src/services/syncService.ts:18-157` |
| **SEC-05** | **Medium** | Backend CORS & Sync | Broken Multi-Origin CORS Reflection & Missing Per-User Lock on `/sync/push` and `/sync/erase` | `backend/src/index.ts:31-40`, `backend/src/routes/sync.ts:67-146` |
| **SEC-06** | **Medium** | Auth Flow (Web/App) | Anti-Enumeration Registration Response Poisons Client Token Storage with Empty Tokens | `backend/src/routes/auth.ts:42-60`, `web/src/hooks/useAuth.tsx:37-43` |
| **SEC-07** | **Low** | Backend Auth & Prototype | Unauthenticated `/auth/logout` Token Revocation & Unfiltered Prototype Keys in Settings | `backend/src/routes/auth.ts:127`, `backend/src/routes/settings.ts:13` |

### Detailed Security Findings & Root-Cause Evidence

#### SEC-01 (High): Cross-Tenant Record Takeover & Re-Parenting (IDOR) in `SyncService.pushChanges`
* **Lower-Trust Principal:** Any authenticated user (`req.user.userId`) calling `POST /api/v1/sync/push` or `POST /api/v1/sync/full`.
* **Accepted Input:** Sync payload arrays (`subjects`, `topics`, `chapters`, `sessions`, `sources`, `skillLabels`, `subjectMilestones`) containing client-supplied UUIDs (`id`) and parent foreign keys (`projectId`, `subjectId`, `topicId`).
* **Intended Control:** Users may only create or update records they own.
* **Crossed Boundary & Evidence:**
  In `backend/src/services/syncService.ts`, `projects` checks `if (existing && existing.userId !== userId)` (lines 226–229). However, `subjects` (lines 259–281), `topics` (lines 296–317), `chapters` (lines 332–353), `sessions` (lines 367–388), `sources` (lines 402–423), `skillLabels` (lines 437–458), and `subjectMilestones` (lines 549–570) only verify that the **incoming** parent ID (`validated.projectId`, `validated.subjectId`, or `validated.topicId`) is in the caller's owned set (`allProjectIds`, `allSubjectIds`, `allTopicIds`). They **never verify that `existing` belongs to the caller** before calling `tx.<model>.upsert({ where: { id: validated.id }, update: dataToSave })`.
* **Concrete Impact:** If User B supplies Victim User A's `subject.id` alongside `projectId: <User B's projectId>` and a future `updatedAt` timestamp, `tx.subject.upsert` overwrites Victim User A's subject and re-parents it into User B's project. Because child `topics`, `chapters`, `sessions`, `sources`, `skillLabels`, and `milestones` are scoped by `subjectId`, re-parenting the subject transfers all of Victim User A's child study records to User B, who can immediately exfiltrate them via `GET /api/v1/sync/pull` or `GET /api/v1/export`.
* **Smallest Effective Fix:** Before running `lastWriteWins` and `upsert` on any existing child entity, verify that the existing row's parent ID (`existing.projectId`, `existing.subjectId`, or `existing.topicId`) is also in `allProjectIds`, `allSubjectIds`, or `allTopicIds`.

#### SEC-02 (High): Complete Loss of `Content-Security-Policy` & Security Headers on `/index.html`
* **Lower-Trust Principal:** External web attacker / XSS payload targeting the React SPA (`web/`).
* **Accepted Input:** Browser navigation to `/` or any SPA route served by `location = /index.html` in `web/nginx.conf`.
* **Intended Control:** `SECURITY.md` states: *"The primary mitigation against token theft via XSS is the strict Content-Security-Policy served by `web/nginx.conf`: `script-src 'self'` with no `unsafe-inline`/`unsafe-eval`."*
* **Crossed Boundary & Evidence:**
  In `web/nginx.conf`, security headers (`X-Frame-Options`, `X-Content-Type-Options`, `Strict-Transport-Security`, `Content-Security-Policy`) are defined at the `server` block level (lines 8–12). However, `location = /index.html` (lines 34–37) and `location /assets/` (lines 29–32) define their own `add_header Cache-Control ...` directives. In nginx (`ngx_http_headers_module`), defining any `add_header` directive inside a `location` block **drops all inherited `add_header` directives from the parent `server` block**.
* **Concrete Impact:** Every request for `/` or `/index.html` is served with **only** `Cache-Control: no-cache` and **zero security headers** (no `Content-Security-Policy`, no `Strict-Transport-Security`, no `X-Frame-Options`, no `X-Content-Type-Options`), completely neutralizing the XSS protection for `localStorage` JWT tokens.
* **Smallest Effective Fix:** Repeat the security headers inside `location = /index.html` and `location /assets/` (or include a shared header snippet) and add `Referrer-Policy` and `Permissions-Policy`.

#### SEC-03 (Medium): Cross-Tenant Foreign Key Injection (`topicId` / `chapterId`) in Sessions, Sources & Sync
* **Lower-Trust Principal:** Authenticated user calling `POST /api/v1/sessions`, `PATCH /api/v1/sessions/:id`, `POST /api/v1/sources`, `PATCH /api/v1/sources/:id`, or `/api/v1/sync/*`.
* **Accepted Input:** Optional `topicId` and `chapterId` UUIDs in the request body.
* **Intended Control:** `topicId` must belong to the target `subjectId`, and `chapterId` must belong to `topicId` under that `subjectId`.
* **Crossed Boundary & Evidence:** `backend/src/routes/sessions.ts` and `backend/src/routes/sources.ts` only check ownership of `subjectId` on `POST` and session/source ownership on `PATCH`. They never validate that `data.topicId` or `data.chapterId` belong to that subject or user (unlike `skill-labels.ts`, which explicitly checks both). Similarly, `syncService.ts` never checks `validated.topicId` or `validated.chapterId` on `sessions`, `sources`, or `skillLabels`.
* **Concrete Impact:** An authenticated user can attach their sessions or sources to another tenant's `Topic` or `Chapter` UUID, corrupting relational integrity.
* **Smallest Effective Fix:** Enforce a shared helper `verifyHierarchyOwnership(tx, userId, subjectId, topicId, chapterId)` in `sessions.ts`, `sources.ts`, and `syncService.ts`.

#### SEC-04 (Medium): Validation Bypass & Stored `javascript:` URI Injection via Sync Endpoints
* **Lower-Trust Principal:** Authenticated user pushing records via `/api/v1/sync/push` or `/api/v1/sync/full`.
* **Accepted Input:** `sources[].url`, string fields (`name`, `title`, `notes`, `description`), and numeric fields (`actualDurationMinutes`, `plannedDurationMinutes`, `xpEarned`, `totalXp`, `freezeTokens`).
* **Intended Control:** Enforce the same domain invariants on `/sync` as on REST endpoints (`http://` or `https://` URLs, bounded string lengths, non-negative durations and XP).
* **Crossed Boundary & Evidence:** While `backend/src/routes/sources.ts` restricts `url` to `http://` or `https://`, `backend/src/services/syncService.ts` (line 99) accepts `url: z.string().nullable()` without scheme validation. A `javascript:` URI pushed via sync is stored in PostgreSQL and synced to web and mobile clients. Furthermore, `syncService.ts` lacks `.max()` string limits and `.min(0)` integer bounds.
* **Smallest Effective Fix:** Harden all Zod schemas in `backend/src/services/syncService.ts` with `http://`/`https://` URL validation, string `.max()` bounds, and non-negative integer constraints, and validate `source.url` protocol on the frontend before rendering `<a href>`.

#### SEC-05 (Medium): Broken Multi-Origin CORS Reflection & Missing Per-User Lock on `/sync/push` and `/sync/erase`
* **Lower-Trust Principal:** Cross-origin web requests and concurrent sync requests from the same user.
* **Crossed Boundary & Evidence:**
  1. `backend/src/index.ts` (lines 31–40) passes `config.CORS_ORIGIN` verbatim to `callback(null, config.CORS_ORIGIN)` for every request with an `Origin` header instead of checking membership in a comma-separated allowlist as documented in `.env.example`.
  2. `backend/src/routes/sync.ts` wraps `POST /sync/full` in `withUserLock(req.user.userId, ...)` (line 113), but leaves `POST /sync/push` (line 67) and `POST /sync/erase` (line 130) unlocked, allowing concurrent requests to race against `/sync/full`.
* **Smallest Effective Fix:** Parse `config.CORS_ORIGIN` as a comma-separated allowlist in `index.ts`, and wrap `/sync/push` and `/sync/erase` in `withUserLock(req.user.userId, ...)`.

#### SEC-06 (Medium): Anti-Enumeration Registration Response Poisons Client Token Storage
* **Lower-Trust Principal:** Any user registering with an email that already exists.
* **Crossed Boundary & Evidence:** `backend/src/routes/auth.ts` (lines 42–60) returns HTTP `201` with `accessToken: ''` and `refreshToken: ''` when an email is already registered. `web/src/hooks/useAuth.tsx` (lines 37–43) blindly stores `""` in `localStorage` and navigates to `/dashboard`, which immediately bounces back to `/login` with no message. On mobile, storing empty tokens with the fake random `user.id` poisons local auth state and causes all subsequent sync calls to fail with 401.
* **Smallest Effective Fix:** In `web/src/hooks/useAuth.tsx` (and the Kotlin client), check `if (!accessToken || !refreshToken)` after `/auth/register` and throw an explicit error using `response.data.message` without writing empty tokens to storage.

#### SEC-07 (Low): Unfiltered Prototype Keys in `settingsSchema`
* **Lower-Trust Principal:** Authenticated user calling `POST /api/v1/settings` or pushing `userSettings` via sync.
* **Crossed Boundary & Evidence:** `settingsSchema` in `backend/src/routes/settings.ts` and `syncService.ts` accepts arbitrary `z.record(z.unknown())` keys without rejecting `__proto__`, `constructor`, or `prototype`, and without restricting keys to known setting prefixes (`theme.`, `pomodoro.`, `notifications.`, `streak.`, `goal.`, `active_timer_type`, `pomodoro_state_json`, `free_timer_state_json`).
* **Smallest Effective Fix:** Restrict `settingsSchema` keys to the explicit allowlist of setting prefixes and reject dangerous prototype keys.

## Part 2: Detailed Functionality Audit

### Functionality Findings Summary

| ID | Surface | Defect Summary | Root Cause Location |
| :--- | :--- | :--- | :--- |
| **FUNC-01** | Backend API | Soft-deleted sessions, subjects, topics, and chapters are included in stats, subject totals, subject detail trees, and achievement checks | `backend/src/routes/stats.ts`, `subjects.ts`, `achievementService.ts`, `export.ts` |
| **FUNC-02** | Backend API | Deleting or editing a study session leaves `userStats.totalStudyMinutes`, `userStats.totalXp`, and `subject.xpTotal` out of sync | `backend/src/routes/sessions.ts:183-270` |
| **FUNC-03** | Backend & Web | Achievement catalog mismatch: Backend & Web only implement 15 achievements while Mobile implements 47 achievements | `backend/src/services/achievementService.ts`, `web/src/pages/Achievements.tsx` |
| **FUNC-04** | Web Dashboard | Switching projects in the top bar (`ProjectSwitcher`) has zero effect on `Subjects`, `Dashboard`, or `Stats`, and creating a subject always assigns it to `projects[0]` | `web/src/pages/Subjects.tsx`, `Dashboard.tsx`, `Stats.tsx`, `backend/src/routes/stats.ts` |
| **FUNC-05** | Web Dashboard | Four divergent XP/level threshold formulas across Web pages cause broken progress bars (100% stuck at Level 6+ in `SubjectDetail.tsx`) and fake skill levels in `Stats.tsx` | `web/src/pages/SubjectDetail.tsx`, `Dashboard.tsx`, `Subjects.tsx`, `Achievements.tsx`, `Stats.tsx` |
| **FUNC-06** | Web & Backend | `Settings.tsx` displays a blank email (reads `email` from JWT which only encodes `userId`) and overwrites the entire `userSettings` JSON blob, wiping mobile-only settings | `web/src/pages/Settings.tsx:85-147`, `backend/src/routes/settings.ts:30-40` |
| **FUNC-07** | Web Dashboard | `Dashboard.tsx` calculates "Today's hours" from only the last 3 sessions (`/sessions?limit=3`); `SubjectDetail.tsx` always shows `0h total study` and lacks chapter/source/session actions | `web/src/pages/Dashboard.tsx:39-66`, `web/src/pages/SubjectDetail.tsx:44-280` |
| **FUNC-08** | Backend & Web | Missing `GET /api/v1/stats/xp-history` endpoint leaves the Web `Stats.tsx` XP Progress section permanently empty | `backend/src/routes/stats.ts`, `web/src/pages/Stats.tsx:131-137` |

## Part 3: UI/UX Consistency Audit

### UI/UX Findings Summary

| ID | Surface | Inconsistency Summary | Root Cause Location |
| :--- | :--- | :--- | :--- |
| **UIUX-01** | Web Theme | Light Mode is non-functional: selecting "Light" in Settings toggles `.dark` on `<html>`, but `index.css` and `tailwind.config.ts` hardcode dark hex values (`#0F1416`) | `web/src/index.css`, `web/tailwind.config.ts` |
| **UIUX-02** | Web Theme | Preset seed colors in `Settings.tsx` use dark container hexes (`#4F378B`) instead of canonical seed hexes (`#6750A4`), and changing Seed Color or Font Scale in `Settings.tsx` does not update CSS variables live | `web/src/pages/Settings.tsx`, `web/src/hooks/useThemeSettings.ts`, `web/src/components/CreateSubjectDialog.tsx` |
| **UIUX-03** | Web Branding | Brand title oscillates between `"Studyhabit"`, `"Study Sanctuary"`, `"StudyHabit"`, and `"Study Habit"`; `Dashboard`, `Login`, and `Register` mix raw OS emojis with Material Symbols Rounded icons | `web/index.html`, `Layout.tsx`, `Login.tsx`, `Register.tsx`, `Dashboard.tsx` |
| **UIUX-04** | Web Dialogs | `Modal.tsx` is only used by `CreateSessionDialog.tsx`; four other dialogs duplicate backdrop markup and `Achievements.tsx` detail modal lacks focus-trap and `Escape`-to-close | `web/src/components/CreateSourceDialog.tsx`, `CreateSubjectDialog.tsx`, `CreateTopicDialog.tsx`, `ManageMilestonesDialog.tsx`, `Achievements.tsx` |
| **UIUX-05** | Web Layout | `Dashboard.tsx` XP bar has broken non-flex sibling alignment and duplicate level labels; `Stats.tsx` 12-week heatmap omits `grid-flow-col` and weekday alignment, scrambling days across rows | `web/src/pages/Dashboard.tsx:119-138`, `web/src/pages/Stats.tsx:66-85, 354-375` |
| **UIUX-06** | Web Forms | `CreateSessionDialog.tsx` allows `plannedDuration` down to `0` (`min="0"`), which fails backend Zod validation (`min(5)`) with a 400 error | `web/src/components/CreateSessionDialog.tsx:188` |

## Part 4: Step-by-Step Implementation Plan for the Coding Agent

Follow Stages 1 through 4 in exact order.

### Stage 1: Backend Security & Functionality Fixes (`backend/`)

#### Task 1.1: Fix Multi-Origin CORS & Swagger Guard in `backend/src/index.ts`
Update `backend/src/index.ts` so `config.CORS_ORIGIN` is parsed as a comma-separated allowlist of origins instead of reflecting the raw configuration string.

```typescript
// Replace the app.use(cors(...)) block in backend/src/index.ts (lines 31-40) with:
const allowedOrigins = config.CORS_ORIGIN === '*'
  ? '*'
  : config.CORS_ORIGIN.split(',').map((o) => o.trim()).filter(Boolean);

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins === '*') {
      callback(null, true);
    } else if (allowedOrigins.includes(origin)) {
      callback(null, origin);
    } else {
      callback(null, false);
    }
  },
  credentials: allowedOrigins !== '*',
}));
```

#### Task 1.2: Harden Sync Ownership (IDOR Fix), Hierarchy Checks, & Input Bounds in `backend/src/services/syncService.ts` and `backend/src/routes/sync.ts`

1. In `backend/src/routes/sync.ts`, wrap **both** `POST /push` and `POST /erase` inside `withUserLock(req.user.userId, async () => { ... })` so concurrent sync operations for the same user are serialized across all sync endpoints:

```typescript
// In backend/src/routes/sync.ts:
router.post('/push', async (req, res, next) => {
  try {
    const payload = pushSchema.parse(req.body);
    const result = await withUserLock(req.user.userId, () =>
      SyncService.pushChanges(req.user.userId, payload as any)
    );
    res.json({ data: result });
  } catch (error: unknown) {
    if (error instanceof ZodError) {
      return res.status(400).json({ error: 'Validation error', details: error.errors });
    }
    next(error);
  }
});

router.post('/erase', async (req, res, next) => {
  try {
    const userId = req.user.userId;
    await withUserLock(userId, async () => {
      await prisma.$transaction([
        prisma.project.deleteMany({ where: { userId } }),
        prisma.achievement.deleteMany({ where: { userId } }),
        prisma.userStats.deleteMany({ where: { userId } }),
        prisma.userSettings.deleteMany({ where: { userId } }),
      ]);
    });
    res.json({ success: true });
  } catch (error: unknown) {
    next(error);
  }
});
```

2. In `backend/src/services/syncService.ts`:
   - Add string length bounds, non-negative integer constraints, and `http://`/`https://` URL validation to the Zod schemas (`projectSchema`, `subjectSchema`, `topicSchema`, `chapterSchema`, `sessionSchema`, `sourceSchema`, `skillLabelSchema`, `achievementSchema`, `userStatsSchema`, `subjectMilestoneSchema`, `userSettingsSchema`).
   - Add an allowed-key filter on `userSettingsSchema` that rejects `__proto__`, `constructor`, and `prototype` and permits only keys starting with `theme.`, `pomodoro.`, `notifications.`, `streak.`, `goal.`, or equal to `active_timer_type`, `pomodoro_state_json`, `free_timer_state_json`.
   - **Critical IDOR Fix (`SEC-01` & `SEC-03`):** Track `allChapterIds` alongside `allProjectIds`, `allSubjectIds`, and `allTopicIds`. For every entity in `pushChanges`:
     - When `existing` is found in the database, verify that `existing`'s current parent ID belongs to the user (`allProjectIds.has(existing.projectId)` for subjects, `allSubjectIds.has(existing.subjectId)` for topics/sessions/sources/skillLabels/milestones, `allTopicIds.has(existing.topicId)` for chapters). If not, push `{ entity, id: validated.id, error: 'forbidden' }` and `continue`!
     - For `sessions`, `sources`, and `skillLabels`, also verify `if (validated.topicId && !allTopicIds.has(validated.topicId))` and `if (validated.chapterId && !allChapterIds.has(validated.chapterId))`, rejecting cross-tenant foreign keys with `'forbidden'`.

```typescript
// Key ownership & hierarchy checks to enforce in backend/src/services/syncService.ts:
const userChapters = allTopicIds.size > 0
  ? await prisma.chapter.findMany({ where: { topicId: { in: Array.from(allTopicIds) } }, select: { id: true } })
  : [];
const allChapterIds = new Set(userChapters.map(c => c.id));

// Inside payload.subjects loop:
const existing = await tx.subject.findUnique({ where: { id: validated.id } });
if (existing && !allProjectIds.has(existing.projectId)) {
  errors.push({ entity: 'subject', id: validated.id, error: 'forbidden' });
  continue;
}

// Inside payload.topics loop:
const existing = await tx.topic.findUnique({ where: { id: validated.id } });
if (existing && !allSubjectIds.has(existing.subjectId)) {
  errors.push({ entity: 'topic', id: validated.id, error: 'forbidden' });
  continue;
}

// Inside payload.chapters loop:
const existing = await tx.chapter.findUnique({ where: { id: validated.id } });
if (existing && !allTopicIds.has(existing.topicId)) {
  errors.push({ entity: 'chapter', id: validated.id, error: 'forbidden' });
  continue;
}
// When chapter upsert succeeds:
allChapterIds.add(validated.id);

// Inside payload.sessions, payload.sources, and payload.skillLabels loops:
if (
  !allSubjectIds.has(validated.subjectId) ||
  (validated.topicId && !allTopicIds.has(validated.topicId)) ||
  (validated.chapterId && !allChapterIds.has(validated.chapterId))
) {
  errors.push({ entity: 'session', id: validated.id, error: 'forbidden' });
  continue;
}
const existing = await tx.studySession.findUnique({ where: { id: validated.id } });
if (existing && !allSubjectIds.has(existing.subjectId)) {
  errors.push({ entity: 'session', id: validated.id, error: 'forbidden' });
  continue;
}

// Inside payload.subjectMilestones loop:
const existing = await tx.subjectMilestone.findUnique({ where: { id: validated.id } });
if (existing && !allSubjectIds.has(existing.subjectId)) {
  errors.push({ entity: 'subjectMilestone', id: validated.id, error: 'forbidden' });
  continue;
}
```

#### Task 1.3: Fix Session & Source Hierarchy Validation and XP/Minutes Accounting in `backend/src/routes/sessions.ts` & `backend/src/routes/sources.ts`

1. In `backend/src/routes/sessions.ts`:
   - Allow `topicId: z.string().uuid().nullable().optional()`, `chapterId: z.string().uuid().nullable().optional()`, and `notes: z.string().max(5000).nullable().optional()` in `sessionSchema` and `updateSessionSchema` (since `CreateSessionDialog.tsx` sends `null` for empty `topicId`, `chapterId`, `confidenceRating`, and `notes`).
   - Validate that `topicId` (if non-null) belongs to `subjectId`, and `chapterId` (if non-null) belongs to `topicId` under `subjectId`.
   - In `PATCH /:id`: calculate `durationDelta = (data.actualDurationMinutes ?? existing.actualDurationMinutes) - existing.actualDurationMinutes` and pass `durationDelta` to `XpService.addXpAndMinutes(req.user.userId, xpDelta, durationDelta, tx)` so editing a session's duration updates `userStats.totalStudyMinutes`.
   - In `DELETE /:id`: run inside `prisma.$transaction` to soft-delete the session (`isDeleted: true, updatedAt: new Date()`) AND decrement `subject.xpTotal` by `existing.xpEarned` and `userStats` by `-existing.xpEarned` and `-existing.actualDurationMinutes` (clamped at 0 in `XpService.addXpAndMinutes`).

2. In `backend/src/routes/sources.ts`:
   - Allow `topicId: z.string().uuid().nullable().optional()`, `chapterId: z.string().uuid().nullable().optional()`, `notes: z.string().max(5000).nullable().optional()`.
   - Verify `topicId` and `chapterId` belong to `subjectId` on both `POST /` and `PATCH /:id`.

3. In `backend/src/services/xpService.ts`:
   - Clamp `newTotalXp = Math.max(0, userStats.totalXp + xp)` and `newTotalMinutes = Math.max(0, userStats.totalStudyMinutes + studyMinutes)` in `addXpAndMinutes` so session deletions never produce negative XP or study minutes.

#### Task 1.4: Filter Soft-Deleted Records in `subjects.ts`, `stats.ts`, `export.ts`, and Add `GET /api/v1/stats/xp-history`

1. **`backend/src/routes/subjects.ts`:**
   - In `GET /` (line 42) and `createProjectSubjectRoutes` `GET /` (line 138), filter included sessions by `where: { isDeleted: false }`:
     ```typescript
     include: {
       sessions: {
         where: { isDeleted: false },
         select: { actualDurationMinutes: true },
       },
     }
     ```
   - In `GET /:id` (line 61), filter `topics` and nested `chapters` by `isDeleted: false` AND compute `totalStudyMinutes` and `totalStudyHours`:
     ```typescript
     const subject = await prisma.subject.findFirst({
       where: { id, project: { userId: req.user.userId, isDeleted: false }, isDeleted: false },
       include: {
         topics: {
           where: { isDeleted: false },
           orderBy: { order: 'asc' },
           include: {
             chapters: { where: { isDeleted: false }, orderBy: { order: 'asc' } },
           },
         },
         sessions: {
           where: { isDeleted: false },
           select: { actualDurationMinutes: true },
         },
       },
     });
     if (!subject) {
       return res.status(404).json({ error: 'Subject not found' });
     }
     const totalStudyMinutes = subject.sessions.reduce((sum, s) => sum + (s.actualDurationMinutes || 0), 0);
     const { sessions, ...rest } = subject;
     res.json({
       data: {
         ...rest,
         totalStudyMinutes,
         totalStudyHours: Number((totalStudyMinutes / 60).toFixed(1)),
       },
     });
     ```
   - Also accept `completenessMode`, `targetHours`, and `targetWeeklyHours` in `subjectSchema` and `updateSubjectSchema`.

2. **`backend/src/routes/stats.ts`:**
   - Accept optional `projectId: z.string().uuid().optional()` query parameter on `/overview`, `/heatmap`, `/subjects`, and the new `/xp-history` endpoint.
   - Filter all `studySession` queries with `isDeleted: false` and `subject: { isDeleted: false, project: { userId: req.user.userId, isDeleted: false, ...(projectId ? { id: projectId } : {}) } }`.
   - In `/overview`, also compute `todayHours` from sessions started since midnight UTC/local today so the Dashboard does not undercount when more than 3 sessions are logged in a day.
   - In `/subjects`, also query each subject's latest subject-level `SkillLabel` (`topicId: null, chapterId: null, isDeleted: false`) so `skillLevel` reflects the actual user-assigned skill label (defaulting to `'beginner'`).
   - Add `GET /api/v1/stats/xp-history`:
     ```typescript
     router.get('/xp-history', async (req, res, next) => {
       try {
         const { days } = daysQuerySchema.parse({ days: req.query.days || 30 });
         const projectId = req.query.projectId ? String(req.query.projectId) : undefined;
         const startDate = new Date();
         startDate.setDate(startDate.getDate() - days);

         const sessions = await prisma.studySession.findMany({
           where: {
             isDeleted: false,
             startedAt: { gte: startDate },
             subject: {
               isDeleted: false,
               project: {
                 userId: req.user.userId,
                 isDeleted: false,
                 ...(projectId ? { id: projectId } : {}),
               },
             },
           },
           orderBy: { startedAt: 'asc' },
           select: { startedAt: true, xpEarned: true },
         });

         const dailyXp = new Map<string, number>();
         for (const s of sessions) {
           const day = s.startedAt.toISOString().split('T')[0];
           dailyXp.set(day, (dailyXp.get(day) ?? 0) + s.xpEarned);
         }

         let cumulativeXp = 0;
         const points: Array<{ date: string; dailyXp: number; cumulativeXp: number }> = [];
         for (let i = days - 1; i >= 0; i--) {
           const d = new Date();
           d.setDate(d.getDate() - i);
           const dateKey = d.toISOString().split('T')[0];
           const gained = dailyXp.get(dateKey) ?? 0;
           cumulativeXp += gained;
           points.push({ date: dateKey, dailyXp: gained, cumulativeXp });
         }

         res.json({ data: points });
       } catch (error: unknown) {
         next(error);
       }
     });
     ```

3. **`backend/src/routes/settings.ts`:**
   - Merge incoming settings keys with existing `userSettings.settings` instead of overwriting the entire JSON object, and validate allowed key prefixes:
     ```typescript
     const ALLOWED_PREFIXES = ['theme.', 'pomodoro.', 'notifications.', 'streak.', 'goal.'];
     const ALLOWED_EXACT = new Set(['active_timer_type', 'pomodoro_state_json', 'free_timer_state_json']);
     const FORBIDDEN_KEYS = new Set(['__proto__', 'constructor', 'prototype']);

     export function isAllowedSettingsKey(key: string): boolean {
       if (FORBIDDEN_KEYS.has(key)) return false;
       if (ALLOWED_EXACT.has(key)) return true;
       return ALLOWED_PREFIXES.some((prefix) => key.startsWith(prefix));
     }
     ```
   - In `POST /api/v1/settings`:
     ```typescript
     const incoming = settingsSchema.parse(req.body);
     const existing = await prisma.userSettings.findUnique({ where: { userId: req.user.userId } });
     const merged = {
       ...((existing?.settings as Record<string, unknown>) ?? {}),
       ...incoming,
     };
     const updated = await prisma.userSettings.upsert({
       where: { userId: req.user.userId },
       create: { userId: req.user.userId, settings: merged as any },
       update: { settings: merged as any, updatedAt: new Date() },
     });
     res.json({ data: updated.settings });
     ```

4. **`backend/src/services/achievementService.ts`:**
   - Add `isDeleted: false` to all Prisma queries in `buildContext` and `getSubjectHours`.
   - Expand `ACHIEVEMENT_THRESHOLDS` from 15 keys to the full **47 achievement keys** matching mobile (`streak_3..365`, `pomodoro_10..5000`, `hours_10..1000`, `sessions_5..500`, `subject_5h`, `subjects_2_5h`, `subjects_5_5h`, `subject_10h`, `subjects_3_10h`, `subjects_5_10h`, `free_timer_first`, `free_timer_10`, `free_timer_30m`, `free_timer_2h`, `long_session_2h..5h`, `confidence_5..50`, `all_5stars_3`, `first_pdf`, `sources_5`, `sources_10`, `skill_advanced`, `skill_expert`, `night_owl`, `early_bird`, `all_badges`).

#### Stage 1 Verification Commands
```bash
cd backend
npx tsc --noEmit
npm run build
```

### Stage 2: Web Dashboard Security, Functionality, & UI/UX Consistency Fixes (`web/`)

#### Task 2.1: Fix `web/nginx.conf` Security Header Inheritance (`SEC-02`)
Update `web/nginx.conf` so `Content-Security-Policy`, `Strict-Transport-Security`, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, and `Permissions-Policy` are present on **every** location block that uses `add_header` (specifically `location = /index.html` and `location /assets/`).

```nginx
server {
    listen 3000;
    listen [::]:3000;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    set $csp_header "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self' https://*.schuelken.uk http://localhost:* http://127.0.0.1:* ws://localhost:* ws://127.0.0.1:* wss://*.schuelken.uk;";

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header Content-Security-Policy $csp_header always;

    location /api/ {
        proxy_pass http://api:3001/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header Content-Security-Policy $csp_header always;
    }

    location = /index.html {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header Content-Security-Policy $csp_header always;
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
```

#### Task 2.2: Fix Light/Dark Mode CSS Tokens, Unified Preset Seeds, & Live Font Scaling (`UIUX-01`, `UIUX-02`)

1. **`web/src/index.css`:** Define light-mode default CSS variables in `:root` and dark-mode overrides in `html.dark`, and support `--font-scale`:

```css
:root {
  color-scheme: light;
  --color-bg: #F5FAFB;
  --color-surface: #EFF4F6;
  --color-surface-lowest: #FFFFFF;
  --color-surface-low: #E9EFF1;
  --color-surface-container: #E3EAEB;
  --color-surface-high: #DDE4E6;
  --color-surface-highest: #D7DFE1;
  --color-on-surface: #171C1E;
  --color-on-surface-variant: #3F484B;
  --color-outline: #6F797B;
  --color-outline-variant: #BFC8CA;
  --color-primary: #006874;
  --color-primary-container: #9EEFFD;
  --color-on-primary-container: #001F24;
  --font-scale: 1;
  font-size: calc(16px * var(--font-scale));
  background-color: var(--color-bg);
  color: var(--color-on-surface);
}

html.dark {
  color-scheme: dark;
  --color-bg: #0F1416;
  --color-surface: #111416;
  --color-surface-lowest: #070F11;
  --color-surface-low: #151C1F;
  --color-surface-container: #192023;
  --color-surface-high: #232A2E;
  --color-surface-highest: #2E3539;
  --color-on-surface: #E1E3E4;
  --color-on-surface-variant: #BFC8CA;
  --color-outline: #899295;
  --color-outline-variant: #3F484B;
  --color-primary: #85D2E0;
  --color-primary-container: #004F58;
  --color-on-primary-container: #A1EFFF;
}

body {
  margin: 0;
  display: flex;
  min-width: 320px;
  min-height: 100vh;
  background-color: var(--color-bg);
  color: var(--color-on-surface);
  font-family: 'DM Sans', system-ui, -apple-system, sans-serif;
}
```

2. **`web/tailwind.config.ts`:** Wire all surface, background, text, and outline tokens to the CSS variables above so Light Mode and Dark Mode both render with proper Material 3 contrast.

3. **`web/src/hooks/useThemeSettings.ts`:** Export canonical `PRESET_SEEDS` (with `seed`, `darkPrimary`, `darkContainer`, `lightPrimary`, `lightContainer`) and `applyThemeToDom(settings)` so both `useThemeSettings.ts` and `Settings.tsx` apply theme mode, seed color, and `--font-scale` immediately on change:

```typescript
export const PRESET_SEEDS = [
  { seed: '#006874', darkPrimary: '#85D2E0', darkContainer: '#006874', lightPrimary: '#006874', lightContainer: '#9EEFFD' }, // Deep Teal
  { seed: '#6750A4', darkPrimary: '#D0BCFF', darkContainer: '#4F378B', lightPrimary: '#6750A4', lightContainer: '#EADDFF' }, // Purple
  { seed: '#0061A4', darkPrimary: '#9ECAFF', darkContainer: '#004A77', lightPrimary: '#0061A4', lightContainer: '#D1E4FF' }, // Blue
  { seed: '#006E1C', darkPrimary: '#80DC89', darkContainer: '#005313', lightPrimary: '#006E1C', lightContainer: '#9BF6A3' }, // Green
  { seed: '#B3261E', darkPrimary: '#FFB4AB', darkContainer: '#93000A', lightPrimary: '#B3261E', lightContainer: '#F9DEDC' }, // Red
  { seed: '#984061', darkPrimary: '#FFB1C8', darkContainer: '#7D264A', lightPrimary: '#984061', lightContainer: '#FFD9E2' }, // Pink
  { seed: '#AC3306', darkPrimary: '#FFB599', darkContainer: '#8D1500', lightPrimary: '#AC3306', lightContainer: '#FFDBCF' }, // Orange
  { seed: '#7B5800', darkPrimary: '#E8C16C', darkContainer: '#5D4200', lightPrimary: '#7B5800', lightContainer: '#FFDEA1' }, // Brown/Amber
  { seed: '#386667', darkPrimary: '#4ED8D9', darkContainer: '#004F50', lightPrimary: '#00696A', lightContainer: '#6FF6F7' }, // Cyan
  { seed: '#343DFF', darkPrimary: '#BFC2FF', darkContainer: '#0008A6', lightPrimary: '#343DFF', lightContainer: '#E0E0FF' }, // Indigo
  { seed: '#1B6B46', darkPrimary: '#89D6A1', darkContainer: '#00522B', lightPrimary: '#1B6B46', lightContainer: '#A4F2BC' }, // Forest
  { seed: '#4A4458', darkPrimary: '#CCC2DC', darkContainer: '#332D41', lightPrimary: '#625B71', lightContainer: '#E8DEF8' }, // Slate
];
```

#### Task 2.3: Create Shared XP & Level Utility (`web/src/utils/xp.ts`) (`FUNC-05`)
Create `web/src/utils/xp.ts` matching `backend/src/services/xpService.ts` and `lib/core/services/xp_service.dart` 1:1, and replace the four divergent functions in `Dashboard.tsx`, `Achievements.tsx`, `SubjectDetail.tsx`, and `Subjects.tsx`:

```typescript
export const LEVEL_NAMES = [
  'Novice',
  'Apprentice',
  'Scholar',
  'Adept',
  'Expert',
  'Master',
  'Grandmaster',
] as const;

export function calculateLevel(totalXp: number): number {
  if (totalXp < 500) return 1;
  if (totalXp < 1500) return 2;
  if (totalXp < 3500) return 3;
  if (totalXp < 7000) return 4;
  if (totalXp < 10500) return 5;

  let level = 6;
  let threshold = 10500;
  while (level < 100 && totalXp >= Math.round((threshold * 1.5) / 100) * 100) {
    threshold = Math.round((threshold * 1.5) / 100) * 100;
    level++;
  }
  return level;
}

export function levelThreshold(level: number): number {
  if (level <= 1) return 0;
  if (level === 2) return 500;
  if (level === 3) return 1500;
  if (level === 4) return 3500;
  if (level === 5) return 7000;
  let threshold = 10500;
  for (let l = 6; l < level; l++) {
    threshold = Math.round((threshold * 1.5) / 100) * 100;
  }
  return threshold;
}

export function getLevelName(level: number): string {
  return LEVEL_NAMES[Math.min(Math.max(1, level) - 1, LEVEL_NAMES.length - 1)];
}

export function getLevelProgress(totalXp: number) {
  const currentLevel = calculateLevel(totalXp);
  const currentFloor = levelThreshold(currentLevel);
  const nextCeiling = levelThreshold(currentLevel + 1);
  const xpInLevel = Math.max(0, totalXp - currentFloor);
  const xpNeededForBand = Math.max(1, nextCeiling - currentFloor);
  const xpToNextLevel = Math.max(0, nextCeiling - totalXp);
  const progressPercent = Math.min(100, Math.max(0, (xpInLevel / xpNeededForBand) * 100));
  return {
    currentLevel,
    levelName: getLevelName(currentLevel),
    xpInLevel,
    xpNeededForBand,
    xpToNextLevel,
    progressPercent,
  };
}
```

#### Task 2.4: Fix Auth Context (`useAuth.tsx`), Registration Guard (`SEC-06`), & User Email Display (`FUNC-06`)
Update `web/src/hooks/useAuth.tsx` to:
1. Store `userEmail` in `localStorage` (`user_email`) and `AuthContext` on login/register, and hydrate it from `GET /api/v1/auth/me` if missing.
2. In `register(email, password)`: check `if (!accessToken || !refreshToken)` (which happens when the backend returns the anti-enumeration 201 dummy response) and throw `new Error(response.data?.message || 'An account with this email may already exist. Please sign in.')` instead of saving empty tokens.
3. In `web/src/pages/Settings.tsx`: read `userEmail` from `useAuth()` instead of decoding the JWT (which does not contain `email`).

#### Task 2.5: Wire Project Filtering (`FUNC-04`), Fix Dashboard & Stats Heatmap (`UIUX-05`), & Expand Achievements (`FUNC-03`)
1. **`web/src/pages/Subjects.tsx`:**
   - Import `useProject` from `../contexts/ProjectContext`.
   - Re-fetch subjects whenever `currentProjectId` changes using `apiClient.get('/subjects', { params: currentProjectId ? { projectId: currentProjectId } : undefined })`.
   - In `handleCreateSubject`, use `currentProjectId` if set (or call `createProject('My Project', 0x006874)` via `useProject()` if the user has no project yet).
2. **`web/src/pages/Dashboard.tsx`:**
   - Read `currentProjectId` from `useProject()` and pass `?projectId=${currentProjectId}` to `/stats/overview` and `/sessions?limit=5`.
   - Use `stats.todayHours` from `/stats/overview` for `"Today: X.Xh studied"`.
   - Fix the broken XP progress bar layout by placing the Level badge and XP progress bar inside a proper `flex items-center gap-4 bg-surfaceContainerHigh rounded-3xl p-6` card, and replace raw emojis (`⏱`, `📅`, `🔥`, `⭐`) with `<span className="material-symbols-rounded">` icons (`schedule`, `calendar_today`, `local_fire_department`, `military_tech`).
3. **`web/src/pages/Stats.tsx`:**
   - Read `currentProjectId` from `useProject()` and pass `projectId` to `/stats/overview`, `/stats/heatmap`, `/stats/subjects`, and the new `/stats/xp-history` endpoint.
   - Render a `Recharts` `AreaChart` / `LineChart` in the **XP Progress** card using the data returned from `/stats/xp-history` (showing the empty state only when `xpHistory.every(p => p.cumulativeXp === 0)`).
   - Fix the 12-week Activity Heatmap alignment:
     - Pad the start date backward to Monday (`(startDate.getDay() + 6) % 7` days) just like `lib/features/stats/heatmap_widget.dart`.
     - Use `grid-rows-7 grid-flow-col gap-1` on the heatmap grid container and 7 exact row labels (`['M', 'T', 'W', 'T', 'F', 'S', 'S']`) with no extra spacer `<div>`.
4. **`web/src/pages/Achievements.tsx`:**
   - Add the complete 47-achievement metadata dictionary (`achievementDescriptions`, `achievementIcons`, `achievementColors`) matching `lib/features/achievements/achievements_metadata.dart`.
   - Wrap the achievement detail dialog in `<Modal>` so keyboard focus trapping and `Escape`-to-close work consistently.
5. **Standardize Brand Title & Modals (`UIUX-03`, `UIUX-04`, `UIUX-06`):**
   - Update `web/index.html`, `Layout.tsx`, `Login.tsx`, and `Register.tsx` to use the canonical name **`StudyHabit`** and `<span className="material-symbols-rounded text-5xl text-primary">school</span>` logo.
   - Refactor `CreateSourceDialog.tsx`, `CreateSubjectDialog.tsx`, `CreateTopicDialog.tsx`, and `ManageMilestonesDialog.tsx` to wrap their content in `<Modal>`.
   - In `CreateSessionDialog.tsx`, change `plannedDuration` input `min="0"` to `min="5"`.
   - In `SubjectDetail.tsx`, make URL/video sources clickable with a protocol check (`(url.startsWith('https://') || url.startsWith('http://'))` opening in `target="_blank" rel="noopener noreferrer"`), and add chapter creation under topics + skill label selection.

#### Stage 2 Verification Commands
```bash
cd web
npm run lint
VITE_API_URL=http://localhost:3001 npm run build
node --test test/smoke.test.js
```

### Stage 3: Archive Flutter & Legacy Desktop Files

Archive the Flutter codebase cleanly into `archive/flutter-legacy/` so git history and reference code are preserved while removing Flutter from active builds.

#### Task 3.1: Move Flutter Files to `archive/flutter-legacy/`
Run the following commands from the repository root:

```bash
mkdir -p archive/flutter-legacy
git mv lib archive/flutter-legacy/
git mv test archive/flutter-legacy/
git mv windows archive/flutter-legacy/
git mv pubspec.yaml pubspec.lock analysis_options.yaml .metadata installer.iss archive/flutter-legacy/
```

### Stage 4: Full Native Kotlin + Jetpack Compose Android Rewrite (`android/`)

Replace the Flutter Android wrapper in `android/` with a pure, self-contained **Native Kotlin + Jetpack Compose + Material 3 + Room + Coroutines/Flow + Hilt/AppContainer + Retrofit/OkHttp + Android ForegroundService + Native PdfRenderer** application under package `de.schuelken.studyhabit`.

#### Why This Architecture Is Much Faster
* **Zero Engine Warmup:** Eliminates the Flutter Dart VM + Impeller engine initialization, cutting cold start time by ~60–70% and APK size by ~18 MB.
* **Direct SQLite via Room (`androidx.room`):** Compiled SQLite queries with Kotlin `Flow` emit directly to Compose state without platform-channel or Dart isolate serialization.
* **Native `PdfRenderer`:** Uses Android's built-in C++ `android.graphics.pdf.PdfRenderer` with bitmap page caching instead of the heavy Syncfusion Flutter PDF plugin.
* **Single-Process Monotonic Timer Service:** `TimerForegroundService` runs in the main Android process using `SystemClock.elapsedRealtime()` and `StateFlow`, eliminating the background isolate bridge (`flutter_foreground_task`) that caused state synchronization lag.

#### Target Directory Structure (`android/`)

```text
android/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
└── app/
    ├── build.gradle.kts
    ├── proguard-rules.pro
    └── src/
        ├── main/
        │   ├── AndroidManifest.xml
        │   ├── res/
        │   │   ├── values/strings.xml
        │   │   ├── values/themes.xml
        │   │   └── xml/network_security_config.xml
        │   └── kotlin/de/schuelken/studyhabit/
        │       ├── StudyHabitApplication.kt
        │       ├── MainActivity.kt
        │       ├── core/
        │       │   ├── di/AppContainer.kt
        │       │   ├── model/Enums.kt
        │       │   ├── database/
        │       │   │   ├── AppDatabase.kt
        │       │   │   ├── Entities.kt
        │       │   │   ├── Converters.kt
        │       │   │   ├── LegacyDatabaseMigrator.kt
        │       │   │   └── dao/
        │       │   │       ├── ProjectDao.kt
        │       │   │       ├── SubjectDao.kt
        │       │   │       ├── TopicDao.kt
        │       │   │       ├── ChapterDao.kt
        │       │   │       ├── SessionDao.kt
        │       │   │       ├── SourceDao.kt
        │       │   │       ├── SkillLabelDao.kt
        │       │   │       ├── MilestoneDao.kt
        │       │   │       ├── AchievementDao.kt
        │       │   │       └── UserStatsDao.kt
        │       │   ├── network/
        │       │   │   ├── StudyHabitApi.kt
        │       │   │   ├── NetworkModels.kt
        │       │   │   ├── TokenStorage.kt
        │       │   │   └── AuthInterceptor.kt
        │       │   ├── preferences/
        │       │   │   └── AppPreferences.kt
        │       │   ├── service/
        │       │   │   ├── XpCalculator.kt
        │       │   │   ├── StreakManager.kt
        │       │   │   ├── AchievementEvaluator.kt
        │       │   │   ├── SyncEngine.kt
        │       │   │   ├── ExportImportService.kt
        │       │   │   ├── ReminderScheduler.kt
        │       │   │   └── TimerForegroundService.kt
        │       │   └── theme/
        │       │       ├── AppTheme.kt
        │       │       └── Type.kt
        │       └── ui/
        │           ├── navigation/AppNavHost.kt
        │           ├── components/
        │           │   ├── AppShellScaffold.kt
        │           │   ├── ProjectSwitcherSheet.kt
        │           │   ├── SyncStatusIcon.kt
        │           │   ├── LevelUpDialog.kt
        │           │   └── AchievementUnlockBanner.kt
        │           ├── home/HomeScreen.kt
        │           ├── subjects/
        │           │   ├── SubjectsScreen.kt
        │           │   ├── CreateSubjectSheet.kt
        │           │   └── SubjectDetailScreen.kt
        │           ├── timer/
        │           │   ├── StartSessionSheet.kt
        │           │   ├── PomodoroScreen.kt
        │           │   ├── FreeTimerScreen.kt
        │           │   ├── SessionReviewSheet.kt
        │           │   └── PdfViewerScreen.kt
        │           ├── stats/
        │           │   ├── StatsScreen.kt
        │           │   └── HeatmapComposable.kt
        │           ├── achievements/
        │           │   ├── AchievementsMetadata.kt
        │           │   └── AchievementsScreen.kt
        │           └── settings/
        │               ├── SettingsScreen.kt
        │               ├── LoginScreen.kt
        │               ├── SyncSettingsScreen.kt
        │               ├── BatteryOptimizationScreen.kt
        │               └── DiagnosticLogsScreen.kt
        └── test/
            └── kotlin/de/schuelken/studyhabit/
                ├── XpCalculatorTest.kt
                ├── StreakManagerTest.kt
                └── AchievementEvaluatorTest.kt
```

#### Task 4.1: Configure Pure Android Gradle Files (`android/settings.gradle.kts`, `android/build.gradle.kts`, `android/app/build.gradle.kts`)

1. **`android/settings.gradle.kts`:** Remove the Flutter SDK includeBuild and `dev.flutter.flutter-plugin-loader` plugin:

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "StudyHabit"
include(":app")
```

2. **`android/build.gradle.kts`:**

```kotlin
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.0" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.1.0" apply false
    id("com.google.devtools.ksp") version "2.1.0-1.0.29" apply false
}
```

3. **`android/app/build.gradle.kts`:**

```kotlin
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.google.devtools.ksp")
}

val keystorePropertiesFile = rootProject.file("app/key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "de.schuelken.studyhabit"
    compileSdk = 35

    defaultConfig {
        applicationId = "de.schuelken.studyhabit"
        minSdk = 26
        targetSdk = 35
        versionCode = 72
        versionName = "2.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                storeType = (keystoreProperties["storeType"] as? String) ?: "pkcs12"
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")
    implementation("androidx.activity:activity-compose:1.9.3")

    // Compose UI & Material 3
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.navigation:navigation-compose:2.8.5")

    // Room SQLite Database
    val roomVersion = "2.6.1"
    implementation("androidx.room:room-runtime:$roomVersion")
    implementation("androidx.room:room-ktx:$roomVersion")
    ksp("androidx.room:room-compiler:$roomVersion")

    // Networking & Serialization
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.jakewharton.retrofit:retrofit2-kotlinx-serialization-converter:1.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    // Encrypted Token Storage & Preferences
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("androidx.work:work-runtime-ktx:2.10.0")

    // Unit Testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
}
```

#### Task 4.2: Update `AndroidManifest.xml` & `network_security_config.xml`
1. Update `android/app/src/main/AndroidManifest.xml` to remove all `io.flutter.*` and `com.pravera.flutter_foreground_task.*` metadata and register `StudyHabitApplication`, `MainActivity` (`androidx.activity.ComponentActivity`), and `de.schuelken.studyhabit.core.service.TimerForegroundService`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application
        android:name=".StudyHabitApplication"
        android:label="StudyHabit"
        android:icon="@mipmap/ic_launcher"
        android:allowBackup="false"
        android:networkSecurityConfig="@xml/network_security_config"
        android:theme="@style/NormalTheme">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <service
            android:name=".core.service.TimerForegroundService"
            android:foregroundServiceType="specialUse"
            android:exported="false"
            android:stopWithTask="false">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="@string/fgs_special_use_subtype" />
        </service>
    </application>
</manifest>
```

2. In `android/app/src/main/res/xml/network_security_config.xml`, replace `10.0.0.0` with `10.0.2.2` (standard Android emulator host loopback) alongside `localhost` and `127.0.0.1`.

#### Task 4.3: Implement the 10-Table Room Database & Legacy Drift SQLite Migration (`core/database/`)

Define the 10 entities in `Entities.kt` with exact column names matching the existing SQLite schema (`projects`, `subjects`, `topics`, `chapters`, `study_sessions`, `skill_labels`, `sources`, `achievements`, `user_stats_table`, `subject_milestones`) so existing on-device `studyhabit.sqlite` files open seamlessly or migrate without data loss:

```kotlin
package de.schuelken.studyhabit.core.database

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "projects")
data class ProjectEntity(
    @PrimaryKey val id: String,
    val name: String,
    val icon: String = "📚",
    @ColumnInfo(name = "color_value") val colorValue: Int,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "last_opened_at") val lastOpenedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_archived") val isArchived: Boolean = false,
    @ColumnInfo(name = "default_work_duration") val defaultWorkDuration: Int = 25,
    @ColumnInfo(name = "default_break_duration") val defaultBreakDuration: Int = 5,
    @ColumnInfo(name = "default_long_break_duration") val defaultLongBreakDuration: Int = 15,
    @ColumnInfo(name = "default_long_break_every") val defaultLongBreakEvery: Int = 4,
    @ColumnInfo(name = "study_reminder_minutes") val studyReminderMinutes: Int = 30,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Entity(tableName = "subjects")
data class SubjectEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "project_id") val projectId: String,
    val name: String,
    val description: String? = null,
    @ColumnInfo(name = "color_value") val colorValue: Int,
    @ColumnInfo(name = "hierarchy_mode") val hierarchyMode: String = "flat",
    @ColumnInfo(name = "default_duration_minutes") val defaultDurationMinutes: Int = 25,
    @ColumnInfo(name = "default_break_minutes") val defaultBreakMinutes: Int = 5,
    @ColumnInfo(name = "xp_total") val xpTotal: Int = 0,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "completeness_mode") val completenessMode: String = "none",
    @ColumnInfo(name = "target_hours") val targetHours: Int? = null,
    @ColumnInfo(name = "target_weekly_hours") val targetWeeklyHours: Int? = null,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Entity(tableName = "topics")
data class TopicEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "subject_id") val subjectId: String,
    val name: String,
    val order: Int = 0,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Entity(tableName = "chapters")
data class ChapterEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "topic_id") val topicId: String,
    val name: String,
    val order: Int = 0,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Entity(tableName = "study_sessions")
data class StudySessionEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "subject_id") val subjectId: String,
    @ColumnInfo(name = "topic_id") val topicId: String? = null,
    @ColumnInfo(name = "chapter_id") val chapterId: String? = null,
    @ColumnInfo(name = "started_at") val startedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "ended_at") val endedAt: Long? = null,
    @ColumnInfo(name = "planned_duration_minutes") val plannedDurationMinutes: Int = 25,
    @ColumnInfo(name = "actual_duration_minutes") val actualDurationMinutes: Int = 0,
    @ColumnInfo(name = "pomodoros_completed") val pomodorosCompleted: Int = 0,
    @ColumnInfo(name = "confidence_rating") val confidenceRating: Int? = null,
    val notes: String? = null,
    @ColumnInfo(name = "xp_earned") val xpEarned: Int = 0,
    @ColumnInfo(name = "source_id") val sourceId: String? = null,
    @ColumnInfo(name = "start_page") val startPage: Int? = null,
    @ColumnInfo(name = "end_page") val endPage: Int? = null,
    @ColumnInfo(name = "is_free_timer") val isFreeTimer: Boolean = false,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Entity(tableName = "skill_labels")
data class SkillLabelEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "subject_id") val subjectId: String,
    @ColumnInfo(name = "topic_id") val topicId: String? = null,
    @ColumnInfo(name = "chapter_id") val chapterId: String? = null,
    val label: String = "beginner",
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Entity(tableName = "sources")
data class SourceEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "subject_id") val subjectId: String,
    @ColumnInfo(name = "topic_id") val topicId: String? = null,
    @ColumnInfo(name = "chapter_id") val chapterId: String? = null,
    val type: String = "pdf",
    val title: String,
    @ColumnInfo(name = "file_path") val filePath: String? = null,
    val url: String? = null,
    @ColumnInfo(name = "current_page") val currentPage: Int? = null,
    @ColumnInfo(name = "total_pages") val totalPages: Int? = null,
    @ColumnInfo(name = "progress_percent") val progressPercent: Double? = null,
    val notes: String? = null,
    @ColumnInfo(name = "added_at") val addedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)

@Entity(tableName = "achievements")
data class AchievementEntity(
    @PrimaryKey val key: String,
    @ColumnInfo(name = "unlocked_at") val unlockedAt: Long? = null,
    val progress: Double = 0.0,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
)

@Entity(tableName = "user_stats_table")
data class UserStatsEntity(
    @PrimaryKey val id: String = "default_stats",
    @ColumnInfo(name = "total_xp") val totalXp: Int = 0,
    @ColumnInfo(name = "current_level") val currentLevel: Int = 1,
    @ColumnInfo(name = "current_streak") val currentStreak: Int = 0,
    @ColumnInfo(name = "longest_streak") val longestStreak: Int = 0,
    @ColumnInfo(name = "last_study_date") val lastStudyDate: Long? = null,
    @ColumnInfo(name = "total_study_minutes") val totalStudyMinutes: Int = 0,
    @ColumnInfo(name = "freeze_tokens") val freezeTokens: Int = 0,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
)

@Entity(tableName = "subject_milestones")
data class SubjectMilestoneEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "subject_id") val subjectId: String,
    val title: String,
    @ColumnInfo(name = "is_completed") val isCompleted: Boolean = false,
    @ColumnInfo(name = "sort_order") val sortOrder: Int = 0,
    @ColumnInfo(name = "completed_at") val completedAt: Long? = null,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_deleted") val isDeleted: Boolean = false,
)
```

#### Task 4.4: Implement Domain Services (`XpCalculator`, `StreakManager`, `AchievementEvaluator`, `SyncEngine`, `ExportImportService`)
1. **`XpCalculator.kt`:** Exact port of `XpService` (`completePomodoro = 50`, `longSession = 120`, `confidence = 10`, `addSource = 5`, `skillAdvance = 100`, `streak7/30/100 = 500`, `dailyGoal = 75`, thresholds `0, 500, 1500, 3500, 7000, 10500`, then `round((prev * 1.5) / 100) * 100`).
2. **`StreakManager.kt`:** Exact port of `StreakService` (`gracePeriodHours` offset, consecutive day increment, 2-day gap freeze token consumption with 7-day cooldown on `streak.lastFreezeUseDate`, +1 freeze token awarded every 10 streak days).
3. **`AchievementEvaluator.kt`:** Evaluates all 47 achievement keys against Room DAOs and returns newly unlocked achievement keys for `AchievementUnlockBanner`.
4. **`SyncEngine.kt`:**
   - Collects local rows modified after `sync.lastSyncedAt` (or all non-deleted rows when `lastSyncedAt == 0L`).
   - Normalizes colors (`colorValue and 0xFFFFFF` on push; `(colorValue and 0xFFFFFF) or 0xFF000000.toInt()` on pull) and timestamps (`Instant.ofEpochMilli(ms).toString()` ISO-8601 UTC).
   - Calls `POST /api/v1/sync/full?since=<ISO-8601>`.
   - Applies remote pull records using Last-Write-Wins (`serverUpdatedAt > local.updatedAt`).
   - Clears local Room tables when `sync.lastSyncedUserId != currentUserId` to prevent cross-account data bleed.
   - Enforces the import/sync settings key allowlist (`theme.*`, `pomodoro.*`, `notifications.*`, `streak.*`, `goal.*`, `active_timer_type`, `pomodoro_state_json`, `free_timer_state_json`) so `sync.serverUrl` can never be overwritten remotely or via JSON import.
5. **`TimerForegroundService.kt`:**
   - Native Android `Service` supporting both **Pomodoro** (`work`, `shortBreak`, `longBreak`, plus `continuousFocus` overtime tracking and 80%-completion XP rule) and **Free Timer** modes.
   - Uses `SystemClock.elapsedRealtime()` for drift-free timing even in Doze mode, updates the ongoing notification once per second, and persists timer state to `SharedPreferences` on start/pause/phase transition so process death recovery and startup orphan cleanup (`SessionDao.cleanupOrphanedSessions`) work identically to the legacy app.

#### Task 4.5: Implement Jetpack Compose Material 3 Screens (`ui/`)
1. **`AppTheme.kt`:**
   - Implements the 12 `presetSeeds` and 7 `curatedPalettes` (`Atmospheric Teal`, `Midnight Slate`, `Forest Sanctuary`, `Royal Plum`, `Amber Hearth`, `Vellum & Ember`, `Lumina Minimal`) plus Android 12+ Material You `dynamicDarkColorScheme` / `dynamicLightColorScheme` and user `fontScale` (`0.9f`, `1.0f`, `1.15f`).
2. **`AppNavHost.kt` & `AppShellScaffold.kt`:**
   - Bottom `NavigationBar` with 4 destinations (`Home`, `Subjects`, `Stats`, `Achievements`), top `CenterAlignedTopAppBar` with Project Switcher button, `SyncStatusIcon`, and Settings button, plus startup auto-redirect to `/subjects/{id}/session` or `/subjects/{id}/free-timer` if an active timer is running.
3. **Feature Screens:**
   - `HomeScreen.kt`: Streak & Level summary cards, Today's focus progress bar (with per-weekday goal), Recent Sessions list, and extended `Start Session` FAB opening `StartSessionSheet`.
   - `SubjectsScreen.kt` & `SubjectDetailScreen.kt`: Subject cards with completeness progress (Hours Goal, Weekly Hours Goal, Milestones), 3-tab detail view (`Timeline` grouped by date with session edit/delete, `Sources` grid with PDF/URL/Video support, `Topics` expandable hierarchy with Chapters and `SkillLabel` selector sheet).
   - `PomodoroScreen.kt` & `FreeTimerScreen.kt`: Adaptive portrait/landscape canvas timer ring with pulse animation, pause/resume/skip/stop controls, overtime counter, and `SessionReviewSheet` (1–5 star confidence rating, notes, animated XP counter, level-up & achievement unlock overlays).
   - `PdfViewerScreen.kt`: Native `android.graphics.pdf.PdfRenderer` reader with pinch-to-zoom, page indicator, and 3-second debounced `currentPage` + session `startPage`/`endPage` auto-save.
   - `StatsScreen.kt`: Overview cards, Compose `Canvas` Weekly Activity bar chart, Subject Distribution donut chart, 12-week Monday-aligned Activity Heatmap, Cumulative XP line chart, and Subject Breakdown table.
   - `AchievementsScreen.kt`: Level progress card and categorized 47-badge grid with detail modal.
   - `SettingsScreen.kt` & Sub-screens: Theme mode/style/seed/font-scale controls, per-weekday daily goal sliders, Pomodoro & notification toggles, JSON Export (via `FileProvider` + `Intent.ACTION_SEND`) and Import (`ActivityResultContracts.OpenDocument` with Merge/Replace dialog), `LoginScreen.kt` (with `http://` cleartext warning), `SyncSettingsScreen.kt` (Sync Now, Disconnect, Erase Cloud Data), `BatteryOptimizationScreen.kt` (OEM detection for Samsung/Xiaomi/Huawei/OnePlus), and `DiagnosticLogsScreen.kt`.

#### Task 4.6: Update `.github/workflows/build-apk.yml` for Pure Native Kotlin CI
Replace the Flutter CI workflow in `.github/workflows/build-apk.yml` with a fast Gradle Android build + unit test + lint + Backend/Web verification pipeline:

```yaml
name: Build & Release Android APK and Web/Backend CI

on:
  push:
    branches: [main, develop, master]
  pull_request:
    branches: [main, develop, master]

permissions:
  contents: write

concurrency:
  group: build-${{ github.ref }}
  cancel-in-progress: true

jobs:
  verify-backend-and-web:
    name: Verify Backend & Web
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
      - name: Backend Typecheck & Build
        working-directory: backend
        run: |
          npm ci
          DATABASE_URL="postgresql://mock:mock@localhost:5432/mock" npx prisma generate
          npx tsc --noEmit
          npm run build
      - name: Web Lint, Test & Build
        working-directory: web
        run: |
          npm ci
          npm run lint
          node --test test/smoke.test.js
          VITE_API_URL=https://studyhabit.schuelken.uk npm run build

  build-android:
    name: Build Native Kotlin Android APK
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: "zulu"
          java-version: "17"
      - uses: gradle/actions/setup-gradle@v4

      - name: Decode keystore from secrets
        if: ${{ secrets.KEYSTORE_BASE64 != '' }}
        working-directory: android
        env:
          KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
        run: |
          echo "$KEYSTORE_BASE64" | base64 --decode > app/release.keystore
          echo "storePassword=$KEYSTORE_PASSWORD" >> app/key.properties
          echo "keyPassword=$KEY_PASSWORD"         >> app/key.properties
          echo "keyAlias=$KEY_ALIAS"               >> app/key.properties
          echo "storeFile=release.keystore"        >> app/key.properties
          echo "storeType=pkcs12"                  >> app/key.properties

      - name: Run Unit Tests, Lint & Assemble Release APK
        working-directory: android
        run: |
          ./gradlew testDebugUnitTest lintDebug assembleRelease

      - name: Cleanup signing artifacts
        if: always()
        working-directory: android
        run: |
          rm -f app/release.keystore app/key.properties
```

#### Stage 4 Verification Commands
```bash
cd android
./gradlew testDebugUnitTest
./gradlew lintDebug
./gradlew assembleRelease
```
