import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/project.dart';
import '../../core/models/subject.dart';
import '../projects/project_providers.dart';
import '../subjects/subject_providers.dart';
import '../subjects/detail/topics/chapter_providers.dart';
import '../subjects/detail/topics/topic_providers.dart';
import 'pomodoro_notifier.dart';

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subjectsAsync = ref.watch(subjectListProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return subjectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Text(
                'Failed to load subjects',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            data: (subjects) => _buildContent(
              context,
              ref,
              colorScheme,
              subjects,
              scrollController,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    List<Subject> subjects,
    ScrollController scrollController,
  ) {
    final currentProjectAsync = ref.watch(lastOpenedProjectProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Start Session',
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
        const Divider(height: 1),
        Expanded(
          child: currentProjectAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Failed to load project')),
            data: (currentProject) => switch (_step) {
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
              3 => _DurationConfig(
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
              _ => const SizedBox.shrink(),
            },
          ),
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

  int _totalSteps() {
    if (_selectedSubject == null) return 3;
    final mode = _selectedSubject!.hierarchyMode;
    if (mode == HierarchyMode.flat) return 1;
    if (mode == HierarchyMode.twoLevel) return 2;
    if (mode == HierarchyMode.threeLevel && _selectedTopicId == null && _topicChoiceMade) return 2;
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

class _SubjectPicker extends StatelessWidget {
  const _SubjectPicker({
    required this.subjects,
    required this.selected,
    required this.onSelected,
  });

  final List<Subject> subjects;
  final Subject? selected;
  final ValueChanged<Subject> onSelected;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'No subjects yet',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
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
                Icon(Icons.info_outline, size: 16, color: colorScheme.secondary),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null && parsed >= widget.min && parsed <= widget.max) {
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
