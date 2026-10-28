package de.schuelken.studyhabit

import de.schuelken.studyhabit.core.service.AnkiDroidService
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
        // 1 card: 10s + 30s = 40s -> maxOf(1, 40 / 60) = 1 min
        assertEquals(1, AnkiDroidService.calculateReviewMinutes(1, emptyList()))

        // 3 cards: 30s + 30s = 60s -> 1 min
        assertEquals(1, AnkiDroidService.calculateReviewMinutes(3, emptyList()))

        // 6 cards: 60s + 30s = 90s -> 1 min
        assertEquals(1, AnkiDroidService.calculateReviewMinutes(6, emptyList()))

        // 10 cards: 100s + 30s = 130s -> 2 min
        assertEquals(2, AnkiDroidService.calculateReviewMinutes(10, emptyList()))

        // 30 cards: 300s + 30s = 330s -> 5 min
        assertEquals(5, AnkiDroidService.calculateReviewMinutes(30, emptyList()))
    }

    @Test
    fun testTimestampsBurstingWithin60Seconds() {
        // Timestamps in seconds: [100, 120, 150, 180, 210, 240]
        // Intervals:
        // first card: 10s base
        // 120 - 100 = 20s
        // 150 - 120 = 30s
        // 180 - 150 = 30s
        // 210 - 180 = 30s
        // 240 - 210 = 30s
        // Total = 10 + 20 + 30 + 30 + 30 + 30 = 150s
        // (150 + 30) / 60 = 180 / 60 = 3 minutes
        val timestamps = listOf(100L, 120L, 150L, 180L, 210L, 240L)
        assertEquals(3, AnkiDroidService.calculateReviewMinutes(6, timestamps))
    }

    @Test
    fun testTimestampsWithLongGapsClampedToBurstStarts() {
        // Timestamps in seconds: [100, 115, 1000, 1020]
        // 100: 10s base
        // 115 - 100 = 15s (<= 60)
        // 1000 - 115 = 885s (> 60s gap, treated as new burst start -> 10s)
        // 1020 - 1000 = 20s (<= 60)
        // Total = 10 + 15 + 10 + 20 = 55s
        // (55 + 30) / 60 = 85 / 60 = 1 minute
        val timestamps = listOf(100L, 115L, 1000L, 1020L)
        assertEquals(1, AnkiDroidService.calculateReviewMinutes(4, timestamps))
    }

    @Test
    fun testUnsortedTimestampsAreSortedCorrectly() {
        // [200, 100, 120] -> sorted [100, 120, 200]
        // 100: 10s
        // 120 - 100 = 20s
        // 200 - 120 = 80s (> 60s -> 10s)
        // Total = 10 + 20 + 10 = 40s -> (40 + 30) / 60 = 1 min
        val timestamps = listOf(200L, 100L, 120L)
        assertEquals(1, AnkiDroidService.calculateReviewMinutes(3, timestamps))
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
}
