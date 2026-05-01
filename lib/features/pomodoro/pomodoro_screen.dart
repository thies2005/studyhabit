import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/subject.dart';
import '../subjects/subject_providers.dart';
import 'pomodoro_notifier.dart';
import 'pomodoro_state.dart';
import 'session_review_sheet.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _workDuration = 25;
  int _breakDuration = 5;
  int _longBreakDuration = 15;
  int _longBreakEvery = 4;
  bool _durationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pomodoroState = ref.watch(pomodoroProvider);
    final subjectAsync = ref.watch(subjectByIdProvider(widget.subjectId));
    final colorScheme = Theme.of(context).colorScheme;

    // Initialize durations from subject defaults (once)
    if (!_durationsInitialized) {
      subjectAsync.whenData((subject) {
        if (subject != null && !_durationsInitialized) {
          _durationsInitialized = true;
          _workDuration = subject.defaultDurationMinutes;
          _breakDuration = subject.defaultBreakMinutes;
        }
      });
    }

    // When idle, show the local work duration; when running, show actual state
    final displaySeconds = pomodoroState.phase == TimerPhase.idle
        ? _workDuration * 60
        : (pomodoroState.isOvertime 
            ? pomodoroState.overtimeSeconds 
            : pomodoroState.remainingSeconds);
    
    final displayTotal = pomodoroState.phase == TimerPhase.idle
        ? _workDuration * 60
        : pomodoroState.totalSeconds;

    final progress = pomodoroState.isOvertime 
        ? 1.0 
        : (displayTotal > 0 ? displaySeconds / displayTotal : 1.0);

    return PopScope(
      canPop: pomodoroState.phase == TimerPhase.idle,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && pomodoroState.phase != TimerPhase.idle) {
          _showStopConfirmDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (pomodoroState.phase == TimerPhase.idle) {
                Navigator.of(context).pop();
              } else {
                _showStopConfirmDialog(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _showTimerSettings(context),
            )
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                'CURRENT SESSION',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _buildBreadcrumb(subjectAsync),
              const Spacer(flex: 2),
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = pomodoroState.isRunning
                        ? 1.0 + _pulseController.value * 0.015
                        : 1.0;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: SizedBox(
                    width: 320,
                    height: 320,
                    child: CustomPaint(
                      painter: TimerRingPainter(
                        progress: progress,
                        arcColor: pomodoroState.isOvertime ? colorScheme.secondary : colorScheme.onSurface,
                        trackColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        gapColor: colorScheme.surface,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatTime(displaySeconds),
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontSize: 72,
                                fontWeight: FontWeight.normal,
                                color: colorScheme.onSurface,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pomodoroState.isOvertime ? 'OVERTIME' : 'REMAINING',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 3.0,
                                fontWeight: FontWeight.w600,
                                 color: pomodoroState.isOvertime ? colorScheme.secondary : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 3),
              _buildControls(pomodoroState),
              const Spacer(),
              _buildUpNext(pomodoroState),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(AsyncValue<Subject?> subjectAsync) {
    return subjectAsync.when(
      loading: () => const Text('Loading...'),
      error: (_, __) => const SizedBox.shrink(),
      data: (subject) {
        if (subject == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            subject.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpNext(PomodoroState pomodoroState) {
    final colorScheme = Theme.of(context).colorScheme;

    final nextPhase = pomodoroState.phase == TimerPhase.work
        ? TimerPhase.shortBreak
        : TimerPhase.work;

    final breakMins = pomodoroState.phase == TimerPhase.work
        ? pomodoroState.breakDurationMinutes
        : null;
    final workMins = pomodoroState.plannedDurationMinutes;

    final (label, icon) = switch (nextPhase) {
      TimerPhase.work => ('Focus ($workMins m)', Icons.center_focus_strong),
      TimerPhase.shortBreak => ('Short Break (${breakMins}m)', Icons.coffee),
      TimerPhase.longBreak => ('Long Break (${breakMins}m)', Icons.free_breakfast),
      TimerPhase.idle => ('Ready', Icons.check_circle),
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UP NEXT',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildControls(PomodoroState pomodoroState) {
    final colorScheme = Theme.of(context).colorScheme;

    if (pomodoroState.phase == TimerPhase.idle) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Duration chips row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DurationChip(
                  label: 'Work',
                  value: '$_workDuration min',
                  icon: Icons.center_focus_strong,
                  onTap: () => _showTimerSettings(context),
                ),
                const SizedBox(width: 12),
                _DurationChip(
                  label: 'Break',
                  value: '$_breakDuration min',
                  icon: Icons.coffee,
                  onTap: () => _showTimerSettings(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _startFocusSession(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Focus'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Stop button
          Column(
            children: [
              InkWell(
                onTap: () => _showStopConfirmDialog(context),
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Icon(Icons.stop, color: colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'STOP',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 32),
          // Play/Pause button
          Column(
            children: [
              InkWell(
                onTap: () {
                  if (pomodoroState.isRunning) {
                    ref.read(pomodoroProvider.notifier).pause();
                  } else {
                    ref.read(pomodoroProvider.notifier).resume();
                  }
                },
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: colorScheme.onSurface,
                  child: Icon(
                    pomodoroState.isRunning ? Icons.pause : Icons.play_arrow,
                    size: 32,
                    color: colorScheme.surface,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                pomodoroState.isRunning ? 'PAUSE' : 'RESUME',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(width: 32),
          // Skip button
          Column(
            children: [
              InkWell(
                onTap: () => ref.read(pomodoroProvider.notifier).skip(),
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Icon(Icons.skip_next, color: colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'SKIP',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStopConfirmDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
          'Your progress will be saved. Are you sure you want to stop?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _stopAndReview();
            },
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopAndReview() async {
    final notifier = ref.read(pomodoroProvider.notifier);
    final pomodoroState = ref.read(pomodoroProvider);

    // Determine the actual work minutes:
    // - If we're still in a work phase (early stop), calculate elapsed now.
    // - If we've already transitioned to break, use lastActualWorkMinutes
    //   that was stored when the work phase completed.
    final int actualWorkMinutes;
    final int displayXp;
    final bool canAwardConfidenceXp;

    if (pomodoroState.phase == TimerPhase.work) {
      final int elapsedSeconds;
      if (pomodoroState.isOvertime) {
        // In overtime: full planned time + overtime seconds
        elapsedSeconds = pomodoroState.totalSeconds + pomodoroState.overtimeSeconds;
      } else {
        elapsedSeconds = pomodoroState.totalSeconds - pomodoroState.remainingSeconds;
      }
      actualWorkMinutes = (elapsedSeconds / 60).round();
      final completionRatio = pomodoroState.totalSeconds > 0
          ? (pomodoroState.isOvertime ? 1.0 : elapsedSeconds / pomodoroState.totalSeconds)
          : 0.0;
      final isEligible = completionRatio >= 0.8;
      canAwardConfidenceXp = isEligible;
      displayXp = isEligible
          ? 50 + (pomodoroState.plannedDurationMinutes >= 50 ? 120 : 0)
          : 0;
    } else {
      // In break or idle — use values stored when the work phase ended
      actualWorkMinutes = pomodoroState.lastActualWorkMinutes > 0
          ? pomodoroState.lastActualWorkMinutes
          : pomodoroState.plannedDurationMinutes;
      displayXp = pomodoroState.lastSessionXpEarned;
      canAwardConfidenceXp = displayXp > 0;
    }

    final hasProgress = pomodoroState.pomodorosCompleted > 0 || actualWorkMinutes > 0;

    if (hasProgress) {
      await SessionReviewSheet.show(
        context,
        durationMinutes: actualWorkMinutes,
        pomodorosCompleted: pomodoroState.pomodorosCompleted,
        baseXpEarned: displayXp,
        canAwardConfidenceXp: canAwardConfidenceXp,
        onSave: (confidence, notes) async {
          await notifier.awardConfidenceXpAndNotes(
            confidenceRating: confidence,
            notes: notes,
          );
        },
      );
    }

    if (mounted) {
      await notifier.stop();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _startFocusSession() {
    final config = PomodoroConfig(
      subjectId: widget.subjectId,
      plannedDurationMinutes: _workDuration,
      breakDurationMinutes: _breakDuration,
      longBreakDurationMinutes: _longBreakDuration,
      longBreakEvery: _longBreakEvery,
    );
    ref.read(pomodoroProvider.notifier).start(config);
  }

  void _showTimerSettings(BuildContext context) {
    final pomodoroState = ref.read(pomodoroProvider);
    final isIdle = pomodoroState.phase == TimerPhase.idle;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _TimerSettingsSheet(
          workDuration: isIdle ? _workDuration : pomodoroState.plannedDurationMinutes,
          breakDuration: isIdle ? _breakDuration : pomodoroState.breakDurationMinutes,
          longBreakDuration: isIdle ? _longBreakDuration : pomodoroState.longBreakDurationMinutes,
          longBreakEvery: isIdle ? _longBreakEvery : pomodoroState.longBreakEvery,
          isRunning: !isIdle,
          onSave: (work, brk, longBrk, longEvery) {
            if (isIdle) {
              setState(() {
                _workDuration = work;
                _breakDuration = brk;
                _longBreakDuration = longBrk;
                _longBreakEvery = longEvery;
              });
            } else {
              // Update the running state for next cycle
              ref.read(pomodoroProvider.notifier).updateSettings(
                plannedDurationMinutes: work,
                breakDurationMinutes: brk,
                longBreakDurationMinutes: longBrk,
                longBreakEvery: longEvery,
              );
              setState(() {
                _workDuration = work;
                _breakDuration = brk;
                _longBreakDuration = longBrk;
                _longBreakEvery = longEvery;
              });
            }
          },
        );
      },
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// Duration chip shown above the Start Focus button
class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// Timer settings bottom sheet
class _TimerSettingsSheet extends StatefulWidget {
  const _TimerSettingsSheet({
    required this.workDuration,
    required this.breakDuration,
    required this.longBreakDuration,
    required this.longBreakEvery,
    required this.onSave,
    this.isRunning = false,
  });

  final int workDuration;
  final int breakDuration;
  final int longBreakDuration;
  final int longBreakEvery;
  final bool isRunning;
  final void Function(int work, int brk, int longBrk, int longEvery) onSave;

  @override
  State<_TimerSettingsSheet> createState() => _TimerSettingsSheetState();
}

class _TimerSettingsSheetState extends State<_TimerSettingsSheet> {
  late double _work;
  late double _brk;
  late double _longBrk;
  late double _longEvery;
  late TextEditingController _workController;
  late TextEditingController _brkController;
  late TextEditingController _longBrkController;

  @override
  void initState() {
    super.initState();
    _work = widget.workDuration.toDouble();
    _brk = widget.breakDuration.toDouble();
    _longBrk = widget.longBreakDuration.toDouble();
    _longEvery = widget.longBreakEvery.toDouble();
    _workController = TextEditingController(text: _work.round().toString());
    _brkController = TextEditingController(text: _brk.round().toString());
    _longBrkController = TextEditingController(text: _longBrk.round().toString());
  }

  @override
  void dispose() {
    _workController.dispose();
    _brkController.dispose();
    _longBrkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Text(
                    'Timer Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (widget.isRunning)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: colorScheme.tertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Changes will apply to the next pomodoro cycle',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildSettingRow(
                    context,
                    label: 'Work Duration',
                    value: _work,
                    min: 1,
                    max: 180,
                    unit: 'min',
                    color: colorScheme.primary,
                    controller: _workController,
                    onChanged: (v) => setState(() {
                      _work = v;
                      _workController.text = v.round().toString();
                    }),
                    onTextChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 1 && parsed <= 180) {
                        setState(() => _work = parsed.toDouble());
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSettingRow(
                    context,
                    label: 'Short Break',
                    value: _brk,
                    min: 1,
                    max: 60,
                    unit: 'min',
                    color: colorScheme.tertiary,
                    controller: _brkController,
                    onChanged: (v) => setState(() {
                      _brk = v;
                      _brkController.text = v.round().toString();
                    }),
                    onTextChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 1 && parsed <= 60) {
                        setState(() => _brk = parsed.toDouble());
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSettingRow(
                    context,
                    label: 'Long Break',
                    value: _longBrk,
                    min: 5,
                    max: 90,
                    unit: 'min',
                    color: colorScheme.tertiary,
                    controller: _longBrkController,
                    onChanged: (v) => setState(() {
                      _longBrk = v;
                      _longBrkController.text = v.round().toString();
                    }),
                    onTextChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 5 && parsed <= 90) {
                        setState(() => _longBrk = parsed.toDouble());
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Long Break Every', style: Theme.of(context).textTheme.bodyLarge),
                      Text('${_longEvery.round()} pomodoros',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _longEvery,
                    min: 2,
                    max: 8,
                    divisions: 6,
                    onChanged: (v) => setState(() => _longEvery = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    widget.onSave(
                      _work.round(),
                      _brk.round(),
                      _longBrk.round(),
                      _longEvery.round(),
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(widget.isRunning ? 'Apply to Next Cycle' : 'Save'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Color color,
    required TextEditingController controller,
    required ValueChanged<double> onChanged,
    required ValueChanged<String> onTextChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            SizedBox(
              width: 80,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  suffixText: unit,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: onTextChanged,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class TimerRingPainter extends CustomPainter {
  const TimerRingPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
    required this.gapColor,
  });

  final double progress;
  final Color arcColor;
  final Color trackColor;
  final Color gapColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    const startAngle = -math.pi / 2;

    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }
    
    // Draw tick marks inside (gaps)
    // We just draw over the track and arc with the background color to simulate gaps
    final gapPaint = Paint()
      ..color = gapColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt;
      
    for (int i = 0; i < 4; i++) {
        final angle = startAngle + (i * math.pi / 2);
        final x1 = center.dx + (radius - 8) * math.cos(angle);
        final y1 = center.dy + (radius - 8) * math.sin(angle);
        final x2 = center.dx + (radius + 8) * math.cos(angle);
        final y2 = center.dy + (radius + 8) * math.sin(angle);
        
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), gapPaint);
    }
  }

  @override
  bool shouldRepaint(TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.arcColor != arcColor;
  }
}
