# StudyHabit Android audit

**31 October 2026 · Native Android 2.0.11 (83) · commit 742a759**

## Verdict

Core offline setup, short free-timer operation, session saving, sampled statistics, and achievement unlocks work. **Fix the Pomodoro accounting and backup-import feedback before treating this build as ready for release.** An unfinished focus phase can be credited as a full Pomodoro, and an invalid backup is reported as successfully imported. The app also needs layout and accessibility work.

This audit records **11 confirmed findings: 2 P1 and 9 P2**, plus separately labeled code-review risks and follow-up opportunities. P1 means high-impact correctness/recovery failure; P2 means a meaningful functional, accessibility, or usability defect. Severity is an audit judgment, not an automated lint score. Conditional findings state their preconditions.

The current build and existing **48 unit tests passed**. Android lint completed with **0 errors, 37 warnings, and 1 informational item**. No Java/Kotlin fatal crash was captured in the cleared crash buffer during this run. Passing these checks did not prevent the runtime failures below.

## Scope and method

| Item | Audited configuration |
|---|---|
| Target | Current Kotlin/Jetpack Compose Android app under `android/`; the root README describes the older Flutter architecture |
| Package | `de.schuelken.studyhabit.debug` |
| Build | Built from the current checkout, assembled and installed over existing debug app data |
| Previous installed build | 2.0.0 (72), updated to 2.0.11 (83) for this run |
| Device | `emulator-5554`, Android SDK x86_64 emulator, Android 15 / API 35 |
| Display | 1080 × 2400 portrait, 420 dpi, approximately 411 × 914 dp; 2400 × 1080 landscape |
| Text and theme | System dark theme with teal seed, app font 1.00x; system font 1.0 and 2.0 tested |
| Network/auth | Existing test account, configured local backend `10.0.2.2:3001` unavailable; folder sync off |
| Notifications | POST_NOTIFICATIONS denied before and throughout the run |
| Evidence | 36 inspected PNGs with corresponding UI XML, action log, relevant log excerpts, unit-test XML, lint XML, and export-validation summary |
| Tools | Test Android Apps android-emulator-qa skill, adb, UI Automator, screenshot inspection, existing Gradle checks; Product Design audit checklist for visual/accessibility review |

Taps were derived from freshly dumped UI-tree bounds. Scrollable views were scrolled to inspect additional content. Screenshots were saved and opened before inclusion. Code was inspected to explain reproduced behavior, and code-only risks are separated from device-confirmed findings. No application source code was changed.

The main test data lives in **QA Audit 2026-10-31 → QA Mathematics → Algebra → Equations**. The saved free-timer test record was deliberately adjusted from a sub-minute timer to **10 minutes**, rated 5 stars, and labeled “QA audit session.” Its 10-minute total is manual test data, not a claim that a ten-minute timer ran. The inflated Pomodoro review was discarded. Existing project data was not cleared or replaced.

## Journey coverage

| Step | Flow | Health | Evidence |
|---|---|---|---|
| 1 | Launch and project switching | Pass in sampled state | 01, 02, 36 |
| 2 | Subject, topic, and chapter creation | Pass | 03–05 |
| 3 | Source creation and PDF error handling | Fail | 06–08 |
| 4 | Free timer, pause/resume, backgrounding | Pass in short test; notification gap | 09–12 |
| 5 | Review, rating, save, and timeline | Pass core save; duration validation fails | 13–16 |
| 6 | Pomodoro phases and duration accounting | Fail | 17, 32, 34, 35 |
| 7 | Statistics and achievements | Pass sampled totals/unlock; visual risks | 18–20 |
| 8 | Settings, sync, battery, blocker, diagnostics | Partial; successful server sync unavailable | 21–26 |
| 9 | Backup import/export | Fail for tested error paths | 27–29 |
| 10 | Large text and landscape | Fail | 30, 31, 33 |

## Confirmed findings

| ID | Priority | Finding |
|---|---|---|
| F01 | P1 | Skipping a focus phase invents study time and completion credit |
| F02 | P1 | An invalid backup is reported as successfully imported |
| F03 | P2 | The next Pomodoro silently loses the chosen focus duration |
| F04 | P2 | Landscape compresses timer controls into nearly invisible slivers |
| F05 | P2 | 200% system text causes clipped and overlapping Home content |
| F06 | P2 | The default teal dark theme has insufficient text contrast |
| F07 | P2 | The Home Start Focus action has no accessible name |
| F08 | P2 | Sources can be saved without a usable file or URL |
| F09 | P2 | Denied notification permission has no timer recovery flow |
| F10 | P2 | Duration input displays a different value from the value to be saved |
| F11 | P2 | Backup export has no direct save route on a device without share targets |

### F01 · P1 · Skipping a focus phase invents study time and completion credit

**Reproduce:** Start a 25-minute Pomodoro. Before the countdown finishes, tap **Skip Phase**, skip the break, then tap **Stop**. In this run the first skip happened about 4 minutes 9 seconds after starting, well short of 25 minutes.

**Observed:** The break showed “1 completed”; the review subsequently claimed **25 minutes studied** and **+50 XP**. The next work phase stayed paused, so it contributed no additional study time. The review was discarded to avoid saving fabricated time.

**Expected:** Keep the actual elapsed work time when skipping. Count a completed Pomodoro only when the completion policy is met; skipping should not pad elapsed time to the target.

**Evidence:** [17-pomodoro](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/17-pomodoro.png), [32-pomodoro-break](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/32-pomodoro-break.png), [35-pomodoro-inflated-review](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/35-pomodoro-inflated-review.png).

**Code connection:** [TimerForegroundService.kt:389](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/core/service/TimerForegroundService.kt:389). `totalElapsed.coerceAtLeast(curr.totalSeconds)` promotes a partial work phase to the entire planned duration. The same operation increments `pomodorosCompleted`. The review trusts those values.

**Recommendation and acceptance checks:** Store measured work seconds independently from planned seconds. Distinguish skipped and completed phases. Verify a skip after 1 second, after several minutes, while paused, and during overtime; none should create unearned minutes or completion XP.

### F02 · P1 · An invalid backup is reported as successfully imported

**Reproduce:** Import the supplied `checks/qa-invalid-backup.json` (contents: `{"qa_invalid_backup":true}`), and choose **Merge**.

**Observed:** The app accepted the file into the import-mode dialog, then displayed **“Imported 0 subjects and 0 sessions.”** No failure explanation appeared. The existing QA subject and session remained in the subsequent export. This run did not establish data loss.

**Expected:** Reject an incompatible backup with an explicit error and recovery guidance. A parsing or database failure must not produce a success message or trigger a success-side sync.

**Evidence:** [27-import-mode](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/27-import-mode.png), [28-import-false-success](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/28-import-false-success.png).

**Code connection:** [SettingsScreen.kt:501](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/settings/SettingsScreen.kt:501); [ExportImportService.kt:215](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/core/service/ExportImportService.kt:215). The import service catches exceptions into `ImportResult.errors`; the UI ignores that field and unconditionally constructs success text. The Replace handler has the same pattern, but Replace was not executed.

**Recommendation and acceptance checks:** Handle nonempty errors before reporting success. Validate the document/version before presenting destructive options. Check malformed JSON, missing required fields, unsupported versions, transaction failures, and a valid round trip. Verify existing data stays intact after each rejected import.

### F03 · P2 · The next Pomodoro silently loses the chosen focus duration

**Reproduce:** Use a subject/session with a 25-minute focus duration while the global focus setting is 44 minutes. Start that session, skip the focus phase, then skip the short break.

**Observed:** The initial countdown was **24:58**; the next focus phase became **44:00**, despite the subject/session selection being 25 minutes. The global setting shown in Settings was 44 minutes.

**Expected:** Use the selected session duration consistently for subsequent focus phases, or make a deliberate switch to the global setting explicit before the user starts.

**Evidence:** [17-pomodoro](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/17-pomodoro.png), [26-backup-settings](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/26-backup-settings.png), [34-pomodoro-duration-reset](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/34-pomodoro-duration-reset.png).

**Code connection:** [TimerForegroundService.kt:407](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/core/service/TimerForegroundService.kt:407). Returning from a break reads `preferences.workDuration` instead of retaining the duration supplied when the session started.

**Recommendation and acceptance checks:** Persist a session work-duration field and reuse it for every work phase and after recovery. Verify different global and subject durations, a custom start duration, natural break completion, and skipped breaks.

### F04 · P2 · Landscape compresses timer controls into nearly invisible slivers

**Reproduce:** Open the Pomodoro timer or its short-break phase and rotate the emulator to landscape at normal text size.

**Observed:** The circular timer occupies almost all available height. Stop, resume, and skip are rendered at the bottom as tiny fragments. The tree still contains wide control bounds, but the visible Stop/Skip icon bounds are only 12 px high. This is a visual usability failure; it does not prove every remaining touch target is untappable.

**Expected:** Keep every timer control fully visible and recognizable in landscape.

**Evidence:** [33-timer-landscape](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/33-timer-landscape.png).

**Code connection:** [PomodoroScreen.kt:83](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/timer/PomodoroScreen.kt:83); [PomodoroScreen.kt:114](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/timer/PomodoroScreen.kt:114). A vertical layout combines a fixed 280 dp timer with the heading, system padding, and controls. There is no landscape-specific arrangement or scrolling. The free-timer source uses a similar layout; its landscape behavior was not separately exercised.

**Recommendation and acceptance checks:** Use available-height constraints and a two-column landscape layout, or a smaller adaptive dial. Verify focus, break, overtime, long subject names, and large fonts in both orientations.

### F05 · P2 · 200% system text causes clipped and overlapping Home content

**Reproduce:** With a saved session and an active timer, set Android system font scale to 2.0 and return to Home.

**Observed:** The project name is vertically clipped; the daily-goal label collides with its value; the floating Start Focus action overlays the session XP/rating area; “Subjects” wraps as “Subject” and a separate “s.” The UI tree clips the XP text to a 13 px-high bound. Font scale was restored to 1.0 afterward.

**Expected:** Retain readable content and usable controls when users enlarge system text.

**Evidence:** [30-home-with-session](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/30-home-with-session.png), [31-home-large-text](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/31-home-large-text.png).

**Code connection:** [AppShellScaffold.kt:69](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/components/AppShellScaffold.kt:69); [HomeScreen.kt:334](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/home/HomeScreen.kt:334). The fixed-height toolbar and compact side-by-side content do not reflow sufficiently at large text sizes. The app also multiplies system font scale by its own scale, so combinations need testing.

**Recommendation and acceptance checks:** Allow a responsive project title, stack goal/session metadata when space is limited, and reserve unobscured space for the floating action. Test system 1.0/1.3/2.0 with supported in-app font settings, including long names and modal sheets.

### F06 · P2 · The default teal dark theme has insufficient text contrast

**Reproduce:** Use the system dark theme with the first teal seed. Inspect subject tabs, timer phase labels, XP values, and outlined text actions.

**Observed:** The rendered teal is **#006874**. Against the dark surface/background around **#111416 / #0F1416**, contrast is about **2.85:1**; against **#192023** cards it is about **2.54:1**. Several affected labels are normal-sized text. The same visual problem is visible in the XP banner and achievement actions.

**Expected:** Use readable dark-theme foreground colors. The usual accessibility target is at least 4.5:1 for normal text and 3:1 for large text; these measurements identify a contrast problem, not full accessibility conformance.

**Evidence:** [04-subject-detail](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/04-subject-detail.png), [13-session-review](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/13-session-review.png), [15-saved-session](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/15-saved-session.png), [20-achievements](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/20-achievements.png).

**Code connection:** [AppTheme.kt:78](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/core/theme/AppTheme.kt:78). The dark color scheme reuses the dark seed directly as `primary` instead of deriving a lighter dark-theme primary. Some foregrounds are also drawn on translucent primary containers.

**Recommendation and acceptance checks:** Generate or select tonal palettes separately for light/dark modes, and check primary/on-primary/container pairs. Measure all 12 seeds plus curated palettes, selected/unselected tabs, disabled states, charts, and focus indicators.

### F07 · P2 · The Home Start Focus action has no accessible name

**Reproduce:** Inspect the Home accessibility tree with UI Automator at normal text size; compare it with the visible screenshot.

**Observed:** The screen visibly shows “Start Focus”, but its actionable node has empty `text`, empty `content-desc`, and **NAF="true"**. Its child Button and View are also unnamed. This occurred in both the initial and populated Home captures. The subject-detail Start Focus icon is named correctly.

**Expected:** Expose an accessible name and button role for the primary Home action.

**Evidence:** [01-home](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/01-home.png), [30-home-with-session](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/30-home-with-session.png).

**Code connection:** [HomeScreen.kt:139](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/home/HomeScreen.kt:139). The ExtendedFloatingActionButton text is present visually but absent from the captured Android semantics. The exact framework/merging cause still needs investigation; the code does supply a Text composable.

**Recommendation and acceptance checks:** Repair the semantics without duplicating announcements. Verify the node name, actual TalkBack focus/activation, Switch Access, and semantics after navigation/animation. This audit confirmed the tree defect; it did not run a full TalkBack session.

### F08 · P2 · Sources can be saved without a usable file or URL

**Reproduce:** Add a source with title “QA Missing PDF” and leave File Path/URI empty. Save it, then open the new source. A URL source with “not-a-url” was also accepted during validation testing.

**Observed:** The empty PDF was saved and selectable as a study source. Opening it displayed **“PDF source or file path not found.”** No choose-file or repair action appeared. A later achievement sequence even awarded Digital Reader for this missing-file source. No external browser was opened for the malformed URL.

**Expected:** Require a readable PDF URI or a valid supported URL before saving. Offer recovery for a previously valid file that later becomes unavailable.

**Evidence:** [06-invalid-source-form](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/06-invalid-source-form.png), [07-missing-pdf](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/07-missing-pdf.png), [08-start-session](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/08-start-session.png).

**Code connection:** [SubjectDetailScreen.kt:907](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/subjects/SubjectDetailScreen.kt:907); [SubjectDetailScreen.kt:921](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/subjects/SubjectDetailScreen.kt:921). For non-Anki sources, the Add button and save path validate only the title. Blank paths and URL text are persisted without resource validation.

**Recommendation and acceptance checks:** Validate by source type, retain URI permission, show inline errors, and allow editing/relinking an unavailable source. Add Digital Reader only after a usable PDF is attached or opened, according to the intended achievement policy.

### F09 · P2 · Denied notification permission has no timer recovery flow

**Reproduce:** Leave POST_NOTIFICATIONS denied, start a timer, background the app, and expand the notification shade.

**Observed:** No StudyHabit timer notification was present. The permission state was `granted=false`, while the timer service was successfully running in the foreground. Starting the timer produced no permission request or in-app explanation. The timer itself continued during the short background test.

**Expected:** Explain the loss of notification controls/alerts and provide a permission request or a route to notification settings, while allowing a deliberate in-app-only session.

**Evidence:** [09-free-timer](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/09-free-timer.png), [11-notification-denied](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/11-notification-denied.png), [12-background-return](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/12-background-return.png).

**Code connection:** [MainActivity.kt:23](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/MainActivity.kt:23); [TimerForegroundService.kt:655](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/core/service/TimerForegroundService.kt:655). The Android manifest declares POST_NOTIFICATIONS, but the current Android Kotlin sources contain no POST_NOTIFICATIONS request flow. The foreground service can run while notification visibility is denied.

**Recommendation and acceptance checks:** Ask contextually before the first timer, distinguish denial from permanent denial, and provide a settings link. Verify API 33+, user cancellation, later revocation, lock-screen controls, and reminder behavior. Alarm delivery under Doze was not tested here.

### F10 · P2 · Duration input displays a different value from the value to be saved

**Reproduce:** Stop a session and replace Actual Duration with **9999**. Dismiss the keyboard.

**Observed:** The input still showed **9999**, while the summary and slider said **720 minutes** and the XP preview said **+1520 XP**. Save remained enabled. The value was changed to 10 before the QA session was saved, so 9999/720 was not persisted in this run.

**Expected:** Show one authoritative duration. An out-of-range entry should either be visibly corrected or rejected with a clear valid range.

**Evidence:** [14-duration-validation](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/14-duration-validation.png).

**Code connection:** [SessionReviewSheet.kt:165](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/timer/SessionReviewSheet.kt:165); [EditSessionDialog.kt:88](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/components/EditSessionDialog.kt:88). The raw digits are assigned to `minutesText`, while the numeric state is independently clamped to 1–720. Save consumes numeric state, not the displayed raw text. The edit dialog has the same source pattern; that dialog was not separately exercised.

**Recommendation and acceptance checks:** Normalize the field on validation/blur or disable saving with an error. Verify empty input, 0, 1, 720, 721, huge integers, and the Reduce by field, and confirm saved/exported duration matches the visible accepted value.

### F11 · P2 · Backup export has no direct save route on a device without share targets

**Reproduce:** On this emulator, choose Settings → Export Backup JSON.

**Observed:** The app generated a valid JSON file in its private export cache, then Android displayed **“No apps can perform this action.”** The user could not save a backup through this Settings action on the stock emulator. This is conditional on available share targets, not evidence that export fails on every phone.

**Expected:** Offer a direct document-save flow in addition to sharing. Users should be able to create a local backup using Android’s document picker.

**Evidence:** [29-export-share](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/29-export-share.png).

**Code connection:** [SettingsScreen.kt:419](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/settings/SettingsScreen.kt:419). The Settings export action only launches ACTION_SEND via a chooser. It does not use ACTION_CREATE_DOCUMENT for local saving or recover from a chooser with no compatible receiver. Sync settings has a separate “Save File...” action, but this was not exercised as a backup substitute.

**Recommendation and acceptance checks:** Add Save backup using CreateDocument, retain Share as an additional action, and report completion or failure. Verify a stock device with no receivers, picker cancellation, permission/write failure, and that a successfully saved file can be imported.

## What worked well

- The app upgraded the existing debug installation and opened its data without a captured fatal crash. This is one observed upgrade path, not a full migration certification.
- Project creation, subject creation, and three-level hierarchy creation completed through the UI. Blank names disabled the tested Create/Add actions.
- The free timer exposed labeled Stop/Pause/Resume controls and a semantic elapsed-time description. It paused at 00:21, stayed paused during a background excursion, resumed, and later showed approximately 00:38–00:39 after backgrounding.
- The 10-minute, 5-star QA record appeared in the subject timeline with its note. Home showed 10/60 minutes; Stats showed one session and 0.2h, consistent with display rounding; the Saturday chart description reported exactly ten minutes.
- The weekly chart exposes a complete spoken summary, and each heatmap cell exposes its date and study minutes. Subject color options and review stars have useful labels/roles.
- Self-Belief unlocked after the 5-star session. A discard confirmation prevented the inflated Pomodoro review from being silently lost or saved.
- Sync showed a connection failure without blocking the local study flows. This validates the displayed failure state, not successful synchronization.
- Export generated valid version-2 JSON containing the QA subject, topic, chapter, two sources, and one 10-minute/5-star session. The exported settings contained no token-named keys. The full existing-data export was not copied into this report; only aggregate validation results were retained.
- Returning to the original Exam project showed no recent sessions and 0/60 project study minutes, while global XP/streak remained visible. This is consistent with project-filtered sessions and global gamification in the sampled state.

## Additional code-review risks — not reproduced on a matching device

### R01 · Foreground-service promotion on API 29–33

[TimerForegroundService.kt:660](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/core/service/TimerForegroundService.kt:660) calls the three-argument `startForeground` with `FOREGROUND_SERVICE_TYPE_SPECIAL_USE` under an API-29 guard, while lint says this field requires API 34. The exception is caught and falls back to a normal notification. This creates a compatibility risk for timer foreground promotion on older supported Android versions. The API-35 emulator successfully promoted the service, so this is **not** a confirmed API-35 failure. Test API 26–28, 29–33, and 34+ and use version-appropriate foreground-service types.

### R02 · Session planned duration follows the current phase

[SessionReviewSheet.kt:100](/home/thies/Projects/studyhabit/android/app/src/main/kotlin/de/schuelken/studyhabit/ui/timer/SessionReviewSheet.kt:100) derives planned minutes from `timerState.totalSeconds`, which represents the currently active work/break phase. Stopping during a five-minute break can therefore use the break duration as the planned study duration; later edits use that duration for Pomodoro/XP calculations. The run verified that phase duration changes, but did not save a break-phase review and inspect its stored planned-duration field. Persist the original work plan separately and test save/edit/export from every phase.

## Smaller UX opportunities

1. **Make chart dates and scales visible.** The heatmap has weekday initials and a Less/More key, but no visible week/month headers. The weekly bars have no numeric y-axis or visible per-bar values. Existing semantic descriptions are a good base; add visual date context and a tap/focus detail view.
2. **Use readable badge names and lock states.** Several names clip at the normal size, and locked items are very dim. Let titles wrap predictably and communicate locked/progress states through text and semantics, not dimming alone. Full badge detail interaction still needs checking.
3. **Make technical help copy precise.** “Diagnostic Logs” is a metrics page rather than an event-log viewer; rename it or add exportable diagnostic events. Battery guidance says “Recommended Steps for Unknown” on this emulator and promises alarms are “never delayed or killed”; use generic device copy and avoid absolute reliability promises. “1 days” and “1 minutes studied” also need plural handling.
4. **Improve sync failure guidance.** The raw “Failed to connect to /10.0.2.2:3001” message has little recovery guidance. Retain technical details behind a disclosure and lead with what users can check and whether local data is safe to keep using.

## Verification results

Executed from `android/`:

```bash
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug --console=plain
```

| Existing test class | Tests | Failures/errors |
|---|---:|---:|
| XpAndStreakTest | 16 | 0 |
| SessionEditHelperTest | 7 | 0 |
| StreakManagerTest | 7 | 0 |
| AnkiDroidServiceTest | 10 | 0 |
| AchievementEvaluatorTest | 4 | 0 |
| XpCalculatorTest | 4 | 0 |
| **Total** | **48** | **0** |

Lint: 37 warnings and one informational item. Warning categories include 13 dependency-version notices, eight obsolete SDK checks, five unused resources, three hardcoded widget strings, two unused attributes, two modifier-parameter conventions, and one each for synchronous SharedPreferences commit, an inlined newer API, target API currency, and data extraction rules. These warnings are not all release blockers, and dependency-version notices were not independently assessed for compatibility or security. Gradle also reported deprecated features relevant to a future Gradle 9 migration.

The crash buffer was empty after the run. App logs include repeated local-server connection failures, a graphics initialization warning, and one “Skipped 51 frames” message near startup. An emulator with serial-console overhead and a debug build is insufficient for a trustworthy performance verdict; no CPU, memory, battery, startup benchmark, or jank profile is claimed.

## Recommended order of work

1. **Correct stored study accounting:** F01, F03, and R02. Add integration coverage around start → pause/skip → work/break transitions → review → save/edit/export. Check measured seconds, planned duration, completion count, and XP together.
2. **Make backup recovery trustworthy:** F02 and F11. Parse/validate before import choices, display errors, and provide direct saving. Run a complete export → fresh test install → merge/replace → compare round trip on disposable test data.
3. **Restore readable, adaptable controls:** F04–F07. Fix landscape and enlarged-text layouts, dark tonal colors, and Home action semantics; then verify with actual TalkBack and Switch Access.
4. **Close validation/permission gaps:** F08–F10 and R01. Validate usable sources and duration fields; provide contextual notification recovery; test supported Android API groups.

## Limits and follow-up matrix

| Area | What this run establishes | Still needed |
|---|---|---|
| First run/authentication | Existing installation upgraded; existing test account remained | Clean install/onboarding, registration/login validation, expiry/refresh/logout, account switching |
| Timers | Short free-timer foreground/background behavior; pause/resume; Pomodoro start/skip/review; orientation issue | Natural full focus/break/long-break expiry, overtime, lock screen, Doze, process death, reboot, long sessions, notification action tests |
| Data integrity | One manual QA record saved; counts agreed; incompatible Merge falsely reports success | Valid merge/replace round trips, duplicate IDs/conflicts, partial failures, schema migrations across supported versions, deletion/edit propagation |
| Sources | Empty-path PDF validation failure, invalid-looking URL acceptance | Real PDF selection/rendering/page restore, expired URI permission, valid web/video launch, missing handler recovery, large PDFs |
| Anki | Existing unit tests passed | AnkiDroid install/permission/deck selection/review sync on a populated device |
| App blocker | Setup screen, permission warning, installed-app list | Actual accessibility grant, blocked app launch, pause/break exclusions, permission revocation, device/OEM behavior |
| Cloud/folder sync | Local-server failure visible; offline UI remained usable | Available backend, successful upload/download, conflict/deletion/offline recovery, folder-provider round trip |
| Accessibility | Screenshot contrast, enlarged text, labels/roles and UI-tree defects | Full TalkBack, Switch Access, keyboard focus order, announcements, motion settings, all themes/languages/sizes; no compliance certification |
| Compatibility | Android 15/API 35, one emulator and two orientations | API 26 onward groups, physical/OEM phones, small/large displays, tablets, gesture navigation, light theme and all palettes |
| Security/performance | Narrow manifest/service/export source review and logs | Full security audit, backend/web audit, dependency vulnerability review, release build, formal performance profiling |

Windows, web, backend behavior, archived Flutter code, store packaging, and production deployment were outside this Android audit. Source inspection alone is not labeled as a runtime pass.

## Run state and artifacts

The current debug build remains installed. The **original Exam project is selected again**. The QA project and its clearly marked test records/sources remain available for reproducing findings; global XP/streak/achievement state includes that test session. No original project was deleted. No Replace All, Erase Cloud Data, logout, or external sharing action was executed. The inflated Pomodoro review was discarded and the final service dump showed no running StudyHabit service. System font scale was restored to 1.0; rotation was returned to sensor mode with original user rotation 0. Notification permission, configured server, account, and app-blocker permission were not changed.

- `evidence/`: inspected PNGs and UI XML; `actions.jsonl`; empty crash log and selected app-log excerpt.
- `checks/unit-tests/`: six existing JUnit XML reports and Gradle binary results.
- `checks/lint-results-debug.xml`: detailed lint output.
- `checks/qa-invalid-backup.json`: safe, schema-invalid import fixture used with Merge.
- `checks/export-validation.json`: aggregate validation of the generated backup; no token contents or full existing user export.
- `checks/run-summary.json`: build identity, test/lint totals, image counts, and APK hash.

## Screenshot walkthrough

All 36 images below were captured in this run and inspected. Numbering identifies captures, not additional test passes. The health note beside each image states what the image and associated interaction establish. HTML images can be clicked to enlarge.

### Capture 01 · Initial Home

**Needs work.** Clear empty state and navigation; primary action is visible but unnamed in the accessibility tree; teal contrast is weak.

![Capture 01: Initial Home](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/01-home.png)

### Capture 02 · Empty Subjects in the QA project

**Healthy.** The empty state explains how to add a subject; the Add Subject icon is named.

![Capture 02: Empty Subjects in the QA project](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/02-empty-subjects.png)

### Capture 03 · Create-subject form

**Healthy with risks.** Blank-name save is disabled. Fields and color options are labeled; contrast and large-font coverage remain concerns.

![Capture 03: Create-subject form](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/03-create-subject.png)

### Capture 04 · Subject detail and empty timeline

**Needs work.** Summary cards and three tabs are clear; teal tab labels have insufficient contrast.

![Capture 04: Subject detail and empty timeline](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/04-subject-detail.png)

### Capture 05 · Three-level hierarchy

**Healthy.** Created Algebra and Equations through the UI; expand/collapse has a specific accessible label.

![Capture 05: Three-level hierarchy](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/05-topics-chapters.png)

### Capture 06 · Invalid URL accepted by the form

**Needs work.** Add remains enabled for an invalid-looking URL. The missing-PDF test below gives the clearest confirmed resource-validation failure.

![Capture 06: Invalid URL accepted by the form](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/06-invalid-source-form.png)

### Capture 07 · Open the PDF saved with an empty path

**Failed.** Clear error text appears, but an unusable source was saved and the reader provides no repair action.

![Capture 07: Open the PDF saved with an empty path](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/07-missing-pdf.png)

### Capture 08 · Start-session sheet

**Mostly healthy.** Timer type, subject, topic, chapter, and optional sources are exposed; the invalid PDF also appears here.

![Capture 08: Start-session sheet](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/08-start-session.png)

### Capture 09 · Running free timer

**Healthy with notification gap.** Readable elapsed time; named Stop/Pause actions and elapsed-time semantics; no notification permission flow.

![Capture 09: Running free timer](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/09-free-timer.png)

### Capture 10 · Paused free timer

**Healthy.** Pause state and Resume action appear correctly.

![Capture 10: Paused free timer](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/10-free-paused.png)

### Capture 11 · Notification shade during the timer

**Needs work.** Only the Android system notification appears; the denied StudyHabit notification has no visible recovery guidance in the app.

![Capture 11: Notification shade during the timer](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/11-notification-denied.png)

### Capture 12 · Return after backgrounding

**Healthy for the short test.** Elapsed time advances and the timer remains active; this is not a long-duration or Doze test.

![Capture 12: Return after backgrounding](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/12-background-return.png)

### Capture 13 · Free-session review

**Mostly healthy.** Duration, notes, labeled 48 dp rating options, and save action are available; XP text contrast is weak.

![Capture 13: Free-session review](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/13-session-review.png)

### Capture 14 · Out-of-range duration

**Failed.** 9999 in the input conflicts with 720 in the summary; no validation error is shown.

![Capture 14: Out-of-range duration](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/14-duration-validation.png)

### Capture 15 · Achievement after saving

**Healthy with contrast risk.** Self-Belief unlocks after a 5-star session; the dialog action has low teal contrast.

![Capture 15: Achievement after saving](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/15-saved-session.png)

### Capture 16 · Persisted test session

**Healthy.** The manually adjusted 10-minute session and QA note appear; edit and delete actions are named. Those actions were not executed.

![Capture 16: Persisted test session](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/16-timeline.png)

### Capture 17 · Initial Pomodoro

**Mostly healthy.** The selected 25-minute countdown starts; Stop, Pause, and Skip are named. No natural expiry was awaited.

![Capture 17: Initial Pomodoro](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/17-pomodoro.png)

### Capture 18 · Statistics summary and heatmap

**Healthy with presentation risks.** One session and 0.2h match the 10-minute test record after rounding. Weekly chart and each heatmap day have accessible descriptions.

![Capture 18: Statistics summary and heatmap](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/18-statistics.png)

### Capture 19 · Statistics after scrolling

**Healthy.** QA Mathematics is listed with 10 XP and 0.2h. The heatmap lacks visible date headers for visual date lookup.

![Capture 19: Statistics after scrolling](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/19-statistics-breakdown.png)

### Capture 20 · Badge catalog

**Mostly healthy.** Badge catalog and categories render. Several long names are visually clipped and locked text is dim; full catalog interaction was not tested.

![Capture 20: Badge catalog](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/20-achievements.png)

### Capture 21 · Settings overview

**Mostly healthy.** Settings grouping is clear, and the unavailable local server is reported. Technical exception wording could be clearer.

![Capture 21: Settings overview](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/21-settings.png)

### Capture 22 · Sync account/server state

**Blocked for successful sync.** Existing test account and local URL are visible. Connection failure is displayed. Login, successful sync, and conflict handling were not exercised.

![Capture 22: Sync account/server state](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/22-sync-settings.png)

### Capture 23 · Battery guidance

**Setup reviewed only.** Status and system-settings action are clear. The “Unknown” manufacturer label and “never delayed” promise should be softened; actual Doze behavior is unverified.

![Capture 23: Battery guidance](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/23-battery.png)

### Capture 24 · App-blocker setup

**Setup reviewed only.** Permission warning, app search, and app list are visible. Accessibility permission was not enabled and actual blocking was not tested.

![Capture 24: App-blocker setup](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/24-app-blocker.png)

### Capture 25 · Diagnostics screen

**Healthy for metrics.** Current version and database counts are visible without exposing token contents. The page contains metrics rather than diagnostic event logs.

![Capture 25: Diagnostics screen](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/25-diagnostics.png)

### Capture 26 · Backup controls and timer preferences

**Needs work.** Global focus is 44 minutes. Backup actions are discoverable, but their failure cases below need attention.

![Capture 26: Backup controls and timer preferences](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/26-backup-settings.png)

### Capture 27 · Import mode for invalid JSON schema

**Needs work.** An incompatible document reaches the Merge/Replace choice before validation; only Merge was executed.

![Capture 27: Import mode for invalid JSON schema](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/27-import-mode.png)

### Capture 28 · Failed import reported as success

**Failed.** The incompatible document produces “Imported 0 subjects and 0 sessions” instead of a parsing/schema error.

![Capture 28: Failed import reported as success](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/28-import-false-success.png)

### Capture 29 · Export on a stock emulator

**Failed in this environment.** The generated file is valid, but the share chooser has no receiver and offers no local-save path.

![Capture 29: Export on a stock emulator](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/29-export-share.png)

### Capture 30 · Populated Home at normal font size

**Mostly healthy.** Saved session, daily-goal minutes, and active-timer return card are coherent; the main action remains unnamed.

![Capture 30: Populated Home at normal font size](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/30-home-with-session.png)

### Capture 31 · Home at 200% system text

**Failed.** Project title clipping, goal-label collisions, floating-action overlap, and broken navigation wrapping are visible.

![Capture 31: Home at 200% system text](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/31-home-large-text.png)

### Capture 32 · Skip unfinished focus into break

**Failed for accounting.** The phase changes to a paused five-minute break, but incorrectly claims one completed Pomodoro.

![Capture 32: Skip unfinished focus into break](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/32-pomodoro-break.png)

### Capture 33 · Timer in landscape

**Failed visually.** Timer dial dominates the viewport and control icons are reduced to slivers; no scrolling recovery is offered.

![Capture 33: Timer in landscape](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/33-timer-landscape.png)

### Capture 34 · Skip break back to focus

**Failed.** The chosen 25-minute focus duration becomes the global 44-minute duration.

![Capture 34: Skip break back to focus](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/34-pomodoro-duration-reset.png)

### Capture 35 · Review after skipping

**Failed.** After roughly four minutes of focus, review claims 25 minutes and +50 XP. Discarded rather than saved.

![Capture 35: Review after skipping](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/35-pomodoro-inflated-review.png)

### Capture 36 · Return to the original Exam project

**Healthy for sampled isolation.** Exam has no recent sessions and 0/60 project minutes; global XP/streak persists. Original active project restored; no timer service remains.

![Capture 36: Return to the original Exam project](/home/thies/Projects/studyhabit/audit/android-2026-10-31/evidence/36-project-isolation.png)

