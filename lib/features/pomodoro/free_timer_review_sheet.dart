import 'package:flutter/material.dart';

class FreeTimerReviewSheet extends StatefulWidget {
  const FreeTimerReviewSheet({
    super.key,
    required this.durationMinutes,
    required this.onSave,
  });

  final int durationMinutes;
  final Future<void> Function(int? confidence, String? notes) onSave;

  static Future<void> show(
    BuildContext context, {
    required int durationMinutes,
    required Future<void> Function(int? confidence, String? notes) onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => FreeTimerReviewSheet(
        durationMinutes: durationMinutes,
        onSave: onSave,
      ),
    );
  }

  @override
  State<FreeTimerReviewSheet> createState() => _FreeTimerReviewSheetState();
}

class _FreeTimerReviewSheetState extends State<FreeTimerReviewSheet> {
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
    final xpEarned = _confidence != null ? 10 : 0;

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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${widget.durationMinutes} minutes logged',
                  style: Theme.of(context).textTheme.bodyLarge,
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
            _AnimatedCounter(
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

class _AnimatedCounter extends StatelessWidget {
  const _AnimatedCounter({
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
  });

  final int value;
  final String prefix;
  final String suffix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, animatedValue, child) {
        return Text('$prefix$animatedValue$suffix', style: style);
      },
    );
  }
}
