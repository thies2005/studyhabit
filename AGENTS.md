# StudyTracker — OpenCode Master Prompt
<!-- 
  HOW TO USE THIS FILE:
  1. Place this file at: <project-root>/AGENTS.md
  2. Place the agent markdown files (below) in: <project-root>/.opencode/agents/
  3. Open opencode in the project root
  4. The orchestrator primary agent reads AGENTS.md automatically
  5. Start with: "Implement StudyTracker — begin Phase 1"
  6. The orchestrator spawns implementation and review subagents per phase automatically
-->

---

## ORCHESTRATOR RULES (Primary Agent — Build Mode)

You are the **StudyTracker Orchestrator**. Your job is to implement a Flutter study tracking app
in 7 sequential phases. For each phase:

1. **Spawn** `@implementor` subagent with the phase task from this file
2. **Wait** for implementor to complete and report back
3. **Spawn** `@reviewer` subagent to validate correctness of what was just built
4. **Read** the reviewer report. If critical issues exist, re-spawn `@implementor` with fixes
5. **Write** a `PHASE_N_HANDOFF.md` summary of completed files and exported symbols
6. **Move** to the next phase only when reviewer gives green light

Never write Flutter code yourself. Delegate all implementation to `@implementor`.
Never review code yourself. Delegate all reviews to `@reviewer`.
Keep your own context lean — summarize, delegate, verify, proceed.

### Context7 Rule (Mandatory for all agents)
Every implementor subagent session MUST begin with:
```
use context7 to load: Flutter docs, Riverpod 3 docs from riverpod.dev,
Drift docs, and go_router docs before writing any code
```
Context7 resolves by library name — it will return the latest available docs.
Each phase section below lists specific libraries to query.

### Phase Gate Criteria
A phase is complete when `@reviewer` confirms:
- [ ] `flutter analyze` returns zero errors
- [ ] All specified files exist with correct class/function names
- [ ] All providers are using Riverpod 3 `@riverpod` code-gen (no manual `Provider()`)
- [ ] No hardcoded colors — only `Theme.of(context).colorScheme.*`
- [ ] Material 3 widgets only — no deprecated Material 2 widgets

---

## STACK VERSIONS (all agents use these exact versions)

```yaml
# pubspec.yaml — exact versions
environment:
  sdk: '>=3.9.0 <4.0.0'
  flutter: '>=3.35.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^3.2.1
  riverpod_annotation: ^3.2.1

  # Database
  drift: ^2.32.1
  drift_flutter: ^0.2.8
  sqlite3_flutter_libs: ^0.5.0

  # Serialization
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0

  # Navigation
  go_router: ^17.1.0

  # PDF
  syncfusion_flutter_pdfviewer: ^31.2.0

  # Charts
  fl_chart: ^1.2.0

  # Theming
  dynamic_color: ^1.7.0
  google_fonts: ^6.2.0
  flex_color_picker: ^3.5.0

  # Files
  file_picker: ^8.1.0
  share_plus: ^10.0.0
  path_provider: ^2.1.0

  # Timer / Notifications
  flutter_local_notifications: ^17.2.0
  flutter_foreground_task: ^8.17.0

  # Animations
  confetti: ^0.7.0

  # Utils
  uuid: ^4.4.0
  intl: ^0.19.0
  shared_preferences: ^2.3.0

dev_dependencies:
  build_runner: ^2.4.0
  drift_dev: ^2.32.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  riverpod_generator: ^3.2.1
  riverpod_lint: ^4.0.0
  flutter_lints: ^4.0.0
```

---

## CANONICAL DATA MODELS (reference for all phases)

```dart
// ALL IDs are String (UUIDv4 via uuid package)
// ALL models use @freezed with fromJson/toJson
// ALL enums are lowercase snake_case in JSON

enum HierarchyMode { flat, twoLevel, threeLevel }
enum SkillLevel { beginner, intermediate, advanced, expert }
enum SourceType { pdf, url, videoUrl }
enum TimerPhase { idle, work, shortBreak, longBreak }
enum ImportMode { merge, replace }

class Project {
  String id; String name; String icon; int colorValue;
  DateTime createdAt; DateTime lastOpenedAt; bool isArchived;
}

class Subject {
  String id; String projectId; String name; String? description;
  int colorValue; HierarchyMode hierarchyMode;
  int defaultDurationMinutes; // default 25
  int defaultBreakMinutes;    // default 5
  int xpTotal; DateTime createdAt;
}

class Topic { String id; String subjectId; String name; int order; }
class Chapter { String id; String topicId; String name; int order; }

class StudySession {
  String id; String subjectId; String? topicId; String? chapterId;
  DateTime startedAt; DateTime? endedAt;
  int plannedDurationMinutes; int actualDurationMinutes;
  int pomodorosCompleted; int? confidenceRating; // 1-5
  String? notes; int xpEarned;
}

class SkillLabel {
  String id; String subjectId; String? topicId; String? chapterId;
  SkillLevel label; DateTime updatedAt;
}

class Source {
  String id; String subjectId; String? topicId; String? chapterId;
  SourceType type; String title; String? filePath; String? url;
  int? currentPage; int? totalPages; double? progressPercent;
  String? notes; DateTime addedAt;
}

class Achievement { String key; DateTime? unlockedAt; double progress; }

class UserStats {
  int totalXp; int currentLevel; int currentStreak; int longestStreak;
  DateTime? lastStudyDate; int totalStudyMinutes; int freezeTokens;
}
```

---

## XP & GAMIFICATION RULES (reference for all phases)

### XP Table
| Trigger | XP |
|---|---|
| Complete 1 Pomodoro (25 min work block) | +50 |
| Complete long session (50+ min actual) | +120 |
| Rate session confidence (any star) | +10 |
| Add a source/document | +5 |
| Advance skill label upward | +100 |
| Hit 7-day streak | +500 |
| Hit 30-day streak | +500 |
| Hit 100-day streak | +500 |

### Level System
```
Level 1=0xp  Level 2=500  Level 3=1500  Level 4=3500  Level 5=7000
Level 6+ : threshold(n) = round(threshold(n-1) * 1.5 / 100) * 100
Names: Novice → Apprentice → Scholar → Adept → Expert → Master → Grandmaster
```

### Streak Rules
- Increments if ≥1 Pomodoro completed on a calendar day
- Grace window: configurable 0–4h past midnight (default 2h), stored in SharedPreferences
- Freeze token: 1 earned per 10-day streak, max 1 use/week

### Achievement Keys
```
streak_3, streak_7, streak_30, streak_100
pomodoro_10, pomodoro_100, pomodoro_500
hours_10, hours_100, subject_5h, subject_10h
first_pdf, confidence_5, skill_advanced, all_badges
```

---

## PROJECT FOLDER STRUCTURE (create on Phase 1)

```
studytracker/
├── AGENTS.md                          ← this file
├── .opencode/agents/                  ← agent markdown files
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── database/
│   │   │   ├── app_database.dart      ← Drift AppDatabase
│   │   │   ├── app_database.g.dart    ← generated
│   │   │   └── daos/
│   │   │       ├── project_dao.dart
│   │   │       ├── subject_dao.dart
│   │   │       ├── session_dao.dart
│   │   │       ├── source_dao.dart
│   │   │       └── stats_dao.dart
│   │   ├── models/                    ← Freezed classes (one file per model)
│   │   ├── providers/
│   │   │   ├── database_provider.dart
│   │   │   ├── theme_provider.dart
│   │   │   └── user_stats_provider.dart
│   │   ├── services/
│   │   │   ├── pomodoro_service.dart
│   │   │   ├── xp_service.dart
│   │   │   ├── streak_service.dart
│   │   │   ├── achievement_service.dart
│   │   │   ├── export_service.dart
│   │   │   ├── import_service.dart
│   │   │   └── sync_service.dart      ← no-op stub in Phase 1
│   │   ├── router/
│   │   │   └── app_router.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   ├── features/
│   │   ├── home/
│   │   ├── projects/
│   │   ├── subjects/
│   │   │   ├── list/
│   │   │   └── detail/
│   │   │       ├── timeline/
│   │   │       ├── sources/
│   │   │       └── topics/
│   │   ├── pomodoro/
│   │   ├── stats/
│   │   ├── achievements/
│   │   └── settings/
│   └── shared/widgets/
├── backend/                           ← Phase 7 only
├── web/                               ← Phase 7 only
├── docker-compose.yml                 ← Phase 7 only
└── .env.example                       ← Phase 7 only
```

---

# PHASE 1 — Foundation: DB, Theme, Navigation Shell

## Implementor Task

**Context7**: load Flutter, Riverpod 3, Drift, go_router docs

Build the project foundation. No real UI content — stub screens only.

### 1. pubspec.yaml
Create with exact versions from Stack Versions section.

### 2. Drift Database (`lib/core/database/app_database.dart`)
Define Drift table classes for all 9 entities from Data Models:
`Projects`, `Subjects`, `Topics`, `Chapters`, `StudySessions`,
`SkillLabels`, `Sources`, `Achievements`, `UserStatsTable`.

Rules:
- All ID columns: `TextColumn` named `id` (UUIDv4 strings)
- All DateTime: `DateTimeColumn` with `withDefault(currentDateAndTime)`
- Nullable fields use `.nullable()`
- Enums stored as `TextColumn` with `map(EnumTypeConverter(...))`
- `@DriftDatabase(tables: [all tables])` on AppDatabase class

DAOs (one file each in `lib/core/database/daos/`):
- `ProjectDao`: `watchAll()→Stream`, `getById()`, `upsert()`, `softDelete()`
- `SubjectDao`: `watchByProject(projectId)`, `getById()`, `upsert()`, `delete()`
- `SessionDao`: `watchBySubject(subjectId)`, `insert()`, `update()`
- `SourceDao`: `watchBySubject(subjectId)`, `upsert()`, `updateProgress()`, `delete()`
- `StatsDao`: `getStats()→Future<UserStatsData?>`, `upsertStats()`, `initStats()`

### 3. Freezed Domain Models (`lib/core/models/`)
One file per model. Use `@freezed` with `copyWith`, `fromJson`, `toJson`.
Files: `project.dart`, `subject.dart`, `topic.dart`, `chapter.dart`,
`study_session.dart`, `skill_label.dart`, `source.dart`,
`achievement.dart`, `user_stats.dart`

Also create `lib/core/models/enums.dart` with all 5 enums.

### 4. Core Providers (`lib/core/providers/`)

```dart
// database_provider.dart
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) => AppDatabase();

// user_stats_provider.dart
@Riverpod(keepAlive: true)
class UserStatsNotifier extends _$UserStatsNotifier {
  // Wraps StatsDao, exposes UserStats stream
  // initStats() on first run
}

// theme_provider.dart
@Riverpod(keepAlive: true)
class ThemeSettings extends _$ThemeSettings {
  // Persists to SharedPreferences
  // Fields: seedColorIndex (int, 0-11), themeMode (ThemeMode)
  // Methods: setSeedColor(int), setThemeMode(ThemeMode)
}
```

### 5. Theme (`lib/core/theme/app_theme.dart`)

```dart
class AppTheme {
  static const List<Color> presetSeeds = [
    Color(0xFF006874), // Deep Teal — DEFAULT
    Color(0xFF6750A4), Color(0xFF0061A4), Color(0xFF006E1C),
    Color(0xFFB3261E), Color(0xFF984061), Color(0xFFAC3306),
    Color(0xFF7B5800), Color(0xFF386667), Color(0xFF343DFF),
    Color(0xFF1B6B46), Color(0xFF4A4458),
  ];

  static ThemeData light(Color seed) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
    textTheme: _buildTextTheme(),
  );

  static ThemeData dark(Color seed) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
    textTheme: _buildTextTheme(),
  );

  static TextTheme _buildTextTheme() => GoogleFonts.dmSansTextTheme().copyWith(
    displayLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
    displayMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
    displaySmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
    headlineLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
    headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
  );
}
```

### 6. Router (`lib/core/router/app_router.dart`)
go_router 17 with `StatefulShellRoute.indexedStack`:
- `/home` → `HomeScreen`
- `/subjects` → `SubjectsScreen`
- `/stats` → `StatsScreen`
- `/achievements` → `AchievementsScreen`

Named push routes (outside shell):
- `/subjects/:subjectId` → `SubjectDetailScreen`
- `/subjects/:subjectId/session` → `PomodoroScreen`
- `/subjects/:subjectId/pdf/:sourceId` → `PdfViewerScreen`
- `/settings` → `SettingsScreen`

### 7. App Shell (`lib/app.dart`, `lib/main.dart`)

`main.dart`: ProviderScope → runApp(StudyTrackerApp())
`app.dart`: Consumer with ThemeSettings + DynamicColorBuilder wrapping MaterialApp.router

Bottom navigation: Material 3 `NavigationBar` with 4 destinations:
🏠 Home | 📚 Subjects | 📊 Stats | 🏆 Achievements

AppBar: title "StudyTracker", leading `IconButton` (projects icon) → stub bottom sheet,
trailing `IconButton` (settings icon) → pushNamed('/settings')

All 4 tab screens show: `Center(child: Text('Phase 1 — {ScreenName}'))` stubs.

### Run after implementation
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
```
Report `flutter analyze` output.

## Reviewer Checklist — Phase 1
```
[ ] pubspec.yaml has all packages with correct versions
[ ] AppDatabase compiles — all 9 tables defined
[ ] All 5 DAOs exist with correct method signatures
[ ] All 9 Freezed models exist with fromJson/toJson
[ ] All enums defined in enums.dart
[ ] ThemeSettings provider persists to SharedPreferences
[ ] AppTheme has 12 preset seed colors
[ ] go_router 17 StatefulShellRoute with 4 branches
[ ] DynamicColorBuilder wraps MaterialApp.router
[ ] flutter analyze: zero errors
[ ] build_runner completes without errors
```

---

# PHASE 2 — Projects, Subjects, Hierarchy System

## Implementor Task

**Context7**: load Flutter Material 3 BottomSheet, NavigationBar, Riverpod 3 AsyncNotifier

Prerequisite: `PHASE_1_HANDOFF.md` exists and Phase 1 review passed.

### 1. Project Providers (`lib/features/projects/`)

```dart
@riverpod
Stream<List<Project>> projectList(Ref ref)  // watchAll from ProjectDao
@riverpod
class ProjectNotifier extends _$ProjectNotifier {
  Future<void> create(String name, String icon, int colorValue)
  Future<void> switchProject(String id)  // updates lastOpenedAt
  Future<void> archive(String id)
}
// lastOpenedProjectProvider — returns Project? with latest lastOpenedAt
@riverpod
Future<Project?> lastOpenedProject(Ref ref)
```

### 2. Project Switcher Bottom Sheet (`lib/features/projects/project_switcher_sheet.dart`)
- `showModalBottomSheet` with `DraggableScrollableSheet`
- Lists all non-archived projects as `ListTile`s with emoji icon + color dot
- Active project has `ListTile(selected: true)`
- Swipe-to-archive via `Dismissible` widget
- FAB inside sheet: "New Project" → `CreateProjectDialog`

### 3. Create Project Dialog (`lib/features/projects/create_project_dialog.dart`)
- `AlertDialog` with 3 fields:
  - Name: `TextField`
  - Icon: horizontal scroll of emoji options (study-themed: 📚🎯🔬💻🎨🏋️📐🎵🌍)
  - Color: `Wrap` of 12 color circles from `AppTheme.presetSeeds`
- Creates project and immediately switches to it

### 4. Subject Providers (`lib/features/subjects/`)

```dart
@riverpod
Stream<List<Subject>> subjectList(Ref ref, String projectId)
@riverpod
class SubjectNotifier extends _$SubjectNotifier {
  Future<void> create({required String name, String? description,
    required int colorValue, required HierarchyMode mode,
    required int defaultDuration, required int defaultBreak})
  Future<void> update(Subject updated)
  Future<void> delete(String id)
}
@riverpod
Future<SubjectStats> subjectStats(Ref ref, String subjectId)
// SubjectStats: totalHours, sessionCount, avgConfidence, currentSkillLevel
```

### 5. Subjects List Screen (`lib/features/subjects/list/subjects_screen.dart`)
- `StreamBuilder` over `subjectListProvider(currentProjectId)`
- Each subject → `SubjectCard` widget:
  ```
  ┌──────────────────────────────────────────┐
  │ [COLOR STRIPE] 📚 Flutter Development    │
  │               ★ Intermediate  •  8.5h   │
  │               Level 4  •  1,240 XP      │
  └──────────────────────────────────────────┘
  ```
  - Color stripe: 4px left border using subject `colorValue` as seed → `ColorScheme.fromSeed(...).primary`
  - Skill badge: chip with color (Beginner=blue, Intermediate=amber, Advanced=deepOrange, Expert=red)
  - Tap → `context.push('/subjects/${subject.id}')`
  
- FAB → `CreateSubjectBottomSheet` (multi-step):
  - Step 1: Name + Description (TextField x2)
  - Step 2: Color picker (12 circles from AppTheme.presetSeeds)
  - Step 3: HierarchyMode selector — 3 option cards with tree diagram preview:
    - Flat: `Subject → Sessions`
    - 2-Level: `Subject → Topic → Sessions`
    - 3-Level: `Subject → Topic → Chapter → Sessions`
  - Step 4: Duration sliders (Work: 5-90min, Break: 1-30min)
  - Bottom: Back / Next / Create buttons

### 6. Subject Detail Screen (`lib/features/subjects/detail/subject_detail_screen.dart`)
- `NestedScrollView` with `SliverAppBar` (expandable, shows subject color gradient)
- `DefaultTabController` with tabs:
  - **Timeline** (always)
  - **Sources** (always)
  - **Topics** (hidden if `subject.hierarchyMode == HierarchyMode.flat`)
- Header content: subject name, total hours chip, XP chip, skill level chip (tappable)

### 7. Skill Label Bottom Sheet (`lib/features/subjects/detail/skill_label_sheet.dart`)
- 4 `RadioListTile`s: Beginner / Intermediate / Advanced / Expert
- Each shows color swatch + description ("Basic understanding", "Can apply concepts", etc.)
- On confirm + upward change: `xpService.award(XpReason.skillAdvance)` + achievement check

### 8. Topics Tab (`lib/features/subjects/detail/topics/topics_tab.dart`)
- `ListView` of `TopicExpansionTile`s
- Each `TopicExpansionTile`:
  - Header: topic name, skill label chip, hours badge
  - Expanded (3-level only): list of `ChapterListTile`s
  - Long-press: rename/delete context menu
- FAB (visible only on Topics tab): `AddTopicDialog`

### 9. Topic & Chapter Providers
```dart
@riverpod
Stream<List<Topic>> topicList(Ref ref, String subjectId)
@riverpod
Stream<List<Chapter>> chapterList(Ref ref, String topicId)
@riverpod
class TopicNotifier extends _$TopicNotifier  // CRUD
@riverpod
class ChapterNotifier extends _$ChapterNotifier  // CRUD
```

## Reviewer Checklist — Phase 2
```
[ ] Project switcher bottom sheet opens from AppBar leading button
[ ] Auto-selects lastOpenedProject on app start
[ ] CreateProjectDialog creates and switches project
[ ] SubjectCard shows color stripe, skill badge, hours, XP
[ ] CreateSubjectBottomSheet has all 4 steps with back/next navigation
[ ] SubjectDetailScreen has SliverAppBar with color gradient
[ ] Topics tab is hidden when hierarchyMode == flat
[ ] SkillLabelSheet awards XP on upward change
[ ] TopicExpansionTile shows chapters when hierarchyMode == threeLevel
[ ] flutter analyze: zero errors
```

---

# PHASE 3 — Pomodoro Timer & Session Flow

## Implementor Task

**Context7**: load flutter_foreground_task TaskHandler API, Flutter AnimationController, CustomPainter

Prerequisite: `PHASE_2_HANDOFF.md` exists and Phase 2 review passed.

### 1. Pomodoro State & Notifier

```dart
// lib/features/pomodoro/pomodoro_state.dart
@freezed
class PomodoroState {
  const factory PomodoroState({
    required TimerPhase phase,
    required int remainingSeconds,
    required int totalSeconds,
    required int pomodorosCompleted,
    required bool isRunning,
    String? activeSessionId,
    required String subjectId,
    String? topicId,
    String? chapterId,
    required int plannedDurationMinutes,
    required int breakDurationMinutes,
    required int longBreakDurationMinutes,
    required int longBreakEvery,
  }) = _PomodoroState;
}

// lib/features/pomodoro/pomodoro_notifier.dart
@riverpod
class PomodoroNotifier extends _$PomodoroNotifier {
  // start(PomodoroConfig config) — creates session in DB, starts foreground task
  // pause() / resume()
  // stop() — finalizes session in DB, returns completed session
  // skipBreak() — jumps to next work phase
  // _onTick() — called by foreground task via SendPort
  // _onPomodoroComplete() — awards XP, saves partial session record
}
```

### 2. Foreground Service (`lib/features/pomodoro/pomodoro_task_handler.dart`)
Implements `flutter_foreground_task` `TaskHandler`:
```dart
class PomodoroTaskHandler extends TaskHandler {
  int _remaining = 0;
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _remaining = await FlutterForegroundTask.getData<int>(key: 'remaining') ?? 0;
  }
  @override
  void onRepeatEvent(DateTime timestamp) {
    _remaining--;
    FlutterForegroundTask.updateService(
      notificationTitle: _formatNotifTitle(),
      notificationText: '${_formatTime(_remaining)} remaining',
    );
    FlutterForegroundTask.sendDataToMain(_remaining);
    if (_remaining <= 0) FlutterForegroundTask.sendDataToMain('PHASE_COMPLETE');
  }
}
```
Register in `AndroidManifest.xml`. Notification channel: "Pomodoro Timer".

### 3. Start Session Sheet (`lib/features/pomodoro/start_session_sheet.dart`)
Full-height `DraggableScrollableSheet`, 4 steps:
1. **Subject picker** — `ListView` of subjects for current project
2. **Topic picker** (skip if flat) — dropdown with inline "＋ New topic"
3. **Chapter picker** (skip if flat/2-level) — same pattern
4. **Duration config**:
   - Work: `Slider` 5–90 min, value display
   - Short break: `Slider` 1–30 min
   - Long break every N: `Slider` 2–8
   Pre-filled from subject defaults.
"Start" button → `pomodoroNotifier.start(config)`, navigate to `/subjects/:id/session`

### 4. Pomodoro Screen (`lib/features/pomodoro/pomodoro_screen.dart`)

```dart
// Full-screen, WillPopScope prevents accidental exit
// Background: ColorScheme.fromSeed(subjectColor).surface

// Animated arc ring (CustomPainter):
class TimerRingPainter extends CustomPainter {
  final double progress; // 0.0-1.0
  final Color arcColor;
  final Color trackColor;
  @override
  void paint(Canvas canvas, Size size) {
    // Track arc (full circle, trackColor, strokeWidth: 12)
    // Progress arc (from -π/2, sweepAngle: 2π * progress, arcColor, strokeWidth: 12)
    // Subtle glow: same arc drawn twice with lower opacity and wider stroke
  }
}
```

Layout (centered column):
```
[Breadcrumb: Subject > Topic > Chapter]  ← small text
[Phase label: "Focus" / "Short Break" / "Long Break"]
[Animated ring 280px diameter]
  [MM:SS counter inside ring — large display font]
[Pomodoro dots: row of filled/empty circles]
[Start/Pause | Stop | Skip Break buttons]
```

Pulse animation: `AnimationController` repeating scale 1.0→1.02→1.0 on ring while running.

### 5. Session Review Bottom Sheet (`lib/features/pomodoro/session_review_sheet.dart`)
Auto-shown when session ends (stop or final Pomodoro):
```
"Session Complete! 🎉"
[Duration: 25 min   Pomodoros: 1]
[Confidence rating: 5 interactive stars]
  → on tap: xpService.award(XpReason.confidence) once
[Notes: TextField, optional]
[XP Earned: +60 XP ← AnimatedCounter from 0]
[Achievement unlock cards if any — AnimatedList]
[Done button → save, pop, trigger confetti if level-up]
```

`AnimatedCounter` widget: uses `Tween<int>` with `CurvedAnimation` to count up over 800ms.

### 6. Achievement Service (`lib/core/services/achievement_service.dart`)
Called after every session save and XP award:
```dart
class AchievementService {
  Future<List<Achievement>> checkAndUnlock(Ref ref) async {
    final stats = await ref.read(userStatsNotifierProvider.future);
    final sessions = await ref.read(/* total session count */);
    final newlyUnlocked = <Achievement>[];
    // Check each key: streak_3, streak_7, pomodoro_10, hours_10, etc.
    // For each: if progress reaches 1.0 and unlockedAt == null → unlock + award XP
    return newlyUnlocked;
  }
}
```

### 7. XP Service (finalized, `lib/core/services/xp_service.dart`)
```dart
class XpService {
  Future<void> award(Ref ref, XpReason reason) async {
    final xp = _xpForReason(reason);
    await ref.read(userStatsNotifierProvider.notifier).addXp(xp);
    await ref.read(achievementServiceProvider).checkAndUnlock(ref);
  }
  int calculateLevel(int totalXp) { /* level formula */ }
  int xpToNextLevel(int totalXp) { /* returns XP needed */ }
  String levelName(int level) { /* Novice...Grandmaster */ }
  int _xpForReason(XpReason reason) { /* lookup table */ }
}
```

### 8. Streak Service (finalized, `lib/core/services/streak_service.dart`)
```dart
class StreakService {
  Future<void> recordStudyDay(Ref ref) async {
    // Read lastStudyDate, graceWindowHours from SharedPreferences
    // Determine if today is new, continuation, or broken
    // Update streak, check for freeze token award (every 10 days)
    // Check streak milestones (7, 30, 100) → award XP
    // Write back to UserStats
  }
}
```

### 9. Level-Up Overlay (`lib/shared/widgets/level_up_overlay.dart`)
```dart
// Shown as overlay over current screen after session review
// ConfettiWidget at top
// AnimatedContainer sliding up: "Level Up! You are now a Scholar"
// Auto-dismiss after 4 seconds with fade-out
```

## Reviewer Checklist — Phase 3
```
[ ] Foreground service keeps timer running when app is backgrounded
[ ] AndroidManifest.xml has FOREGROUND_SERVICE permission
[ ] PomodoroState is Freezed with all required fields
[ ] Animated ring draws correct progress arc
[ ] Pomodoro dots update as Pomodoros complete
[ ] Session Review bottom sheet shows after stop/completion
[ ] Confidence stars award XP exactly once
[ ] AnimatedCounter counts up from 0 on session review
[ ] AchievementService checks all 15 achievement keys
[ ] XpService level formula matches spec
[ ] StreakService handles grace window correctly
[ ] flutter analyze: zero errors
```

---

# PHASE 4 — Subject Detail: Timeline & Sources Tabs

## Implementor Task

**Context7**: load syncfusion_flutter_pdfviewer API, Flutter SliverList/AnimatedList, file_picker API

Prerequisite: `PHASE_3_HANDOFF.md` exists and Phase 3 review passed.

### 1. Timeline Tab (`lib/features/subjects/detail/timeline/timeline_tab.dart`)

Provider:
```dart
@riverpod
Stream<Map<DateTime, List<StudySession>>> sessionsByDate(Ref ref, String subjectId)
// Groups sessions by calendar date, sorted descending
```

UI: `CustomScrollView` with:
- `SliverPersistentHeader` for sticky date labels
- `SliverList` of `SessionCard` widgets

`SessionCard` widget (collapsible via `AnimatedCrossFade`):
```
COLLAPSED:
┌────────────────────────────────────────────┐
│ ⏱ 25 min  ★★★★☆  +50 XP  [Intermediate]  │
└────────────────────────────────────────────┘

EXPANDED (tap to toggle):
┌────────────────────────────────────────────┐
│ ⏱ 25 min  ★★★★☆  +50 XP  [Intermediate]  │
├────────────────────────────────────────────┤
│ 📚 Flutter Dev > State Management          │  ← hidden if flat
│ 📝 "Finished Riverpod 3 intro chapter"     │  ← hidden if notes == null
│ 🎯 Skill at session: Intermediate          │
└────────────────────────────────────────────┘
```
- Long-press → `showDialog` "Delete session?" with confirmation
- Date header format: "Today", "Yesterday", "Mon Apr 7" etc.
- Confidence stars shown as read-only `Row` of `Icon(Icons.star, size: 14)`
- If `confidenceRating == null`: show "Not rated" in muted text

### 2. Sources Tab (`lib/features/subjects/detail/sources/sources_tab.dart`)

Provider:
```dart
@riverpod
Stream<List<Source>> sourceList(Ref ref, String subjectId)
@riverpod
class SourceNotifier extends _$SourceNotifier {
  Future<void> addPdf(String subjectId, String? topicId, String? chapterId,
                       String title, String filePath, int totalPages)
  Future<void> addUrl(String subjectId, String? topicId, String? chapterId,
                       SourceType type, String title, String url)
  Future<void> updateProgress(String id, {int? currentPage, double? progressPercent})
  Future<void> delete(String id)
}
```

`LayoutBuilder` responsive grid:
- Phone (< 600px): 2-column `GridView`
- Tablet (≥ 600px): 3-column `GridView`

`PdfSourceCard`:
```
┌───────────────────┐
│  [PDF ICON]       │
│  Title (2 lines)  │
│  ▓▓▓▓░░░░  24/312│
└───────────────────┘
```
- `LinearProgressIndicator(value: source.currentPage! / source.totalPages!)`
- Background: `ColorScheme.surfaceVariant`
- Tap → `context.push('/subjects/$subjectId/pdf/${source.id}')`

`UrlSourceCard` / `VideoSourceCard`:
- Show URL favicon placeholder (first letter of domain in colored circle)
- Title + domain
- `Slider(value: progressPercent)` → on change: `sourceNotifier.updateProgress()`
- External icon button → `launchUrl(Uri.parse(source.url!))`

`AddSourceBottomSheet`:
- `SegmentedButton` type picker: PDF / URL / Video URL
- PDF branch: `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'])`
  Auto-detect totalPages using `PdfDocument` from syncfusion
- URL/Video branch: URL `TextField` + title `TextField`
- Optional topic/chapter pickers (shown based on subject's hierarchyMode)
- "Add" button → calls appropriate `SourceNotifier` method + awards +5 XP

FAB in Sources tab → `AddSourceBottomSheet`

### 3. PDF Viewer Screen (`lib/features/pomodoro/pdf_viewer_screen.dart`)

```dart
class PdfViewerScreen extends ConsumerStatefulWidget {
  final String subjectId;
  final String sourceId;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  late final SfPdfViewerController _controller;
  Timer? _debounce;

  void _onPageChanged(PdfPageChangedDetails details) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      ref.read(sourceNotifierProvider.notifier).updateProgress(
        widget.sourceId,
        currentPage: details.newPageNumber,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(sourceByIdProvider(widget.sourceId));
    return Scaffold(
      appBar: AppBar(
        title: Text(source.title),
        actions: [
          Text('${source.currentPage ?? 1} / ${source.totalPages ?? 1}'),
        ],
      ),
      body: SfPdfViewer.file(
        File(source.filePath!),
        controller: _controller,
        initialPageNumber: source.currentPage ?? 1,
        onPageChanged: _onPageChanged,
      ),
    );
  }

  @override
  void dispose() {
    // Save final page position
    final page = _controller.pageNumber;
    ref.read(sourceNotifierProvider.notifier)
        .updateProgress(widget.sourceId, currentPage: page);
    super.dispose();
  }
}
```

Add `sourceByIdProvider`:
```dart
@riverpod
Future<Source> sourceById(Ref ref, String sourceId)
```

## Reviewer Checklist — Phase 4
```
[ ] SessionCard collapses/expands correctly with AnimatedCrossFade
[ ] Sessions grouped by date with sticky "Today"/"Yesterday" headers
[ ] Long-press delete shows confirmation dialog
[ ] Sources grid is 2-col on phone, 3-col on tablet
[ ] PdfSourceCard shows LinearProgressIndicator with page numbers
[ ] UrlCard manual progress slider saves to DB
[ ] AddSourceBottomSheet file picker opens for PDF
[ ] PDF total pages auto-detected on import
[ ] PdfViewerScreen opens at saved page position
[ ] Page changes saved with 3-second debounce
[ ] +5 XP awarded when source added
[ ] flutter analyze: zero errors
```

---

# PHASE 5 — Stats Screen & Achievements Screen

## Implementor Task

**Context7**: load fl_chart BarChart, PieChart, LineChart APIs, Flutter CustomPainter for heatmap

Prerequisite: `PHASE_4_HANDOFF.md` exists and Phase 4 review passed.

### 1. Stats Providers (`lib/features/stats/stats_providers.dart`)

```dart
@freezed
class StatsOverview {
  const factory StatsOverview({
    required double totalHours,
    required double weekHours,
    required int currentStreak,
    required int totalXp,
    required int currentLevel,
    required String levelName,
  }) = _StatsOverview;
}

@freezed
class DailyActivity {
  const factory DailyActivity({
    required DateTime date,
    required double hours,
  }) = _DailyActivity;
}

@freezed
class SubjectTime {
  const factory SubjectTime({
    required Subject subject,
    required double hours,
    required double percentage,
  }) = _SubjectTime;
}

@freezed
class HeatmapDay {
  const factory HeatmapDay({
    required DateTime date,
    required int minutes,
  }) = _HeatmapDay;
}

@riverpod
Future<StatsOverview> statsOverview(Ref ref)

@riverpod
Future<List<DailyActivity>> weeklyActivity(Ref ref) // last 7 days

@riverpod
Future<List<SubjectTime>> subjectDistribution(Ref ref, int days)

@riverpod
Future<List<HeatmapDay>> heatmapData(Ref ref) // last 84 days (12 weeks)

@riverpod
Future<List<SubjectBreakdown>> subjectBreakdown(Ref ref)
// SubjectBreakdown: subject, totalHours, sessionCount, avgConfidence, skillLevel
```

### 2. Stats Screen (`lib/features/stats/stats_screen.dart`)

`CustomScrollView` with `SliverPadding` sections:

**Overview Cards** — `GridView` 2x2:
- "Total Hours" `totalHours.toStringAsFixed(1)`
- "This Week" `weekHours.toStringAsFixed(1)h`  
- "Streak 🔥" `${currentStreak}d`
- "Level" badge with level name

**Weekly Bar Chart** (fl_chart `BarChart`):
- Last 7 days, x-axis: Mon/Tue/.../Sun labels
- Bar color: `colorScheme.primary`
- Tap bar: `BarTouchData` tooltip showing exact minutes
- y-axis: 0 to max hours, 4 grid lines

**Subject Pie Chart** (fl_chart `PieChart`):
- Sections colored by `ColorScheme.fromSeed(subject.colorValue).primary`
- Center hole radius: 60
- `PieTouchData` shows subject name + % on tap
- Legend below: horizontal scroll of color chips + labels

**XP Line Chart** (fl_chart `LineChart`):
- Last 30 days cumulative XP
- `LineChartBarData(gradient: LinearGradient([colorScheme.primary, colorScheme.tertiary]))`
- `belowBarData` fill with `colorScheme.primaryContainer` at 30% opacity
- Smooth curve: `isCurved: true, curveSmoothness: 0.3`

**Activity Heatmap** (`StudyHeatmap` custom widget):
```dart
class StudyHeatmap extends StatelessWidget {
  // 12-week grid, 7 days tall
  // Each cell: 12x12 rounded square
  // Color based on minutes:
  //   0 min     → colorScheme.surfaceVariant
  //   1-29 min  → colorScheme.primary.withOpacity(0.25)
  //   30-59 min → colorScheme.primary.withOpacity(0.5)
  //   60-119min → colorScheme.primary.withOpacity(0.75)
  //   120+ min  → colorScheme.primary
  // Tooltip on tap: "Apr 8: 45 min"
  // Week day labels on left: M T W T F S S
  // Month labels on top: Jan Feb ...
}
```

**Subject Breakdown Table**:
`DataTable` with columns: Subject | Hours | Sessions | Avg★ | Skill
- Each row: colored dot + name | hours | count | star rating | skill chip
- Sortable by hours (default desc)

### 3. Achievements Screen (`lib/features/achievements/achievements_screen.dart`)

Provider:
```dart
@riverpod
Future<List<Achievement>> achievementList(Ref ref)
// Returns all achievement keys with progress and unlock status
```

**Level Card** at top:
```dart
Card(
  child: Column(children: [
    Text(levelName, style: displayMedium),    // e.g. "Scholar"
    Text('Level $currentLevel'),
    LinearProgressIndicator(value: xpProgress), // xp in current level / xp needed
    Text('$currentXpInLevel / $xpForNextLevel XP'),
  ])
)
```

**Badge Grid** (`GridView.builder`, 3 columns):
Each `AchievementBadge`:
- **Unlocked**: full-color icon (use `Icons.*` themed to subject), name, formatted date
- **Locked**: `ColorFiltered(colorFilter: grayscale)` icon, name, `LinearProgressIndicator`
- Tap → `showModalBottomSheet` with:
  - Achievement icon (large, 64px)
  - Title + full description
  - Progress bar + "X / Y" text
  - Unlock date (if unlocked)

Achievement icon mapping (use Icons from material):
```dart
const achievementIcons = {
  'streak_3': Icons.local_fire_department,
  'streak_7': Icons.whatshot,
  'streak_30': Icons.bolt,
  'streak_100': Icons.military_tech,
  'pomodoro_10': Icons.timer,
  'pomodoro_100': Icons.alarm_on,
  'pomodoro_500': Icons.av_timer,
  'hours_10': Icons.schedule,
  'hours_100': Icons.history_edu,
  'subject_5h': Icons.auto_stories,
  'subject_10h': Icons.menu_book,
  'first_pdf': Icons.picture_as_pdf,
  'confidence_5': Icons.star,
  'skill_advanced': Icons.trending_up,
  'all_badges': Icons.emoji_events,
};
```

### 4. Achievement Unlock Widget (reusable, `lib/shared/widgets/achievement_unlock_card.dart`)
Used from Phase 3's session review:
```dart
// Slide-up AnimatedPositioned card
// Shows: icon (48px) + title + description
// Shimmer glow effect: Container with gradient border
// Auto-dismiss after 3 seconds
// Also callable standalone: AchievementUnlockCard.show(context, achievement)
```

## Reviewer Checklist — Phase 5
```
[ ] StatsOverview shows 4 correct cards
[ ] Weekly bar chart renders last 7 days with tap tooltips
[ ] Pie chart colored by subject seed color
[ ] XP line chart has gradient fill below line
[ ] Heatmap shows 12x7 grid with 5 intensity levels
[ ] Heatmap cells show tooltip on tap
[ ] Achievements screen shows level card with XP progress
[ ] Badge grid: unlocked = color, locked = grayscale + progress bar
[ ] Tap badge → detail bottom sheet
[ ] AchievementUnlockCard auto-dismisses after 3s
[ ] flutter analyze: zero errors
```

---

# PHASE 6 — Settings, Export/Import, Home Screen Finalization

## Implementor Task

**Context7**: load SharedPreferences API, Dart json_serializable, share_plus API, file_picker API

Prerequisite: `PHASE_5_HANDOFF.md` exists and Phase 5 review passed.

### 1. Settings Screen (`lib/features/settings/settings_screen.dart`)

Use `ListView` with `Card`-wrapped `ListTile` groups:

**Appearance Card**:
- Theme mode: `SegmentedButton<ThemeMode>` — System / Light / Dark
- Seed color: `Wrap` of 12 circles + "Custom..." opens `ColorPicker` from flex_color_picker
- Font scale: `SegmentedButton` — Small (0.9) / Normal (1.0) / Large (1.15)

**Pomodoro Card**:
- Work duration: `ListTile` with `Slider(min:5, max:90)` + value label
- Short break: `Slider(min:1, max:30)`
- Long break: `Slider(min:5, max:60)`
- Long break every: `Slider(min:2, max:8)` (shows as "Every 4 Pomodoros")
- Auto-start breaks: `SwitchListTile`
- Vibration on complete: `SwitchListTile`

**Notifications Card**:
- Enable notifications: `SwitchListTile`

**Streak Card**:
- Grace period: `ListTile` with `Slider(min:0, max:4)` step 0.5h
- Freeze tokens available: `ListTile(trailing: Chip(label: Text('$n tokens')))`

**Data Card**:
- Export: `ListTile(leading: Icon(Icons.upload), title: Text('Export All Data'))`
  → `exportService.exportToJson()` → `Share.shareXFiles([XFile(file.path)])`
  → show `SnackBar('Export ready!')` on success
- Import: `ListTile(leading: Icon(Icons.download), title: Text('Import Data'))`
  → file picker → `showDialog` with `ImportModeDialog` (Merge / Replace)
  → import → show result dialog: "Imported 3 projects, 12 subjects, 47 sessions"
- Clear all: `ListTile(leading: Icon(Icons.delete_forever, color: errorColor))`
  → double confirmation: first AlertDialog "Are you sure?" then second "This cannot be undone. Type DELETE to confirm" with TextField

**Phase 2 Card** (disabled/grayed):
```dart
Card(
  color: colorScheme.surfaceVariant.withOpacity(0.5),
  child: ListTile(
    enabled: false,
    leading: const Icon(Icons.cloud_sync),
    title: const Text('Connect to Server'),
    subtitle: const Text('Sync across devices — Phase 7'),
    trailing: Chip(
      label: Text('Coming Soon'),
      backgroundColor: colorScheme.secondaryContainer,
    ),
  ),
)
```

### 2. Export Service (`lib/core/services/export_service.dart`)

```dart
// ExportDocument Freezed model:
@freezed
class ExportDocument {
  const factory ExportDocument({
    required int exportVersion,       // 1
    required String exportedAt,       // ISO8601
    required UserStats userStats,
    required List<ExportProject> projects,
    required List<Achievement> achievements,
  }) = _ExportDocument;
}

@freezed
class ExportProject {
  const factory ExportProject({
    required Project project,
    required List<ExportSubject> subjects,
  }) = _ExportProject;
}

@freezed
class ExportSubject {
  const factory ExportSubject({
    required Subject subject,
    required List<Topic> topics,
    required List<Chapter> chapters,
    required List<StudySession> sessions,
    required List<Source> sources,    // filePath included, no PDF bytes
    required List<SkillLabel> skillLabels,
  }) = _ExportSubject;
}

class ExportService {
  Future<File> exportToJson() async {
    // 1. Query all data via DAOs
    // 2. Build ExportDocument
    // 3. Write to path: getTemporaryDirectory()/studytracker_YYYYMMDD_HHmmss.json
    // 4. Return file
  }
}
```

### 3. Import Service (`lib/core/services/import_service.dart`)

```dart
@freezed
class ImportResult {
  const factory ImportResult({
    required int projectCount,
    required int subjectCount,
    required int sessionCount,
    required int sourceCount,
    required List<String> errors,
  }) = _ImportResult;
}

class ImportService {
  Future<ImportResult> importFromJson(File file, ImportMode mode) async {
    // 1. Read and parse JSON → ExportDocument
    // 2. Validate exportVersion == 1
    // 3. if mode == replace: clear all tables (in correct FK order)
    // 4. Upsert all entities (in correct FK order: projects→subjects→topics→chapters→sessions)
    // 5. Return ImportResult
  }
}
```

### 4. Home Screen (finalized, `lib/features/home/home_screen.dart`)

`CustomScrollView`:

**Header Section** (SliverToBoxAdapter):
```
┌────────────────────────────────────────────┐
│  🔥 12-day streak      Level 4 — Adept     │
│  [XP bar: ████████░░░░  1,240 / 1,500]     │
│  Today: 1.5h studied                       │
└────────────────────────────────────────────┘
```
- Streak chip: `Chip(avatar: Icon(Icons.local_fire_department), label: Text('$streak days'))`
- Level badge: `Chip` with level name
- XP bar: `AnimatedProgressBar` (custom widget using `TweenAnimationBuilder`)
- Today's hours: computed from today's sessions

**Start Session FAB** (large, centered):
```dart
FloatingActionButton.extended(
  onPressed: () => showModalBottomSheet(context: context, builder: (_) => StartSessionSheet()),
  icon: Icon(Icons.play_arrow),
  label: Text('Start Session'),
)
```

**Recent Sessions** (SliverList, last 3):
Compact `SessionCard` showing: subject name (colored dot) | duration | confidence stars
Tap → navigate to subject detail timeline tab.

**Empty State** (shown if no sessions ever):
```dart
Center(child: Column(children: [
  Icon(Icons.school_outlined, size: 64, color: colorScheme.primary),
  Text("Let's start learning!", style: headlineMedium),
  Text("Tap the button below to begin your first session"),
]))
```

### 5. App-wide Animations

`AnimatedProgressBar` widget (`lib/shared/widgets/animated_progress_bar.dart`):
```dart
class AnimatedProgressBar extends StatelessWidget {
  final double value; // 0.0-1.0
  // Uses TweenAnimationBuilder<double> with 600ms ease-out curve
  // Renders LinearProgressIndicator with animated value
}
```

`AnimatedCounter` widget (`lib/shared/widgets/animated_counter.dart`):
```dart
class AnimatedCounter extends StatelessWidget {
  final int value;
  final String prefix; // e.g. "+"
  final String suffix; // e.g. " XP"
  // TweenAnimationBuilder<int>, 800ms, easeOut
}
```

## Reviewer Checklist — Phase 6
```
[ ] Settings: theme mode SegmentedButton updates app theme live
[ ] Settings: seed color picker opens ColorPicker dialog
[ ] Settings: all Pomodoro sliders have correct min/max and show value
[ ] Settings: font scale actually applies via MediaQuery.textScaleFactorOf
[ ] Export: produces valid JSON file, opens share sheet
[ ] Export: warning shown that PDFs are not bundled
[ ] Import: Merge mode doesn't duplicate existing sessions by ID
[ ] Import: Replace mode shows double-confirmation with "DELETE" field
[ ] Import: result dialog shows exact counts
[ ] Home screen: XP bar animates on load
[ ] Home screen: recent sessions list shows last 3
[ ] Home screen: empty state shown with no sessions
[ ] AnimatedProgressBar and AnimatedCounter widgets exist and are used
[ ] Phase 2 card is visible but disabled in Settings
[ ] flutter analyze: zero errors
```

---

# PHASE 7 — Backend Scaffold (Phase 2 Foundation)

## Implementor Task

**Context7**: load Express + TypeScript patterns, Prisma ORM docs, Docker multi-stage build, React + Vite + TypeScript setup

Prerequisite: `PHASE_6_HANDOFF.md` exists and Phase 6 review passed.
This phase builds the OPTIONAL backend. Flutter app must continue to work without it.

### 1. Backend: Node.js + Express + TypeScript (`backend/`)

`backend/package.json` dependencies:
```json
{
  "dependencies": {
    "express": "^5.0.0",
    "@prisma/client": "^6.x",
    "bcryptjs": "^2.x",
    "jsonwebtoken": "^9.x",
    "zod": "^3.x",
    "cors": "^2.x",
    "helmet": "^8.x",
    "morgan": "^1.x"
  },
  "devDependencies": {
    "typescript": "^5.x",
    "prisma": "^6.x",
    "@types/express": "^5.x",
    "@types/bcryptjs": "^2.x",
    "@types/jsonwebtoken": "^9.x",
    "tsx": "^4.x",
    "tsup": "^8.x"
  }
}
```

`backend/src/` structure:
```
index.ts           # express app, middleware chain, listen
config.ts          # zod env validation: DATABASE_URL, JWT_SECRET, JWT_REFRESH_SECRET, PORT
middleware/
  auth.ts          # verifyJwt middleware — attaches req.user
  errorHandler.ts  # global error handler
  validate.ts      # zod request validation middleware factory
routes/
  auth.ts          # POST /register, /login, /refresh, /logout
  projects.ts      # GET/POST/PATCH/:id/DELETE/:id
  subjects.ts      # GET/POST/PATCH/:id/DELETE/:id  (scoped to project)
  sessions.ts      # GET/POST/PATCH/:id/DELETE/:id  (scoped to subject)
  sources.ts       # GET/POST/PATCH/:id/DELETE/:id
  stats.ts         # GET /overview, /heatmap?days=84, /subjects?days=30
  achievements.ts  # GET list, POST /:key/unlock
services/
  authService.ts   # register, login, refreshToken (bcrypt + jwt)
  xpService.ts     # mirrors Flutter XP logic — called from session routes
  syncService.ts   # last-write-wins upsert helper by updatedAt
prisma/
  schema.prisma    # full schema
```

### 2. Prisma Schema (`backend/prisma/schema.prisma`)

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id           String    @id @default(uuid())
  email        String    @unique
  passwordHash String
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt
  projects     Project[]
}

model Project {
  id           String    @id @default(uuid())
  userId       String
  user         User      @relation(fields: [userId], references: [id])
  name         String
  icon         String    @default("📚")
  colorValue   Int
  createdAt    DateTime  @default(now())
  lastOpenedAt DateTime  @default(now())
  isArchived   Boolean   @default(false)
  updatedAt    DateTime  @updatedAt
  subjects     Subject[]
}

model Subject {
  id                     String        @id @default(uuid())
  projectId              String
  project                Project       @relation(...)
  name                   String
  description            String?
  colorValue             Int
  hierarchyMode          String        @default("flat")
  defaultDurationMinutes Int           @default(25)
  defaultBreakMinutes    Int           @default(5)
  xpTotal                Int           @default(0)
  createdAt              DateTime      @default(now())
  updatedAt              DateTime      @updatedAt
  topics                 Topic[]
  sessions               StudySession[]
  sources                Source[]
  skillLabels            SkillLabel[]
}

// Topic, Chapter, StudySession, Source, SkillLabel, Achievement, UserStats
// — mirror Flutter data models exactly, all with userId or parent FK
// — all with updatedAt DateTime @updatedAt for sync conflict resolution
```

### 3. REST API Contract (`/api/v1/`)

All routes require `Authorization: Bearer <token>` except `/auth/*`.
Standard response shape:
```typescript
// Success: { data: T, message?: string }
// Error:   { error: string, details?: ZodIssue[] }
```

Key routes:
```
POST   /api/v1/auth/register        body: { email, password }
POST   /api/v1/auth/login           body: { email, password }  → { accessToken, refreshToken }
POST   /api/v1/auth/refresh         body: { refreshToken }     → { accessToken }

GET    /api/v1/projects             → Project[]
POST   /api/v1/projects             body: Project (sans id/userId)
PATCH  /api/v1/projects/:id         body: Partial<Project>
DELETE /api/v1/projects/:id

GET    /api/v1/projects/:id/subjects
POST   /api/v1/projects/:id/subjects
# ... full CRUD for all entities

GET    /api/v1/stats/overview
GET    /api/v1/stats/heatmap?days=84
GET    /api/v1/stats/subjects?days=30
```

### 4. Docker Setup

`backend/Dockerfile` (multi-stage):
```dockerfile
FROM node:22-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:22-alpine AS build
WORKDIR /app
COPY . .
COPY --from=deps /app/node_modules ./node_modules
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY prisma ./prisma
RUN npx prisma generate
EXPOSE 3001
CMD ["node", "dist/index.js"]
```

`docker-compose.yml` (Coolify-compatible, repo root):
```yaml
version: '3.9'
services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: studytracker
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s retries: 5 timeout: 5s

  api:
    build: ./backend
    restart: unless-stopped
    ports:
      - "${API_PORT:-3001}:3001"
    environment:
      DATABASE_URL: postgres://${DB_USER}:${DB_PASSWORD}@db:5432/studytracker
      JWT_SECRET: ${JWT_SECRET}
      JWT_REFRESH_SECRET: ${JWT_REFRESH_SECRET}
      NODE_ENV: production
    depends_on:
      db:
        condition: service_healthy
    command: >
      sh -c "npx prisma migrate deploy && node dist/index.js"

  web:
    build: ./web
    restart: unless-stopped
    ports:
      - "${WEB_PORT:-3000}:80"
    environment:
      VITE_API_URL: ${API_URL}
    depends_on:
      - api

volumes:
  pgdata:
```

`.env.example`:
```
DB_USER=studytracker
DB_PASSWORD=changeme_strong_password_here
JWT_SECRET=changeme_min64chars_random_hex_string
JWT_REFRESH_SECRET=changeme_different_min64chars_random_hex
API_URL=https://api.yourdomain.com
API_PORT=3001
WEB_PORT=3000
```

### 5. Flutter Sync Integration

`lib/core/services/sync_service.dart` — activate Phase 2:
```dart
abstract class SyncService {
  Future<void> syncPending();
  Stream<SyncStatus> get syncStatus;
}

enum SyncStatus { idle, syncing, synced, error }

// Phase 1 (current):
class NoOpSyncService implements SyncService {
  @override Future<void> syncPending() async {}
  @override Stream<SyncStatus> get syncStatus => Stream.value(SyncStatus.idle);
}

// Phase 2 (activate when backend enabled):
class HttpSyncService implements SyncService {
  // Reads from `pending_sync_ops` Drift table
  // POSTs/PATCHes each op to /api/v1/
  // 409 conflict → last-write-wins by updatedAt
  // On 2xx → mark op as synced
  // Sync status chip in AppBar: ✓ synced | ⟳ syncing | ○ offline
}

// Provider switches based on settings:
@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  final isEnabled = ref.watch(backendEnabledProvider);
  return isEnabled ? HttpSyncService(ref) : NoOpSyncService();
}
```

Add `pending_sync_ops` Drift table:
```dart
class PendingSyncOps extends Table {
  TextColumn get id => text()();
  TextColumn get entity => text()();      // 'session', 'subject', etc.
  TextColumn get operation => text()();   // 'create', 'update', 'delete'
  TextColumn get payload => text()();     // JSON string
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}
```

### 6. React Web Dashboard (`web/`)

```
web/
├── index.html
├── vite.config.ts
├── tailwind.config.ts
├── src/
│   ├── main.tsx
│   ├── App.tsx              # React Router v7 routes
│   ├── api/
│   │   ├── client.ts        # axios instance with JWT interceptor
│   │   └── hooks.ts         # React Query / SWR hooks
│   ├── pages/
│   │   ├── Login.tsx        # email + password form, JWT storage
│   │   ├── Dashboard.tsx    # streak, XP bar, today sessions, start session button
│   │   ├── Subjects.tsx     # subject list → subject detail
│   │   ├── SubjectDetail.tsx# timeline + sources (no PDF viewer, just metadata)
│   │   ├── Stats.tsx        # Recharts: bar, pie, line, heatmap
│   │   └── Achievements.tsx # badge grid
│   ├── components/
│   │   ├── Layout.tsx       # sidebar nav (desktop) / bottom nav (mobile)
│   │   ├── StatsCharts.tsx
│   │   └── AchievementGrid.tsx
│   └── hooks/
│       └── useAuth.ts
```

Styling: Tailwind CSS v4, seed color via CSS variable `--color-seed` set from user settings.
Same 12 preset seed colors as Flutter app.

## Reviewer Checklist — Phase 7
```
[ ] backend/src compiles with tsc --noEmit
[ ] Prisma schema has all models with userId FKs
[ ] All CRUD routes return correct status codes (201 create, 200 update, 204 delete)
[ ] Auth routes issue JWT with 15min expiry and refresh with 7d expiry
[ ] docker-compose.yml has healthcheck on db
[ ] api service runs prisma migrate deploy before starting
[ ] .env.example has all required variables documented
[ ] Flutter sync_service.dart has both NoOpSyncService and HttpSyncService stubs
[ ] pending_sync_ops Drift table added to AppDatabase
[ ] syncServiceProvider switches based on backendEnabledProvider
[ ] web/ Vite + React project initializes without errors
[ ] Flutter app still works with backend disabled (backendEnabledProvider = false)
[ ] flutter analyze: zero errors
```

---

## CROSS-PHASE CODING RULES (enforced by reviewer in every phase)

1. **Riverpod 3**: Use `@riverpod` code-gen. Never `Provider(...)`, `StateProvider(...)`, or `ChangeNotifierProvider(...)` manually.
2. **Drift 2.32**: DAOs return `Stream<List<T>>` for lists (reactive), `Future<T?>` for single lookups.
3. **All IDs**: `const Uuid().v4()` from `uuid` package. No `DateTime.now().millisecondsSinceEpoch`.
4. **go_router 17**: Use `GoRoute(path:, builder:)`. Type-safe routes via `go_router_builder` if desired. Never push full paths manually — use named routes.
5. **Material 3 only**: `FilledButton`, `OutlinedButton`, `TextButton`, `NavigationBar`, `BottomSheet`, `Card`, `Chip`, `Dialog`. No `RaisedButton`, `FlatButton`, `BottomNavigationBar`.
6. **No hardcoded colors**: `Theme.of(context).colorScheme.primary`, `.surface`, `.onSurface`, etc. Zero `Color(0xFF...)` in widget files.
7. **`const` constructors**: Use everywhere possible. The linter enforces `prefer_const_constructors`.
8. **Error handling**: Wrap all DB and file operations in `try/catch`. Surface errors via `AsyncValue.error(e, st)` in Riverpod notifiers. Never `print()` in production code — use `debugPrint()`.
9. **Freezed models**: Always `copyWith()` for updates. Never mutate fields directly.
10. **No `BuildContext` after async gap**: Use `mounted` check or `ref.context` pattern.
11. **`flutter analyze` must pass**: Zero errors, zero warnings. Lint rules: `flutter_lints ^4.0`, `riverpod_lint ^4.0`.

---

## HANDOFF TEMPLATE

After each phase, the orchestrator writes `PHASE_N_HANDOFF.md`:

```markdown
# Phase N Handoff

## Status: ✅ Passed Review

## Files Created
- lib/core/database/app_database.dart — AppDatabase with N tables
- lib/features/.../screen.dart — ScreenName with ProviderX, ProviderY
...

## Exported Symbols (for next phase)
- `appDatabaseProvider` — Riverpod provider for AppDatabase instance
- `SubjectNotifier` — CRUD notifier for subjects
- `pomodoroNotifierProvider` — current timer state
...

## Known Limitations
- PDF thumbnail not implemented (placeholder icon used)
...

## Review Notes
- Reviewer found: [issue] → Fixed by: [fix]
```

