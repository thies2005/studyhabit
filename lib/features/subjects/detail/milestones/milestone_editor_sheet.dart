import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/subject_milestone.dart';
import '../../subject_providers.dart';

class MilestoneEditorSheet extends ConsumerStatefulWidget {
  const MilestoneEditorSheet({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<MilestoneEditorSheet> createState() =>
      _MilestoneEditorSheetState();
}

class _MilestoneEditorSheetState extends ConsumerState<MilestoneEditorSheet> {
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final milestonesAsync =
        ref.watch(milestoneListProvider(widget.subjectId));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Milestones',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // Milestones list
          Expanded(
            child: milestonesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Text('Failed to load milestones'),
              ),
              data: (milestones) {
                if (milestones.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.checklist_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No milestones yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add your first milestone below',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ReorderableListView.builder(
                  scrollController: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: milestones.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final reordered = List<SubjectMilestone>.from(milestones);
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                    final items = reordered
                        .asMap()
                        .entries
                        .map((e) => (id: e.value.id, sortOrder: e.key))
                        .toList();
                    ref
                        .read(milestoneProvider.notifier)
                        .reorder(widget.subjectId, items);
                  },
                  itemBuilder: (context, index) {
                    final milestone = milestones[index];
                    return Card(
                      key: ValueKey(milestone.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Checkbox(
                          value: milestone.isCompleted,
                          onChanged: (_) {
                            ref
                                .read(milestoneProvider.notifier)
                                .toggleComplete(milestone.id);
                          },
                        ),
                        title: Text(
                          milestone.title,
                          style: TextStyle(
                            decoration: milestone.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: milestone.isCompleted
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_handle,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (!milestone.isCompleted)
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: colorScheme.error,
                                  size: 20,
                                ),
                                onPressed: () {
                                  ref
                                      .read(milestoneProvider.notifier)
                                      .deleteMilestone(milestone.id);
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Add milestone input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'New milestone',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addMilestone(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _addMilestone,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addMilestone() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    ref
        .read(milestoneProvider.notifier)
        .add(widget.subjectId, title);

    _titleController.clear();
  }
}
