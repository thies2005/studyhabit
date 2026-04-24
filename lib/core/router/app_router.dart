import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/achievements/achievements_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/pomodoro/pdf_viewer_screen.dart';
import '../../features/pomodoro/pomodoro_screen.dart';
import '../../features/pomodoro/free_timer_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/subjects/detail/subject_detail_screen.dart';
import '../../features/subjects/list/subjects_screen.dart';
import '../../features/settings/diagnostic_logs_screen.dart';
import '../../features/settings/battery_optimization_guide.dart';
import '../../shared/widgets/app_shell_scaffold.dart';
import '../../features/pomodoro/pomodoro_notifier.dart';
import '../../features/pomodoro/free_timer_notifier.dart';
import '../../core/models/enums.dart';


part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  bool hasCheckedInitialRedirect = false;
  
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      // Only check for active timers on initial app launch
      if (hasCheckedInitialRedirect) return null;
      hasCheckedInitialRedirect = true;
      
      final pomodoro = ref.read(pomodoroProvider);
      final freeTimer = ref.read(freeTimerProvider);

      if (pomodoro.phase != TimerPhase.idle && pomodoro.subjectId.isNotEmpty) {
        return '/subjects/${pomodoro.subjectId}/session';
      }
      if (freeTimer.activeSessionId != null && freeTimer.subjectId != null) {
        return '/subjects/${freeTimer.subjectId}/free-timer';
      }

      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/subjects',
                name: 'subjects',
                builder: (context, state) => const SubjectsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                name: 'stats',
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/achievements',
                name: 'achievements',
                builder: (context, state) => const AchievementsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/subjects/:subjectId',
        name: 'subject-detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final subjectId = state.pathParameters['subjectId']!;
          return SubjectDetailScreen(subjectId: subjectId);
        },
      ),
      GoRoute(
        path: '/subjects/:subjectId/session',
        name: 'pomodoro',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final subjectId = state.pathParameters['subjectId']!;
          return PomodoroScreen(subjectId: subjectId);
        },
      ),
      GoRoute(
        path: '/subjects/:subjectId/free-timer',
        name: 'free-timer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final subjectId = state.pathParameters['subjectId']!;
          return FreeTimerScreen(subjectId: subjectId);
        },
      ),
      GoRoute(
        path: '/subjects/:subjectId/pdf/:sourceId',
        name: 'pdf-viewer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final subjectId = state.pathParameters['subjectId']!;
          final sourceId = state.pathParameters['sourceId']!;
          return PdfViewerScreen(subjectId: subjectId, sourceId: sourceId);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'logs',
            name: 'diagnostic-logs',
            builder: (context, state) => const DiagnosticLogsScreen(),
          ),
          GoRoute(
            path: 'battery-tips',
            name: 'battery-tips',
            builder: (context, state) => const BatteryOptimizationGuide(),
          ),
        ],
      ),
    ],
  );
}
