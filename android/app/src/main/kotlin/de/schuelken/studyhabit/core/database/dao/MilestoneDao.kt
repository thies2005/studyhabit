package de.schuelken.studyhabit.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import de.schuelken.studyhabit.core.database.SubjectMilestoneEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface MilestoneDao {
    @Query("SELECT * FROM subject_milestones WHERE subject_id = :subjectId AND is_deleted = 0 ORDER BY sort_order ASC")
    fun getMilestonesForSubjectFlow(subjectId: String): Flow<List<SubjectMilestoneEntity>>

    @Query("SELECT * FROM subject_milestones WHERE subject_id = :subjectId AND is_deleted = 0 ORDER BY sort_order ASC")
    suspend fun getMilestonesForSubject(subjectId: String): List<SubjectMilestoneEntity>

    @Query("SELECT * FROM subject_milestones WHERE is_deleted = 0")
    suspend fun getAllMilestones(): List<SubjectMilestoneEntity>

    @Query("SELECT * FROM subject_milestones WHERE id = :id LIMIT 1")
    suspend fun getById(id: String): SubjectMilestoneEntity?

    @Query("SELECT * FROM subject_milestones WHERE updated_at > :since")
    suspend fun getModifiedSince(since: Long): List<SubjectMilestoneEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(milestone: SubjectMilestoneEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(milestones: List<SubjectMilestoneEntity>)

    @Query("UPDATE subject_milestones SET is_deleted = 1, updated_at = :updatedAt WHERE id = :id")
    suspend fun softDelete(id: String, updatedAt: Long = System.currentTimeMillis())

    @Query("DELETE FROM subject_milestones")
    suspend fun deleteAll()
}
