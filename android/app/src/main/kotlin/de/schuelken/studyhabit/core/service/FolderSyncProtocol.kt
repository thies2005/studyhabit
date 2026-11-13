package de.schuelken.studyhabit.core.service

import de.schuelken.studyhabit.core.database.AchievementEntity
import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.database.UserStatsEntity
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.security.MessageDigest

/** Complete publications are immutable; a visible filename alone does not commit a publication. */
internal object FolderSyncProtocol {
    private val json = Json { encodeDefaults = true }
    private val deviceFilePattern = Regex("studyhabit_device_[0-9a-f-]{36}\\.json")
    private val legacyPublicationPattern = Regex("studyhabit_device_[0-9a-f-]{36}_[0-9a-f-]{36}\\.json")

    @Serializable
    private data class Publication(val protocol: Int, val checksum: String, val payload: String)

    fun deviceFileName(deviceId: String): String = "studyhabit_device_${deviceId}.json"

    fun fileName(deviceId: String, publicationId: String): String =
        "studyhabit_device_${deviceId}_${publicationId}.json"

    fun isPublication(name: String): Boolean =
        deviceFilePattern.matches(name) || legacyPublicationPattern.matches(name)

    fun isOwnLegacyPublication(name: String, deviceId: String): Boolean =
        legacyPublicationPattern.matches(name) && name.startsWith("studyhabit_device_${deviceId}_")

    fun sameSnapshot(left: ExportDocument, right: ExportDocument): Boolean =
        left.copy(exportedAt = "") == right.copy(exportedAt = "")

    fun encode(document: ExportDocument): String {
        val payload = json.encodeToString(document)
        return json.encodeToString(Publication(1, checksum(payload), payload))
    }

    fun decode(contents: String): ExportDocument {
        val publication = json.decodeFromString<Publication>(contents)
        require(publication.protocol == 1) { "Unsupported device snapshot protocol" }
        require(publication.checksum == checksum(publication.payload)) { "Incomplete device snapshot" }
        return BackupCodec.decode(publication.payload)
    }

    private fun checksum(payload: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(payload.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

    /** Total ordering ensures every reader chooses the same winner, including equal timestamps. */
    fun <T> compare(
        left: T,
        right: T,
        updatedAt: (T) -> Long,
        isDeleted: (T) -> Boolean,
        stableContent: (T) -> String,
    ): Int = updatedAt(left).compareTo(updatedAt(right)).takeIf { it != 0 }
        ?: isDeleted(left).compareTo(isDeleted(right)).takeIf { it != 0 }
        ?: if (left == right) 0 else stableContent(left).compareTo(stableContent(right))

    data class MergePlan<T>(val pushed: Int, val updates: List<Pair<T, T?>>)

    fun <T> planRows(
        remote: List<T>,
        local: List<T>,
        id: (T) -> String,
        updatedAt: (T) -> Long,
        deleted: (T) -> Boolean,
        stable: (T) -> String,
    ): MergePlan<T> {
        val remoteById = mutableMapOf<String, T>()
        for (entry in remote) {
            val key = id(entry)
            val previous = remoteById[key]
            if (previous == null || compare(entry, previous, updatedAt, deleted, stable) > 0) {
                remoteById[key] = entry
            }
        }
        var pushed = 0
        val updates = mutableListOf<Pair<T, T?>>()
        for (entry in local) {
            val other = remoteById.remove(id(entry))
            if (other == null) {
                pushed++
            } else {
                val order = compare(entry, other, updatedAt, deleted, stable)
                if (order > 0) pushed++
                if (order < 0) updates.add(other to entry)
            }
        }
        for (entry in remoteById.values) updates.add(entry to null)
        return MergePlan(pushed, updates)
    }

    fun mergeAchievements(
        remote: List<AchievementEntity>,
        local: List<AchievementEntity>,
    ): MergePlan<AchievementEntity> {
        val localByKey = local.associateBy { it.key }
        val remoteByKey = remote.groupBy { it.key }
        val allKeys = (localByKey.keys + remoteByKey.keys).toSortedSet()

        var pushed = 0
        val updates = mutableListOf<Pair<AchievementEntity, AchievementEntity?>>()

        for (key in allKeys) {
            val localEntry = localByKey[key]
            val remoteEntries = remoteByKey[key].orEmpty()
            val allEntries = listOfNotNull(localEntry) + remoteEntries

            val mergedProgress = allEntries.maxOf { it.progress.takeIf(Double::isFinite) ?: 0.0 }
            val mergedUnlockedAt = allEntries.mapNotNull { it.unlockedAt }.minOrNull()
            val mergedUpdatedAt = allEntries.maxOf { it.updatedAt }
            val merged = AchievementEntity(
                key = key,
                unlockedAt = mergedUnlockedAt,
                progress = mergedProgress,
                updatedAt = mergedUpdatedAt,
            )

            if (remoteEntries.isEmpty()) {
                if (localEntry != null) pushed++
            } else if (localEntry != null) {
                val bestRemoteProgress = remoteEntries.maxOf { it.progress.takeIf(Double::isFinite) ?: 0.0 }
                val bestRemoteUnlockedAt = remoteEntries.mapNotNull { it.unlockedAt }.minOrNull()
                val localProgress = localEntry.progress.takeIf(Double::isFinite) ?: 0.0
                val localAheadOnProgress = localProgress > bestRemoteProgress
                val localAheadOnUnlock = localEntry.unlockedAt != null &&
                    (bestRemoteUnlockedAt == null || localEntry.unlockedAt < bestRemoteUnlockedAt)
                if (localAheadOnProgress || localAheadOnUnlock) {
                    pushed++
                }
            }

            val localChanged = localEntry == null ||
                mergedProgress > (localEntry.progress.takeIf(Double::isFinite) ?: 0.0) ||
                mergedUnlockedAt != localEntry.unlockedAt
            if (localChanged) {
                updates.add(merged to localEntry)
            }
        }
        return MergePlan(pushed, updates)
    }

    fun sessions(document: ExportDocument): List<StudySessionEntity> =
        document.projects.flatMap { it.subjects.flatMap { subject -> subject.sessions } }

    fun bonusXp(stats: UserStatsEntity, sessions: List<StudySessionEntity>): Int =
        (stats.totalXp.toLong() - sessions.filterNot { it.isDeleted }.sumOf { it.xpEarned.toLong() })
            .coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()

    fun reconcileStats(
        base: UserStatsEntity,
        sessions: List<StudySessionEntity>,
        bonusXp: Int,
        longestStreak: Int,
    ): UserStatsEntity {
        val active = sessions.filterNot { it.isDeleted }
        val xp = (active.sumOf { it.xpEarned.toLong() } + bonusXp)
            .coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()
        val minutes = active.sumOf { it.actualDurationMinutes.toLong() }
            .coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()
        return base.copy(
            totalXp = xp,
            currentLevel = XpCalculator.calculateLevel(xp),
            totalStudyMinutes = minutes,
            longestStreak = maxOf(longestStreak, base.currentStreak),
        )
    }

    /** PDF links grant access on the originating Android install only. */
    fun portable(document: ExportDocument): ExportDocument = document.copy(
        projects = document.projects.map { project ->
            project.copy(project = project.project.copy(lastOpenedAt = 0), subjects = project.subjects.map { subject ->
                subject.copy(sources = subject.sources.map { source ->
                    if (source.type == "pdf") source.copy(filePath = null) else source
                })
            })
        },
    )
}
