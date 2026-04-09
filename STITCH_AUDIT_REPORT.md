# Stitch Design Audit Report — StudyTracker

## Source: Stitch Project "Study Tracker Pro" (ID: 17996001450145089048)

### Design System: "Focused Curator"
- **Theme**: Dark mode default, Deep Teal (#006874)
- **Fonts**: Plus Jakarta Sans (headlines), DM Sans/Be Vietnam Pro (body), Space Grotesk (labels/data)
- **Roundness**: ROUND_EIGHT (16dp corners)
- **Philosophy**: "Atmospheric Structure" — tonal layering, no borders, glassmorphism

---

## MOBILE APP AUDIT — Significant Differences Found

### 1. Home Screen (HIGH PRIORITY)
**Stitch Design (Home Minimalist)**:
- Two large prominent stat cards side by side: "Current Streak — 12 days" and "Current Level — 08 Scholar"
- "Weekly Focus" section with XP progress bar showing "2,450 / 3,000 XP to Level 09 (82%)"
- "Start Session" FAB with `play_circle` icon (not `play_arrow`)
- Recent Sessions with subject-specific icons (functions, translate, history_edu), date, duration, XP earned
- Inspirational quote at bottom: "Curiosity is the engine of achievement."

**Current Implementation**:
- Single compact Card with small Chips for streak/level
- XP bar is there but cramped
- FAB uses `play_arrow` icon
- Recent sessions show color stripe + subject name + duration + stars
- No inspirational quote section

**Required Changes**:
- Replace compact header with two large stat cards (streak + level)
- Add prominent "Weekly Focus" XP progress section
- Change FAB icon to `play_circle`
- Enhance session cards with subject-specific icons and date formatting
- Add motivational quote section at bottom

### 2. Subjects List (HIGH PRIORITY)
**Stitch Design (Subjects Minimalist)**:
- Page header "Academic Subjects" with subtitle "Semester II • 2024"
- Subject cards with: Material icon, **completion percentage with progress bar**, subject name, description preview, "schedule Xh/week", "assignment X tasks"
- "Add New Module" inline button + FAB "New Subject"

**Current Implementation**:
- No page header
- Subject cards with: color stripe, subject name, skill chip, hours text, XP text
- FAB "Add Subject" only

**Required Changes**:
- Add page header with project name + subtitle
- Redesign SubjectCard to include: icon, completion progress bar, description preview, hours/week, task count
- Change "Add Subject" to "New Subject" with `add` icon

### 3. Subject Detail (MEDIUM PRIORITY)
**Stitch Design (Subject Detail Minimalist)**:
- Large header: "Mathematics / Level 400" + subject title + description
- 4 prominent stat chips: Completion %, Time Spent, Sources count, Ranking/Top %
- Tabs: Timeline, Sources, Topics
- Timeline entries with colored difficulty tags (LECTURE/HARD, LAB/MEDIUM, READING/EASY)
- "Mastery in Sight" encouragement card at bottom

**Current Implementation**:
- SliverAppBar with gradient, subject name
- Tabs are correct
- Timeline entries are collapsible but lack difficulty tags
- No encouragement card

**Required Changes**:
- Enhance header with level indicator
- Add prominent stat chips row (Completion, Time, Sources, Ranking)
- Add difficulty/color tags to timeline entries
- Add encouragement/milestone card at bottom of timeline

### 4. Pomodoro Timer (MEDIUM PRIORITY)
**Stitch Design (Timer Minimalist)**:
- "Current Session / Deep Work: UI Architecture" context label
- Timer display "25:00 remaining" text below the circle
- Controls: Stop (filled), Pause (large FAB), Skip Next
- "Up Next: Short Break (5m)" preview with coffee icon
- Bottom nav visible

**Current Implementation**:
- Has animated ring + pulse (good)
- Phase label + breadcrumb
- Controls: Skip Break text + large FAB
- No "Up Next" preview

**Required Changes**:
- Add "Up Next" preview showing next phase with icon
- Add "remaining" text below time display
- Refine control layout: Stop (left), Pause/Play (center), Skip (right)

### 5. Bottom Navigation (LOW PRIORITY)
**Stitch**: Uses `home`, `import_contacts`, `leaderboard`, `emoji_events`
**Current**: Uses `home`, `menu_book`, `bar_chart`, `emoji_events`

**Required Changes**:
- Change Subjects icon to `import_contacts`
- Change Stats icon to `leaderboard`

### 6. AppBar (LOW PRIORITY)
**Stitch**: Shows `menu_book` (StudyTracker), `notifications_none`, `settings`
**Current**: Shows `folder_open` (projects), `settings`

**Required Changes**:
- Change leading icon to `menu_book`
- Add notification bell icon (even if stub)
- Move project switcher to a different trigger

### 7. Theme/Visual Polish (MEDIUM PRIORITY)
**Stitch Design Principles**:
- **No borders on cards** — tonal boundaries only (remove `outlineVariant` borders)
- **Glassmorphism** on FAB and bottom nav (backdrop-blur + semi-transparent)
- **Tertiary color (#FDB87C)** for streaks, rewards, highlights
- **Larger typography** — more generous spacing
- **Ambient shadows** tinted with surface-tint

**Current Issues**:
- SubjectCard has explicit border: `outlineVariant.withValues(alpha: 0.3)`
- No glassmorphism effects
- Standard color usage without tertiary accent for rewards

**Required Changes**:
- Remove explicit card borders, use tonal surface shifts
- Add glassmorphism to NavigationBar (semi-transparent background)
- Use `colorScheme.tertiary` for streak/reward highlights
- Increase spacing in header sections

---

## DESKTOP WEB AUDIT — Major Redesign Needed

### Stitch Desktop Design Pattern:
- **Left sidebar** (fixed): Logo + "Deep Work Mode" toggle, nav items with icons, workspace switcher, settings/logout
- **Top bar**: Search, notifications, timer, Start Session button
- **Content area**: Responsive card layouts

### Current Web Implementation:
- Has Layout.tsx with sidebar
- Has pages: Dashboard, Subjects, SubjectDetail, Stats, Achievements, Login, Register
- Needs alignment with Stitch desktop patterns (sidebar design, card layouts, stat displays)

### Specific Desktop Screens Needed:
1. **Home Dashboard**: Welcome section, Level card, 4 stat cards, Recent Sessions, Streak, Daily Objectives, Study Tip
2. **Subjects List**: Grid with subject cards showing level, time invested, XP
3. **Subject Detail**: In-progress header, tabs (Timeline/Sources/Topics), session cards with tags
4. **Performance Insights**: Charts (bar, pie, line, heatmap)
5. **Achievements**: Badge grid with level card
6. **Settings**: Multi-section settings page
7. **Session Review**: Modal overlay with confidence stars, XP counter

---

## IMPLEMENTATION PLAN

### Phase A: Mobile UI Alignment (Flutter)
1. Fix theme: remove card borders, add glassmorphism to nav
2. Redesign Home Screen: large stat cards, weekly focus, enhanced session list
3. Redesign Subjects List: header, enhanced SubjectCard with progress bars
4. Enhance Subject Detail: stat chips, difficulty tags, encouragement card
5. Enhance Pomodoro Timer: "Up Next" preview, refined controls
6. Fix icon choices in bottom nav and AppBar

### Phase B: Desktop Web Alignment (React)
1. Redesign sidebar to match Stitch desktop pattern
2. Redesign Dashboard page with all sections
3. Redesign Subjects page with grid cards
4. Redesign Subject Detail page
5. Implement Stats/Performance Insights page
6. Implement Achievements page
7. Implement Settings page

### Phase C: Backend Sync & Deployment
1. Verify offline-first sync architecture
2. Test import/export
3. Docker deployment verification
4. Coolify readiness
