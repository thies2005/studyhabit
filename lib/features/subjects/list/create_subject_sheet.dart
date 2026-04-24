import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/project_providers.dart';
import '../subject_providers.dart';
import '../detail/milestones/milestone_editor_sheet.dart';

class CreateSubjectSheet extends ConsumerStatefulWidget {
  const CreateSubjectSheet({super.key});

  @override
  ConsumerState<CreateSubjectSheet> createState() => _CreateSubjectSheetState();
}

class _CreateSubjectSheetState extends ConsumerState<CreateSubjectSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _hoursController = TextEditingController(text: '50');
  final _weeklyHoursController = TextEditingController(text: '10');
  int _currentStep = 0;
  int _selectedColorIndex = 0;
  HierarchyMode _hierarchyMode = HierarchyMode.flat;
  double _workDuration = 25;
  double _breakDuration = 5;
  bool _useSettingsDefaults = true;
  CompletenessMode _completenessMode = CompletenessMode.none;
  double _targetHours = 50;
  double _targetWeeklyHours = 10;

  static const _totalSteps = 5;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _hoursController.dispose();
    _weeklyHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentProjectAsync = ref.watch(lastOpenedProjectProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Subject',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: List.generate(_totalSteps, (index) {
                final isActive = index <= _currentStep;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  currentProjectAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (project) => project == null
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Card(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              child: ListTile(
                                leading: Icon(
                                  Icons.folder_off_outlined,
                                  color: colorScheme.primary,
                                ),
                                title: const Text('No active project'),
                                subtitle: const Text(
                                  'Create or switch to a project before adding subjects.',
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  _buildStep(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _back,
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: _currentStep < _totalSteps - 1
                      ? FilledButton(
                          onPressed: _canProceed() ? _next : null,
                          child: const Text('Next'),
                        )
                      : FilledButton(
                          onPressed: _canProceed() ? _create : null,
                          child: const Text('Create'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    return switch (_currentStep) {
      0 => _nameController.text.trim().isNotEmpty,
      1 => true,
      2 => true,
      3 => true,
      4 => true,
      _ => false,
    };
  }

  Widget _buildStep() {
    return switch (_currentStep) {
      0 => _buildNameStep(),
      1 => _buildColorStep(),
      2 => _buildHierarchyStep(),
      3 => _buildDurationStep(),
      4 => _buildCompletenessStep(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildNameStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Name & Description', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Subject Name',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descController,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildColorStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Choose Color', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < AppTheme.presetSeeds.length; i++)
              GestureDetector(
                onTap: () => setState(() => _selectedColorIndex = i),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedColorIndex == i
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.presetSeeds[i],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildHierarchyStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Hierarchy Mode', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        RadioGroup<HierarchyMode>(
          groupValue: _hierarchyMode,
          onChanged: (v) =>
              setState(() => _hierarchyMode = v ?? _hierarchyMode),
          child: Column(
            children: HierarchyMode.values.map((mode) {
              final isSelected = _hierarchyMode == mode;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _hierarchyMode = mode),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<HierarchyMode>(value: mode),
                            const SizedBox(width: 8),
                            Text(
                              _hierarchyLabel(mode),
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 48),
                          child: Text(
                            _hierarchyDiagram(mode),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeSettingsAsync = ref.watch(themeSettingsProvider);

    return themeSettingsAsync.when(
      loading: () => _buildDurationSliders(theme),
      error: (_, __) => _buildDurationSliders(theme),
      data: (settings) {
        if (_useSettingsDefaults) {
          _workDuration = settings.workDuration.toDouble();
          _breakDuration = settings.shortBreak.toDouble();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Durations', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _useSettingsDefaults,
              onChanged: (v) => setState(() => _useSettingsDefaults = v),
              title: Text(
                'Use default timing from Settings',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            if (_useSettingsDefaults)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: colorScheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'Work ${settings.workDuration} min / Break ${settings.shortBreak} min',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            if (!_useSettingsDefaults) ...[
              const SizedBox(height: 12),
              _buildDurationSliders(theme),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDurationSliders(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Durations', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Text('Work: ${_workDuration.round()} minutes'),
        Slider(
          value: _workDuration,
          min: 5,
          max: 90,
          divisions: 17,
          label: '${_workDuration.round()} min',
          onChanged: (v) => setState(() => _workDuration = v),
        ),
        const SizedBox(height: 12),
        Text('Break: ${_breakDuration.round()} minutes'),
        Slider(
          value: _breakDuration,
          min: 1,
          max: 30,
          divisions: 29,
          label: '${_breakDuration.round()} min',
          onChanged: (v) => setState(() => _breakDuration = v),
        ),
      ],
    );
  }

  Widget _buildCompletenessStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Completeness Tracking', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Choose how to track progress for this subject',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        RadioGroup<CompletenessMode>(
          groupValue: _completenessMode,
          onChanged: (v) =>
              setState(() => _completenessMode = v ?? _completenessMode),
          child: Column(
            children: CompletenessMode.values.map((mode) {
              final isSelected = _completenessMode == mode;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _completenessMode = mode),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<CompletenessMode>(value: mode),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _completenessLabel(mode),
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 48),
                          child: Text(
                            _completenessDescription(mode),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Hours goal input when hoursGoal selected
        if (_completenessMode == CompletenessMode.hoursGoal) ...[
          const SizedBox(height: 16),
          Text('Target Hours', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hoursController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hours',
                    suffixText: 'h',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null && parsed >= 5 && parsed <= 500) {
                      setState(() => _targetHours = parsed.toDouble());
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_targetHours.round()}h',
                      style: theme.textTheme.labelMedium,
                    ),
                    Slider(
                      value: _targetHours,
                      min: 5,
                      max: 500,
                      divisions: 99,
                      label: '${_targetHours.round()}h',
                      onChanged: (v) {
                        setState(() {
                          _targetHours = v;
                          _hoursController.text = v.round().toString();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        // Weekly hours goal input when weeklyHoursGoal selected
        if (_completenessMode == CompletenessMode.weeklyHoursGoal) ...[
          const SizedBox(height: 16),
          Text('Weekly Hours Goal', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weeklyHoursController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hours / week',
                    suffixText: 'h',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null && parsed >= 1 && parsed <= 80) {
                      setState(() => _targetWeeklyHours = parsed.toDouble());
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_targetWeeklyHours.round()}h/week',
                      style: theme.textTheme.labelMedium,
                    ),
                    Slider(
                      value: _targetWeeklyHours,
                      min: 1,
                      max: 80,
                      divisions: 79,
                      label: '${_targetWeeklyHours.round()}h',
                      onChanged: (v) {
                        setState(() {
                          _targetWeeklyHours = v;
                          _weeklyHoursController.text = v.round().toString();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        // Milestones hint
        if (_completenessMode == CompletenessMode.milestones)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: colorScheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You'll add milestones after creating the subject.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _completenessLabel(CompletenessMode mode) => switch (mode) {
        CompletenessMode.none => 'None',
        CompletenessMode.hoursGoal => 'Hours Goal',
        CompletenessMode.milestones => 'Milestones',
        CompletenessMode.weeklyHoursGoal => 'Weekly Hours Goal',
      };

  String _completenessDescription(CompletenessMode mode) => switch (mode) {
        CompletenessMode.none =>
          'Just track hours and sessions normally',
        CompletenessMode.hoursGoal =>
          'Set a target hours and see progress toward it',
        CompletenessMode.milestones =>
          'Check off goals as you complete them',
        CompletenessMode.weeklyHoursGoal =>
          'Set a weekly study hours target to hit each week',
      };

  String _hierarchyLabel(HierarchyMode mode) => switch (mode) {
        HierarchyMode.flat => 'Flat',
        HierarchyMode.twoLevel => 'Two-Level',
        HierarchyMode.threeLevel => 'Three-Level',
      };

  String _hierarchyDiagram(HierarchyMode mode) => switch (mode) {
        HierarchyMode.flat => 'Subject \u2192 Sessions',
        HierarchyMode.twoLevel => 'Subject \u2192 Topic \u2192 Sessions',
        HierarchyMode.threeLevel =>
          'Subject \u2192 Topic \u2192 Chapter \u2192 Sessions',
      };

  void _back() => setState(() => _currentStep--);

  void _next() => setState(() => _currentStep++);

  Future<void> _create() async {
    await _createSubject();
  }

  Future<void> _createSubject() async {
    // Capture navigator and messenger before async gap
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final shouldOpenMilestones =
        _completenessMode == CompletenessMode.milestones;

    final newSubjectId = await ref.read(subjectProvider.notifier).create(
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          colorValue: AppTheme.presetSeeds[_selectedColorIndex].toARGB32(),
          mode: _hierarchyMode,
          defaultDuration: _workDuration.round(),
          defaultBreak: _breakDuration.round(),
          completenessMode: _completenessMode,
          targetHours: _completenessMode == CompletenessMode.hoursGoal
              ? _targetHours.round()
              : null,
          targetWeeklyHours: _completenessMode == CompletenessMode.weeklyHoursGoal
              ? _targetWeeklyHours.round()
              : null,
        );

    if (newSubjectId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Create or switch to a project first'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    navigator.pop();

    // After pop, this widget is unmounted — use the navigator's context
    // via a post-frame callback to open the milestone editor.
    if (shouldOpenMilestones) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet<void>(
          context: navigator.context,
          isScrollControlled: true,
          builder: (_) => MilestoneEditorSheet(subjectId: newSubjectId),
        );
      });
    }
  }
}
