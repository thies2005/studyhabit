package de.schuelken.studyhabit.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import de.schuelken.studyhabit.core.database.ProjectEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ProjectDao {
    @Query("SELECT * FROM projects WHERE is_deleted = 0 ORDER BY last_opened_at DESC")
    fun getAllProjectsFlow(): Flow<List<ProjectEntity>>

    @Query("SELECT * FROM projects WHERE is_deleted = 0 ORDER BY last_opened_at DESC")
    suspend fun getAllProjects(): List<ProjectEntity>

    @Query("SELECT * FROM projects WHERE id = :id AND is_deleted = 0 LIMIT 1")
    suspend fun getProjectById(id: String): ProjectEntity?

    @Query("SELECT * FROM projects WHERE id = :id AND is_deleted = 0 LIMIT 1")
    fun getProjectByIdFlow(id: String): Flow<ProjectEntity?>

    @Query("SELECT * FROM projects WHERE updated_at > :since")
    suspend fun getModifiedSince(since: Long): List<ProjectEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(project: ProjectEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(projects: List<ProjectEntity>)

    @Query("UPDATE projects SET last_opened_at = :time, updated_at = :time WHERE id = :id")
    suspend fun updateLastOpened(id: String, time: Long)

    @Query("UPDATE projects SET name = :name, icon = :icon, updated_at = :updatedAt WHERE id = :id")
    suspend fun renameProject(id: String, name: String, icon: String, updatedAt: Long = System.currentTimeMillis())

    @Query("UPDATE projects SET is_deleted = 1, updated_at = :updatedAt WHERE id = :id")
    suspend fun softDelete(id: String, updatedAt: Long = System.currentTimeMillis())

    @Query("DELETE FROM projects")
    suspend fun deleteAll()
}
