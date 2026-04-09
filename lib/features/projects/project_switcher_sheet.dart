import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/project.dart';
import 'create_project_dialog.dart';
import 'project_providers.dart';

class ProjectSwitcherSheet extends ConsumerWidget {
  const ProjectSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        final currentProjectAsync = ref.watch(lastOpenedProjectProvider);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Projects',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () {
                      final rootContext =
                          Navigator.of(context, rootNavigator: true).context;
                      Navigator.of(context).pop();
                      showDialog<void>(
                        context: rootContext,
                        builder: (_) => const CreateProjectDialog(),
                      );
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: projectsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Failed to load projects',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                data: (projects) {
                  final activeProjects =
                      projects.where((p) => !p.isArchived).toList();

                  return currentProjectAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (currentProject) => activeProjects.isEmpty
                        ? Center(
                            child: Text(
                              'No projects yet.\nTap + to create one.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: activeProjects.length,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemBuilder: (context, index) {
                              final project = activeProjects[index];
                              final isSelected =
                                  currentProject?.id == project.id;
                              return _ProjectListTile(
                                project: project,
                                isSelected: isSelected,
                                onTap: () async {
                                  await ref
                                      .read(projectProvider.notifier)
                                      .switchProject(project.id);
                                  if (context.mounted) {
                                    context.pop();
                                  }
                                },
                                onDismissed: () {
                                  ref
                                      .read(projectProvider.notifier)
                                      .archive(project.id);
                                },
                              );
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProjectListTile extends StatelessWidget {
  const _ProjectListTile({
    required this.project,
    required this.isSelected,
    required this.onTap,
    required this.onDismissed,
  });

  final Project project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final seed = Color(project.colorValue);

    return Dismissible(
      key: ValueKey(project.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colorScheme.error,
        child: Icon(Icons.archive, color: colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        return showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Archive Project?'),
            content: Text('${project.name} will be hidden but not deleted.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Archive'),
              ),
            ],
          ),
        );
      },
      child: ListTile(
        selected: isSelected,
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(project.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            CircleAvatar(radius: 6, backgroundColor: seed),
          ],
        ),
        title: Text(
          project.name,
          style: isSelected
              ? TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                )
              : null,
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: colorScheme.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}
