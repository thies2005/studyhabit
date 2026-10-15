package de.schuelken.studyhabit.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import de.schuelken.studyhabit.core.database.SubjectEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface SubjectDao {
    @Query("SELECT * FROM subjects WHERE project_id = :projectId AND is_deleted = 0 ORDER BY created_at DESC")
    fun getSubjectsForProjectFlow(projectId: String): Flow<List<SubjectEntity>>

    @Query("SELECT * FROM subjects WHERE project_id = :projectId AND is_deleted = 0 ORDER BY created_at DESC")
    suspend fun getSubjectsForProject(projectId: String): List<SubjectEntity>

    @Query("SELECT * FROM subjects WHERE is_deleted = 0 ORDER BY created_at DESC")
    fun getAllSubjectsFlow(): Flow<List<SubjectEntity>>

    @Query("SELECT * FROM subjects WHERE is_deleted = 0 ORDER BY created_at DESC")
    suspend fun getAllSubjects(): List<SubjectEntity>

    @Query("SELECT * FROM subjects WHERE id = :id AND is_deleted = 0 LIMIT 1")
    suspend fun getSubjectById(id: String): SubjectEntity?

    @Query("SELECT * FROM subjects WHERE id = :id AND is_deleted = 0 LIMIT 1")
    fun getSubjectByIdFlow(id: String): Flow<SubjectEntity?>

    @Query("SELECT * FROM subjects WHERE updated_at > :since")
    suspend fun getModifiedSince(since: Long): List<SubjectEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(subject: SubjectEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(subjects: List<SubjectEntity>)

    @Query("UPDATE subjects SET xp_total = MAX(0, xp_total + :xpDelta), updated_at = :updatedAt WHERE id = :subjectId")
    suspend fun updateXp(subjectId: String, xpDelta: Int, updatedAt: Long = System.currentTimeMillis())

    @Query("UPDATE subjects SET is_deleted = 1, updated_at = :updatedAt WHERE id = :id")
    suspend fun softDelete(id: String, updatedAt: Long = System.currentTimeMillis())

    @Query("DELETE FROM subjects")
    suspend fun deleteAll()
}
