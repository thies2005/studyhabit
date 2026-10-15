package de.schuelken.studyhabit.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import de.schuelken.studyhabit.core.database.TopicEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TopicDao {
    @Query("SELECT * FROM topics WHERE subject_id = :subjectId AND is_deleted = 0 ORDER BY `order` ASC")
    fun getTopicsForSubjectFlow(subjectId: String): Flow<List<TopicEntity>>

    @Query("SELECT * FROM topics WHERE subject_id = :subjectId AND is_deleted = 0 ORDER BY `order` ASC")
    suspend fun getTopicsForSubject(subjectId: String): List<TopicEntity>

    @Query("SELECT * FROM topics WHERE is_deleted = 0")
    suspend fun getAllTopics(): List<TopicEntity>

    @Query("SELECT * FROM topics WHERE id = :id AND is_deleted = 0 LIMIT 1")
    suspend fun getTopicById(id: String): TopicEntity?

    @Query("SELECT * FROM topics WHERE updated_at > :since")
    suspend fun getModifiedSince(since: Long): List<TopicEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(topic: TopicEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(topics: List<TopicEntity>)

    @Query("UPDATE topics SET is_deleted = 1, updated_at = :updatedAt WHERE id = :id")
    suspend fun softDelete(id: String, updatedAt: Long = System.currentTimeMillis())

    @Query("DELETE FROM topics")
    suspend fun deleteAll()
}
