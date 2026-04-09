# Web Dashboard Implementation Plan — Stitch Desktop Design Alignment

## Current State: BROKEN
- Build fails (JSX errors in Dashboard.tsx)
- localStorage key mismatch (useAuth vs api/client)
- No charting library (spec requires Recharts)
- Missing PostCSS config for Tailwind
- Orphaned components (StatsCharts, AchievementGrid never imported)
- SubjectDetail page has no route
- No Inter font loaded
- Does NOT match Stitch desktop design (uses top nav bar, not sidebar)

## Stitch Desktop Design Pattern

### Layout: Left Sidebar Navigation
```
┌──────────────────────────────────────────────────────────┐
│ SIDEBAR (240px fixed)  │  CONTENT AREA (flexible)        │
│                        │                                  │
│ Study Sanctuary        │  [Search] [🔔] [⏱] [Start]     │
│ Deep Work Mode toggle  │                                  │
│                        │  Welcome back, Alex.             │
│ 🏠 Home               │  ⭐ You've completed 85%...      │
│ 📚 Subjects            │                                  │
│ 📊 Stats               │  Level 24 - Zen Master          │
│ 🏆 Achievements        │  [██████████████░░] 12,450/15K  │
│                        │                                  │
│ 🔀 Workspace Switcher  │  Deep Work: 42h | Eff: 94% |    │
│ ⚙️ Settings            │  Sessions: 128 | Rank: #402     │
│ 🚪 Log Out             │                                  │
│                        │  Recent Sessions | View All      │
│                        │  [session cards...]              │
│                        │                                  │
│                        │  🔥 14 Days Strong               │
│                        │  3 days to "Unstoppable"         │
│                        │                                  │
│                        │  ✅ Daily Objectives             │
│                        │  💡 Study Tip                    │
└──────────────────────────────────────────────────────────┘
```

### Desktop Screens from Stitch:
1. **Home Dashboard**: Welcome, level card, 4 stat cards, recent sessions, streak, daily objectives, study tip
2. **Subjects List**: Grid cards with level, XP, time invested
3. **Subject Detail**: In-progress header, tabs (Timeline/Sources/Topics), session cards with tags
4. **Performance Insights**: Charts (bar, pie, line, heatmap)
5. **Achievements**: Badge grid with level card
6. **Settings**: Multi-section settings page

## Implementation Tasks

### Phase 1: Fix Build & Core Infrastructure
1. Fix Dashboard.tsx JSX error (remove extra `</div>` tags)
2. Fix localStorage key mismatch in useAuth.ts
3. Add postcss.config.js for Tailwind
4. Add Inter font via @fontsource/inter
5. Install recharts for charts
6. Fix color rendering bug (pad to 6 hex digits)
7. Remove unused imports

### Phase 2: Redesign Layout to Sidebar Pattern
1. Replace Layout.tsx top nav with left sidebar:
   - Fixed 240px sidebar on desktop, drawer on mobile
   - App logo + "Deep Work Mode" toggle
   - Nav items with icons (Home, Subjects, Stats, Achievements)
   - Workspace Switcher button
   - Settings + Log Out at bottom
2. Top content bar: search input, notifications bell, timer icon, Start Session button
3. Responsive: sidebar collapses to drawer on mobile (< 768px)

### Phase 3: Redesign Dashboard Page
1. Welcome section with user name + progress message
2. Level card: Level number + name + XP progress bar
3. 4 stat cards in row: Deep Work hours, Efficiency %, Sessions count, Global Rank
4. Recent Sessions list with subject icon, name, time, XP badge, duration
5. Streak card: fire icon + "N Days Strong" + milestone progress
6. Daily Objectives: checklist with checkboxes
7. Study Tip: card with tip title + description

### Phase 4: Redesign Subjects Page
1. Page header: "My Subjects" + description + "New Subject" button
2. Subject cards in responsive grid:
   - Material icon
   - "Current Level" badge (Lvl XX)
   - Subject name (bold)
   - Description (2 lines)
   - "Time Invested" value
   - "Total Experience" value
3. "Upcoming Milestone" card at bottom

### Phase 5: Redesign Subject Detail Page
1. Wire route: /subjects/:subjectId in App.tsx
2. "In Progress" header badge with total study time
3. Subject title + description
4. Tab buttons: Timeline, Sources, Topics
5. Study Sessions list with date headers, tags, descriptions
6. Stats sidebar: Retention %, Streak days
7. Primary Sources section: PDF/URL/Video cards
8. Next Milestone card

### Phase 6: Redesign Stats Page (Performance Insights)
1. Use Recharts for all charts:
   - Weekly bar chart (7 days)
   - Subject distribution pie chart
   - XP line chart (30 days)
   - Activity heatmap (custom CSS grid)
2. Overview stat cards at top
3. Subject breakdown table

### Phase 7: Redesign Achievements Page
1. Level card with XP progress at top
2. 3-column badge grid:
   - Unlocked: full color icon + name + date
   - Locked: grayscale + progress bar
3. Tap/click → detail modal

### Phase 8: Settings Page (NEW)
1. Appearance: theme toggle, seed color picker
2. Pomodoro: duration sliders
3. Notifications: toggle
4. Streak: grace period slider
5. Data: export/import/clear buttons
6. Connect to Server: disabled with "Coming Soon" badge

### Phase 9: Sync & Offline Support
1. Offline-first: cache API responses in localStorage
2. Queue mutations when offline
3. Sync status indicator in sidebar
4. Auto-retry when back online

## Color & Style Guide (from Stitch Design)
- Background: #101415 (dark)
- Surface: #1C2021
- Surface high: #323536
- Primary: #85D2E0
- Primary container: #006874
- Tertiary: #FDB87C (for streaks/rewards)
- On surface: #E0E3E3
- Fonts: Plus Jakarta Sans (headings), DM Sans (body), Space Grotesk (data)
- No borders on cards — tonal boundaries only
- 16dp corner radius
- Glassmorphism on modals/overlays
