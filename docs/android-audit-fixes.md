# Android audit fixes and blocker presets

Addresses the 31 October 2026 audit findings F01–F11 and related timer risks R01/R02.

- Pomodoro skips retain measured work, exclude breaks, and award completion only after reaching the phase target. Selected work/break durations survive phase transitions and persistence. Reviews and notification-stop saves use the work plan rather than the current break duration. Older Android versions use the compatible foreground-service overload.
- Backup documents are parsed and version-checked before import choices. Failed imports show errors; transaction rollback counts and failures after committed data are distinguished. Backup saving uses Android CreateDocument, with sharing available separately.
- Both timers adapt to landscape; Home reflows at enlarged system text sizes. The main focus action has an explicit accessible name. Theme foreground/container pairs meet the tested 4.5:1 primary text contrast target across every existing seed and curated palette.
- PDF sources require a readable PDF before saving and offer relinking when unavailable. URL sources require a supported absolute HTTP(S) URL. Invalid duration/reduction values disable saving with inline guidance.
- Both session entry points provide contextual notification permission guidance and an explicit option to continue without notifications.
- App blocker presets add all installed launcher apps, social apps, or games to the current selection, with Clear Selection and individual adjustments. Social matches use Android categories plus known packages; games use Android game metadata. Empty categories are disabled. The service retains Settings, keyboard, launcher, and own-app safety exemptions. Presets do not grant accessibility permission or enable blocking automatically.

## Verification

- Independent plan and implementation reviews: Pass.
- Android: 58 unit tests pass, debug/release APK assembly passes, lint has zero errors (36 warnings, one informational item).
- Backend: Prisma generation, TypeScript typecheck/build, and eight tests pass.
- Web: lint passes with four existing warnings, smoke test and production build pass.
- Emulator API 35: All Apps selects installed apps and Clear Selection clears them; Social Media/Games show disabled zero-count states on this stock emulator. Classification and additive selection also have regression tests.
- Emulator: early skip gives no completion credit, next focus retains 25 minutes, landscape controls remain visible, 200% Home text reflows without the former action overlap, duration 9999 shows validation and disables Save, and denied notification guidance offers continuation. Backup saving opens the document picker.

The full audit and raw device evidence remain local. Production server/folder sync, actual social/game blocking on populated physical devices, full TalkBack testing, older API runtime behavior, and a complete backup replace round trip were not certified by these checks.
