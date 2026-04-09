import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/achievement.dart';

class AchievementUnlockCard extends StatefulWidget {
  const AchievementUnlockCard({
    super.key,
    required this.achievement,
    this.autoDismiss = true,
  });

  final Achievement achievement;
  final bool autoDismiss;

  static Future<void> show(
    BuildContext context, {
    required Achievement achievement,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AchievementUnlockCard(achievement: achievement);
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

  @override
  State<AchievementUnlockCard> createState() => _AchievementUnlockCardState();
}

class _AchievementUnlockCardState extends State<AchievementUnlockCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
      if (widget.autoDismiss) {
        _dismissTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = achievementIcons[widget.achievement.key] ?? Icons.emoji_events;
    final name =
        achievementNames[widget.achievement.key] ?? widget.achievement.key;
    final description = achievementDescriptions[widget.achievement.key] ?? '';

    return Stack(
      children: [
        Positioned(
          bottom: 32,
          left: 24,
          right: 24,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _controller,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.tertiaryContainer,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 28, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Achievement Unlocked!',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const achievementIcons = <String, IconData>{
  'streak_3': Icons.local_fire_department,
  'streak_7': Icons.whatshot,
  'streak_30': Icons.bolt,
  'streak_100': Icons.military_tech,
  'pomodoro_10': Icons.timer,
  'pomodoro_100': Icons.alarm_on,
  'pomodoro_500': Icons.av_timer,
  'hours_10': Icons.schedule,
  'hours_100': Icons.history_edu,
  'subject_5h': Icons.auto_stories,
  'subject_10h': Icons.menu_book,
  'first_pdf': Icons.picture_as_pdf,
  'confidence_5': Icons.star,
  'skill_advanced': Icons.trending_up,
  'all_badges': Icons.emoji_events,
};

const achievementNames = <String, String>{
  'streak_3': '3-Day Streak',
  'streak_7': '7-Day Streak',
  'streak_30': '30-Day Streak',
  'streak_100': '100-Day Streak',
  'pomodoro_10': '10 Pomodoros',
  'pomodoro_100': '100 Pomodoros',
  'pomodoro_500': '500 Pomodoros',
  'hours_10': '10 Hours',
  'hours_100': '100 Hours',
  'subject_5h': '5h Subject',
  'subject_10h': '10h Subject',
  'first_pdf': 'First PDF',
  'confidence_5': 'Confident',
  'skill_advanced': 'Advanced Skill',
  'all_badges': 'All Badges',
};

const achievementDescriptions = <String, String>{
  'streak_3': 'Study for 3 days in a row',
  'streak_7': 'Maintain a 7-day study streak',
  'streak_30': 'Keep studying for 30 days straight',
  'streak_100': 'An incredible 100-day streak',
  'pomodoro_10': 'Complete 10 Pomodoro sessions',
  'pomodoro_100': 'Complete 100 Pomodoro sessions',
  'pomodoro_500': 'Complete 500 Pomodoro sessions',
  'hours_10': 'Accumulate 10 hours of study time',
  'hours_100': 'Accumulate 100 hours of study time',
  'subject_5h': 'Study a subject for 5+ hours',
  'subject_10h': 'Study a subject for 10+ hours',
  'first_pdf': 'Add your first PDF source',
  'confidence_5': 'Rate a session with 5 stars',
  'skill_advanced': 'Reach Advanced skill level',
  'all_badges': 'Unlock all other achievements',
};
