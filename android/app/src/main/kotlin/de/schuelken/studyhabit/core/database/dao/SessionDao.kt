package de.schuelken.studyhabit.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import de.schuelken.studyhabit.core.database.StudySessionEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface SessionDao {
    @Query("SELECT * FROM study_sessions WHERE subject_id = :subjectId AND is_deleted = 0 ORDER BY started_at DESC")
    fun getSessionsForSubjectFlow(subjectId: String): Flow<List<StudySessionEntity>>

    @Query("SELECT * FROM study_sessions WHERE subject_id = :subjectId AND is_deleted = 0 ORDER BY started_at DESC")
    suspend fun getSessionsForSubject(subjectId: String): List<StudySessionEntity>

    @Query("SELECT * FROM study_sessions WHERE is_deleted = 0 ORDER BY started_at DESC")
    fun getAllSessionsFlow(): Flow<List<StudySessionEntity>>

    @Query("SELECT * FROM study_sessions WHERE is_deleted = 0 ORDER BY started_at DESC")
    suspend fun getAllSessions(): List<StudySessionEntity>

    @Query("SELECT * FROM study_sessions WHERE id = :id AND is_deleted = 0 LIMIT 1")
    suspend fun getSessionById(id: String): StudySessionEntity?

    @Query("SELECT * FROM study_sessions WHERE is_deleted = 0 ORDER BY started_at DESC LIMIT :limit")
    fun getRecentSessionsFlow(limit: Int = 10): Flow<List<StudySessionEntity>>

    @Query("""
        SELECT s.* FROM study_sessions s
        INNER JOIN subjects subj ON s.subject_id = subj.id
        WHERE subj.project_id = :projectId AND s.is_deleted = 0 AND subj.is_deleted = 0
        ORDER BY s.started_at DESC
        LIMIT :limit
    """)
    fun getRecentSessionsForProjectFlow(projectId: String, limit: Int = 10): Flow<List<StudySessionEntity>>

    @Query("""
        SELECT s.* FROM study_sessions s
        INNER JOIN subjects subj ON s.subject_id = subj.id
        WHERE subj.project_id = :projectId AND s.is_deleted = 0 AND subj.is_deleted = 0 AND s.started_at >= :sinceMs
        ORDER BY s.started_at DESC
    """)
    fun getSessionsForProjectSinceFlow(projectId: String, sinceMs: Long): Flow<List<StudySessionEntity>>

    @Query("SELECT * FROM study_sessions WHERE is_deleted = 0 AND started_at >= :sinceMs ORDER BY started_at DESC")
    fun getSessionsSinceFlow(sinceMs: Long): Flow<List<StudySessionEntity>>

    @Query("SELECT * FROM study_sessions WHERE updated_at > :since")
    suspend fun getModifiedSince(since: Long): List<StudySessionEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(session: StudySessionEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(sessions: List<StudySessionEntity>)

    @Query("UPDATE study_sessions SET is_deleted = 1, updated_at = :updatedAt WHERE id = :id")
    suspend fun softDelete(id: String, updatedAt: Long = System.currentTimeMillis())

    @Query("""
        UPDATE study_sessions
        SET ended_at = CASE
            WHEN is_free_timer = 1 OR planned_duration_minutes = 0
            THEN COALESCE(updated_at, started_at + 60000)
            ELSE started_at + (planned_duration_minutes * 60000)
        END,
        actual_duration_minutes = CASE
            WHEN is_free_timer = 1 OR planned_duration_minutes = 0
            THEN MAX(1, CAST((COALESCE(updated_at, :cutoffTimestamp) - started_at) / 60000 AS INTEGER))
            ELSE planned_duration_minutes
        END,
        updated_at = :now
        WHERE ended_at IS NULL AND started_at < :cutoffTimestamp
    """)
    suspend fun cleanupOrphanedSessions(cutoffTimestamp: Long, now: Long = System.currentTimeMillis())

    @Query("DELETE FROM study_sessions")
    suspend fun deleteAll()
}
