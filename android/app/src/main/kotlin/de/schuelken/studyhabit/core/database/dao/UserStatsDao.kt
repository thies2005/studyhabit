package de.schuelken.studyhabit.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import de.schuelken.studyhabit.core.database.UserStatsEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface UserStatsDao {
    @Query("SELECT * FROM user_stats_table WHERE id = 'default_stats' LIMIT 1")
    fun getUserStatsFlow(): Flow<UserStatsEntity?>

    @Query("SELECT * FROM user_stats_table WHERE id = 'default_stats' LIMIT 1")
    suspend fun getUserStats(): UserStatsEntity?

    @Query("SELECT * FROM user_stats_table WHERE updated_at > :since")
    suspend fun getModifiedSince(since: Long): List<UserStatsEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(stats: UserStatsEntity)

    @Query("DELETE FROM user_stats_table")
    suspend fun deleteAll()
}
