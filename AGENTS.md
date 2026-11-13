# StudyHabit

## Purpose and layout

Native Android app in `android/`, Express/Prisma backend in `backend/`, and Vite/React frontend in `web/`. Archived Flutter is not the current app.

## Working agreements

- Inspect the code and instructions first; make the smallest correct change and
  preserve unrelated staged, unstaged and untracked work. Never commit secrets.
- Plan and independently review substantial changes in proportion to their risk,
  using available tools. Make routine reversible decisions without approval loops.
- Give delegated workers a bounded scope, working directory and acceptance
  criteria. Assigned workers do not recursively delegate. Serialize shared edits
  and device control, and inspect results before integration.
- Commit, push and publish only when authorized. Report actual providers/fallbacks,
  checks performed and concrete limitations; never imply an unavailable review ran.
- Read the repository root guide when working in a subdirectory. Read
  `../AGENTS.md` for workspace publishing guidance when present; essential project
  safeguards below remain applicable without ancestor-file discovery.

## Setup and commands

From `android/` with JDK 17 and Android SDK: `./gradlew assembleDebug`. From `backend/`: `npm ci`, configure a disposable Postgres database and environment as documented, `npx prisma generate`, `npm run dev`. From `web/`: `npm ci`, `npm run dev`. Repository-root `docker compose --profile internal-db up -d db` starts the optional local database.

## Verification

From `android/`: `./gradlew testDebugUnitTest lintDebug`. From `backend/`: `npx tsc --noEmit`, `npm test`, `npm run build` (tests need their documented database). From `web/`: `npm run lint`, `node --test test/smoke.test.js`, `npm run build` (set the intended `VITE_API_URL` for deployment builds). From root for release changes: `python3 -m unittest discover -s scripts/tests -p 'test_*.py'`.

## Android QA

- For Android UI/flow changes, test relevant normal, error and persistence
  scenarios on an appropriate device when available; report blocked scenarios.
- Prefer Gemini 4 Hydrogen through Antigravity (AGY) for Android QA. Use
  GPT-6.1 Terra through Codex when working without AGY. The worker needs both
  adb shell and screenshot viewing. Report the actual provider and any fallback.
- Record device serial, API, package, build variant and source commit. Use
  `adb -s SERIAL` for device operations; inspect UI-tree bounds before taps.
- Capture screenshots and scoped logs without secrets. Report pass/fail/blocked
  outcomes with evidence. Unit tests alone do not establish emulator validation.
- Serialize shared-device control. Do not perform production actions or reset
  user data without authorization.

## Release and boundaries

Preserve signing identity, immutable stable tags and published assets. A stable release requires an explicit request; ordinary pushes authorize no stable release. Follow the repository release guide for source versions, default-branch ancestry, checks, notes and publication; monitor workflows and verify downloads before claiming success. Do not clean up releases without explicit scoped authorization. APK/AAB or metadata alone does not imply Play or F-Droid publication.

`android-release.yml` is the sole Android publisher; do not add competing publishers or automatic version-bump commits. Preserve literal source version metadata for validators and account for the final release commit in version-code allocation. Use Conventional Commits when committing.

## Sources

[README](README.md), [release guide](docs/releases/README.md), [Android workflow](.github/workflows/android-release.yml), [deployment checklist](RELEASE.md).
