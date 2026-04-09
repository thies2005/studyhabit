# StudyTracker

A full-featured study tracking application with gamification, Pomodoro timer, and cross-platform support. Track your study sessions, manage subjects and topics, earn XP, and visualize your progress with charts and achievements.

## Features

- **Pomodoro Timer** — Configurable work/break intervals with foreground service for background operation
- **Subject & Hierarchy Management** — Organize studies with projects, subjects, topics, and chapters (flat, 2-level, or 3-level hierarchy)
- **XP & Leveling System** — Earn XP for completing sessions, rating confidence, adding sources, and maintaining streaks. Progress from Novice to Grandmaster
- **Streak Tracking** — Daily streaks with configurable grace period and freeze tokens
- **15 Achievements** — Unlock badges for streaks, Pomodoro milestones, hours studied, and more
- **PDF Viewer** — Built-in PDF reader with progress tracking and auto-save
- **Source Management** — Attach PDFs, URLs, and video URLs to any subject/topic/chapter
- **Statistics Dashboard** — Weekly bar charts, subject distribution pie charts, XP line charts, 12-week activity heatmap
- **Data Export/Import** — Full JSON export with merge or replace import modes
- **Material 3 Design** — Dynamic theming with 12 seed colors, dark mode, glassmorphism navigation
- **Offline-First** — Local SQLite database via Drift, works without server
- **Web Dashboard** — React-based dashboard for viewing stats, achievements, and subjects in the browser
- **REST API** — Express + Prisma + PostgreSQL backend with JWT authentication

## Architecture

```
studytracker/
├── lib/                    # Flutter mobile app (Dart)
│   ├── core/
│   │   ├── database/       # Drift SQLite (10 tables)
│   │   ├── models/         # Freezed domain models
│   │   ├── providers/      # Riverpod 3 providers
│   │   ├── services/       # XP, streak, achievement, sync
│   │   ├── router/         # go_router navigation
│   │   └── theme/          # Material 3 theming
│   ├── features/           # Feature modules
│   │   ├── home/           # Dashboard with streak, XP, sessions
│   │   ├── projects/       # Project switching, creation
│   │   ├── subjects/       # Subject CRUD, hierarchy, detail
│   │   ├── pomodoro/       # Timer, session review, PDF viewer
│   │   ├── stats/          # Charts, heatmap, breakdown table
│   │   ├── achievements/   # Badge grid, level card
│   │   └── settings/       # Theme, Pomodoro, export/import
│   └── shared/widgets/     # Reusable components
├── web/                    # React web dashboard (TypeScript)
│   ├── src/
│   │   ├── pages/          # Dashboard, Subjects, Stats, Achievements, Settings
│   │   ├── components/     # Layout, StatsCharts, AchievementGrid
│   │   ├── api/            # Axios client, React hooks
│   │   └── hooks/          # useAuth
│   ├── Dockerfile          # Multi-stage → nginx
│   └── nginx.conf          # SPA routing
├── backend/                # Express REST API (TypeScript)
│   ├── src/
│   │   ├── routes/         # Auth, projects, subjects, sessions, sources, stats, achievements
│   │   ├── services/       # Auth (JWT), XP, sync
│   │   └── middleware/     # Auth verification, validation, error handling
│   ├── prisma/schema.prisma
│   └── Dockerfile          # Multi-stage → Node.js
├── docker-compose.yml      # PostgreSQL + API + Web
└── .env.example            # Environment variables
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Mobile App | Flutter 3.35+, Dart 3.9+ |
| State Management | Riverpod 3 (code-gen) |
| Local Database | Drift 2.x (SQLite) |
| Navigation | go_router 17 |
| Charts | fl_chart |
| PDF Viewer | Syncfusion PDF Viewer |
| Web Dashboard | React 19, Vite 6, Tailwind CSS 3 |
| Web Charts | Recharts 3 |
| Backend API | Express 5, TypeScript 5 |
| ORM | Prisma 6 |
| Database | PostgreSQL 16 |
| Auth | JWT (bcryptjs + jsonwebtoken) |
| Deployment | Docker, Docker Compose, Coolify |

## Quick Start

### Mobile App (Flutter)

```bash
# Prerequisites: Flutter 3.35+, Android Studio / Xcode

# Install dependencies
flutter pub get

# Generate code (Freezed, Drift, Riverpod)
flutter pub run build_runner build --delete-conflicting-outputs

# Run on connected device/emulator
flutter run

# Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Web Dashboard (Development)

```bash
cd web

# Install dependencies
npm install

# Start dev server
npm run dev
# Open http://localhost:5173
```

### Backend API (Development)

```bash
cd backend

# Install dependencies
npm install

# Set up environment
cp ../.env.example .env
# Edit .env with your values

# Run Prisma migrations
npx prisma migrate dev

# Start dev server
npm run dev
# API runs on http://localhost:3001
```

## Deployment

### Docker Compose (Standalone)

```bash
# Copy env template and configure
cp .env.example .env
# Edit .env with strong passwords and JWT secrets

# Build and start all services
docker compose up -d --build

# Services:
#   - Web dashboard:  http://localhost:3000
#   - API:             http://localhost:3001
#   - PostgreSQL:      localhost:5432 (internal only)
```

### Coolify

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed Coolify deployment instructions.

## XP & Gamification

| Action | XP |
|--------|-----|
| Complete 1 Pomodoro (25 min) | +50 |
| Complete long session (50+ min) | +120 |
| Rate session confidence | +10 |
| Add a source/document | +5 |
| Advance skill label upward | +100 |
| Hit 7/30/100-day streak | +500 |

**Level Thresholds:** Novice (0) → Apprentice (500) → Scholar (1500) → Adept (3500) → Expert (7000) → Master → Grandmaster

## API Endpoints

Base URL: `/api/v1`

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/register` | Create account |
| POST | `/auth/login` | Login (returns JWT) |
| POST | `/auth/refresh` | Refresh access token |
| GET | `/projects` | List user projects |
| POST | `/projects` | Create project |
| PATCH | `/projects/:id` | Update project |
| DELETE | `/projects/:id` | Delete project |
| GET | `/projects/:id/subjects` | List subjects |
| GET/POST/PATCH/DELETE | `/subjects/:id` | Subject CRUD |
| GET/POST/PATCH/DELETE | `/sessions/:id` | Session CRUD |
| GET/POST/PATCH/DELETE | `/sources/:id` | Source CRUD |
| GET | `/stats/overview` | Stats overview |
| GET | `/stats/heatmap?days=84` | Activity heatmap data |
| GET | `/stats/subjects?days=30` | Subject breakdown |
| GET | `/achievements` | List achievements |
| POST | `/achievements/:key/unlock` | Unlock achievement |

## Offline Mode

The Flutter app is fully functional offline. All data is stored locally in SQLite. The server sync feature is optional and can be enabled in Settings.

## License

MIT
