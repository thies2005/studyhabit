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
              onPressed: () {},
            )
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'CURRENT SESSION',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
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
                        arcColor: colorScheme.onSurface,
                        trackColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        gapColor: colorScheme.surface,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatTime(pomodoroState.remainingSeconds),
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontSize: 72,
                                fontWeight: FontWeight.normal,
                                color: colorScheme.onSurface,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'REMAINING',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 3.0,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
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
              const Text(
                'UP NEXT',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
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
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => ref.read(pomodoroProvider.notifier).startTimer(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Focus'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
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
              const Text(
                'STOP',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
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
                onTap: () => ref.read(pomodoroProvider.notifier).skipBreak(),
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Icon(Icons.skip_next, color: colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'SKIP',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
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
    return '${m.toString().padLeft(2, '0')} : ${s.toString().padLeft(2, '0')}';
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
