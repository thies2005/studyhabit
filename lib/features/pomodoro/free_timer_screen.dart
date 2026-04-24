import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/subject.dart';
import '../subjects/subject_providers.dart';
import 'free_timer_notifier.dart';
import 'free_timer_review_sheet.dart';
import 'pomodoro_screen.dart'; // To reuse TimerRingPainter if needed

class FreeTimerScreen extends ConsumerStatefulWidget {
  const FreeTimerScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<FreeTimerScreen> createState() => _FreeTimerScreenState();
}

class _FreeTimerScreenState extends ConsumerState<FreeTimerScreen>
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
    final state = ref.watch(freeTimerProvider);
    final subjectAsync = ref.watch(subjectByIdProvider(widget.subjectId));
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !state.isRunning && state.activeSessionId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
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
            onPressed: () => _showStopConfirmDialog(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'FREE TIMER SESSION',
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
                    final scale = state.isRunning
                        ? 1.0 + _pulseController.value * 0.015
                        : 1.0;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: SizedBox(
                    width: 320,
                    height: 320,
                    child: CustomPaint(
                      painter: TimerRingPainter(
                        // For free timer, we can show a rotating sub-progress or just a static ring
                        progress: (state.elapsedSeconds % 60) / 60.0,
                        arcColor: colorScheme.primary,
                        trackColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        gapColor: colorScheme.surface,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatTime(state.elapsedSeconds),
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontSize: 64,
                                fontWeight: FontWeight.normal,
                                color: colorScheme.onSurface,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ELAPSED',
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
              _buildControls(state),
              const Spacer(),
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

  Widget _buildControls(state) {
    final colorScheme = Theme.of(context).colorScheme;
    final notifier = ref.read(freeTimerProvider.notifier);

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
                  if (state.isRunning) {
                    notifier.pause();
                  } else {
                    notifier.resume();
                  }
                },
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: colorScheme.onSurface,
                  child: Icon(
                    state.isRunning ? Icons.pause : Icons.play_arrow,
                    size: 32,
                    color: colorScheme.surface,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                state.isRunning ? 'PAUSE' : 'RESUME',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
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
          'Do you want to stop this timer and log your study time?',
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
    final state = ref.read(freeTimerProvider);
    final notifier = ref.read(freeTimerProvider.notifier);
    
    final elapsedMinutes = state.elapsedSeconds ~/ 60;

    if (elapsedMinutes > 0) {
      await FreeTimerReviewSheet.show(
        context,
        durationMinutes: elapsedMinutes,
        onSave: (confidence, notes) async {
          await notifier.awardConfidenceXpAndNotes(
            confidenceRating: confidence,
            notes: notes,
          );
        },
      );
    }

    await notifier.stop();
    if (mounted) {
      context.pop(); // Go back from timer screen
    }
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
