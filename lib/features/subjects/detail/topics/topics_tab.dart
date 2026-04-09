import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/enums.dart';
import '../../subject_providers.dart';
import 'chapter_providers.dart';
import 'topic_providers.dart';
import 'add_topic_dialog.dart';
import '../skill_label_sheet.dart';

class TopicsTab extends ConsumerWidget {
  const TopicsTab({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectAsync = ref.watch(subjectByIdProvider(subjectId));
    final topicsAsync = ref.watch(topicListProvider(subjectId));

    return subjectAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading topics')),
      data: (subject) {
        if (subject == null) return const SizedBox.shrink();

        return topicsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading topics')),
          data: (topics) => Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AddTopicDialog(subjectId: subjectId),
              ),
              child: const Icon(Icons.add),
            ),
            body: topics.isEmpty
                ? _EmptyTopics(
                    onAdd: () => showDialog<void>(
                      context: context,
                      builder: (_) => AddTopicDialog(subjectId: subjectId),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: topics.length,
                    itemBuilder: (context, index) => _TopicExpansionTile(
                      subjectId: subjectId,
                      topicId: topics[index].id,
                      topicName: topics[index].name,
                      hierarchyMode: subject.hierarchyMode,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _EmptyTopics extends StatelessWidget {
  const _EmptyTopics({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No topics yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: onAdd, child: const Text('Add Topic')),
        ],
      ),
    );
  }
}

class _TopicExpansionTile extends ConsumerWidget {
  const _TopicExpansionTile({
    required this.subjectId,
    required this.topicId,
    required this.topicName,
    required this.hierarchyMode,
  });

  final String subjectId;
  final String topicId;
  final String topicName;
  final HierarchyMode hierarchyMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final showChapters = hierarchyMode == HierarchyMode.threeLevel;

    final chaptersAsync = showChapters
        ? ref.watch(chapterListProvider(topicId))
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(child: Text(topicName)),
            IconButton(
              icon: const Icon(Icons.label_outline, size: 20),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) =>
                    SkillLabelSheet(subjectId: subjectId, topicId: topicId),
              ),
            ),
          ],
        ),
        children: [
          if (showChapters && chaptersAsync != null)
            chaptersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (chapters) => chapters.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No chapters yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Column(
                      children: chapters
                          .map(
                            (ch) => ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.article_outlined,
                                size: 18,
                              ),
                              title: Text(ch.name),
                              trailing: PopupMenuButton<String>(
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Rename'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                                onSelected: (action) {
                                  if (action == 'delete') {
                                    ref
                                        .read(chapterProvider.notifier)
                                        .delete(ch.id);
                                  } else if (action == 'rename') {
                                    _showRenameDialog(
                                      context,
                                      'Rename Chapter',
                                      ch.name,
                                      (newName) => ref
                                          .read(chapterProvider.notifier)
                                          .rename(ch.id, newName),
                                    );
                                  }
                                },
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
        ],
      ),
    );
  }
}

void _showRenameDialog(
  BuildContext context,
  String title,
  String currentName,
  ValueChanged<String> onRename,
) {
  final controller = TextEditingController(text: currentName);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              onRename(controller.text.trim());
            }
            Navigator.of(context).pop();
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}
