import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/daos/session_dao.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/study_session.dart';
import '../../../../core/providers/database_provider.dart';
import '../../subject_providers.dart';
import 'timeline_providers.dart';

class TimelineTab extends ConsumerWidget {
  const TimelineTab({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsByDateProvider(subjectId));

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load sessions',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
      data: (dateMap) {
        if (dateMap.isEmpty) {
          return _EmptyTimeline(subjectId: subjectId);
        }

        final dates = dateMap.keys.toList();
        final subjectAsync = ref.watch(subjectByIdProvider(subjectId));
        HierarchyMode hierarchyMode = HierarchyMode.flat;
        subjectAsync.whenData((s) {
          if (s != null) hierarchyMode = s.hierarchyMode;
        });

        return _TimelineList(
          dates: dates,
          dateMap: dateMap,
          subjectId: subjectId,
          hierarchyMode: hierarchyMode,
        );
      },
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timeline_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No sessions yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start a study session to see your timeline',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.pushNamed(
              'pomodoro',
              pathParameters: {'subjectId': subjectId},
            ),
            child: const Text('Start Session'),
          ),
        ],
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({
    required this.dates,
    required this.dateMap,
    required this.subjectId,
    required this.hierarchyMode,
  });

  final List<DateTime> dates;
  final Map<DateTime, List<StudySession>> dateMap;
  final String subjectId;
  final HierarchyMode hierarchyMode;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.builder(
            itemCount: dates.length,
            itemBuilder: (context, dateIndex) {
              final date = dates[dateIndex];
              final sessions = dateMap[date]!;

              return _DateSection(
                date: date,
                sessions: sessions,
                subjectId: subjectId,
                hierarchyMode: hierarchyMode,
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: _EncouragementCard()),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

class _DateSection extends StatelessWidget {
  const _DateSection({
    required this.date,
    required this.sessions,
    required this.subjectId,
    required this.hierarchyMode,
  });

  final DateTime date;
  final List<StudySession> sessions;
  final String subjectId;
  final HierarchyMode hierarchyMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = _formatDate(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...sessions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SessionCard(
              session: s,
              subjectId: subjectId,
              hierarchyMode: hierarchyMode,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == yesterday) return 'Yesterday';
    return DateFormat('EEE MMM d').format(date);
  }
}

class _EncouragementCard extends StatelessWidget {
  const _EncouragementCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        color: colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.visibility,
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mastery in Sight',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Keep pushing forward! Every session brings you closer to excellence.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.trending_up, color: colorScheme.tertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class SessionCard extends ConsumerStatefulWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.subjectId,
    required this.hierarchyMode,
  });

  final StudySession session;
  final String subjectId;
  final HierarchyMode hierarchyMode;

  @override
  ConsumerState<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<SessionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final actualMinutes = session.actualDurationMinutes;
    final confidence = session.confidenceRating;
    final xpEarned = session.xpEarned;
    final notes = session.notes;
    final topicId = session.topicId;
    final chapterId = session.chapterId;
    final pomodoros = session.pomodorosCompleted;
    final endedAt = session.endedAt;
    final startedAt = session.startedAt;

    final showHierarchy =
        widget.hierarchyMode != HierarchyMode.flat &&
        (topicId != null || chapterId != null);

    final durationText = actualMinutes > 0
        ? '${actualMinutes}m'
        : endedAt != null
        ? '${endedAt.difference(startedAt).inMinutes}m'
        : '0m';

    return GestureDetector(
      onLongPress: () => _showDeleteDialog(context, session.id),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedCrossFade(
            firstChild: _CollapsedView(
              durationText: durationText,
              confidence: confidence,
              xpEarned: xpEarned,
              pomodoros: pomodoros,
            ),
            secondChild: _ExpandedView(
              durationText: durationText,
              confidence: confidence,
              xpEarned: xpEarned,
              pomodoros: pomodoros,
              topicId: topicId,
              chapterId: chapterId,
              notes: notes,
              showHierarchy: showHierarchy,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String sessionId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text(
          'Are you sure you want to delete this session? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteSession(sessionId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final dao = SessionDao(db);
      await dao.delete(sessionId);
    } catch (e) {
      debugPrint('Error deleting session: $e');
    }
  }
}

class _CollapsedView extends StatelessWidget {
  const _CollapsedView({
    required this.durationText,
    required this.confidence,
    required this.xpEarned,
    required this.pomodoros,
  });

  final String durationText;
  final int? confidence;
  final int xpEarned;
  final int pomodoros;

  String _getSessionType() {
    // Default to LECTURE if no specific type is tracked
    return 'LECTURE';
  }

  String _getDifficultyLabel() {
    if (confidence == null) return 'NOT RATED';
    if (confidence! <= 2) return 'EASY';
    if (confidence! == 3) return 'MEDIUM';
    return 'HARD';
  }

  Color _getDifficultyColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (confidence == null) return colorScheme.onSurfaceVariant;
    if (confidence! <= 2) return colorScheme.primary;
    if (confidence! == 3) return colorScheme.tertiary;
    return colorScheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final difficultyColor = _getDifficultyColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: colorScheme.outline),
              const SizedBox(width: 4),
              Text(durationText, style: textTheme.bodyMedium),
              const SizedBox(width: 8),
              _DifficultyBadge(
                label: _getSessionType(),
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(width: 6),
              _DifficultyBadge(
                label: _getDifficultyLabel(),
                color: difficultyColor,
              ),
              const Spacer(),
              if (pomodoros > 0) ...[
                Icon(
                  Icons.local_fire_department,
                  size: 14,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 2),
                Text('$pomodoros', style: textTheme.labelSmall),
                const SizedBox(width: 8),
              ],
              Text(
                '+$xpEarned XP',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _ExpandedView extends ConsumerWidget {
  const _ExpandedView({
    required this.durationText,
    required this.confidence,
    required this.xpEarned,
    required this.pomodoros,
    required this.topicId,
    required this.chapterId,
    required this.notes,
    required this.showHierarchy,
  });

  final String durationText;
  final int? confidence;
  final int xpEarned;
  final int pomodoros;
  final String? topicId;
  final String? chapterId;
  final String? notes;
  final bool showHierarchy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: colorScheme.outline),
              const SizedBox(width: 4),
              Text(durationText, style: textTheme.bodyMedium),
              const SizedBox(width: 12),
              if (confidence != null)
                ...List.generate(5, (i) {
                  return Icon(
                    Icons.star,
                    size: 14,
                    color: i < confidence!
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  );
                })
              else
                Text(
                  'Not rated',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              const Spacer(),
              if (pomodoros > 0) ...[
                Icon(
                  Icons.local_fire_department,
                  size: 14,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 2),
                Text('$pomodoros', style: textTheme.labelSmall),
                const SizedBox(width: 8),
              ],
              Text(
                '+$xpEarned XP',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (showHierarchy && topicId != null) ...[
            const SizedBox(height: 8),
            _Breadcrumb(topicId: topicId!, chapterId: chapterId),
          ],
          if (notes != null && notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, size: 14, color: colorScheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '"$notes"',
                    style: textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Breadcrumb extends ConsumerWidget {
  const _Breadcrumb({required this.topicId, required this.chapterId});

  final String topicId;
  final String? chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final topicAsync = ref.watch(topicByIdProvider(topicId));

    return topicAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (topic) {
        if (topic == null) return const SizedBox.shrink();

        if (chapterId == null || chapterId!.isEmpty) {
          return Row(
            children: [
              Icon(Icons.folder_outlined, size: 14, color: colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                topic.name,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
            ],
          );
        }

        final chapterAsync = ref.watch(chapterByIdProvider(chapterId!));

        return chapterAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (chapter) {
            if (chapter == null) {
              return Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    topic.name,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 14,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  topic.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
                Icon(Icons.chevron_right, size: 14, color: colorScheme.outline),
                Text(
                  chapter.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
