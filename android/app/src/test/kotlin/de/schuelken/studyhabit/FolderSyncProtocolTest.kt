package de.schuelken.studyhabit

import de.schuelken.studyhabit.core.database.AchievementEntity
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
        val otherId = "22222222-2222-2222-2222-222222222222"
        val singleFile = FolderSyncProtocol.deviceFileName(id)
        val legacyFile = FolderSyncProtocol.fileName(id, id)
        val otherLegacyFile = FolderSyncProtocol.fileName(otherId, id)
        assertTrue(FolderSyncProtocol.isPublication(singleFile))
        assertTrue(FolderSyncProtocol.isPublication(legacyFile))
        assertFalse(FolderSyncProtocol.isPublication("studyhabit_sync.json"))
        assertFalse(FolderSyncProtocol.isOwnLegacyPublication(singleFile, id))
        assertTrue(FolderSyncProtocol.isOwnLegacyPublication(legacyFile, id))
        assertFalse(FolderSyncProtocol.isOwnLegacyPublication(otherLegacyFile, id))
        assertTrue(FolderSyncProtocol.sameSnapshot(doc, doc.copy(exportedAt = "2026-11-05T00:00:00Z")))
        assertFalse(FolderSyncProtocol.sameSnapshot(doc, doc.copy(userStats = UserStatsEntity(updatedAt = 21))))
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

    @Test fun achievementsMergeMonotonicallyAcrossDevices() {
        val local = listOf(
            AchievementEntity(key = "streak_7", unlockedAt = 1000L, progress = 1.0, updatedAt = 1000L),
            AchievementEntity(key = "hours_10", unlockedAt = null, progress = 0.3, updatedAt = 1000L),
            AchievementEntity(key = "local_only", unlockedAt = null, progress = 0.6, updatedAt = 1200L),
        )
        val remote = listOf(
            // Remote has newer updatedAt but lower progress & null unlockedAt — must not clobber local unlock!
            AchievementEntity(key = "streak_7", unlockedAt = null, progress = 0.4, updatedAt = 5000L),
            // Remote has higher progress and earlier unlock across two writers
            AchievementEntity(key = "hours_10", unlockedAt = 2500L, progress = 1.0, updatedAt = 2500L),
            AchievementEntity(key = "hours_10", unlockedAt = 2000L, progress = 1.0, updatedAt = 3000L),
            AchievementEntity(key = "remote_only", unlockedAt = 900L, progress = 1.0, updatedAt = 900L),
        )

        val plan = FolderSyncProtocol.mergeAchievements(remote, local)
        // local_only + streak_7 (ahead of remote)
        assertEquals(2, plan.pushed)

        val updatedByKey = plan.updates.associate { it.first.key to it.first }
        assertFalse("streak_7 should not regress", updatedByKey.containsKey("streak_7"))
        assertEquals(2000L, updatedByKey["hours_10"]?.unlockedAt)
        assertEquals(1.0, updatedByKey["hours_10"]?.progress ?: 0.0, 0.0001)
        assertEquals(900L, updatedByKey["remote_only"]?.unlockedAt)
        assertEquals(1.0, updatedByKey["remote_only"]?.progress ?: 0.0, 0.0001)
    }
}
