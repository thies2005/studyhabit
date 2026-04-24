import 'package:flutter/material.dart';

class AchievementMetadata {
  final String name;
  final String description;
  final IconData icon;
  final String category;

  const AchievementMetadata({
    required this.name,
    required this.description,
    required this.icon,
    this.category = 'General',
  });
}

const Map<String, AchievementMetadata> achievementMetadataMap = {
  // Streaks
  'streak_3': AchievementMetadata(
    name: 'Getting Warm',
    description: 'Maintain a 3-day study streak.',
    icon: Icons.local_fire_department,
    category: 'Streaks',
  ),
  'streak_7': AchievementMetadata(
    name: 'Weekly Warrior',
    description: 'Maintain a 7-day study streak.',
    icon: Icons.local_fire_department,
    category: 'Streaks',
  ),
  'streak_14': AchievementMetadata(
    name: 'Two Week Triumph',
    description: 'Maintain a 14-day study streak.',
    icon: Icons.local_fire_department,
    category: 'Streaks',
  ),
  'streak_30': AchievementMetadata(
    name: 'Monthly Master',
    description: 'Maintain a 30-day study streak.',
    icon: Icons.calendar_month,
    category: 'Streaks',
  ),
  'streak_50': AchievementMetadata(
    name: 'Half Century',
    description: 'Maintain a 50-day study streak.',
    icon: Icons.workspace_premium,
    category: 'Streaks',
  ),
  'streak_100': AchievementMetadata(
    name: 'Century Club',
    description: 'Maintain a 100-day study streak.',
    icon: Icons.workspace_premium,
    category: 'Streaks',
  ),
  'streak_200': AchievementMetadata(
    name: 'Bicentennial',
    description: 'Maintain a 200-day study streak.',
    icon: Icons.military_tech,
    category: 'Streaks',
  ),
  'streak_365': AchievementMetadata(
    name: 'Orbital Period',
    description: 'Maintain a 365-day study streak.',
    icon: Icons.public,
    category: 'Streaks',
  ),

  // Pomodoros
  'pomodoro_10': AchievementMetadata(
    name: 'Focus Novice',
    description: 'Complete 10 Pomodoro sessions.',
    icon: Icons.timer,
    category: 'Pomodoros',
  ),
  'pomodoro_25': AchievementMetadata(
    name: 'Focus Apprentice',
    description: 'Complete 25 Pomodoro sessions.',
    icon: Icons.timer,
    category: 'Pomodoros',
  ),
  'pomodoro_50': AchievementMetadata(
    name: 'Focus Adept',
    description: 'Complete 50 Pomodoro sessions.',
    icon: Icons.timer,
    category: 'Pomodoros',
  ),
  'pomodoro_100': AchievementMetadata(
    name: 'Focus Master',
    description: 'Complete 100 Pomodoro sessions.',
    icon: Icons.timer,
    category: 'Pomodoros',
  ),
  'pomodoro_250': AchievementMetadata(
    name: 'Focus Elite',
    description: 'Complete 250 Pomodoro sessions.',
    icon: Icons.timer,
    category: 'Pomodoros',
  ),
  'pomodoro_500': AchievementMetadata(
    name: 'Focus Legend',
    description: 'Complete 500 Pomodoro sessions.',
    icon: Icons.timer,
    category: 'Pomodoros',
  ),
  'pomodoro_1000': AchievementMetadata(
    name: 'Titan of Time',
    description: 'Complete 1000 Pomodoro sessions.',
    icon: Icons.timer,
    category: 'Pomodoros',
  ),
  'pomodoro_2500': AchievementMetadata(
    name: 'Time Lord',
    description: 'Complete 2500 Pomodoro sessions.',
    icon: Icons.timer,
    category: 'Pomodoros',
  ),
  'pomodoro_5000': AchievementMetadata(
    name: 'Eternal Focus',
    description: 'Complete 5000 Pomodoro sessions.',
    icon: Icons.all_inclusive,
    category: 'Pomodoros',
  ),

  // Hours
  'hours_10': AchievementMetadata(
    name: '10-Hour Club',
    description: 'Total study time reaches 10 hours.',
    icon: Icons.hourglass_top,
    category: 'Study Hours',
  ),
  'hours_25': AchievementMetadata(
    name: '25-Hour Club',
    description: 'Total study time reaches 25 hours.',
    icon: Icons.hourglass_bottom,
    category: 'Study Hours',
  ),
  'hours_50': AchievementMetadata(
    name: '50-Hour Club',
    description: 'Total study time reaches 50 hours.',
    icon: Icons.hourglass_full,
    category: 'Study Hours',
  ),
  'hours_100': AchievementMetadata(
    name: '100-Hour Club',
    description: 'Total study time reaches 100 hours.',
    icon: Icons.watch_later,
    category: 'Study Hours',
  ),
  'hours_200': AchievementMetadata(
    name: 'Double Century',
    description: 'Total study time reaches 200 hours.',
    icon: Icons.watch_later,
    category: 'Study Hours',
  ),
  'hours_500': AchievementMetadata(
    name: 'Grind Master',
    description: 'Total study time reaches 500 hours.',
    icon: Icons.history_edu,
    category: 'Study Hours',
  ),
  'hours_1000': AchievementMetadata(
    name: 'The Millenary',
    description: 'Total study time reaches 1000 hours.',
    icon: Icons.auto_awesome,
    category: 'Study Hours',
  ),

  // Sessions
  'sessions_5': AchievementMetadata(
    name: 'Starter',
    description: 'Complete 5 study sessions.',
    icon: Icons.play_circle,
    category: 'Consistency',
  ),
  'sessions_20': AchievementMetadata(
    name: 'Consistent',
    description: 'Complete 20 study sessions.',
    icon: Icons.play_circle,
    category: 'Consistency',
  ),
  'sessions_50': AchievementMetadata(
    name: 'Regular',
    description: 'Complete 50 study sessions.',
    icon: Icons.play_circle,
    category: 'Consistency',
  ),
  'sessions_100': AchievementMetadata(
    name: 'Dedicated',
    description: 'Complete 100 study sessions.',
    icon: Icons.play_circle,
    category: 'Consistency',
  ),
  'sessions_250': AchievementMetadata(
    name: 'Reliable',
    description: 'Complete 250 study sessions.',
    icon: Icons.play_circle,
    category: 'Consistency',
  ),
  'sessions_500': AchievementMetadata(
    name: 'Indomitable',
    description: 'Complete 500 study sessions.',
    icon: Icons.play_circle,
    category: 'Consistency',
  ),

  // Subject milestones
  'subject_5h': AchievementMetadata(
    name: 'Specialist',
    description: 'Study one subject for at least 5 hours.',
    icon: Icons.school,
    category: 'Subject Mastery',
  ),
  'subjects_2_5h': AchievementMetadata(
    name: 'Multitasker',
    description: 'Study two subjects for at least 5 hours each.',
    icon: Icons.school,
    category: 'Subject Mastery',
  ),
  'subjects_5_5h': AchievementMetadata(
    name: 'Polymath',
    description: 'Study five subjects for at least 5 hours each.',
    icon: Icons.school,
    category: 'Subject Mastery',
  ),
  'subject_10h': AchievementMetadata(
    name: 'Deep Diver',
    description: 'Study one subject for at least 10 hours.',
    icon: Icons.bolt,
    category: 'Subject Mastery',
  ),
  'subjects_3_10h': AchievementMetadata(
    name: 'Broad Horizon',
    description: 'Study three subjects for at least 10 hours each.',
    icon: Icons.bolt,
    category: 'Subject Mastery',
  ),
  'subjects_5_10h': AchievementMetadata(
    name: 'Master Scholar',
    description: 'Study five subjects for at least 10 hours each.',
    icon: Icons.bolt,
    category: 'Subject Mastery',
  ),

  // Free timer
  'free_timer_first': AchievementMetadata(
    name: 'Freedom',
    description: 'Start your first non-Pomodoro session.',
    icon: Icons.speed,
    category: 'Flexibility',
  ),
  'free_timer_10': AchievementMetadata(
    name: 'Flow State',
    description: 'Complete 10 free timer sessions.',
    icon: Icons.speed,
    category: 'Flexibility',
  ),
  'free_timer_30m': AchievementMetadata(
    name: 'Quality Time',
    description: 'Complete a free timer session of 30 mins or more.',
    icon: Icons.speed,
    category: 'Flexibility',
  ),
  'free_timer_2h': AchievementMetadata(
    name: 'Marathoner',
    description: 'Complete a free timer session of 2 hours or more.',
    icon: Icons.speed,
    category: 'Flexibility',
  ),

  // Long sessions
  'long_session_2h': AchievementMetadata(
    name: 'The Grind',
    description: 'Log a session of at least 2 hours.',
    icon: Icons.fitness_center,
    category: 'Intensity',
  ),
  'long_session_3h': AchievementMetadata(
    name: 'Endurance',
    description: 'Log a session of at least 3 hours.',
    icon: Icons.fitness_center,
    category: 'Intensity',
  ),
  'long_session_5h': AchievementMetadata(
    name: 'Iron Mind',
    description: 'Log a session of at least 5 hours.',
    icon: Icons.fitness_center,
    category: 'Intensity',
  ),

  // Confidence
  'confidence_5': AchievementMetadata(
    name: 'Honest Review',
    description: 'Rate your first session.',
    icon: Icons.star,
    category: 'Smart Study',
  ),
  'confidence_10': AchievementMetadata(
    name: 'Self-Aware',
    description: 'Rate 10 sessions.',
    icon: Icons.star,
    category: 'Smart Study',
  ),
  'confidence_50': AchievementMetadata(
    name: 'Reflective',
    description: 'Rate 50 sessions.',
    icon: Icons.star,
    category: 'Smart Study',
  ),
  'all_5stars_3': AchievementMetadata(
    name: 'Peak Performance',
    description: 'Achieve 3 high-confidence ratings in any subjects.',
    icon: Icons.auto_awesome,
    category: 'Smart Study',
  ),

  // Sources
  'first_pdf': AchievementMetadata(
    name: 'Digital Library',
    description: 'Add your first PDF source.',
    icon: Icons.picture_as_pdf,
    category: 'Sources',
  ),
  'sources_5': AchievementMetadata(
    name: 'Collector',
    description: 'Add 5 PDF sources.',
    icon: Icons.picture_as_pdf,
    category: 'Sources',
  ),
  'sources_10': AchievementMetadata(
    name: 'Archivist',
    description: 'Add 10 PDF sources.',
    icon: Icons.picture_as_pdf,
    category: 'Sources',
  ),

  // Skill
  'skill_advanced': AchievementMetadata(
    name: 'Moving Up',
    description: 'Reach Advanced skill level in any subject.',
    icon: Icons.trending_up,
    category: 'Skill',
  ),
  'skill_expert': AchievementMetadata(
    name: 'Expert Opinion',
    description: 'Reach Expert skill level in any subject.',
    icon: Icons.workspace_premium,
    category: 'Skill',
  ),

  // Night/Day
  'night_owl': AchievementMetadata(
    name: 'Night Owl',
    description: 'Study after 10 PM.',
    icon: Icons.nightlight_round,
    category: 'Dedication',
  ),
  'early_bird': AchievementMetadata(
    name: 'Early Bird',
    description: 'Study before 7 AM.',
    icon: Icons.wb_sunny,
    category: 'Dedication',
  ),

  // Misc
  'all_badges': AchievementMetadata(
    name: 'Completionist',
    description: 'Unlock all 65 original achievements.',
    icon: Icons.emoji_events,
    category: 'Mastery',
  ),
};
