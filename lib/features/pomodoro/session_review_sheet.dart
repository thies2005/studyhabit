import 'package:flutter/material.dart';

class SessionReviewSheet extends StatefulWidget {
  const SessionReviewSheet({
    super.key,
    required this.durationMinutes,
    required this.pomodorosCompleted,
    required this.onSave,
  });

  final int durationMinutes;
  final int pomodorosCompleted;
  final Future<void> Function(int? confidence, String? notes) onSave;

  static Future<void> show(
    BuildContext context, {
    required int durationMinutes,
    required int pomodorosCompleted,
    required Future<void> Function(int? confidence, String? notes) onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => SessionReviewSheet(
        durationMinutes: durationMinutes,
        pomodorosCompleted: pomodorosCompleted,
        onSave: onSave,
      ),
    );
  }

  @override
  State<SessionReviewSheet> createState() => _SessionReviewSheetState();
}

class _SessionReviewSheetState extends State<SessionReviewSheet> {
  int? _confidence;
  final _notesController = TextEditingController();
  bool _saved = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseXp =
        widget.pomodorosCompleted * 50 +
        (widget.durationMinutes >= 50 ? 120 : 0);
    final confidenceXp = _confidence != null ? 10 : 0;
    final xpEarned = baseXp + confidenceXp;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Session Complete!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  icon: Icons.timer,
                  label: '${widget.durationMinutes} min',
                ),
                _StatChip(
                  icon: Icons.circle,
                  label:
                      '${widget.pomodorosCompleted} pomodoro${widget.pomodorosCompleted != 1 ? 's' : ''}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Confidence Rating',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                final isSelected =
                    _confidence != null && _confidence! >= starValue;
                return IconButton(
                  iconSize: 36,
                  icon: Icon(
                    isSelected ? Icons.star : Icons.star_outline,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    setState(() {
                      _confidence = _confidence == starValue ? null : starValue;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            AnimatedCounter(
              value: xpEarned,
              prefix: '+',
              suffix: ' XP',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saved ? null : _handleSave,
                child: Text(_saved ? 'Saved' : 'Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _saved = true);
    await widget.onSave(
      _confidence,
      _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  final int value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, animatedValue, child) {
        return Text('$prefix$animatedValue$suffix', style: style);
      },
    );
  }
}
