package de.schuelken.studyhabit.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import de.schuelken.studyhabit.core.database.AchievementEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface AchievementDao {
    @Query("SELECT * FROM achievements")
    fun getAllAchievementsFlow(): Flow<List<AchievementEntity>>

    @Query("SELECT * FROM achievements")
    suspend fun getAllAchievements(): List<AchievementEntity>

    @Query("SELECT * FROM achievements WHERE `key` = :key LIMIT 1")
    suspend fun getAchievementByKey(key: String): AchievementEntity?

    @Query("SELECT * FROM achievements WHERE updated_at > :since")
    suspend fun getModifiedSince(since: Long): List<AchievementEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(achievement: AchievementEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(achievements: List<AchievementEntity>)

    @Query("DELETE FROM achievements")
    suspend fun deleteAll()
}
