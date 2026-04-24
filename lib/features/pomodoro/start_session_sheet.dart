import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

import '../../core/models/enums.dart';
import '../../core/models/project.dart';
import '../../core/models/subject.dart';
import '../../core/theme/app_theme.dart';
import '../projects/project_providers.dart';
import '../subjects/subject_providers.dart';
import '../subjects/detail/topics/chapter_providers.dart';
import '../subjects/detail/topics/topic_providers.dart';
import 'pomodoro_notifier.dart';
import 'free_timer_notifier.dart';

class StartSessionSheet extends ConsumerStatefulWidget {
  const StartSessionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const StartSessionSheet(),
    );
  }

  @override
  ConsumerState<StartSessionSheet> createState() => _StartSessionSheetState();
}

class _StartSessionSheetState extends ConsumerState<StartSessionSheet> {
  int _step = 0;
  Subject? _selectedSubject;
  String? _selectedTopicId;
  String? _selectedChapterId;
  bool _topicChoiceMade = false;
  bool _chapterChoiceMade = false;
  double _workDuration = 25;
  double _shortBreak = 5;
  double _longBreakDuration = 15;
  double _longBreakEvery = 4;
  String? _problematicManufacturer;
  bool _isFreeTimerMode = false;

  // Inline creation state
  bool _creatingProject = false;
  bool _creatingSubject = false;

  @override
  void initState() {
    super.initState();
    _detectOem();
  }

  Future<void> _detectOem() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      final problematicOems = ['xiaomi', 'samsung', 'huawei', 'oppo', 'vivo', 'realme'];
      if (problematicOems.contains(manufacturer)) {
        setState(() {
          _problematicManufacturer = manufacturer;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          // Check for project first
          final projectAsync = ref.watch(lastOpenedProjectProvider);

          return projectAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Failed to load')),
            data: (currentProject) {
              // No project exists → show create project
              if (currentProject == null || _creatingProject) {
                return _buildCreateProjectFlow(context);
              }

              // Project exists, check subjects
              final subjectsAsync = ref.watch(subjectListProvider);
              return subjectsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text(
                    'Failed to load subjects',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                data: (subjects) {
                  // No subjects → show create subject
                  if (subjects.isEmpty || _creatingSubject) {
                    return _buildCreateSubjectFlow(context);
                  }

                  // Normal flow
                  return _buildSessionFlow(
                    context,
                    subjects,
                    currentProject,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ─── CREATE PROJECT INLINE ───

  Widget _buildCreateProjectFlow(BuildContext context) {
    return _InlineCreateProjectForm(
      onCreated: () {
        setState(() {
          _creatingProject = false;
        });
      },
      onCancel: () {
        Navigator.of(context).pop();
      },
    );
  }

  // ─── CREATE SUBJECT INLINE ───

  Widget _buildCreateSubjectFlow(BuildContext context) {
    return _InlineCreateSubjectForm(
      onCreated: (subject) {
        setState(() {
          _creatingSubject = false;
          _selectedSubject = subject;
          _workDuration = subject.defaultDurationMinutes.toDouble();
          _shortBreak = subject.defaultBreakMinutes.toDouble();
        });
      },
      onCancel: () {
        if (_creatingSubject) {
          setState(() => _creatingSubject = false);
        } else {
          Navigator.of(context).pop();
        }
      },
    );
  }

  // ─── NORMAL SESSION FLOW ───

  Widget _buildSessionFlow(
    BuildContext context,
    List<Subject> subjects,
    Project? currentProject,
  ) {

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                _getStepTitle(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (_step > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _step--),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Pomodoro'),
                icon: Icon(Icons.timer),
              ),
              ButtonSegment(
                value: true,
                label: Text('Free Timer'),
                icon: Icon(Icons.speed),
              ),
            ],
            selected: {_isFreeTimerMode},
            onSelectionChanged: (value) {
              setState(() => _isFreeTimerMode = value.first);
            },
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_step) {
            0 => _SubjectPicker(
                subjects: subjects,
                selected: _selectedSubject,
                onSelected: (s) {
                  setState(() {
                    _selectedSubject = s;
                    _selectedTopicId = null;
                    _selectedChapterId = null;
                    _topicChoiceMade = false;
                    _chapterChoiceMade = false;
                    _workDuration = s.defaultDurationMinutes.toDouble();
                    _shortBreak = s.defaultBreakMinutes.toDouble();
                  });
                  _applyProjectDefaults(currentProject);
                },
                onCreateNew: () {
                  setState(() => _creatingSubject = true);
                },
              ),
            1 => _TopicPicker(
                subjectId: _selectedSubject!.id,
                selectedTopicId: _selectedTopicId,
                onSelected: (id) => setState(() {
                  _selectedTopicId = id;
                  _topicChoiceMade = true;
                }),
                hierarchyMode: _selectedSubject!.hierarchyMode,
              ),
            2 => _ChapterPicker(
                topicId: _selectedTopicId ?? '',
                selectedChapterId: _selectedChapterId,
                onSelected: (id) => setState(() {
                  _selectedChapterId = id;
                  _chapterChoiceMade = true;
                }),
              ),
            3 => Column(
                children: [
                  Expanded(
                    child: _DurationConfig(
                      workDuration: _workDuration,
                      shortBreak: _shortBreak,
                      longBreakDuration: _longBreakDuration,
                      longBreakEvery: _longBreakEvery,
                      projectDefaults: currentProject,
                      onWorkChanged: (v) => setState(() => _workDuration = v),
                      onBreakChanged: (v) => setState(() => _shortBreak = v),
                      onLongBreakDurationChanged: (v) =>
                          setState(() => _longBreakDuration = v),
                      onLongBreakEveryChanged: (v) =>
                          setState(() => _longBreakEvery = v),
                    ),
                  ),
                  if (_problematicManufacturer != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: InkWell(
                        onTap: () => context.pushNamed('battery-tips'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.tertiary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Detected ${_problematicManufacturer!.toUpperCase()} device. Tap here to ensure the timer works in background.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            _ => const SizedBox.shrink(),
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _canProceed()
                        ? () {
                            if (_step < _totalSteps()) {
                              setState(() => _step++);
                            } else {
                              _startSession(context, ref);
                            }
                          }
                        : null,
                    child: Text(_step < _totalSteps() ? 'Next' : 'Start'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getStepTitle() {
    return switch (_step) {
      0 => 'Choose Subject',
      1 => 'Select Topic',
      2 => 'Select Chapter',
      3 => 'Session Settings',
      _ => 'Start Session',
    };
  }

  int _totalSteps() {
    if (_selectedSubject == null) return 3;
    final mode = _selectedSubject!.hierarchyMode;
    final maxHierarchyStep = mode == HierarchyMode.flat
        ? 0
        : mode == HierarchyMode.twoLevel
            ? 1
            : 2;

    if (_isFreeTimerMode) return maxHierarchyStep;

    if (mode == HierarchyMode.threeLevel &&
        _selectedTopicId == null &&
        _topicChoiceMade) {
      return 2;
    }
    return 3;
  }

  void _applyProjectDefaults(Project? project) {
    if (project != null) {
      setState(() {
        _longBreakDuration = project.defaultLongBreakDuration.toDouble();
        _longBreakEvery = project.defaultLongBreakEvery.toDouble();
      });
    }
  }

  bool _canProceed() {
    return switch (_step) {
      0 => _selectedSubject != null,
      1 =>
        _selectedSubject!.hierarchyMode == HierarchyMode.flat ||
            _topicChoiceMade,
      2 => _chapterChoiceMade,
      3 => true,
      _ => false,
    };
  }

  void _startSession(BuildContext context, WidgetRef ref) {
    if (_isFreeTimerMode) {
      ref.read(freeTimerProvider.notifier).start(
        subjectId: _selectedSubject!.id,
        topicId: _selectedTopicId,
        chapterId: _selectedChapterId,
      );
      Navigator.of(context).pop();
      context.pushNamed(
        'free-timer',
        pathParameters: {'subjectId': _selectedSubject!.id},
      );
    } else {
      final config = PomodoroConfig(
        subjectId: _selectedSubject!.id,
        topicId: _selectedTopicId,
        chapterId: _selectedChapterId,
        plannedDurationMinutes: _workDuration.round(),
        breakDurationMinutes: _shortBreak.round(),
        longBreakDurationMinutes: _longBreakDuration.round(),
        longBreakEvery: _longBreakEvery.round(),
      );

      ref.read(pomodoroProvider.notifier).start(config);

      Navigator.of(context).pop();
      context.pushNamed(
        'pomodoro',
        pathParameters: {'subjectId': _selectedSubject!.id},
      );
    }
  }
}

// ─── INLINE PROJECT CREATION ───

class _InlineCreateProjectForm extends ConsumerStatefulWidget {
  const _InlineCreateProjectForm({
    required this.onCreated,
    required this.onCancel,
  });

  final VoidCallback onCreated;
  final VoidCallback onCancel;

  @override
  ConsumerState<_InlineCreateProjectForm> createState() =>
      _InlineCreateProjectFormState();
}

class _InlineCreateProjectFormState
    extends ConsumerState<_InlineCreateProjectForm> {
  final _nameController = TextEditingController();
  int _selectedColorIndex = 0;
  bool _isCreating = false;

  static const _emojiOptions = [
    '📚', '🎯', '🔬', '💻', '🎨', '🏋️', '📐', '🎵', '🌍', '🧠', '⚡', '🏛️',
  ];
  int _selectedEmojiIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Create Your First Project',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onCancel,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Welcome message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.waving_hand, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Welcome! Create a project to organize your study subjects.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  hintText: 'e.g. University, Self-Learning',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              Text('Icon', style: Theme.of(context).textTheme.titleSmall),
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
                      onTap: () =>
                          setState(() => _selectedEmojiIndex = index),
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
                              ? Border.all(
                                  color: colorScheme.primary, width: 2)
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
              Text('Color', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < AppTheme.presetSeeds.length; i++)
                    _ColorDot(
                      color: AppTheme.presetSeeds[i],
                      selected: _selectedColorIndex == i,
                      onTap: () =>
                          setState(() => _selectedColorIndex = i),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _nameController.text.trim().isEmpty || _isCreating
                    ? null
                    : _createProject,
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Project & Continue'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createProject() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);

    final project = await ref.read(projectProvider.notifier).create(
          name: name,
          icon: _emojiOptions[_selectedEmojiIndex],
          colorValue: AppTheme.presetSeeds[_selectedColorIndex].toARGB32(),
        );

    if (!mounted) return;

    if (project == null) {
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to create project'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    await ref.read(projectProvider.notifier).switchProject(project.id);
    if (mounted) {
      setState(() => _isCreating = false);
      widget.onCreated();
    }
  }
}

// ─── INLINE SUBJECT CREATION ───

class _InlineCreateSubjectForm extends ConsumerStatefulWidget {
  const _InlineCreateSubjectForm({
    required this.onCreated,
    required this.onCancel,
  });

  final ValueChanged<Subject> onCreated;
  final VoidCallback onCancel;

  @override
  ConsumerState<_InlineCreateSubjectForm> createState() =>
      _InlineCreateSubjectFormState();
}

class _InlineCreateSubjectFormState
    extends ConsumerState<_InlineCreateSubjectForm> {
  final _nameController = TextEditingController();
  int _selectedColorIndex = 0;
  double _workDuration = 25;
  double _shortBreak = 5;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Create a Subject',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onCancel,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.menu_book, color: colorScheme.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add a subject to start tracking your study sessions.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                  hintText: 'e.g. Mathematics, Flutter, History',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              Text('Color', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < AppTheme.presetSeeds.length; i++)
                    _ColorDot(
                      color: AppTheme.presetSeeds[i],
                      selected: _selectedColorIndex == i,
                      onTap: () =>
                          setState(() => _selectedColorIndex = i),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Default Timing',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _SimpleSliderRow(
                label: 'Work Duration',
                value: _workDuration,
                min: 5,
                max: 180,
                unit: 'min',
                color: colorScheme.primary,
                onChanged: (v) => setState(() => _workDuration = v),
              ),
              const SizedBox(height: 16),
              _SimpleSliderRow(
                label: 'Break Duration',
                value: _shortBreak,
                min: 1,
                max: 60,
                unit: 'min',
                color: colorScheme.tertiary,
                onChanged: (v) => setState(() => _shortBreak = v),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _nameController.text.trim().isEmpty || _isCreating
                    ? null
                    : _createSubject,
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Subject & Continue'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createSubject() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);

    final newSubjectId = await ref.read(subjectProvider.notifier).create(
          name: name,
          colorValue: AppTheme.presetSeeds[_selectedColorIndex].toARGB32(),
          mode: HierarchyMode.flat,
          defaultDuration: _workDuration.round(),
          defaultBreak: _shortBreak.round(),
        );

    if (!mounted) return;

    if (newSubjectId == null) {
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to create subject'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Fetch the newly created subject list to get the new subject
    final subjects = await ref.read(subjectListProvider.future);
    final newSubject = subjects.isNotEmpty
        ? subjects.firstWhere((s) => s.id == newSubjectId, orElse: () => subjects.last)
        : null;

    if (mounted && newSubject != null) {
      setState(() => _isCreating = false);
      widget.onCreated(newSubject);
    } else if (mounted) {
      setState(() {
        _isCreating = false;
      });
    }
  }
}

// ─── SUBJECT PICKER (with create button) ───

class _SubjectPicker extends StatelessWidget {
  const _SubjectPicker({
    required this.subjects,
    required this.selected,
    required this.onSelected,
    required this.onCreateNew,
  });

  final List<Subject> subjects;
  final Subject? selected;
  final ValueChanged<Subject> onSelected;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: subjects.length + 1, // +1 for create new button
      itemBuilder: (context, index) {
        // "Create new subject" card at end
        if (index == subjects.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: Container(
                  width: 8,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: const Text('+ Create New Subject'),
                textColor: Theme.of(context).colorScheme.primary,
                onTap: onCreateNew,
              ),
            ),
          );
        }

        final subject = subjects[index];
        final isSelected = selected?.id == subject.id;
        final subjectColor = ColorScheme.fromSeed(
          seedColor: Color(subject.colorValue),
        ).primary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected
                    ? subjectColor
                    : Theme.of(context).colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ListTile(
              leading: Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              title: Text(subject.name),
              selected: isSelected,
              onTap: () => onSelected(subject),
            ),
          ),
        );
      },
    );
  }
}

class _TopicPicker extends ConsumerWidget {
  const _TopicPicker({
    required this.subjectId,
    required this.selectedTopicId,
    required this.onSelected,
    required this.hierarchyMode,
  });

  final String subjectId;
  final String? selectedTopicId;
  final ValueChanged<String?> onSelected;
  final HierarchyMode hierarchyMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicListProvider(subjectId));

    return topicsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          'Failed to load topics',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
      data: (topics) {
        if (topics.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No topics yet',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => onSelected(null),
                    child: const Text('Continue without topic'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select a topic',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: topics.length + 1,
                itemBuilder: (context, index) {
                  if (index == topics.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: const Text('No specific topic'),
                        selected: selectedTopicId == null,
                        onTap: () => onSelected(null),
                      ),
                    );
                  }
                  final topic = topics[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      title: Text(topic.name),
                      selected: selectedTopicId == topic.id,
                      onTap: () => onSelected(topic.id),
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

class _ChapterPicker extends ConsumerWidget {
  const _ChapterPicker({
    required this.topicId,
    required this.selectedChapterId,
    required this.onSelected,
  });

  final String topicId;
  final String? selectedChapterId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chapterListProvider(topicId));

    return chaptersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          'Failed to load chapters',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
      data: (chapters) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select a chapter',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: chapters.length + 1,
                itemBuilder: (context, index) {
                  if (index == chapters.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: const Text('No specific chapter'),
                        selected: selectedChapterId == null,
                        onTap: () => onSelected(null),
                      ),
                    );
                  }
                  final chapter = chapters[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      title: Text(chapter.name),
                      selected: selectedChapterId == chapter.id,
                      onTap: () => onSelected(chapter.id),
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

class _DurationConfig extends StatelessWidget {
  const _DurationConfig({
    required this.workDuration,
    required this.shortBreak,
    required this.longBreakDuration,
    required this.longBreakEvery,
    required this.projectDefaults,
    required this.onWorkChanged,
    required this.onBreakChanged,
    required this.onLongBreakDurationChanged,
    required this.onLongBreakEveryChanged,
  });

  final double workDuration;
  final double shortBreak;
  final double longBreakDuration;
  final double longBreakEvery;
  final Project? projectDefaults;
  final ValueChanged<double> onWorkChanged;
  final ValueChanged<double> onBreakChanged;
  final ValueChanged<double> onLongBreakDurationChanged;
  final ValueChanged<double> onLongBreakEveryChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Session Settings',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (projectDefaults != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Project defaults: ${projectDefaults!.defaultWorkDuration}/${projectDefaults!.defaultBreakDuration}/${projectDefaults!.defaultLongBreakDuration} min',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'Work Duration',
          value: workDuration,
          min: 5,
          max: 180,
          unit: 'min',
          color: colorScheme.primary,
          onChanged: onWorkChanged,
        ),
        const SizedBox(height: 24),
        _SliderRow(
          label: 'Short Break',
          value: shortBreak,
          min: 1,
          max: 60,
          unit: 'min',
          color: colorScheme.tertiary,
          onChanged: onBreakChanged,
        ),
        const SizedBox(height: 24),
        _SliderRow(
          label: 'Long Break Duration',
          value: longBreakDuration,
          min: 5,
          max: 90,
          unit: 'min',
          color: colorScheme.tertiary,
          onChanged: onLongBreakDurationChanged,
        ),
        const SizedBox(height: 24),
        _SliderRow(
          label: 'Long Break Every',
          value: longBreakEvery,
          min: 1,
          max: 10,
          unit: '',
          color: colorScheme.secondary,
          onChanged: onLongBreakEveryChanged,
          isInt: true,
        ),
      ],
    );
  }
}

// ─── SHARED WIDGETS ───

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

class _SimpleSliderRow extends StatelessWidget {
  const _SimpleSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Color color;
  final ValueChanged<double> onChanged;

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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color),
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

class _SliderRow extends StatefulWidget {
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
  State<_SliderRow> createState() => _SliderRowState();
}

class _SliderRowState extends State<_SliderRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.round().toString());
  }

  @override
  void didUpdateWidget(covariant _SliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (_controller.text != widget.value.round().toString()) {
        _controller.text = widget.value.round().toString();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.bodyLarge),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  suffixText: widget.unit,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null &&
                      parsed >= widget.min &&
                      parsed <= widget.max) {
                    widget.onChanged(parsed.toDouble());
                  }
                },
              ),
            ),
          ],
        ),
        Slider(
          value: widget.value,
          min: widget.min,
          max: widget.max,
          divisions: (widget.max - widget.min).toInt(),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}
