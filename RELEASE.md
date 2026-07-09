# Release Checklist

Pre-flight checks before publishing a StudyHabit release (Android APK + Windows
installer + backend + web).

## Backend

- [ ] `cd backend && npx tsc --noEmit` passes.
- [ ] `cd backend && npm run build` succeeds.
- [ ] `npx prisma migrate deploy` applies cleanly against a **fresh** database
      (verifies the migration history in `backend/prisma/migrations/`).
- [ ] `npx prisma migrate status` shows no pending/drifted migrations on the
      production DB.
- [ ] Secrets (`DB_PASSWORD`, `JWT_SECRET`) sourced from the secret manager —
      not from a checked-out `.env`. See `SECURITY.md`.
- [ ] `CORS_ORIGIN` set to the production web origin (not `*`).
- [ ] `npm audit --production` reviewed for new advisories.

## Web

- [ ] `cd web && npm run lint` passes.
- [ ] `cd web && VITE_API_URL=<prod url> npm run build` succeeds.
      (A production build **fails** if `VITE_API_URL` is unset — this is
      intentional, to avoid shipping a SPA that points at localhost.)
- [ ] Keyboard-only walkthrough of dashboard / subjects / settings / a modal
      (Tab, Shift+Tab, Escape on open dialog).
- [ ] axe-core browser check on the main pages.

## Android

- [ ] `flutter analyze` passes.
- [ ] `flutter build apk --release` produces a signed APK.
- [ ] Foreground service (Pomodoro timer) survives backgrounding on Android 14+.
- [ ] A crafted settings-import JSON that sets `sync.serverUrl` is **rejected**
      (import key whitelist).

## Windows

- [ ] `flutter build windows --release` succeeds.
- [ ] Window title is "Study Habit" and cannot be resized below 450×600.
- [ ] **Code-sign** `studyhabit.exe` and the Inno Setup installer with an
      Authenticode certificate (currently a TODO — see `SECURITY.md`). Unsigned
      builds trigger SmartScreen.
- [ ] `installer.iss` `AppVersion` matches `pubspec.yaml` (CI does this
      automatically; verify for manual builds).

## CI

- [ ] The version-bump commit does **not** force-push (no `--force`).
- [ ] Android and Windows jobs report the same `versionCode`.
- [ ] `flutter analyze` passes in CI without the removed `sed custom_lint` step.

## Post-release

- [ ] GitHub Release created with both artifacts.
- [ ] If secrets were rotated, confirm refresh-token flow still works.
