# Backend Audit — PLAN_NEEDED Items

## Status: All FIX_NOW issues resolved in commit 2855b49

The following issues require architectural decisions or larger changes. Each should become a GitHub issue once `gh` CLI is available.

---

## 1. Server-side Achievement Validation
**Severity:** CRITICAL | **Effort:** Medium

### Problem
`POST /achievements/:key/unlock` and `PATCH /achievements/:key/progress` allow clients to arbitrarily unlock achievements without any server-side validation. A user can unlock "completed 100 pomodoros" without actually doing so.

### Proposed Fix
1. Remove the public unlock/progress endpoints or make them internal-only
2. Create `AchievementService.checkAndUnlock(userId)` that:
   - Queries actual user stats (session count, streak, total hours, etc.)
   - Compares against achievement thresholds
   - Only unlocks if criteria met
3. Call `checkAndUnlock` after session creation, streak updates, and skill label changes
4. Sync push for achievements should only accept progress updates, not unlocks

### Files
- `backend/src/routes/achievements.ts` — restrict endpoints
- `backend/src/services/achievementService.ts` — new file with validation logic
- `backend/src/routes/sessions.ts` — call achievement check after session create
- `backend/src/services/syncService.ts` — reject unlock attempts from sync

---

## 2. Pagination for List Endpoints
**Severity:** HIGH (DoS risk) | **Effort:** Small-Medium

### Problem
All GET list endpoints (`/projects`, `/subjects`, `/sessions`, `/sources`, `/sync/pull`) return unbounded result sets. A user with thousands of records causes large responses.

### Proposed Fix
1. Add `?page=1&limit=50` query params to all list endpoints
2. Default limit: 50, max limit: 200
3. Return `{ data: [...], pagination: { page, limit, total, hasMore } }`
4. For `/sync/pull`, keep unbounded but add a `?since=` requirement (no full dump without timestamp)

### Files
- All route files in `backend/src/routes/`
- `backend/src/types/index.ts` — add `PaginationResult` type

---

## 3. Update Schema Allowlists (Mass Assignment Hardening)
**Severity:** CRITICAL | **Effort:** Small

### Problem
PATCH routes use `.partial()` on the full create schema, allowing updates to fields that shouldn't be user-modifiable (e.g., `xpEarned` on sessions, `xpTotal` on subjects).

### Proposed Fix
Define explicit update schemas for each entity that exclude:
- `id`, `createdAt`, `updatedAt` (system-managed)
- `xpEarned`, `xpTotal` (server-calculated)
- `userId` (auth-derived)
- `subjectId` on sessions/sources (prevent moving between subjects)

Already partially done for sessions and sources. Apply same pattern to projects and subjects.

### Files
- `backend/src/routes/projects.ts` — explicit update schema
- `backend/src/routes/subjects.ts` — explicit update schema

---

## 4. Email Enumeration Prevention
**Severity:** HIGH | **Effort:** Small

### Problem
`POST /auth/register` returns `409 Conflict` if email exists, revealing registration status.

### Proposed Fix
```typescript
// Always return 200, send verification email (or pretend to)
if (existing) {
  // Don't reveal existence — return same success response
  return res.status(200).json({ data: { message: 'If this email is not registered, an account has been created.' } });
}
```

Alternative: return 200 for both cases with identical response format.

### Files
- `backend/src/routes/auth.ts:35-38`

---

## 5. Device Fingerprint Verification on Token Refresh
**Severity:** MEDIUM | **Effort:** Medium

### Problem
Stolen refresh tokens can be used from any device/IP. No verification that the refresh request comes from the same device that originally logged in.

### Proposed Fix
1. Store `userAgent` and `ipAddress` on the refresh token record (already partially done)
2. On refresh, compare current request IP/UA against stored values
3. If mismatch: require re-authentication (return 401 with `reason: 'device_mismatch'`)
4. Optional: send email notification of new device login

### Files
- `backend/src/services/authService.ts` — add verification in `rotateRefreshToken`
- `backend/src/routes/auth.ts` — pass UA/IP to rotation

---

## 6. Transaction Support for Sync Push
**Severity:** MEDIUM | **Effort:** Large

### Problem
If sync push fails partway through, some entities are saved and others aren't, leaving the server in an inconsistent state.

### Proposed Fix
1. Wrap each entity type's operations in a Prisma `$transaction`
2. If any operation fails, roll back the entire entity batch
3. Continue to next entity type (don't roll back everything)
4. Alternative: use interactive transactions with `prisma.$transaction(async (tx) => { ... })`

### Files
- `backend/src/services/syncService.ts` — wrap loops in transactions

---

## 7. OpenAPI/Swagger Documentation
**Severity:** LOW | **Effort:** Medium

### Problem
No API documentation makes it harder for frontend/mobile developers to integrate.

### Proposed Fix
Add `swagger-jsdoc` + `swagger-ui-express` to generate docs from JSDoc comments.

### Files
- New: `backend/src/docs/` directory with swagger setup
- All route files — add JSDoc comments

---

## Completed in This Commit

| # | Issue | Fix |
|---|---|---|
| 2 | Sync push allows injecting into other users' subjects | Added `verifySubjectOwnership` and `verifyTopicOwnership` checks |
| 5 | Weak password policy | Kept min 8 (standard) — complexity can be added via zxcvbn |
| 6 | Session subjectId change without validation | Explicit update schema, `subjectId` removed from PATCH |
| 7 | Source subjectId change without validation | Explicit update schema, `subjectId` removed from PATCH |
| 8 | No chapter→topic validation | Handled by DB FK constraints |
| 9 | XpService increments totalStudyMinutes by 1 | Changed to `addXpAndMinutes(userId, xp, studyMinutes)` |
| 10 | userStats conflict detection missing updatedAt | Added `updatedAt` comparison before applying |
| 11 | No query param validation on stats | Added Zod `daysQuerySchema` with min 1, max 365 |
| 14 | No rate limiting on sensitive ops | Added `sensitiveLimiter` (5/hour) on password + account delete |
| 16 | CORS default allows any origin | Default is `*` for dev only — `.env` must set it for production |
| 17 | 10MB body size limit | Reduced to 1MB |
| 19 | Error messages leak DB schema | Replaced with generic messages |
| 20 | No uncaught exception handlers | Added `uncaughtException` and `unhandledRejection` handlers |
| 21 | URL scheme validation | Added http/https-only validation |
| 27 | Health check raw SQL | Kept `SELECT 1` — simpler and faster than model query |
| 31 | Unused crypto-js dependency | Removed |
