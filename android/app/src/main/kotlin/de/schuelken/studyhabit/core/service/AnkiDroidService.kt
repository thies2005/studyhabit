package de.schuelken.studyhabit.core.service

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.ContextCompat
import androidx.room.withTransaction
import de.schuelken.studyhabit.core.database.AppDatabase
import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.preferences.AppPreferences
import de.schuelken.studyhabit.ui.widget.StudyHabitWidgetProvider
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

data class AnkiDeckInfo(
    val deckId: Long,
    val deckName: String,
    val dueCount: Int
)

typealias AnkiDeck = AnkiDeckInfo

data class AnkiDeckStudyStats(
    val cardsStudiedToday: Int,
    val durationMinutes: Int,
    val dueCount: Int
)

data class AnkiDeckGroup(
    val parentDeck: AnkiDeckInfo,
    val subDecks: List<AnkiDeckInfo>,
    val totalDueCount: Int
)

data class AnkiDeckNode(
    val fullPath: String,
    val shortName: String,
    val deck: AnkiDeckInfo,
    val children: List<AnkiDeckNode>,
    val totalDueCount: Int
)

class AnkiDroidService(
    private val context: Context,
    private val database: AppDatabase,
    private val preferences: AppPreferences,
    private val streakManager: StreakManager,
    private val achievementEvaluator: AchievementEvaluator,
    private val onDataChanged: () -> Unit
) {

    companion object {
        const val READ_WRITE_PERMISSION = "com.ichi2.anki.permission.READ_WRITE_DATABASE"

        fun buildDeckTree(decks: List<AnkiDeckInfo>): List<AnkiDeckNode> {
            val validDecks = decks.filter { it.deckName.isNotBlank() }
            if (validDecks.isEmpty()) return emptyList()

            val explicitByPath = mutableMapOf<String, AnkiDeckInfo>()
            val rootPaths = linkedSetOf<String>()
            val childrenByParent = mutableMapOf<String, LinkedHashSet<String>>()

            for (deck in validDecks) {
                val segments = deck.deckName.split("::").map { it.trim() }.filter { it.isNotEmpty() }
                if (segments.isEmpty()) continue
                val normPath = segments.joinToString("::")
                explicitByPath[normPath] = deck.copy(deckName = normPath)
                rootPaths.add(segments[0])
                for (i in 1 until segments.size) {
                    val parentPath = segments.take(i).joinToString("::")
                    val childPath = segments.take(i + 1).joinToString("::")
                    childrenByParent.getOrPut(parentPath) { linkedSetOf() }.add(childPath)
                }
            }

            fun buildNode(path: String): AnkiDeckNode {
                val shortName = path.substringAfterLast("::")
                val childPaths = childrenByParent[path]
                    ?.sortedBy { it.substringAfterLast("::").lowercase() }
                    ?: emptyList()
                val childNodes = childPaths.map { buildNode(it) }
                val explicit = explicitByPath[path]
                val childrenDueSum = childNodes.sumOf { it.totalDueCount }
                val totalDue = maxOf(explicit?.dueCount ?: 0, childrenDueSum)
                val deckInfo = explicit?.copy(dueCount = totalDue)
                    ?: AnkiDeckInfo(
                        deckId = -path.hashCode().toLong(),
                        deckName = path,
                        dueCount = totalDue
                    )
                return AnkiDeckNode(
                    fullPath = path,
                    shortName = shortName,
                    deck = deckInfo,
                    children = childNodes,
                    totalDueCount = totalDue
                )
            }

            return rootPaths.map { buildNode(it) }
        }

        fun groupDecksHierarchically(decks: List<AnkiDeckInfo>): List<AnkiDeckGroup> {
            val validDecks = decks.filter { it.deckName.isNotBlank() }
            val rootNames = validDecks.map { it.deckName.substringBefore("::").trim() }
                .filter { it.isNotEmpty() }
                .distinct()

            return rootNames.map { rootName ->
                val explicitParent = validDecks.firstOrNull { it.deckName.trim() == rootName }
                val subDecks = validDecks.filter { it.deckName.startsWith("$rootName::") }.sortedBy { it.deckName }
                val sumSubDue = subDecks.sumOf { it.dueCount }
                val totalDue = maxOf(explicitParent?.dueCount ?: 0, sumSubDue)
                val parentDeck = explicitParent?.copy(dueCount = totalDue)
                    ?: AnkiDeckInfo(deckId = -rootName.hashCode().toLong(), deckName = rootName, dueCount = totalDue)
                AnkiDeckGroup(parentDeck = parentDeck, subDecks = subDecks, totalDueCount = totalDue)
            }
        }

        fun calculateReviewMinutes(cardsCount: Int, reviewTimestampsSec: List<Long>): Int {
            if (cardsCount <= 0) return 0
            if (reviewTimestampsSec.isEmpty()) {
                return maxOf(1, (cardsCount * 10 + 30) / 60)
            }

            val sorted = reviewTimestampsSec.sorted()
            var totalSeconds = 10L
            for (i in 1 until sorted.size) {
                val delta = (sorted[i] - sorted[i - 1]).coerceAtLeast(0L)
                totalSeconds += if (delta in 1L..60L) delta else 10L
            }
            return maxOf(1, ((totalSeconds + 30) / 60).toInt())
        }
    }

    fun isAnkiInstalled(): Boolean {
        val hasPackage = runCatching {
            context.packageManager.getPackageInfo("com.ichi2.anki", 0) != null
        }.getOrDefault(false)

        val hasProvider = context.packageManager.resolveContentProvider(
            "com.ichi2.anki.flashcards", 0
        ) != null

        return hasPackage || hasProvider
    }

    fun hasAnkiPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            READ_WRITE_PERMISSION
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun getDecks(): List<AnkiDeckInfo> {
        if (!isAnkiInstalled() || !hasAnkiPermission()) return emptyList()

        return runCatching {
            val decksUri = Uri.parse("content://com.ichi2.anki.flashcards/decks")
            context.contentResolver.query(decksUri, null, null, null, null)?.use { cursor ->
                val idCol = cursor.getColumnIndex("deck_id")
                val nameCol = cursor.getColumnIndex("deck_name")
                val countsCol = cursor.getColumnIndex("deck_counts")
                val result = mutableListOf<AnkiDeckInfo>()

                while (cursor.moveToNext()) {
                    val id = if (idCol >= 0) cursor.getLong(idCol) else cursor.position.toLong()
                    val name = if (nameCol >= 0) cursor.getString(nameCol) else ""
                    var due = 0
                    if (countsCol >= 0) {
                        val countsJson = cursor.getString(countsCol)
                        if (!countsJson.isNullOrBlank()) {
                            due = runCatching {
                                val trimmed = countsJson.trim().removePrefix("[").removeSuffix("]")
                                trimmed.split(",").mapNotNull { it.trim().toIntOrNull() }.sum()
                            }.getOrDefault(0)
                        }
                    }
                    if (name.isNotBlank()) {
                        result.add(AnkiDeckInfo(deckId = id, deckName = name, dueCount = due))
                    }
                }
                result
            } ?: emptyList()
        }.getOrDefault(emptyList())
    }

    fun getTodayDeckStudyStats(deckName: String, dueCount: Int = 0): AnkiDeckStudyStats {
        if (!isAnkiInstalled() || !hasAnkiPermission()) {
            return AnkiDeckStudyStats(cardsStudiedToday = 0, durationMinutes = 0, dueCount = dueCount)
        }

        val safeDeckName = deckName.replace("\"", "")
        val cardsUri = Uri.parse("content://com.ichi2.anki.flashcards/cards")
        val selection = "deck:\"$safeDeckName\" rated:1"

        // 1. Try querying /cards with timestamp projection
        val statsFromCards = runCatching {
            val projection = arrayOf("_id", "last_review_time_seconds")
            context.contentResolver.query(cardsUri, projection, selection, null, null)?.use { cursor ->
                val timeCol = cursor.getColumnIndex("last_review_time_seconds")
                val timestamps = mutableListOf<Long>()
                while (cursor.moveToNext()) {
                    if (timeCol >= 0 && !cursor.isNull(timeCol)) {
                        timestamps.add(cursor.getLong(timeCol))
                    }
                }
                val count = cursor.count
                val duration = calculateReviewMinutes(count, timestamps)
                AnkiDeckStudyStats(cardsStudiedToday = count, durationMinutes = duration, dueCount = dueCount)
            }
        }.getOrNull()

        if (statsFromCards != null) return statsFromCards

        // 2. Try querying /cards with just _id
        val fallbackCards = runCatching {
            context.contentResolver.query(cardsUri, arrayOf("_id"), selection, null, null)?.use { cursor ->
                val count = cursor.count
                val duration = calculateReviewMinutes(count, emptyList())
                AnkiDeckStudyStats(cardsStudiedToday = count, durationMinutes = duration, dueCount = dueCount)
            }
        }.getOrNull()

        if (fallbackCards != null) return fallbackCards

        // 3. Fallback to /notes
        val notesUri = Uri.parse("content://com.ichi2.anki.flashcards/notes")
        val fallbackNotes = runCatching {
            context.contentResolver.query(notesUri, arrayOf("_id"), selection, null, null)?.use { cursor ->
                val count = cursor.count
                val duration = calculateReviewMinutes(count, emptyList())
                AnkiDeckStudyStats(cardsStudiedToday = count, durationMinutes = duration, dueCount = dueCount)
            }
        }.getOrNull()

        return fallbackNotes ?: AnkiDeckStudyStats(cardsStudiedToday = 0, durationMinutes = 0, dueCount = dueCount)
    }

    suspend fun syncLinkedDecks(subjectId: String? = null): Int {
        if (!isAnkiInstalled() || !hasAnkiPermission()) return 0

        val ankiSources = if (subjectId != null) {
            database.sourceDao().getSourcesForSubject(subjectId).filter { it.type == "anki" && !it.isDeleted }
        } else {
            database.sourceDao().getAllSources().filter { it.type == "anki" && !it.isDeleted }
        }

        if (ankiSources.isEmpty()) return 0

        val decks = runCatching { getDecks() }.getOrDefault(emptyList())
        val now = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
        val todayStr = LocalDate.now(zone).toString()
        var syncedCount = 0

        for (source in ankiSources) {
            val rawPath = source.filePath?.removePrefix("anki://deck/")
            val deckId = rawPath?.substringBefore("?")?.toLongOrNull()
            val encodedName = rawPath?.substringAfter("?name=", "")
                ?.takeIf { it.isNotEmpty() }
                ?.let { Uri.decode(it) }
            val matchedDeck = when {
                deckId != null && deckId > 0 -> decks.firstOrNull { it.deckId == deckId }
                encodedName != null -> decks.firstOrNull { it.deckName == encodedName }
                else -> null
            } ?: decks.firstOrNull { it.deckName == (encodedName ?: source.title) }
            val resolvedDeckName = matchedDeck?.deckName ?: encodedName ?: source.title
            val subDecksDue = decks.filter { it.deckName.startsWith("$resolvedDeckName::") }.sumOf { it.dueCount }
            val dueCount = if (decks.isNotEmpty()) {
                maxOf(matchedDeck?.dueCount ?: 0, subDecksDue)
            } else {
                source.totalPages ?: 0
            }
            val stats = getTodayDeckStudyStats(resolvedDeckName, dueCount)

            // Update source page progress
            database.sourceDao().upsert(
                source.copy(
                    currentPage = stats.cardsStudiedToday,
                    totalPages = stats.dueCount,
                    updatedAt = now
                )
            )

            if (stats.cardsStudiedToday > 0) {
                val sessionId = UUID.nameUUIDFromBytes(
                    "anki:${source.subjectId}:${source.id}:$todayStr".toByteArray(Charsets.UTF_8)
                ).toString()

                val existing = database.sessionDao().getSessionById(sessionId)

                if (existing == null || existing.endPage != stats.cardsStudiedToday || existing.actualDurationMinutes != stats.durationMinutes) {
                    val newXp = XpCalculator.calculateSessionXp(
                        actualMinutes = stats.durationMinutes,
                        confidence = 4,
                        isPomodoro = false,
                        pomodorosCompleted = 0,
                        plannedSeconds = 0,
                        studiedSeconds = stats.durationMinutes * 60
                    )

                    database.withTransaction {
                        val xpDelta = newXp - (existing?.xpEarned ?: 0)
                        val minutesDelta = stats.durationMinutes - (existing?.actualDurationMinutes ?: 0)

                        val session = StudySessionEntity(
                            id = sessionId,
                            subjectId = source.subjectId,
                            sourceId = source.id,
                            startedAt = existing?.startedAt ?: now,
                            endedAt = now,
                            plannedDurationMinutes = stats.durationMinutes,
                            actualDurationMinutes = stats.durationMinutes,
                            endPage = stats.cardsStudiedToday,
                            confidenceRating = existing?.confidenceRating ?: 4,
                            notes = "AnkiDroid: ${source.title} (${stats.cardsStudiedToday} cards)",
                            xpEarned = newXp,
                            isFreeTimer = true,
                            updatedAt = now
                        )
                        database.sessionDao().upsert(session)
                        database.subjectDao().updateXp(source.subjectId, xpDelta)

                        var streakBonusXp = 0
                        if (existing == null) {
                            streakManager.recordStudyDay { reason ->
                                streakBonusXp += XpCalculator.xpForReason(reason)
                            }
                        }

                        val currentStats = database.userStatsDao().getUserStats() ?: UserStatsEntity()
                        val newTotalXp = (currentStats.totalXp + xpDelta + streakBonusXp).coerceAtLeast(0)
                        val newLevel = XpCalculator.calculateLevel(newTotalXp)
                        val newTotalMinutes = (currentStats.totalStudyMinutes + minutesDelta).coerceAtLeast(0)
                        database.userStatsDao().upsert(
                            currentStats.copy(
                                totalXp = newTotalXp,
                                currentLevel = newLevel,
                                totalStudyMinutes = newTotalMinutes,
                                updatedAt = now
                            )
                        )
                    }
                }
            }
            syncedCount++
        }

        achievementEvaluator.checkAndUnlock()
        StudyHabitWidgetProvider.updateAllWidgets(context)
        onDataChanged()
        return syncedCount
    }
}
