package de.schuelken.studyhabit

import de.schuelken.studyhabit.core.model.XpReason
import de.schuelken.studyhabit.core.service.XpCalculator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class XpCalculatorTest {

    @Test
    fun testLevelCalculation() {
        assertEquals(1, XpCalculator.calculateLevel(0))
        assertEquals(1, XpCalculator.calculateLevel(499))
        assertEquals(2, XpCalculator.calculateLevel(500))
        assertEquals(2, XpCalculator.calculateLevel(1499))
        assertEquals(3, XpCalculator.calculateLevel(1500))
        assertEquals(4, XpCalculator.calculateLevel(3500))
        assertEquals(5, XpCalculator.calculateLevel(7000))
        assertEquals(6, XpCalculator.calculateLevel(10500))
        assertEquals(7, XpCalculator.calculateLevel(15800))
    }

    @Test
    fun testLevelThresholds() {
        assertEquals(0, XpCalculator.levelThreshold(1))
        assertEquals(500, XpCalculator.levelThreshold(2))
        assertEquals(1500, XpCalculator.levelThreshold(3))
        assertEquals(3500, XpCalculator.levelThreshold(4))
        assertEquals(7000, XpCalculator.levelThreshold(5))
        assertEquals(10500, XpCalculator.levelThreshold(6))
        assertEquals(15800, XpCalculator.levelThreshold(7))
    }

    @Test
    fun testXpForReasons() {
        assertEquals(50, XpCalculator.xpForReason(XpReason.COMPLETE_POMODORO))
        assertEquals(120, XpCalculator.xpForReason(XpReason.LONG_SESSION))
        assertEquals(10, XpCalculator.xpForReason(XpReason.CONFIDENCE))
        assertEquals(5, XpCalculator.xpForReason(XpReason.ADD_SOURCE))
        assertEquals(100, XpCalculator.xpForReason(XpReason.SKILL_ADVANCE))
        assertEquals(500, XpCalculator.xpForReason(XpReason.STREAK_7))
        assertEquals(500, XpCalculator.xpForReason(XpReason.STREAK_30))
        assertEquals(500, XpCalculator.xpForReason(XpReason.STREAK_100))
        assertEquals(75, XpCalculator.xpForReason(XpReason.DAILY_GOAL))
    }

    @Test
    fun testLevelProgress() {
        val progress = XpCalculator.getLevelProgress(250)
        assertEquals(1, progress.currentLevel)
        assertEquals("Novice", progress.levelName)
        assertEquals(250, progress.xpInLevel)
        assertEquals(250, progress.xpToNextLevel)
        assertEquals(50.0f, progress.progressPercent, 0.01f)

        val progressLevel2 = XpCalculator.getLevelProgress(1000)
        assertEquals(2, progressLevel2.currentLevel)
        assertEquals("Apprentice", progressLevel2.levelName)
        assertEquals(500, progressLevel2.xpInLevel)
        assertEquals(500, progressLevel2.xpToNextLevel)
        assertEquals(50.0f, progressLevel2.progressPercent, 0.01f)
    }
}
