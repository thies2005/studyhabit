package de.schuelken.studyhabit.core.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import de.schuelken.studyhabit.core.database.dao.AchievementDao
import de.schuelken.studyhabit.core.database.dao.ChapterDao
import de.schuelken.studyhabit.core.database.dao.MilestoneDao
import de.schuelken.studyhabit.core.database.dao.ProjectDao
import de.schuelken.studyhabit.core.database.dao.SessionDao
import de.schuelken.studyhabit.core.database.dao.SkillLabelDao
import de.schuelken.studyhabit.core.database.dao.SourceDao
import de.schuelken.studyhabit.core.database.dao.SubjectDao
import de.schuelken.studyhabit.core.database.dao.TopicDao
import de.schuelken.studyhabit.core.database.dao.UserStatsDao

@Database(
    entities = [
        ProjectEntity::class,
        SubjectEntity::class,
        TopicEntity::class,
        ChapterEntity::class,
        StudySessionEntity::class,
        SkillLabelEntity::class,
        SourceEntity::class,
        AchievementEntity::class,
        UserStatsEntity::class,
        SubjectMilestoneEntity::class
    ],
    version = 1,
    exportSchema = false
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun projectDao(): ProjectDao
    abstract fun subjectDao(): SubjectDao
    abstract fun topicDao(): TopicDao
    abstract fun chapterDao(): ChapterDao
    abstract fun sessionDao(): SessionDao
    abstract fun sourceDao(): SourceDao
    abstract fun skillLabelDao(): SkillLabelDao
    abstract fun milestoneDao(): MilestoneDao
    abstract fun achievementDao(): AchievementDao
    abstract fun userStatsDao(): UserStatsDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "studyhabit.sqlite"
                )
                    .fallbackToDestructiveMigration()
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
