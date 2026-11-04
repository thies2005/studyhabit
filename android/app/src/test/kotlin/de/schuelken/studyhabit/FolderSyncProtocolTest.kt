package de.schuelken.studyhabit

import de.schuelken.studyhabit.core.database.ProjectEntity
import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.service.ExportDocument
import de.schuelken.studyhabit.core.service.ExportProject
import de.schuelken.studyhabit.core.service.FolderSyncProtocol
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class FolderSyncProtocolTest {
    private data class Row(val id: String, val time: Long, val deleted: Boolean, val value: String)

    private fun plan(remote: List<Row>, local: List<Row>) =
        FolderSyncProtocol.planRows(remote, local, Row::id, Row::time, Row::deleted, Row::value)

    @Test fun independentWritersConvergeWithoutRepublishingPulledRows() {
        val pixel = Row("pixel", 10, false, "new session")
        val tablet = Row("tablet", 10, false, "new subject")
        val third = Row("third", 10, false, "new project")
        val all = listOf(pixel, tablet, third)

        for (own in all) {
            val merge = plan(all.reversed(), listOf(own))
            assertEquals(0, merge.pushed)
            assertEquals(all.toSet() - own, merge.updates.map { it.first }.toSet())
        }
        assertEquals(1, plan(listOf(pixel, tablet), all).pushed)
    }

    @Test fun equalTimestampDeleteWinsAndOtherTiesConvergeInAnyOrder() {
        val before = Row("deleted", 10, false, "before")
        val tombstone = Row("deleted", 10, true, "before")
        val first = Row("edited", 10, false, "first")
        val second = Row("edited", 10, false, "second")
        val remote = listOf(tombstone, second, before, first)
        assertEquals(listOf(tombstone, second), plan(remote, listOf(before, first)).updates.map { it.first })
        assertEquals(listOf(tombstone, second), plan(remote.reversed(), listOf(before, first)).updates.map { it.first })
        assertTrue(plan(listOf(before), listOf(tombstone)).updates.isEmpty())
        assertEquals(1, plan(listOf(before), listOf(tombstone)).pushed)
    }

    @Test fun completeSnapshotsRoundTripAndCorruptionIsRejected() {
        val doc = ExportDocument(
            exportedAt = "2026-11-04T12:00:00Z",
            userStats = UserStatsEntity(updatedAt = 20),
            projects = listOf(ExportProject(ProjectEntity("id", "original", colorValue = 1), emptyList())),
            achievements = emptyList(),
        )
        val encoded = FolderSyncProtocol.encode(doc)
        assertEquals(doc, FolderSyncProtocol.decode(encoded))
        assertThrows(IllegalArgumentException::class.java) { FolderSyncProtocol.decode(encoded.dropLast(10)) }
        assertThrows(IllegalArgumentException::class.java) { FolderSyncProtocol.decode(encoded.replace("original", "modified")) }
        val id = "11111111-1111-1111-1111-111111111111"
        assertTrue(FolderSyncProtocol.isPublication(FolderSyncProtocol.fileName(id, id)))
        assertFalse(FolderSyncProtocol.isPublication("studyhabit_sync.json"))
    }

    @Test fun shorteningAndDeletionReduceTotalsWithoutDiscardingBonusXp() {
        val old = StudySessionEntity(id = "session", subjectId = "subject", actualDurationMinutes = 60, xpEarned = 120)
        val oldStats = UserStatsEntity(totalStudyMinutes = 60, totalXp = 125)
        val bonus = FolderSyncProtocol.bonusXp(oldStats, listOf(old))
        val shorter = old.copy(actualDurationMinutes = 20, xpEarned = 40)
        val shorterStats = FolderSyncProtocol.reconcileStats(oldStats, listOf(shorter), bonus, 0)
        assertEquals(20, shorterStats.totalStudyMinutes)
        assertEquals(45, shorterStats.totalXp)
        val deletedStats = FolderSyncProtocol.reconcileStats(oldStats, listOf(shorter.copy(isDeleted = true)), bonus, 0)
        assertEquals(0, deletedStats.totalStudyMinutes)
        assertEquals(5, deletedStats.totalXp)
    }
}
