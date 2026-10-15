import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'project_providers.dart';

const _emojiOptions = [
  '📚',
  '🎯',
  '🔬',
  '💻',
  '🎨',
  '🏋️',
  '📐',
  '🎵',
  '🌍',
  '🧠',
  '⚡',
  '🏛️',
];

class CreateProjectDialog extends ConsumerStatefulWidget {
  const CreateProjectDialog({super.key});

  @override
  ConsumerState<CreateProjectDialog> createState() =>
      _CreateProjectDialogState();
}

class _CreateProjectDialogState extends ConsumerState<CreateProjectDialog> {
  final _nameController = TextEditingController();
  int _selectedEmojiIndex = 0;
  int _selectedColorIndex = 0;
  double _workDuration = 25;
  double _shortBreak = 5;
  double _longBreakDuration = 15;
  double _longBreakEvery = 4;
  double _studyReminderMinutes = 30;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return AlertDialog(
      scrollable: true,
      title: const Text('New Project'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Project Name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Text('Icon', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _emojiOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedEmojiIndex;
                return InkWell(
                  onTap: () => setState(() => _selectedEmojiIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      border: isSelected
                          ? Border.all(color: colorScheme.primary, width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _emojiOptions[index],
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text('Color', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < AppTheme.presetSeeds.length; i++)
                _ColorDot(
                  color: AppTheme.presetSeeds[i],
                  selected: _selectedColorIndex == i,
                  onTap: () => setState(() => _selectedColorIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Default Timing', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _SliderRow(
            label: 'Work Duration',
            value: _workDuration,
            min: 5,
            max: 90,
            unit: 'min',
            color: colorScheme.primary,
            onChanged: (v) => setState(() => _workDuration = v),
          ),
          const SizedBox(height: 16),
          _SliderRow(
            label: 'Short Break',
            value: _shortBreak,
            min: 1,
            max: 30,
            unit: 'min',
            color: colorScheme.tertiary,
            onChanged: (v) => setState(() => _shortBreak = v),
          ),
          const SizedBox(height: 16),
          _SliderRow(
            label: 'Long Break',
            value: _longBreakDuration,
            min: 5,
            max: 60,
            unit: 'min',
            color: colorScheme.tertiary,
            onChanged: (v) => setState(() => _longBreakDuration = v),
          ),
          const SizedBox(height: 16),
          _SliderRow(
            label: 'Long Break Every',
            value: _longBreakEvery,
            min: 2,
            max: 8,
            unit: '',
            color: colorScheme.secondary,
            onChanged: (v) => setState(() => _longBreakEvery = v),
            isInt: true,
          ),
          const SizedBox(height: 20),
          Text('Study Reminder', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _SliderRow(
            label: 'Remind after',
            value: _studyReminderMinutes,
            min: 5,
            max: 180,
            unit: 'min',
            color: colorScheme.secondary,
            onChanged: (v) => setState(() => _studyReminderMinutes = v),
          ),
        ],
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

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final project = await ref
        .read(projectProvider.notifier)
        .create(
          name: name,
          icon: _emojiOptions[_selectedEmojiIndex],
          colorValue: AppTheme.presetSeeds[_selectedColorIndex].toARGB32(),
          defaultWorkDuration: _workDuration.round(),
          defaultBreakDuration: _shortBreak.round(),
          defaultLongBreakDuration: _longBreakDuration.round(),
          defaultLongBreakEvery: _longBreakEvery.round(),
          studyReminderMinutes: _studyReminderMinutes.round(),
        );
    if (!mounted) return;

    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to create project'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    await ref.read(projectProvider.notifier).switchProject(project.id);

    if (mounted) Navigator.of(context).pop();
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: CircleAvatar(radius: 14, backgroundColor: color),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.color,
    required this.onChanged,
    this.isInt = false,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Color color;
  final ValueChanged<double> onChanged;
  final bool isInt;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.round().toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            Text(
              '$displayValue $unit',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: color),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
