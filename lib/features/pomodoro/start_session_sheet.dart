import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/subject.dart';
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
              longBreakEvery: _longBreakEvery,
              onWorkChanged: (v) => setState(() => _workDuration = v),
              onBreakChanged: (v) => setState(() => _shortBreak = v),
              onLongBreakEveryChanged: (v) =>
                  setState(() => _longBreakEvery = v),
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

  int _totalSteps() {
    if (_selectedSubject == null) return 3;
    final mode = _selectedSubject!.hierarchyMode;
    if (mode == HierarchyMode.flat) return 1;
    if (mode == HierarchyMode.twoLevel) return 2;
    if (mode == HierarchyMode.threeLevel && _selectedTopicId == null && _topicChoiceMade) return 2;
    return 3;
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
    required this.longBreakEvery,
    required this.onWorkChanged,
    required this.onBreakChanged,
    required this.onLongBreakEveryChanged,
  });

  final double workDuration;
  final double shortBreak;
  final double longBreakEvery;
  final ValueChanged<double> onWorkChanged;
  final ValueChanged<double> onBreakChanged;
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
        const SizedBox(height: 24),
        _SliderRow(
          label: 'Work Duration',
          value: workDuration,
          min: 5,
          max: 90,
          unit: 'min',
          color: colorScheme.primary,
          onChanged: onWorkChanged,
        ),
        const SizedBox(height: 24),
        _SliderRow(
          label: 'Short Break',
          value: shortBreak,
          min: 1,
          max: 30,
          unit: 'min',
          color: colorScheme.tertiary,
          onChanged: onBreakChanged,
        ),
        const SizedBox(height: 24),
        _SliderRow(
          label: 'Long Break Every',
          value: longBreakEvery,
          min: 2,
          max: 8,
          unit: '',
          color: colorScheme.secondary,
          onChanged: onLongBreakEveryChanged,
          isInt: true,
        ),
      ],
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
    final displayValue = isInt
        ? value.round().toString()
        : value.round().toString();

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
