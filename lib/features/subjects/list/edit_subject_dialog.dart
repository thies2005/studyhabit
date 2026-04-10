import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/subject.dart';
import '../subject_providers.dart';

class EditSubjectDialog extends ConsumerStatefulWidget {
  const EditSubjectDialog({required this.subject, super.key});

  final Subject subject;

  @override
  ConsumerState<EditSubjectDialog> createState() => _EditSubjectDialogState();
}

class _EditSubjectDialogState extends ConsumerState<EditSubjectDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  int _selectedColorIndex = 0;
  late double _workDuration;
  late double _breakDuration;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subject.name);
    _descController = TextEditingController(text: widget.subject.description ?? '');
    
    _selectedColorIndex = AppTheme.presetSeeds.indexWhere(
      (c) => c.value == widget.subject.colorValue,
    );
    if (_selectedColorIndex < 0) _selectedColorIndex = 0;

    _workDuration = widget.subject.defaultDurationMinutes.toDouble();
    _breakDuration = widget.subject.defaultBreakMinutes.toDouble();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final desc = _descController.text.trim();

    final updated = widget.subject.copyWith(
      name: name,
      description: desc.isEmpty ? null : desc,
      colorValue: AppTheme.presetSeeds[_selectedColorIndex].value,
      defaultDurationMinutes: _workDuration.toInt(),
      defaultBreakMinutes: _breakDuration.toInt(),
    );

    ref.read(subjectProvider.notifier).updateSubject(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Subject'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(AppTheme.presetSeeds.length, (index) {
                final color = AppTheme.presetSeeds[index];
                final isSelected = index == _selectedColorIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = index),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Text('Default work duration: ${_workDuration.toInt()} min'),
            Slider(
              value: _workDuration,
              min: 5,
              max: 90,
              divisions: 17,
              onChanged: (v) => setState(() => _workDuration = v),
            ),
            Text('Default break duration: ${_breakDuration.toInt()} min'),
            Slider(
              value: _breakDuration,
              min: 1,
              max: 30,
              divisions: 29,
              onChanged: (v) => setState(() => _breakDuration = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
