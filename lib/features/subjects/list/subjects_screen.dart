import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/project.dart';
import '../../../core/models/subject.dart';
import '../subject_providers.dart';
import '../../projects/project_providers.dart';
import 'create_subject_sheet.dart';
import 'completeness_mode_dialog.dart';
import '../detail/milestones/milestone_editor_sheet.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectListProvider);
    final projectAsync = ref.watch(lastOpenedProjectProvider);

    return projectAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: CircularProgressIndicator()),
      data: (project) => subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            'Failed to load subjects',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        data: (subjects) => Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const CreateSubjectSheet(),
            ),
            icon: const Icon(Icons.add),
            label: const Text('New Subject'),
          ),
          body: CustomScrollView(
            slivers: [
              if (project != null)
                SliverToBoxAdapter(child: _PageHeader(project: project)),
              if (subjects.isEmpty)
                SliverFillRemaining(
                  child: _EmptyState(
                    onAdd: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const CreateSubjectSheet(),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SubjectCard(subject: subjects[index]),
                      ),
                      childCount: subjects.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Academic Subjects',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No subjects yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first subject to start tracking',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: onAdd,
              child: const Text('Add Subject'),
            ),
          ],
        ),
      ),
    );
  }
}

class SubjectCard extends ConsumerWidget {
  const SubjectCard({super.key, required this.subject});

  final Subject subject;

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
    final colorScheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(subjectStatsProvider(subject.id));

    final iconIndex = subject.colorValue % _subjectIcons.length;
    final subjectIcon = _subjectIcons[iconIndex.abs()];

    return Card(
      color: colorScheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.pushNamed(
          'subject-detail',
          pathParameters: {'subjectId': subject.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      subjectIcon,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subject.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _PopupMenu(
                    subject: subject,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (subject.description != null &&
                  subject.description!.isNotEmpty)
                Text(
                  subject.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),
              statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stats.completenessPercent != null) ...[
                        Row(
                          children: [
                            Text(
                              '${stats.completenessLabel} — '
                              '${(stats.completenessPercent! * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: stats.completenessPercent! >= 1.0
                                        ? colorScheme.tertiary
                                        : colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: stats.completenessPercent!.clamp(0.0, 1.0),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.totalHours.toStringAsFixed(1)}h total',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.assignment,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.sessionCount} sessions',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupMenu extends ConsumerWidget {
  const _PopupMenu({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) => _onSelect(context, ref, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'set_mode',
          child: Row(
            children: [
              Icon(Icons.track_changes, size: 20),
              SizedBox(width: 12),
              Text('Set Completeness Mode'),
            ],
          ),
        ),
        if (subject.completenessMode == CompletenessMode.milestones)
          const PopupMenuItem(
            value: 'edit_milestones',
            child: Row(
              children: [
                Icon(Icons.checklist, size: 20),
                SizedBox(width: 12),
                Text('Edit Milestones'),
              ],
            ),
          ),
        if (subject.completenessMode == CompletenessMode.hoursGoal)
          const PopupMenuItem(
            value: 'set_hours',
            child: Row(
              children: [
                Icon(Icons.hourglass_bottom, size: 20),
                SizedBox(width: 12),
                Text('Set Hours Target'),
              ],
            ),
          ),
        if (subject.completenessMode == CompletenessMode.weeklyHoursGoal)
          const PopupMenuItem(
            value: 'set_weekly_hours',
            child: Row(
              children: [
                Icon(Icons.date_range, size: 20),
                SizedBox(width: 12),
                Text('Set Weekly Hours Target'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20),
              SizedBox(width: 12),
              Text('Delete Subject'),
            ],
          ),
        ),
      ],
    );
  }

  void _onSelect(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'set_mode':
        showDialog<void>(
          context: context,
          builder: (_) => CompletenessModeDialog(subject: subject),
        );
      case 'edit_milestones':
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => MilestoneEditorSheet(subjectId: subject.id),
        );
      case 'set_hours':
        _showSetHoursDialog(context, ref);
      case 'set_weekly_hours':
        _showSetWeeklyHoursDialog(context, ref);
      case 'delete':
        _confirmDelete(context, ref);
    }
  }

  void _showSetHoursDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: subject.targetHours?.toString() ?? '50',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Hours Target'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Target hours',
            suffixText: 'h',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
              FilledButton(
                onPressed: () {
                  final hours = int.tryParse(controller.text);
                  if (hours != null && hours > 0) {
                    ref.read(subjectNotifierProvider.notifier).updateSubject(
                      subject.copyWith(
                        completenessMode: CompletenessMode.hoursGoal,
                        targetHours: hours,
                      ),
                    );
                  }
                  Navigator.of(ctx).pop();
                },
                child: const Text('Save'),
              ),
        ],
      ),
    );
  }

  void _showSetWeeklyHoursDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: subject.targetWeeklyHours?.toString() ?? '10',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Weekly Hours Target'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Hours per week',
            suffixText: 'h/week',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final hours = int.tryParse(controller.text);
              if (hours != null && hours > 0) {
                ref.read(subjectNotifierProvider.notifier).updateSubject(
                      subject.copyWith(
                        completenessMode: CompletenessMode.weeklyHoursGoal,
                        targetWeeklyHours: hours,
                      ),
                    );
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text('Are you sure you want to delete "${subject.name}"? '
            'This will also delete all sessions, milestones, and data for this subject.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              ref.read(subjectNotifierProvider.notifier).delete(subject.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
