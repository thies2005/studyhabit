package de.schuelken.studyhabit.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import de.schuelken.studyhabit.core.database.SourceEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface SourceDao {
    @Query("SELECT * FROM sources WHERE subject_id = :subjectId AND is_deleted = 0 ORDER BY added_at DESC")
    fun getSourcesForSubjectFlow(subjectId: String): Flow<List<SourceEntity>>

    @Query("SELECT * FROM sources WHERE subject_id = :subjectId AND is_deleted = 0 ORDER BY added_at DESC")
    suspend fun getSourcesForSubject(subjectId: String): List<SourceEntity>

    @Query("SELECT * FROM sources WHERE is_deleted = 0")
    suspend fun getAllSources(): List<SourceEntity>

    @Query("SELECT * FROM sources WHERE id = :id AND is_deleted = 0 LIMIT 1")
    suspend fun getSourceById(id: String): SourceEntity?

    @Query("SELECT * FROM sources WHERE updated_at > :since")
    suspend fun getModifiedSince(since: Long): List<SourceEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(source: SourceEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(sources: List<SourceEntity>)

    @Query("UPDATE sources SET current_page = :currentPage, progress_percent = :progressPercent, updated_at = :updatedAt WHERE id = :id")
    suspend fun updatePageProgress(id: String, currentPage: Int, progressPercent: Double?, updatedAt: Long = System.currentTimeMillis())

    @Query("UPDATE sources SET is_deleted = 1, updated_at = :updatedAt WHERE id = :id")
    suspend fun softDelete(id: String, updatedAt: Long = System.currentTimeMillis())

    @Query("DELETE FROM sources")
    suspend fun deleteAll()
}
