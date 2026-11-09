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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

data class AnkiDeckInfo(
    val deckId: Long,
    val deckName: String,
    val dueCount: Int
)

typealias AnkiDeck = AnkiDeckInfo

data class AnkiDeckStudyStats(
    val cardsStudiedToday: Int,
    val durationMinutes: Int,
    val dueCount: Int,
    val firstReviewEpochSec: Long? = null,
    val lastReviewEpochSec: Long? = null
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

    private val syncMutex = Mutex()
    @Volatile private var lastSyncCompletedAtMs: Long = 0L
    @Volatile private var lastSyncKey: String = ""

    companion object {
        const val READ_WRITE_PERMISSION = "com.ichi2.anki.permission.READ_WRITE_DATABASE"
        const val LAST_REVIEW_TIME_SECONDS = "last_review_time_secs"
        const val PAST_DAYS_SYNC_WINDOW = 30
        const val DEFAULT_SECONDS_PER_CARD = 20L
        const val MIN_SECONDS_PER_CARD = 15L
        const val MAX_ACTIVE_REVIEW_INTERVAL_SEC = 180L

        fun normalizeDeckPath(deckName: String): String {
            return deckName.split("::")
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .joinToString("::")
        }

        fun escapeAnkiSearchTerm(value: String): String {
            return value.replace("\\", "\\\\").replace("\"", "\\\"")
        }

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

        fun resolveDueCount(
            deckName: String,
            matchedDeck: AnkiDeckInfo?,
            decks: List<AnkiDeckInfo>
        ): Int {
            if (decks.isEmpty()) return matchedDeck?.dueCount ?: 0
            val normTarget = normalizeDeckPath(deckName)
            val tree = buildDeckTree(decks)

            fun findNode(nodes: List<AnkiDeckNode>): AnkiDeckNode? {
                for (node in nodes) {
                    if (node.fullPath.equals(normTarget, ignoreCase = true)) return node
                    val found = findNode(node.children)
                    if (found != null) return found
                }
                return null
            }

            return findNode(tree)?.totalDueCount ?: matchedDeck?.dueCount ?: 0
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

        fun filterTimestampsForDate(
            timestampsSec: List<Long>,
            date: LocalDate,
            zone: ZoneId,
            gracePeriodHours: Double = 4.0
        ): List<Long> {
            if (timestampsSec.isEmpty()) return emptyList()
            val graceSec = (gracePeriodHours.coerceIn(0.0, 12.0) * 3600.0).toLong()
            val startSec = date.atStartOfDay(zone).toEpochSecond()
            val endSec = date.plusDays(1).atStartOfDay(zone).toEpochSecond() + maxOf(graceSec, 4 * 3600L)
            return timestampsSec.filter { it in startSec until endSec }
        }

        fun calculateReviewMinutes(cardsCount: Int, reviewTimestampsSec: List<Long>): Int {
            if (cardsCount <= 0) return 0
            if (reviewTimestampsSec.isEmpty()) {
                return maxOf(1, ((cardsCount * DEFAULT_SECONDS_PER_CARD + 30L) / 60L).toInt())
            }

            val sorted = reviewTimestampsSec.sorted()
            var totalSeconds = DEFAULT_SECONDS_PER_CARD
            for (i in 1 until sorted.size) {
                val delta = (sorted[i] - sorted[i - 1]).coerceAtLeast(0L)
                totalSeconds += if (delta in 1L..MAX_ACTIVE_REVIEW_INTERVAL_SEC) delta else DEFAULT_SECONDS_PER_CARD
            }
            val extraReviews = (cardsCount - sorted.size).coerceAtLeast(0)
            totalSeconds += extraReviews * DEFAULT_SECONDS_PER_CARD
            totalSeconds = maxOf(totalSeconds, cardsCount * MIN_SECONDS_PER_CARD)
            return maxOf(1, ((totalSeconds + 30L) / 60L).toInt())
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

        val decksUri = Uri.parse("content://com.ichi2.anki.flashcards/decks")
        val projection = arrayOf("deck_id", "deck_name", "deck_counts")

        fun parseDecksCursor(useProjection: Boolean): List<AnkiDeckInfo>? {
            return runCatching {
                context.contentResolver.query(
                    decksUri,
                    if (useProjection) projection else null,
                    null,
                    null,
                    null
                )?.use { cursor ->
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
                }
            }.getOrNull()
        }

        return parseDecksCursor(useProjection = true)
            ?: parseDecksCursor(useProjection = false)
            ?: emptyList()
    }

    private data class RawQueryResult(
        val count: Int,
        val timestampsSec: List<Long>
    )

    private fun queryCardsOrNotes(selection: String, includeTimestamps: Boolean): RawQueryResult? {
        val cardsUri = Uri.parse("content://com.ichi2.anki.flashcards/cards")

        if (includeTimestamps) {
            val withTimestamps = runCatching {
                val projection = arrayOf("_id", LAST_REVIEW_TIME_SECONDS)
                context.contentResolver.query(cardsUri, projection, selection, null, null)?.use { cursor ->
                    val timeCol = cursor.getColumnIndex(LAST_REVIEW_TIME_SECONDS)
                        .takeIf { it >= 0 }
                        ?: cursor.getColumnIndex("last_review_time_seconds")
                    val timestamps = mutableListOf<Long>()
                    while (cursor.moveToNext()) {
                        if (timeCol >= 0 && !cursor.isNull(timeCol)) {
                            val ts = cursor.getLong(timeCol)
                            if (ts > 0L) timestamps.add(ts)
                        }
                    }
                    RawQueryResult(count = cursor.count, timestampsSec = timestamps)
                }
            }.getOrNull()

            if (withTimestamps != null) return withTimestamps
        }

        val idOnlyCards = runCatching {
            context.contentResolver.query(cardsUri, arrayOf("_id"), selection, null, null)?.use { cursor ->
                RawQueryResult(count = cursor.count, timestampsSec = emptyList())
            }
        }.getOrNull()

        if (idOnlyCards != null) return idOnlyCards

        val notesUri = Uri.parse("content://com.ichi2.anki.flashcards/notes")
        return runCatching {
            val cursor = context.contentResolver.query(notesUri, arrayOf("_id"), selection, null, null)
            if (cursor == null) {
                RawQueryResult(count = 0, timestampsSec = emptyList())
            } else {
                cursor.use {
                    RawQueryResult(count = it.count, timestampsSec = emptyList())
                }
            }
        }.getOrNull()
    }

    private fun countCardsInWindow(deckName: String, days: Int): Int {
        val safeDeckName = escapeAnkiSearchTerm(deckName)
        val selection = "deck:\"$safeDeckName\" rated:$days"
        return queryCardsOrNotes(selection, includeTimestamps = false)?.count ?: 0
    }

    private fun countCardsForDayFast(deckName: String, dayOffset: Int): Int {
        val safeDeckName = escapeAnkiSearchTerm(deckName)
        val ratedTerm = if (dayOffset <= 0) "prop:rated=0" else "prop:rated=-$dayOffset"
        val primary = queryCardsOrNotes("deck:\"$safeDeckName\" $ratedTerm", includeTimestamps = false)
        if (primary != null && (primary.count > 0 || dayOffset > 0)) {
            return primary.count
        }
        if (dayOffset <= 0) {
            return queryCardsOrNotes("deck:\"$safeDeckName\" rated:1", includeTimestamps = false)?.count ?: 0
        }
        return 0
    }

    fun getTodayDeckStudyStats(deckName: String, dueCount: Int = 0): AnkiDeckStudyStats {
        val zone = ZoneId.systemDefault()
        return getDeckStudyStatsForDay(
            deckName = deckName,
            dueCount = dueCount,
            dayOffset = 0,
            targetDate = LocalDate.now(zone),
            zone = zone
        )
    }

    fun getDeckStudyStatsForDay(
        deckName: String,
        dueCount: Int = 0,
        dayOffset: Int = 0,
        targetDate: LocalDate = LocalDate.now(ZoneId.systemDefault()),
        zone: ZoneId = ZoneId.systemDefault()
    ): AnkiDeckStudyStats {
        if (!isAnkiInstalled() || !hasAnkiPermission()) {
            return AnkiDeckStudyStats(cardsStudiedToday = 0, durationMinutes = 0, dueCount = dueCount)
        }

        val safeDeckName = escapeAnkiSearchTerm(deckName)
        val ratedTerm = if (dayOffset <= 0) "prop:rated=0" else "prop:rated=-$dayOffset"
        val primarySelection = "deck:\"$safeDeckName\" $ratedTerm"

        var baseResult = queryCardsOrNotes(primarySelection, includeTimestamps = true)
        var usedLegacyRated = false

        if ((baseResult == null || baseResult.count == 0) && dayOffset <= 0) {
            val legacyResult = queryCardsOrNotes("deck:\"$safeDeckName\" rated:1", includeTimestamps = true)
            if (legacyResult != null && legacyResult.count > 0) {
                baseResult = legacyResult
                usedLegacyRated = true
            }
        }

        val effectiveBase = baseResult
            ?: return AnkiDeckStudyStats(cardsStudiedToday = 0, durationMinutes = 0, dueCount = dueCount)

        if (effectiveBase.count <= 0) {
            return AnkiDeckStudyStats(cardsStudiedToday = 0, durationMinutes = 0, dueCount = dueCount)
        }

        // Sum across rating buttons (1=Again, 2=Hard, 3=Good, 4=Easy) so cards rated with
        // multiple buttons on the same day (e.g. Again then Good) count all review ratings.
        var ratingButtonsSum = 0
        for (button in 1..4) {
            val buttonQuery = if (dayOffset <= 0 || usedLegacyRated) {
                "deck:\"$safeDeckName\" rated:1:$button"
            } else {
                "deck:\"$safeDeckName\" $ratedTerm:$button"
            }
            val btnCount = queryCardsOrNotes(buttonQuery, includeTimestamps = false)?.count ?: 0
            ratingButtonsSum += btnCount
        }

        val totalCardsStudied = maxOf(effectiveBase.count, ratingButtonsSum)
        val dayTimestamps = filterTimestampsForDate(
            timestampsSec = effectiveBase.timestampsSec,
            date = targetDate,
            zone = zone,
            gracePeriodHours = preferences.gracePeriodHours
        )
        val duration = calculateReviewMinutes(totalCardsStudied, dayTimestamps)

        return AnkiDeckStudyStats(
            cardsStudiedToday = totalCardsStudied,
            durationMinutes = duration,
            dueCount = dueCount,
            firstReviewEpochSec = dayTimestamps.minOrNull(),
            lastReviewEpochSec = dayTimestamps.maxOrNull()
        )
    }

    suspend fun syncLinkedDecks(
        subjectId: String? = null,
        syncPastDays: Boolean = false,
        notifyDataChanged: Boolean = true
    ): Int = withContext(Dispatchers.IO) {
        syncMutex.withLock {
        if (!isAnkiInstalled() || !hasAnkiPermission()) return@withLock 0

        val syncKey = "${subjectId.orEmpty()}:$syncPastDays"
        val nowCheck = System.currentTimeMillis()
        if (syncKey == lastSyncKey && (nowCheck - lastSyncCompletedAtMs) in 0L..1500L) {
            return@withLock 0
        }

        val ankiSources = if (subjectId != null) {
            database.sourceDao().getSourcesForSubject(subjectId)
                .filter { it.type.equals("anki", ignoreCase = true) && !it.isDeleted }
        } else {
            database.sourceDao().getAllSources()
                .filter { it.type.equals("anki", ignoreCase = true) && !it.isDeleted }
        }

        if (ankiSources.isEmpty()) return@withLock 0

        val decks = runCatching { getDecks() }.getOrDefault(emptyList())
        val now = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now(zone)
        var syncedCount = 0
        var anyDataChanged = false

        for (source in ankiSources) {
            val rawPath = source.filePath?.removePrefix("anki://deck/")
            val deckId = rawPath?.substringBefore("?")?.toLongOrNull()
            val encodedName = rawPath?.substringAfter("?name=", "")
                ?.takeIf { it.isNotEmpty() }
                ?.let { Uri.decode(it) }

            val matchedDeck = when {
                deckId != null && deckId > 0 -> decks.firstOrNull { it.deckId == deckId }
                encodedName != null -> decks.firstOrNull {
                    it.deckName == encodedName || normalizeDeckPath(it.deckName) == normalizeDeckPath(encodedName)
                }
                else -> null
            } ?: decks.firstOrNull {
                val target = encodedName ?: source.title
                it.deckName == target || normalizeDeckPath(it.deckName) == normalizeDeckPath(target)
            }

            val resolvedDeckName = matchedDeck?.deckName ?: encodedName ?: source.title
            val dueCount = if (decks.isNotEmpty()) {
                resolveDueCount(resolvedDeckName, matchedDeck, decks)
            } else {
                source.totalPages ?: 0
            }

            val maxDayOffset = if (!syncPastDays) {
                0
            } else {
                val count31 = countCardsInWindow(resolvedDeckName, PAST_DAYS_SYNC_WINDOW + 1)
                if (count31 <= 0) {
                    0
                } else {
                    val count7 = countCardsInWindow(resolvedDeckName, 7)
                    if (count31 > count7) PAST_DAYS_SYNC_WINDOW else 6
                }
            }

            // Process chronologically from oldest past day to today so StreakManager advances in order
            for (dayOffset in maxDayOffset downTo 0) {
                val targetDate = today.minusDays(dayOffset.toLong())
                val dateStr = targetDate.toString()
                val sessionId = UUID.nameUUIDFromBytes(
                    "anki:${source.subjectId}:${source.id}:$dateStr".toByteArray(Charsets.UTF_8)
                ).toString()

                val existing = database.sessionDao().getSessionById(sessionId)

                // Fast-skip older past days (> 1 day ago) that already have a synced session
                if (dayOffset > 1 && existing != null && (existing.endPage ?: 0) > 0) {
                    continue
                }

                // Do not resurrect soft-deleted sessions
                val isSoftDeleted = existing == null && database.sessionDao().hasRecord(sessionId)
                if (dayOffset > 0 && isSoftDeleted) {
                    continue
                }

                if (dayOffset > 0 && countCardsForDayFast(resolvedDeckName, dayOffset) <= 0) {
                    continue
                }

                val stats = getDeckStudyStatsForDay(
                    deckName = resolvedDeckName,
                    dueCount = dueCount,
                    dayOffset = dayOffset,
                    targetDate = targetDate,
                    zone = zone
                )

                if (dayOffset == 0) {
                    if (source.currentPage != stats.cardsStudiedToday || source.totalPages != stats.dueCount) {
                        database.sourceDao().upsert(
                            source.copy(
                                currentPage = stats.cardsStudiedToday,
                                totalPages = stats.dueCount,
                                updatedAt = now
                            )
                        )
                        anyDataChanged = true
                    }
                }

                if (isSoftDeleted) {
                    continue
                }

                if (stats.cardsStudiedToday > 0) {
                    val effectiveMinutes = if (existing != null) {
                        maxOf(existing.actualDurationMinutes, stats.durationMinutes)
                    } else {
                        stats.durationMinutes
                    }

                    if (existing == null ||
                        existing.endPage != stats.cardsStudiedToday ||
                        existing.actualDurationMinutes != effectiveMinutes
                    ) {
                        val newXp = XpCalculator.calculateSessionXp(
                            actualMinutes = effectiveMinutes,
                            confidence = existing?.confidenceRating ?: 4,
                            isPomodoro = false,
                            pomodorosCompleted = 0,
                            plannedSeconds = 0,
                            studiedSeconds = effectiveMinutes * 60
                        )

                        val firstMs = stats.firstReviewEpochSec?.let { it * 1000L }
                        val lastMs = stats.lastReviewEpochSec?.let { it * 1000L }
                        val sessionStartedAt = existing?.startedAt ?: if (dayOffset == 0) {
                            firstMs ?: now
                        } else {
                            firstMs ?: targetDate.atTime(12, 0).atZone(zone).toInstant().toEpochMilli()
                        }
                        val sessionEndedAt = if (dayOffset == 0) {
                            maxOf(now, lastMs ?: now, sessionStartedAt + effectiveMinutes * 60_000L)
                        } else {
                            maxOf(lastMs ?: sessionStartedAt, sessionStartedAt + effectiveMinutes * 60_000L)
                        }

                        database.withTransaction {
                            val xpDelta = newXp - (existing?.xpEarned ?: 0)
                            val minutesDelta = effectiveMinutes - (existing?.actualDurationMinutes ?: 0)

                            val session = StudySessionEntity(
                                id = sessionId,
                                subjectId = source.subjectId,
                                sourceId = source.id,
                                startedAt = sessionStartedAt,
                                endedAt = sessionEndedAt,
                                plannedDurationMinutes = effectiveMinutes,
                                actualDurationMinutes = effectiveMinutes,
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
                                streakManager.recordStudyDay(nowMillis = sessionStartedAt) { reason ->
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
                        anyDataChanged = true
                    }
                }
            }
            syncedCount++
        }

        lastSyncKey = syncKey
        lastSyncCompletedAtMs = System.currentTimeMillis()

        if (anyDataChanged) {
            achievementEvaluator.checkAndUnlock()
            StudyHabitWidgetProvider.updateAllWidgets(context)
            if (notifyDataChanged) {
                onDataChanged()
            }
        }
        return@withLock syncedCount
        }
    }
}
