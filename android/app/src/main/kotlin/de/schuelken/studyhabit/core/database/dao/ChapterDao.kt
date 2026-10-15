package de.schuelken.studyhabit.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import de.schuelken.studyhabit.core.database.ChapterEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ChapterDao {
    @Query("SELECT * FROM chapters WHERE topic_id = :topicId AND is_deleted = 0 ORDER BY `order` ASC")
    fun getChaptersForTopicFlow(topicId: String): Flow<List<ChapterEntity>>

    @Query("SELECT * FROM chapters WHERE topic_id = :topicId AND is_deleted = 0 ORDER BY `order` ASC")
    suspend fun getChaptersForTopic(topicId: String): List<ChapterEntity>

    @Query("SELECT * FROM chapters WHERE is_deleted = 0")
    suspend fun getAllChapters(): List<ChapterEntity>

    @Query("SELECT * FROM chapters WHERE id = :id AND is_deleted = 0 LIMIT 1")
    suspend fun getChapterById(id: String): ChapterEntity?

    @Query("SELECT * FROM chapters WHERE updated_at > :since")
    suspend fun getModifiedSince(since: Long): List<ChapterEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(chapter: ChapterEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(chapters: List<ChapterEntity>)

    @Query("UPDATE chapters SET is_deleted = 1, updated_at = :updatedAt WHERE id = :id")
    suspend fun softDelete(id: String, updatedAt: Long = System.currentTimeMillis())

    @Query("DELETE FROM chapters")
    suspend fun deleteAll()
}
