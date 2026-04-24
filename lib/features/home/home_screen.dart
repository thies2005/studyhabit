import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_stats.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/user_stats_provider.dart';
import '../../core/services/xp_service.dart';
import '../../features/subjects/subject_providers.dart';
import '../../features/pomodoro/start_session_sheet.dart';
import '../../shared/widgets/animated_progress_bar.dart';

part 'home_screen.g.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(userStatsProvider);
    final sessionsAsync = ref.watch(allSessionsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => _HeaderSection(stats: stats),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => _WeeklyFocusSection(stats: stats),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: sessionsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return const _EmptyState();
                  }
                  return _RecentSessionsList(
                    sessions: sessions.take(3).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => StartSessionSheet.show(context),
        icon: const Icon(Icons.play_circle),
        label: const Text('Start Session'),
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  const _HeaderSection({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final xpService = ref.read(xpServiceProvider);
    final levelName = xpService.levelName(stats.currentLevel);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Current Streak',
            value: '${stats.currentStreak}',
            subtitle: 'days',
            color: colorScheme.tertiary,
            icon: Icons.local_fire_department,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Current Level',
            value: stats.currentLevel.toString().padLeft(2, '0'),
            subtitle: levelName,
            color: colorScheme.primary,
            icon: Icons.emoji_events,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Icon(icon, size: 20, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class _WeeklyFocusSection extends ConsumerWidget {
  const _WeeklyFocusSection({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final xpService = ref.read(xpServiceProvider);
    final currentLevelXp = xpService.currentLevelXp(stats.totalXp);
    final currentLevelXpNeeded = xpService.currentLevelXpNeeded(stats.totalXp);
    final xpProgress = currentLevelXpNeeded > 0
        ? currentLevelXp / currentLevelXpNeeded
        : 0.0;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Focus',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$currentLevelXp / $currentLevelXpNeeded XP to Level ${stats.currentLevel + 1}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedProgressBar(value: xpProgress, height: 8),
          ],
        ),
      ),
    );
  }
}

class _RecentSessionsList extends ConsumerWidget {
  const _RecentSessionsList({required this.sessions});

  final List<StudySessionData> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Sessions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () => context.goNamed('subjects'),
                child: const Text('View all'),
              ),
            ],
          ),
        ),
        ...sessions.map((session) => _SessionCard(session: session)),
        const SizedBox(height: 100),
      ],
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});

  final StudySessionData session;

  static final List<IconData> _subjectIcons = [
    Icons.functions,
    Icons.psychology,
    Icons.terminal,
    Icons.account_balance,
    Icons.brush,
    Icons.science,
    Icons.code,
    Icons.translate,
    Icons.history_edu,
    Icons.calculate,
    Icons.school,
    Icons.menu_book,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectAsync = ref.watch(subjectByIdProvider(session.subjectId));
    final colorScheme = Theme.of(context).colorScheme;

    return subjectAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (subject) {
        if (subject == null) return const SizedBox.shrink();

        final minutes = session.actualDurationMinutes;
        final hours = minutes / 60.0;
        final durationText = hours >= 1.0
            ? '${hours.toStringAsFixed(1)}h'
            : '${minutes}m';

        final iconIndex = subject.colorValue % _subjectIcons.length;
        final subjectIcon = _subjectIcons[iconIndex.abs()];

        final dateText = _formatRelativeDate(session.startedAt);
        final xpEarned = session.xpEarned;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(subjectIcon, color: colorScheme.onPrimaryContainer),
            ),
            title: Text(
              subject.name,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(dateText),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  durationText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '+$xpEarned XP',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.tertiary),
                ),
              ],
            ),
            onTap: () {
              context.pushNamed(
                'subject-detail',
                pathParameters: {'subjectId': subject.id},
              );
            },
          ),
        );
      },
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(date.year, date.month, date.day);

    final difference = today.difference(sessionDay).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';

    return '${date.month}/${date.day}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            "Let's start learning!",
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap button below to begin your first session',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.format_quote,
                    size: 24,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Curiosity is the engine of achievement.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Provider helpers
@riverpod
Stream<List<StudySessionData>> allSessions(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .select(db.studySessions)
      .watch()
      .map(
        (rows) => rows
            .map(
              (row) => StudySessionData(
                id: row.id,
                subjectId: row.subjectId,
                actualDurationMinutes: row.actualDurationMinutes,
                confidenceRating: row.confidenceRating,
                startedAt: row.startedAt,
                xpEarned: row.xpEarned,
              ),
            )
            .toList(),
      );
}

@riverpod
Stream<int> todaySessions(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.studySessions).watch().map((sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return sessions
        .where(
          (s) =>
              s.startedAt.year == today.year &&
              s.startedAt.month == today.month &&
              s.startedAt.day == today.day,
        )
        .fold<int>(0, (sum, s) => sum + s.actualDurationMinutes);
  });
}

class StudySessionData {
  const StudySessionData({
    required this.id,
    required this.subjectId,
    required this.actualDurationMinutes,
    required this.confidenceRating,
    required this.startedAt,
    required this.xpEarned,
  });

  final String id;
  final String subjectId;
  final int actualDurationMinutes;
  final int? confidenceRating;
  final DateTime startedAt;
  final int xpEarned;
}
