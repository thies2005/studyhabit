# Security Policy & Notes

This document captures the security-relevant design decisions, residual risks,
and operational procedures for the StudyHabit app (backend, web, desktop,
mobile).

## Reporting a vulnerability

Please do not open public issues for security problems. Instead, email the
maintainer directly with details and a reproduction. Reports are acknowledged
within 72 hours.

## Authentication & token storage

**Backend:** stateless JWT access tokens (15 min expiry) + opaque refresh tokens
(7-day expiry). Refresh tokens are 64-byte random values, stored **SHA-256
hashed** in the database, rotated on every refresh, capped at 5 active devices
per user, and cleaned up by an hourly background job. Passwords are hashed with
bcrypt (cost factor 12).

**Web dashboard:** access and refresh tokens are stored in `localStorage`.
- This was a deliberate decision (no cookie/session backend coupling, simple
  PWA support) over the more secure httpOnly-cookie approach.
- The **primary mitigation** against token theft via XSS is the strict
  Content-Security-Policy served by `web/nginx.conf`: `script-src 'self'`
  with no `unsafe-inline`/`unsafe-eval`, which blocks inline script injection.
- **Residual risk:** any XSS bypass or a malicious browser extension can still
  read `localStorage`. If this becomes a concern, migrate to httpOnly cookies
  (requires backend cookie support + CSRF protection).

**Mobile / desktop:** tokens are stored in `flutter_secure_storage`
(Android Keystore `EncryptedSharedPreferences`, iOS Keychain, Windows DPAPI),
with `resetOnError` enabled on Android to recover from key invalidation.

## Secret rotation (operator action required)

The working-tree `.env` contains real operational secrets (`DB_PASSWORD`,
`JWT_SECRET`). It is `.gitignore`d and never committed, but anyone with a
checkout of this machine has live secrets. To rotate:

1. Generate new values:
   ```sh
   openssl rand -hex 32   # new JWT_SECRET
   openssl rand -hex 32   # new DB password (also set on the Postgres instance)
   ```
2. Update your secret manager / deployment environment, **not** the `.env`.
3. Restart the API. Existing refresh tokens remain valid until their 7-day
   expiry; access JWTs expire in 15 min. Users will be silently re-issued tokens
   via refresh, or asked to re-login if the refresh secret changed.
4. `JWT_REFRESH_SECRET` is no longer used by the app (refresh tokens are opaque)
   and can be removed from your environment.

## CORS

The default `CORS_ORIGIN` is an explicit allowlist (the production origin),
**not** `*`. Self-hosters should set `CORS_ORIGIN` to their exact web origin.
Auth uses `Authorization: Bearer` headers (not cookies), so CSRF is not in play.

## Self-hosting over plain HTTP

The mobile login screen allows a user-configurable server URL, including
`http://` (for LAN/local servers). When `http://` is selected, the field shows
an inline warning that credentials are sent unencrypted. The Android
`network_security_config.xml` permits cleartext **only** to `localhost` /
loopback; public hosts require HTTPS.

Importing a settings file cannot overwrite `sync.serverUrl` — setting keys are
whitelisted on import (mirroring the sync allowlist), so a crafted import file
cannot silently redirect credentials.

## Database migrations

Production runs `prisma migrate deploy` (versioned, reversible migrations in
`backend/prisma/migrations/`). Never use `prisma db push` in production — it is
non-versioned and can cause data loss.

## Windows code signing (operator action required)

The Windows executable and Inno Setup installer are **not code-signed**.
SmartScreen will flag the unsigned `.exe`, and there is no supply-chain
integrity guarantee for downloaders. To sign releases:

1. Obtain an Authenticode (OV/EV) code-signing certificate.
2. Sign `studyhabit.exe` and the installer with `signtool` in the
   `build-windows` CI job before publishing the release.
3. Consider adding an auto-updater with signature verification once signed
   builds are available.

## Foreground service (Android)

The Pomodoro timer uses a foreground service of type `specialUse` so it keeps
accurate time while backgrounded. The manifest declares
`android:foregroundServiceType="specialUse"`, the
`PROPERTY_SPECIAL_USE_FGS_SUBTYPE` justification, and the required permission.
The justification (see `android/app/src/main/res/values/strings.xml`) describes
the use case for Google Play review.

## Known follow-ups (not yet implemented)

- **Desktop timer/notifications:** on Windows, the Pomodoro timer may drift
  when the window is backgrounded for long periods, and session-complete
  notifications do not fire on desktop (the foreground-service + local
  notifications path is mobile-only). A desktop fallback ticker + toast
  notifications are planned.
- **bcryptjs:** the backend uses the pure-JS `bcryptjs` at cost 12, which is
  more CPU-DoS-prone than native `bcrypt`/`argon2`. Migration is optional and
  tracked as a low-priority item.
- **Real XP-history endpoint:** the web Stats page shows an honest empty state
  for XP progress; a per-day XP-history backend endpoint is a follow-up feature.
