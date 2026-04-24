import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/subject.dart';
import '../subject_providers.dart';

class CompletenessModeDialog extends ConsumerStatefulWidget {
  const CompletenessModeDialog({super.key, required this.subject});

  final Subject subject;

  @override
  ConsumerState<CompletenessModeDialog> createState() =>
      _CompletenessModeDialogState();
}

class _CompletenessModeDialogState
    extends ConsumerState<CompletenessModeDialog> {
  late CompletenessMode _selectedMode;
  late TextEditingController _hoursController;
  late TextEditingController _weeklyHoursController;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.subject.completenessMode;
    _hoursController = TextEditingController(
      text: widget.subject.targetHours?.toString() ?? '50',
    );
    _weeklyHoursController = TextEditingController(
      text: widget.subject.targetWeeklyHours?.toString() ?? '10',
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _weeklyHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Completeness Tracking'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<CompletenessMode>(
              groupValue: _selectedMode,
              onChanged: (v) {
                if (v != null) setState(() => _selectedMode = v);
              },
              child: Column(
                children: [
                  ...CompletenessMode.values.map((mode) {
                    final isSelected = _selectedMode == mode;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedMode = mode),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
                              width: isSelected ? 2 : 1,
                            ),
                            color: isSelected
                                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Radio<CompletenessMode>(value: mode),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _label(mode),
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    Text(
                                      _description(mode),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            if (_selectedMode == CompletenessMode.hoursGoal) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _hoursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target hours',
                  suffixText: 'h',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_selectedMode == CompletenessMode.weeklyHoursGoal) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _weeklyHoursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weekly hours goal',
                  suffixText: 'h/week',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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

  void _save() {
    int? targetHours;
    int? targetWeeklyHours;

    if (_selectedMode == CompletenessMode.hoursGoal) {
      targetHours = int.tryParse(_hoursController.text);
      if (targetHours == null || targetHours <= 0) return;
    }

    if (_selectedMode == CompletenessMode.weeklyHoursGoal) {
      targetWeeklyHours = int.tryParse(_weeklyHoursController.text);
      if (targetWeeklyHours == null || targetWeeklyHours <= 0) return;
    }

    ref.read(subjectProvider.notifier).updateSubject(
          widget.subject.copyWith(
            completenessMode: _selectedMode,
            targetHours: targetHours,
            targetWeeklyHours: targetWeeklyHours,
          ),
        );

    Navigator.of(context).pop();
  }

  String _label(CompletenessMode mode) => switch (mode) {
        CompletenessMode.none => 'None',
        CompletenessMode.hoursGoal => 'Hours Goal',
        CompletenessMode.milestones => 'Milestones',
        CompletenessMode.weeklyHoursGoal => 'Weekly Hours Goal',
      };

  String _description(CompletenessMode mode) => switch (mode) {
        CompletenessMode.none =>
          'No progress tracking',
        CompletenessMode.hoursGoal =>
          'Set a target hours and see progress toward it',
        CompletenessMode.milestones =>
          'Check off goals as you complete them',
        CompletenessMode.weeklyHoursGoal =>
          'Set a weekly study hours target to hit each week',
      };
}
