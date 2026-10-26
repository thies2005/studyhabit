package de.schuelken.studyhabit.core.service

import android.content.Context
import de.schuelken.studyhabit.core.database.AchievementEntity
import de.schuelken.studyhabit.core.database.AppDatabase
import de.schuelken.studyhabit.core.database.ChapterEntity
import de.schuelken.studyhabit.core.database.ProjectEntity
import de.schuelken.studyhabit.core.database.SkillLabelEntity
import de.schuelken.studyhabit.core.database.SourceEntity
import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.database.SubjectEntity
import de.schuelken.studyhabit.core.database.SubjectMilestoneEntity
import de.schuelken.studyhabit.core.database.TopicEntity
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.model.ImportMode
import de.schuelken.studyhabit.core.preferences.AppPreferences
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import java.io.File
import java.time.Instant

@Serializable
data class ExportDocument(
    val exportVersion: Int = 2,
    val exportedAt: String,
    val userStats: UserStatsEntity,
    val projects: List<ExportProject>,
    val achievements: List<AchievementEntity>,
    val settings: Map<String, JsonElement>? = null,
)

@Serializable
data class ExportProject(
    val project: ProjectEntity,
    val subjects: List<ExportSubject>,
)

@Serializable
data class ExportSubject(
    val subject: SubjectEntity,
    val topics: List<TopicEntity> = emptyList(),
    val chapters: List<ChapterEntity> = emptyList(),
    val sessions: List<StudySessionEntity> = emptyList(),
    val sources: List<SourceEntity> = emptyList(),
    val skillLabels: List<SkillLabelEntity> = emptyList(),
    val milestones: List<SubjectMilestoneEntity> = emptyList(),
)

data class ImportResult(
    val projectCount: Int,
    val subjectCount: Int,
    val sessionCount: Int,
    val sourceCount: Int,
    val errors: List<String> = emptyList(),
)

class ExportImportService(
    private val context: Context,
    private val database: AppDatabase,
    private val preferences: AppPreferences,
) {
    val json = Json {
        ignoreUnknownKeys = true
        prettyPrint = true
        encodeDefaults = true
    }

    suspend fun buildExportDocument(includeDeleted: Boolean = false): ExportDocument {
        val projects = if (includeDeleted) database.projectDao().getModifiedSince(-1L) else database.projectDao().getAllProjects()
        val subjects = if (includeDeleted) database.subjectDao().getModifiedSince(-1L) else database.subjectDao().getAllSubjects()
        val topics = if (includeDeleted) database.topicDao().getModifiedSince(-1L) else database.topicDao().getAllTopics()
        val chapters = if (includeDeleted) database.chapterDao().getModifiedSince(-1L) else database.chapterDao().getAllChapters()
        val sessions = if (includeDeleted) database.sessionDao().getModifiedSince(-1L) else database.sessionDao().getAllSessions()
        val sources = if (includeDeleted) database.sourceDao().getModifiedSince(-1L) else database.sourceDao().getAllSources()
        val skillLabels = if (includeDeleted) database.skillLabelDao().getModifiedSince(-1L) else database.skillLabelDao().getAllSkillLabels()
        val milestones = if (includeDeleted) database.milestoneDao().getModifiedSince(-1L) else database.milestoneDao().getAllMilestones()
        val achievements = database.achievementDao().getAllAchievements()
        val stats = database.userStatsDao().getUserStats() ?: UserStatsEntity()

        val exportProjects = projects.map { project ->
            val projectSubjects = subjects.filter { it.projectId == project.id }
            val exportSubjects = projectSubjects.map { subject ->
                val subjectTopics = topics.filter { it.subjectId == subject.id }
                val topicIds = subjectTopics.map { it.id }.toSet()
                val subjectChapters = chapters.filter { topicIds.contains(it.topicId) }
                val subjectSessions = sessions.filter { it.subjectId == subject.id }
                val subjectSources = sources.filter { it.subjectId == subject.id }
                val subjectSkillLabels = skillLabels.filter { it.subjectId == subject.id }
                val subjectMilestones = milestones.filter { it.subjectId == subject.id }

                ExportSubject(
                    subject = subject,
                    topics = subjectTopics,
                    chapters = subjectChapters,
                    sessions = subjectSessions,
                    sources = subjectSources,
                    skillLabels = subjectSkillLabels,
                    milestones = subjectMilestones,
                )
            }
            ExportProject(project = project, subjects = exportSubjects)
        }

        val settingsMap = preferences.getAllowedSettingsMap().mapValues { (_, value) ->
            when (value) {
                is Boolean -> JsonPrimitive(value)
                is Number -> JsonPrimitive(value)
                is String -> JsonPrimitive(value)
                else -> JsonPrimitive(value.toString())
            }
        }

        return ExportDocument(
            exportVersion = 2,
            exportedAt = Instant.now().toString(),
            userStats = stats,
            projects = exportProjects,
            achievements = achievements,
            settings = settingsMap.ifEmpty { null },
        )
    }

    suspend fun exportToJson(): File {
        val document = buildExportDocument()
        val jsonString = json.encodeToString(document)
        val tempDir = context.cacheDir
        val timestamp = System.currentTimeMillis()
        val file = File(tempDir, "studyhabit_export_$timestamp.json")
        file.writeText(jsonString)
        return file
    }

    suspend fun importFromJson(jsonString: String, mode: ImportMode): ImportResult {
        val errors = mutableListOf<String>()
        var projectCount = 0
        var subjectCount = 0
        var sessionCount = 0
        var sourceCount = 0

        try {
            val doc = json.decodeFromString<ExportDocument>(jsonString)

            if (mode == ImportMode.REPLACE) {
                database.skillLabelDao().deleteAll()
                database.milestoneDao().deleteAll()
                database.sourceDao().deleteAll()
                database.sessionDao().deleteAll()
                database.chapterDao().deleteAll()
                database.topicDao().deleteAll()
                database.subjectDao().deleteAll()
                database.projectDao().deleteAll()
                database.achievementDao().deleteAll()
                database.userStatsDao().deleteAll()
            }

            for (exportProj in doc.projects) {
                database.projectDao().upsert(exportProj.project)
                projectCount++

                for (exportSubj in exportProj.subjects) {
                    database.subjectDao().upsert(exportSubj.subject)
                    subjectCount++

                    if (exportSubj.topics.isNotEmpty()) {
                        database.topicDao().upsertAll(exportSubj.topics)
                    }
                    if (exportSubj.chapters.isNotEmpty()) {
                        database.chapterDao().upsertAll(exportSubj.chapters)
                    }
                    if (exportSubj.sessions.isNotEmpty()) {
                        database.sessionDao().upsertAll(exportSubj.sessions)
                        sessionCount += exportSubj.sessions.size
                    }
                    if (exportSubj.sources.isNotEmpty()) {
                        database.sourceDao().upsertAll(exportSubj.sources)
                        sourceCount += exportSubj.sources.size
                    }
                    if (exportSubj.skillLabels.isNotEmpty()) {
                        database.skillLabelDao().upsertAll(exportSubj.skillLabels)
                    }
                    if (exportSubj.milestones.isNotEmpty()) {
                        database.milestoneDao().upsertAll(exportSubj.milestones)
                    }
                }
            }

            if (doc.achievements.isNotEmpty()) {
                database.achievementDao().upsertAll(doc.achievements)
            }

            database.userStatsDao().upsert(doc.userStats)

            doc.settings?.let { settings ->
                preferences.applySettingsMap(settings)
            }
        } catch (e: Exception) {
            errors.add(e.message ?: "Unknown import error")
        }

        return ImportResult(
            projectCount = projectCount,
            subjectCount = subjectCount,
            sessionCount = sessionCount,
            sourceCount = sourceCount,
            errors = errors,
        )
    }
}
