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

    final subjectColorScheme =
        subjectAsync.whenOrNull<ColorScheme?>(
          data: (subject) {
            if (subject == null) return null;
            return ColorScheme.fromSeed(seedColor: Color(subject.colorValue));
          },
        ) ??
        colorScheme;

    final accentColor = pomodoroState.phase == TimerPhase.work
        ? subjectColorScheme.primary
        : pomodoroState.phase == TimerPhase.shortBreak
        ? colorScheme.tertiary
        : colorScheme.secondary;

    final phaseLabel = switch (pomodoroState.phase) {
      TimerPhase.idle => 'Ready',
      TimerPhase.work => 'Focus',
      TimerPhase.shortBreak => 'Short Break',
      TimerPhase.longBreak => 'Long Break',
    };

    final progress = pomodoroState.totalSeconds > 0
        ? pomodoroState.remainingSeconds / pomodoroState.totalSeconds
        : 1.0;

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
          title: Text(phaseLabel),
          actions: [
            if (pomodoroState.phase != TimerPhase.idle)
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: () => _showStopConfirmDialog(context),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildBreadcrumb(subjectAsync),
              const SizedBox(height: 24),
              Text(
                phaseLabel,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: accentColor),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = pomodoroState.isRunning
                          ? 1.0 + _pulseController.value * 0.02
                          : 1.0;
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: SizedBox(
                      width: 280,
                      height: 280,
                      child: CustomPaint(
                        painter: TimerRingPainter(
                          progress: progress,
                          arcColor: accentColor,
                          trackColor: colorScheme.surfaceContainerHighest,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _formatTime(pomodoroState.remainingSeconds),
                                style: Theme.of(context).textTheme.displayLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'remaining',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildPomodoroDots(
                pomodoroState.pomodorosCompleted,
                pomodoroState.longBreakEvery,
                accentColor,
              ),
              const SizedBox(height: 8),
              _buildUpNext(pomodoroState),
              const SizedBox(height: 24),
              _buildControls(pomodoroState),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(AsyncValue<Subject?> subjectAsync) {
    return subjectAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (subject) {
        if (subject == null) return const SizedBox.shrink();
        return Text(
          subject.name,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }

  Widget _buildPomodoroDots(
    int completed,
    int longBreakEvery,
    Color accentColor,
  ) {
    final total = longBreakEvery;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isFilled = index < completed % longBreakEvery;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? accentColor
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        );
      }),
    );
  }

  Widget _buildUpNext(PomodoroState pomodoroState) {
    final colorScheme = Theme.of(context).colorScheme;

    final nextPhase = pomodoroState.phase == TimerPhase.work
        ? TimerPhase.shortBreak
        : TimerPhase.work;

    final (label, icon) = switch (nextPhase) {
      TimerPhase.work => ('Focus (25m)', Icons.center_focus_strong),
      TimerPhase.shortBreak => ('Short Break (5m)', Icons.coffee),
      TimerPhase.longBreak => ('Long Break (15m)', Icons.free_breakfast),
      TimerPhase.idle => ('Ready', Icons.check_circle),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'Up Next: $label',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(PomodoroState pomodoroState) {
    final colorScheme = Theme.of(context).colorScheme;

    if (pomodoroState.phase == TimerPhase.idle) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => ref.read(pomodoroProvider.notifier).startTimer(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Focus'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      );
    }

    final isBreak =
        pomodoroState.phase == TimerPhase.shortBreak ||
        pomodoroState.phase == TimerPhase.longBreak;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Stop button (left)
          IconButton.filled(
            onPressed: () => _showStopConfirmDialog(context),
            icon: const Icon(Icons.stop),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.errorContainer,
              foregroundColor: colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: 32),
          // Play/Pause FAB (center)
          FloatingActionButton.large(
            onPressed: pomodoroState.isRunning
                ? () => ref.read(pomodoroProvider.notifier).pause()
                : () => ref.read(pomodoroProvider.notifier).resume(),
            child: Icon(
              pomodoroState.isRunning ? Icons.pause : Icons.play_arrow,
            ),
          ),
          const SizedBox(width: 32),
          // Skip button (right)
          if (isBreak)
            IconButton.filled(
              onPressed: () => ref.read(pomodoroProvider.notifier).skipBreak(),
              icon: const Icon(Icons.skip_next),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurface,
              ),
            )
          else
            const SizedBox(width: 56),
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

    if (pomodoroState.pomodorosCompleted > 0 ||
        pomodoroState.remainingSeconds < pomodoroState.totalSeconds) {
      final elapsed =
          pomodoroState.totalSeconds - pomodoroState.remainingSeconds;
      final actualMinutes = elapsed ~/ 60;

      await SessionReviewSheet.show(
        context,
        durationMinutes: actualMinutes > 0
            ? actualMinutes
            : pomodoroState.plannedDurationMinutes,
        pomodorosCompleted: pomodoroState.pomodorosCompleted,
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

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class TimerRingPainter extends CustomPainter {
  const TimerRingPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
  });

  final double progress;
  final Color arcColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = arcColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    const startAngle = -math.pi / 2;

    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        glowPaint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.arcColor != arcColor;
  }
}
