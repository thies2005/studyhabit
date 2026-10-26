package de.schuelken.studyhabit

import de.schuelken.studyhabit.core.database.AchievementEntity
import de.schuelken.studyhabit.core.database.SkillLabelEntity
import de.schuelken.studyhabit.core.database.SourceEntity
import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.database.dao.AchievementDao
import de.schuelken.studyhabit.core.database.dao.SessionDao
import de.schuelken.studyhabit.core.database.dao.SkillLabelDao
import de.schuelken.studyhabit.core.database.dao.SourceDao
import de.schuelken.studyhabit.core.service.AchievementEvaluator
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class FakeSessionDao : SessionDao {
    val sessions = mutableListOf<StudySessionEntity>()

    override fun getSessionsForSubjectFlow(subjectId: String): Flow<List<StudySessionEntity>> =
        flowOf(sessions.filter { it.subjectId == subjectId })

    override suspend fun getSessionsForSubject(subjectId: String): List<StudySessionEntity> =
        sessions.filter { it.subjectId == subjectId }

    override fun getAllSessionsFlow(): Flow<List<StudySessionEntity>> = flowOf(sessions)

    override suspend fun getAllSessions(): List<StudySessionEntity> = sessions

    override suspend fun getSessionById(id: String): StudySessionEntity? =
        sessions.firstOrNull { it.id == id }

    override fun getRecentSessionsFlow(limit: Int): Flow<List<StudySessionEntity>> =
        flowOf(sessions.take(limit))

    override fun getRecentSessionsForProjectFlow(projectId: String, limit: Int): Flow<List<StudySessionEntity>> =
        flowOf(sessions.take(limit))

    override fun getSessionsForProjectSinceFlow(projectId: String, sinceMs: Long): Flow<List<StudySessionEntity>> =
        flowOf(sessions.filter { it.startedAt >= sinceMs })

    override fun getSessionsSinceFlow(sinceMs: Long): Flow<List<StudySessionEntity>> =
        flowOf(sessions.filter { it.startedAt >= sinceMs })

    override suspend fun getModifiedSince(since: Long): List<StudySessionEntity> =
        sessions.filter { it.updatedAt > since }

    override suspend fun upsert(session: StudySessionEntity) {
        sessions.removeAll { it.id == session.id }
        sessions.add(session)
    }

    override suspend fun upsertAll(sessions: List<StudySessionEntity>) {
        sessions.forEach { upsert(it) }
    }

    override suspend fun softDelete(id: String, updatedAt: Long) {
        val s = getSessionById(id) ?: return
        upsert(s.copy(isDeleted = true, updatedAt = updatedAt))
    }

    override suspend fun cleanupOrphanedSessions(cutoff: Long, now: Long) {}

    override suspend fun deleteAll() {
        sessions.clear()
    }
}

class FakeSourceDao : SourceDao {
    val sources = mutableListOf<SourceEntity>()

    override fun getSourcesForSubjectFlow(subjectId: String): Flow<List<SourceEntity>> =
        flowOf(sources.filter { it.subjectId == subjectId })

    override suspend fun getSourcesForSubject(subjectId: String): List<SourceEntity> =
        sources.filter { it.subjectId == subjectId }

    override suspend fun getAllSources(): List<SourceEntity> = sources

    override suspend fun getSourceById(id: String): SourceEntity? =
        sources.firstOrNull { it.id == id }

    override suspend fun getModifiedSince(since: Long): List<SourceEntity> =
        sources.filter { it.updatedAt > since }

    override suspend fun upsert(source: SourceEntity) {
        sources.removeAll { it.id == source.id }
        sources.add(source)
    }

    override suspend fun upsertAll(sources: List<SourceEntity>) {
        sources.forEach { upsert(it) }
    }

    override suspend fun updatePageProgress(id: String, currentPage: Int, progressPercent: Double?, updatedAt: Long) {
        val s = getSourceById(id) ?: return
        upsert(s.copy(currentPage = currentPage, progressPercent = progressPercent, updatedAt = updatedAt))
    }

    override suspend fun softDelete(id: String, updatedAt: Long) {
        val s = getSourceById(id) ?: return
        upsert(s.copy(isDeleted = true, updatedAt = updatedAt))
    }

    override suspend fun deleteAll() {
        sources.clear()
    }
}

class FakeSkillLabelDao : SkillLabelDao {
    val labels = mutableListOf<SkillLabelEntity>()

    override fun getSkillLabelsForSubjectFlow(subjectId: String): Flow<List<SkillLabelEntity>> =
        flowOf(labels.filter { it.subjectId == subjectId })

    override suspend fun getAllSkillLabels(): List<SkillLabelEntity> = labels

    override suspend fun getModifiedSince(since: Long): List<SkillLabelEntity> =
        labels.filter { it.updatedAt > since }

    override suspend fun upsert(skillLabel: SkillLabelEntity) {
        labels.removeAll { it.id == skillLabel.id }
        labels.add(skillLabel)
    }

    override suspend fun upsertAll(skillLabels: List<SkillLabelEntity>) {
        skillLabels.forEach { upsert(it) }
    }

    override suspend fun softDelete(id: String, updatedAt: Long) {
        val l = labels.firstOrNull { it.id == id } ?: return
        upsert(l.copy(isDeleted = true, updatedAt = updatedAt))
    }

    override suspend fun deleteAll() {
        labels.clear()
    }
}

class FakeAchievementDao : AchievementDao {
    val achievements = mutableMapOf<String, AchievementEntity>()

    override fun getAllAchievementsFlow(): Flow<List<AchievementEntity>> =
        flowOf(achievements.values.toList())

    override suspend fun getAllAchievements(): List<AchievementEntity> =
        achievements.values.toList()

    override suspend fun getAchievementByKey(key: String): AchievementEntity? =
        achievements[key]

    override suspend fun getModifiedSince(since: Long): List<AchievementEntity> =
        achievements.values.filter { it.updatedAt > since }

    override suspend fun upsert(achievement: AchievementEntity) {
        achievements[achievement.key] = achievement
    }

    override suspend fun upsertAll(achievements: List<AchievementEntity>) {
        achievements.forEach { upsert(it) }
    }

    override suspend fun deleteAll() {
        achievements.clear()
    }
}

class AchievementEvaluatorTest {

    private lateinit var sessionDao: FakeSessionDao
    private lateinit var userStatsDao: FakeUserStatsDao
    private lateinit var sourceDao: FakeSourceDao
    private lateinit var skillLabelDao: FakeSkillLabelDao
    private lateinit var achievementDao: FakeAchievementDao
    private lateinit var evaluator: AchievementEvaluator

    @Before
    fun setup() {
        sessionDao = FakeSessionDao()
        userStatsDao = FakeUserStatsDao()
        sourceDao = FakeSourceDao()
        skillLabelDao = FakeSkillLabelDao()
        achievementDao = FakeAchievementDao()
        evaluator = AchievementEvaluator(
            sessionDao,
            userStatsDao,
            sourceDao,
            skillLabelDao,
            achievementDao
        )
    }

    @Test
    fun testInitialEvaluationUnlocksNothing() = runBlocking {
        val newlyUnlocked = evaluator.checkAndUnlock()
        assertTrue(newlyUnlocked.isEmpty())
    }

    @Test
    fun testStreakUnlock() = runBlocking {
        userStatsDao.stats = UserStatsEntity(currentStreak = 7)
        val newlyUnlocked = evaluator.checkAndUnlock()
        val keys = newlyUnlocked.map { it.key }
        assertTrue(keys.contains("streak_3"))
        assertTrue(keys.contains("streak_7"))
    }

    @Test
    fun testPomodoroAndConfidenceUnlock() = runBlocking {
        for (i in 1..10) {
            sessionDao.sessions.add(
                StudySessionEntity(
                    id = "s_$i",
                    subjectId = "sub_1",
                    pomodorosCompleted = 1,
                    actualDurationMinutes = 25,
                    confidenceRating = 5
                )
            )
        }

        val newlyUnlocked = evaluator.checkAndUnlock()
        val keys = newlyUnlocked.map { it.key }
        assertTrue(keys.contains("pomodoro_10"))
        assertTrue(keys.contains("confidence_5"))
        assertTrue(keys.contains("confidence_10"))
        assertTrue(keys.contains("sessions_5"))

        // Re-running does not re-award already unlocked
        val secondRun = evaluator.checkAndUnlock()
        assertTrue(secondRun.isEmpty())
    }

    @Test
    fun testPdfSourceUnlock() = runBlocking {
        sourceDao.sources.add(
            SourceEntity(
                id = "src_1",
                subjectId = "sub_1",
                type = "pdf",
                title = "Calculus Book"
            )
        )

        val newlyUnlocked = evaluator.checkAndUnlock()
        val keys = newlyUnlocked.map { it.key }
        assertTrue(keys.contains("first_pdf"))
    }
}
