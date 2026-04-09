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
  bool _confirming = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_confirming) {
      return AlertDialog(
        title: const Text('Confirm Topic'),
        content: Text('Create topic "${_nameController.text.trim()}"?'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _confirming = false),
            child: const Text('Edit'),
          ),
          FilledButton(
            onPressed: _create,
            child: const Text('Confirm'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('New Topic'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Topic Name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) {
          if (_nameController.text.trim().isNotEmpty) {
            setState(() => _confirming = true);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () => setState(() => _confirming = true),
          child: const Text('Next'),
        ),
      ],
    );
  }

  void _create() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    ref.read(topicProvider.notifier).create(widget.subjectId, name);
    Navigator.of(context).pop();
  }
}
