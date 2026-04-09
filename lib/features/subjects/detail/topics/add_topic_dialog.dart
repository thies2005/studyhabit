import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'topic_providers.dart';

class AddTopicDialog extends ConsumerStatefulWidget {
  const AddTopicDialog({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<AddTopicDialog> createState() => _AddTopicDialogState();
}

class _AddTopicDialogState extends ConsumerState<AddTopicDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Topic'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Topic Name',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _nameController.text.trim().isEmpty ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _create() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    ref
        .read(topicProvider.notifier)
        .create(widget.subjectId, name, DateTime.now().millisecondsSinceEpoch);
    Navigator.of(context).pop();
  }
}
