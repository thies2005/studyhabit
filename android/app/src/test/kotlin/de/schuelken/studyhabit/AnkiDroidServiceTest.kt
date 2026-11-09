package de.schuelken.studyhabit

import de.schuelken.studyhabit.core.service.AnkiDeckInfo
import de.schuelken.studyhabit.core.service.AnkiDroidService
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Test

class AnkiDroidServiceTest {

    @Test
    fun testZeroCardsReturnsZeroMinutes() {
        assertEquals(0, AnkiDroidService.calculateReviewMinutes(0, emptyList()))
        assertEquals(0, AnkiDroidService.calculateReviewMinutes(0, listOf(100L, 200L)))
    }

    @Test
    fun testEmptyTimestampsUsesCardCountEstimation() {
        // 1 card: 20s + 30s = 50s -> maxOf(1, 50 / 60) = 1 min
        assertEquals(1, AnkiDroidService.calculateReviewMinutes(1, emptyList()))

        // 3 cards: 60s + 30s = 90s -> 1 min
        assertEquals(1, AnkiDroidService.calculateReviewMinutes(3, emptyList()))

        // 6 cards: 120s + 30s = 150s -> 2 min
        assertEquals(2, AnkiDroidService.calculateReviewMinutes(6, emptyList()))

        // 10 cards: 200s + 30s = 230s -> 3 min
        assertEquals(3, AnkiDroidService.calculateReviewMinutes(10, emptyList()))

        // 30 cards: 600s + 30s = 630s -> 10 min
        assertEquals(10, AnkiDroidService.calculateReviewMinutes(30, emptyList()))
    }

    @Test
    fun testTimestampsBurstingWithinActiveInterval() {
        // Timestamps in seconds: [100, 120, 150, 180, 210, 240]
        // Intervals:
        // first card: 20s base
        // 120 - 100 = 20s
        // 150 - 120 = 30s
        // 180 - 150 = 30s
        // 210 - 180 = 30s
        // 240 - 210 = 30s
        // Total = 20 + 20 + 30 + 30 + 30 + 30 = 160s
        // (160 + 30) / 60 = 190 / 60 = 3 minutes
        val timestamps = listOf(100L, 120L, 150L, 180L, 210L, 240L)
        assertEquals(3, AnkiDroidService.calculateReviewMinutes(6, timestamps))
    }

    @Test
    fun testTimestampsWithLongGapsClampedToBurstStarts() {
        // Timestamps in seconds: [100, 115, 1000, 1020]
        // 100: 20s base
        // 115 - 100 = 15s (<= 180)
        // 1000 - 115 = 885s (> 180s gap, treated as new burst start -> 20s)
        // 1020 - 1000 = 20s (<= 180)
        // Total = 20 + 15 + 20 + 20 = 75s
        // (75 + 30) / 60 = 105 / 60 = 1 minute
        val timestamps = listOf(100L, 115L, 1000L, 1020L)
        assertEquals(1, AnkiDroidService.calculateReviewMinutes(4, timestamps))
    }

    @Test
    fun testUnsortedTimestampsAreSortedCorrectly() {
        // [500, 100, 120] -> sorted [100, 120, 500]
        // 100: 20s
        // 120 - 100 = 20s
        // 500 - 120 = 380s (> 180s -> 20s)
        // Total = 20 + 20 + 20 = 60s -> (60 + 30) / 60 = 1 min
        val timestamps = listOf(500L, 100L, 120L)
        assertEquals(1, AnkiDroidService.calculateReviewMinutes(3, timestamps))
    }

    @Test
    fun testExtraReviewsBeyondUniqueCardTimestampsAreCounted() {
        // 10 unique card timestamps spaced 20s apart (= 200s), but 20 total reviews (e.g. Again + Good)
        // Extra 10 reviews add 10 * 20s = 200s -> total 400s -> (400 + 30) / 60 = 7 minutes
        val timestamps = (0 until 10).map { 1000L + it * 20L }
        assertEquals(7, AnkiDroidService.calculateReviewMinutes(20, timestamps))
    }

    @Test
    fun testFilterTimestampsForDateRestrictsToTargetDayWindow() {
        val zone = ZoneId.of("UTC")
        val targetDate = LocalDate.of(2026, 11, 5)
        val dayStartSec = targetDate.atStartOfDay(zone).toEpochSecond()
        val prevDaySec = dayStartSec - 3600L
        val noonSec = dayStartSec + 12 * 3600L
        val lateNightGraceSec = dayStartSec + 26 * 3600L // 2 AM next day (within 4h grace)
        val nextDayAfternoonSec = dayStartSec + 36 * 3600L

        val filtered = AnkiDroidService.filterTimestampsForDate(
            timestampsSec = listOf(prevDaySec, noonSec, lateNightGraceSec, nextDayAfternoonSec),
            date = targetDate,
            zone = zone,
            gracePeriodHours = 4.0
        )
        assertEquals(listOf(noonSec, lateNightGraceSec), filtered)
    }

    @Test
    fun testResolveDueCountDoesNotDoubleCountMultiLevelSubDecks() {
        // Simulates Anki's deckDueTree where parent decks already include subdeck totals
        val decks = listOf(
            AnkiDeckInfo(1L, "Medizin", 53),
            AnkiDeckInfo(2L, "Medizin::Vorklinik", 45),
            AnkiDeckInfo(3L, "Medizin::Vorklinik::Anatomie", 30),
            AnkiDeckInfo(4L, "Medizin::Vorklinik::Anatomie::Kopf", 10),
            AnkiDeckInfo(5L, "Medizin::Vorklinik::Anatomie::Thorax", 20),
            AnkiDeckInfo(6L, "Medizin::Vorklinik::Physiologie", 15),
            AnkiDeckInfo(7L, "Medizin::Klinik", 8),
            AnkiDeckInfo(8L, "Medizin::Klinik::Innere", 8)
        )
        assertEquals(53, AnkiDroidService.resolveDueCount("Medizin", decks[0], decks))
        assertEquals(45, AnkiDroidService.resolveDueCount("Medizin::Vorklinik", decks[1], decks))
        assertEquals(30, AnkiDroidService.resolveDueCount("Medizin::Vorklinik::Anatomie", decks[2], decks))
        assertEquals(10, AnkiDroidService.resolveDueCount("Medizin::Vorklinik::Anatomie::Kopf", decks[3], decks))
    }

    @Test
    fun testEscapeAnkiSearchTermEscapesBackslashesAndQuotes() {
        assertEquals("Medizin::Anatomie \\\"Kopf\\\"", AnkiDroidService.escapeAnkiSearchTerm("Medizin::Anatomie \"Kopf\""))
        assertEquals("Path\\\\Sub", AnkiDroidService.escapeAnkiSearchTerm("Path\\Sub"))
    }

    @Test
    fun testGroupDecksHierarchicallyWithFlatDecks() {
        val decks = listOf(
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(1L, "Biology", 10),
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(2L, "Chemistry", 5)
        )
        val groups = AnkiDroidService.groupDecksHierarchically(decks)
        assertEquals(2, groups.size)
        assertEquals("Biology", groups[0].parentDeck.deckName)
        assertEquals(0, groups[0].subDecks.size)
        assertEquals(10, groups[0].totalDueCount)

        assertEquals("Chemistry", groups[1].parentDeck.deckName)
        assertEquals(0, groups[1].subDecks.size)
        assertEquals(5, groups[1].totalDueCount)
    }

    @Test
    fun testGroupDecksHierarchicallyWithExplicitParentAndSubDecks() {
        val decks = listOf(
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(1L, "Japanese", 5),
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(2L, "Japanese::Vocab", 12),
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(3L, "Japanese::Kanji", 8)
        )
        val groups = AnkiDroidService.groupDecksHierarchically(decks)
        assertEquals(1, groups.size)
        val group = groups[0]
        assertEquals("Japanese", group.parentDeck.deckName)
        assertEquals(2, group.subDecks.size)
        assertEquals("Japanese::Kanji", group.subDecks[0].deckName)
        assertEquals("Japanese::Vocab", group.subDecks[1].deckName)
        // totalDueCount is maxOf(parent.dueCount, sum of subDue: 12 + 8 = 20) -> 20
        assertEquals(20, group.totalDueCount)
    }

    @Test
    fun testGroupDecksHierarchicallySynthesizesMissingParent() {
        val decks = listOf(
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(2L, "Medicine::Pathology", 15),
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(3L, "Medicine::Anatomy", 10)
        )
        val groups = AnkiDroidService.groupDecksHierarchically(decks)
        assertEquals(1, groups.size)
        val group = groups[0]
        assertEquals("Medicine", group.parentDeck.deckName)
        assertEquals(2, group.subDecks.size)
        assertEquals("Medicine::Anatomy", group.subDecks[0].deckName)
        assertEquals("Medicine::Pathology", group.subDecks[1].deckName)
        assertEquals(25, group.totalDueCount)
    }

    @Test
    fun testGroupDecksHierarchicallyFiltersBlanks() {
        val decks = listOf(
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(1L, "   ", 0),
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(2L, "Math", 3)
        )
        val groups = AnkiDroidService.groupDecksHierarchically(decks)
        assertEquals(1, groups.size)
        assertEquals("Math", groups[0].parentDeck.deckName)
    }

    @Test
    fun testBuildDeckTreeMultiLevelHierarchy() {
        val decks = listOf(
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(1L, "Medizin", 0),
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(2L, "Medizin::Vorklinik::Anatomie::Kopf", 10),
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(3L, "Medizin::Vorklinik::Anatomie::Thorax", 20),
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(4L, "Medizin::Vorklinik::Physiologie", 15),
            de.schuelken.studyhabit.core.service.AnkiDeckInfo(5L, "Medizin::Klinik::Innere", 8)
        )
        val tree = AnkiDroidService.buildDeckTree(decks)
        assertEquals(1, tree.size)

        val root = tree[0]
        assertEquals("Medizin", root.shortName)
        assertEquals("Medizin", root.fullPath)
        assertEquals(53, root.totalDueCount)
        // Root must ONLY have direct 1st-level children (Klinik, Vorklinik), NOT deeper descendants
        assertEquals(2, root.children.size)
        assertEquals("Klinik", root.children[0].shortName)
        assertEquals("Vorklinik", root.children[1].shortName)

        val klinik = root.children[0]
        assertEquals("Medizin::Klinik", klinik.fullPath)
        assertEquals(8, klinik.totalDueCount)
        assertEquals(1, klinik.children.size)
        assertEquals("Innere", klinik.children[0].shortName)
        assertEquals("Medizin::Klinik::Innere", klinik.children[0].fullPath)

        val vorklinik = root.children[1]
        assertEquals("Medizin::Vorklinik", vorklinik.fullPath)
        assertEquals(45, vorklinik.totalDueCount)
        // Vorklinik must ONLY have direct 2nd-level children (Anatomie, Physiologie), NOT Kopf/Thorax
        assertEquals(2, vorklinik.children.size)
        assertEquals("Anatomie", vorklinik.children[0].shortName)
        assertEquals("Physiologie", vorklinik.children[1].shortName)

        val anatomie = vorklinik.children[0]
        assertEquals("Medizin::Vorklinik::Anatomie", anatomie.fullPath)
        assertEquals(30, anatomie.totalDueCount)
        assertEquals(2, anatomie.children.size)
        assertEquals("Kopf", anatomie.children[0].shortName)
        assertEquals(10, anatomie.children[0].totalDueCount)
        assertEquals("Thorax", anatomie.children[1].shortName)
        assertEquals(20, anatomie.children[1].totalDueCount)
    }
}
