import 'package:flutter/material.dart';

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.backgroundColor,
    this.valueColor,
    this.height = 4.0,
    this.borderRadius,
  });

  final double value; // 0.0-1.0
  final Color? backgroundColor;
  final Color? valueColor;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? colorScheme.surfaceContainerHighest;
    final fg = valueColor ?? colorScheme.primary;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, anim, child) {
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Container(color: bg),
                FractionallySizedBox(
                  widthFactor: anim.clamp(0.0, 1.0),
                  child: Container(color: fg),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
