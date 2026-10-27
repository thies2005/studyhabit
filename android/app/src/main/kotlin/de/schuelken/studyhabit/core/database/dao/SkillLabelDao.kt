package de.schuelken.studyhabit.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import de.schuelken.studyhabit.core.database.SkillLabelEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface SkillLabelDao {
    @Query("SELECT * FROM skill_labels WHERE subject_id = :subjectId AND is_deleted = 0")
    fun getSkillLabelsForSubjectFlow(subjectId: String): Flow<List<SkillLabelEntity>>

    @Query("SELECT * FROM skill_labels WHERE is_deleted = 0")
    suspend fun getAllSkillLabels(): List<SkillLabelEntity>

    @Query("SELECT * FROM skill_labels WHERE id = :id LIMIT 1")
    suspend fun getById(id: String): SkillLabelEntity?

    @Query("SELECT * FROM skill_labels WHERE updated_at > :since")
    suspend fun getModifiedSince(since: Long): List<SkillLabelEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(skillLabel: SkillLabelEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(skillLabels: List<SkillLabelEntity>)

    @Query("UPDATE skill_labels SET is_deleted = 1, updated_at = :updatedAt WHERE id = :id")
    suspend fun softDelete(id: String, updatedAt: Long = System.currentTimeMillis())

    @Query("DELETE FROM skill_labels")
    suspend fun deleteAll()
}
