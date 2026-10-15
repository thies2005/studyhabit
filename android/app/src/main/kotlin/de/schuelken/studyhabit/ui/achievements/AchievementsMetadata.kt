package de.schuelken.studyhabit.ui.achievements

data class AchievementMetadata(
    val key: String,
    val title: String,
    val description: String,
    val icon: String,
    val category: String,
)

object AchievementsMetadata {
    val ALL = listOf(
        // Streaks
        AchievementMetadata("streak_3", "Spark of Discipline", "Study 3 days in a row", "🔥", "Streaks"),
        AchievementMetadata("streak_7", "Weekly Warrior", "Maintain a 7-day study streak", "🔥", "Streaks"),
        AchievementMetadata("streak_14", "Fortnight Focus", "Maintain a 14-day study streak", "🔥", "Streaks"),
        AchievementMetadata("streak_30", "Monthly Master", "Maintain a 30-day study streak", "🔥", "Streaks"),
        AchievementMetadata("streak_50", "Halfway Hero", "Maintain a 50-day study streak", "🔥", "Streaks"),
        AchievementMetadata("streak_100", "Century Club", "Maintain a 100-day study streak", "🔥", "Streaks"),
        AchievementMetadata("streak_200", "Bicentennial Mind", "Maintain a 200-day study streak", "🔥", "Streaks"),
        AchievementMetadata("streak_365", "Year of Dedication", "Maintain a 365-day study streak", "👑", "Streaks"),

        // Pomodoros
        AchievementMetadata("pomodoro_10", "Pomodoro Novice", "Complete 10 Pomodoro sessions", "🍅", "Pomodoros"),
        AchievementMetadata("pomodoro_25", "Pomodoro Apprentice", "Complete 25 Pomodoro sessions", "🍅", "Pomodoros"),
        AchievementMetadata("pomodoro_50", "Pomodoro Journeyman", "Complete 50 Pomodoro sessions", "🍅", "Pomodoros"),
        AchievementMetadata("pomodoro_100", "Pomodoro Expert", "Complete 100 Pomodoro sessions", "🍅", "Pomodoros"),
        AchievementMetadata("pomodoro_250", "Pomodoro Veteran", "Complete 250 Pomodoro sessions", "🍅", "Pomodoros"),
        AchievementMetadata("pomodoro_500", "Pomodoro Master", "Complete 500 Pomodoro sessions", "🍅", "Pomodoros"),
        AchievementMetadata("pomodoro_1000", "Pomodoro Grandmaster", "Complete 1,000 Pomodoro sessions", "🍅", "Pomodoros"),
        AchievementMetadata("pomodoro_2500", "Pomodoro Legend", "Complete 2,500 Pomodoro sessions", "🍅", "Pomodoros"),
        AchievementMetadata("pomodoro_5000", "Pomodoro Immortal", "Complete 5,000 Pomodoro sessions", "🏆", "Pomodoros"),

        // Hours
        AchievementMetadata("hours_10", "Decade of Hours", "Log 10 hours of study time", "⏳", "Hours"),
        AchievementMetadata("hours_25", "Quarter Century", "Log 25 hours of study time", "⏳", "Hours"),
        AchievementMetadata("hours_50", "Half-Century Focus", "Log 50 hours of study time", "⏳", "Hours"),
        AchievementMetadata("hours_100", "Centurion Scholar", "Log 100 hours of study time", "⏳", "Hours"),
        AchievementMetadata("hours_200", "Double Century", "Log 200 hours of study time", "⏳", "Hours"),
        AchievementMetadata("hours_500", "Deep Thinker", "Log 500 hours of study time", "⏳", "Hours"),
        AchievementMetadata("hours_1000", "Master of Craft", "Log 1,000 hours of study time", "🌟", "Hours"),

        // Sessions
        AchievementMetadata("sessions_5", "Starting Small", "Complete 5 study sessions", "📝", "Sessions"),
        AchievementMetadata("sessions_20", "Building Momentum", "Complete 20 study sessions", "📝", "Sessions"),
        AchievementMetadata("sessions_50", "Consistent Learner", "Complete 50 study sessions", "📝", "Sessions"),
        AchievementMetadata("sessions_100", "Habitual Scholar", "Complete 100 study sessions", "📝", "Sessions"),
        AchievementMetadata("sessions_250", "Academic Engine", "Complete 250 study sessions", "📝", "Sessions"),
        AchievementMetadata("sessions_500", "Unstoppable Force", "Complete 500 study sessions", "🏆", "Sessions"),

        // Subject Milestones
        AchievementMetadata("subject_5h", "Deep Diver", "Study a single subject for 5+ hours", "📚", "Subjects"),
        AchievementMetadata("subjects_2_5h", "Dual Specialist", "Study 2 different subjects for 5+ hours each", "📚", "Subjects"),
        AchievementMetadata("subjects_5_5h", "Polymath Explorer", "Study 5 different subjects for 5+ hours each", "📚", "Subjects"),
        AchievementMetadata("subject_10h", "Subject Authority", "Study a single subject for 10+ hours", "📚", "Subjects"),
        AchievementMetadata("subjects_3_10h", "Trio Master", "Study 3 different subjects for 10+ hours each", "📚", "Subjects"),
        AchievementMetadata("subjects_5_10h", "Renaissance Scholar", "Study 5 different subjects for 10+ hours each", "🎓", "Subjects"),

        // Free Timer & Long Sessions
        AchievementMetadata("free_timer_first", "Freedom to Focus", "Complete your first free timer session", "⏱️", "Special"),
        AchievementMetadata("free_timer_10", "Unstructured Scholar", "Complete 10 free timer sessions", "⏱️", "Special"),
        AchievementMetadata("free_timer_30m", "Endurance Lap", "Log a 30+ minute free timer session", "⏱️", "Special"),
        AchievementMetadata("free_timer_2h", "Marathon Session", "Log a 2+ hour continuous free timer session", "⏱️", "Special"),
        AchievementMetadata("long_session_2h", "Two-Hour Titan", "Log a 2-hour study session", "💪", "Special"),
        AchievementMetadata("long_session_3h", "Iron Will", "Log a 3-hour study session", "💪", "Special"),
        AchievementMetadata("long_session_5h", "Ultra Focus", "Log an epic 5-hour study session", "💪", "Special"),

        // Confidence & Sources & Skills
        AchievementMetadata("confidence_5", "Self-Belief", "Rate a session with 5 stars", "⭐", "Special"),
        AchievementMetadata("confidence_10", "Confidence Builder", "Rate 10 sessions with 5 stars", "⭐", "Special"),
        AchievementMetadata("confidence_50", "Unshakable Mind", "Rate 50 sessions with 5 stars", "⭐", "Special"),
        AchievementMetadata("all_5stars_3", "Perfect Triplet", "Have 3 sessions rated 5 stars in one subject", "⭐", "Special"),
        AchievementMetadata("first_pdf", "Digital Reader", "Add your first PDF source", "📄", "Special"),
        AchievementMetadata("sources_5", "Resourceful", "Add 5 study sources", "📄", "Special"),
        AchievementMetadata("sources_10", "Archivist", "Add 10 study sources", "📄", "Special"),
        AchievementMetadata("skill_advanced", "Advancing Skills", "Mark a topic or chapter as Advanced", "🎯", "Special"),
        AchievementMetadata("skill_expert", "Subject Mastery", "Mark a topic or chapter as Expert", "🎯", "Special"),
        AchievementMetadata("night_owl", "Night Owl", "Complete a session after 10 PM", "🦉", "Special"),
        AchievementMetadata("early_bird", "Early Bird", "Complete a session before 7 AM", "🌅", "Special"),
        AchievementMetadata("all_badges", "Grand Completionist", "Unlock all other achievements in StudyHabit", "👑", "Special"),
    )

    val MAP = ALL.associateBy { it.key }
}
