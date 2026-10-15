package de.schuelken.studyhabit

import android.content.SharedPreferences
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.database.dao.UserStatsDao
import de.schuelken.studyhabit.core.model.XpReason
import de.schuelken.studyhabit.core.preferences.AppPreferences
import de.schuelken.studyhabit.core.service.StreakManager
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

class FakeUserStatsDao : UserStatsDao {
    var stats: UserStatsEntity? = null

    override fun getUserStatsFlow(): Flow<UserStatsEntity?> = flowOf(stats)

    override suspend fun getUserStats(): UserStatsEntity? = stats

    override suspend fun getModifiedSince(since: Long): List<UserStatsEntity> {
        val s = stats ?: return emptyList()
        return if (s.updatedAt > since) listOf(s) else emptyList()
    }

    override suspend fun upsert(stats: UserStatsEntity) {
        this.stats = stats
    }

    override suspend fun deleteAll() {
        stats = null
    }
}

class FakeSharedPreferences : SharedPreferences {
    val map = mutableMapOf<String, Any>()

    override fun getAll(): MutableMap<String, *> = map

    override fun getString(key: String?, defValue: String?): String? =
        map[key] as? String ?: defValue

    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? =
        map[key] as? MutableSet<String> ?: defValues

    override fun getInt(key: String?, defValue: Int): Int =
        (map[key] as? Number)?.toInt() ?: defValue

    override fun getLong(key: String?, defValue: Long): Long =
        (map[key] as? Number)?.toLong() ?: defValue

    override fun getFloat(key: String?, defValue: Float): Float =
        (map[key] as? Number)?.toFloat() ?: defValue

    override fun getBoolean(key: String?, defValue: Boolean): Boolean =
        map[key] as? Boolean ?: defValue

    override fun contains(key: String?): Boolean = map.containsKey(key)

    override fun edit(): SharedPreferences.Editor = FakeEditor(this)

    override fun registerOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {}

    override fun unregisterOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {}

    class FakeEditor(private val parent: FakeSharedPreferences) : SharedPreferences.Editor {
        private val temp = mutableMapOf<String, Any?>()
        private var clear = false

        override fun putString(key: String?, value: String?): SharedPreferences.Editor {
            key?.let { temp[it] = value }
            return this
        }

        override fun putStringSet(key: String?, values: MutableSet<String>?): SharedPreferences.Editor {
            key?.let { temp[it] = values }
            return this
        }

        override fun putInt(key: String?, value: Int): SharedPreferences.Editor {
            key?.let { temp[it] = value }
            return this
        }

        override fun putLong(key: String?, value: Long): SharedPreferences.Editor {
            key?.let { temp[it] = value }
            return this
        }

        override fun putFloat(key: String?, value: Float): SharedPreferences.Editor {
            key?.let { temp[it] = value }
            return this
        }

        override fun putBoolean(key: String?, value: Boolean): SharedPreferences.Editor {
            key?.let { temp[it] = value }
            return this
        }

        override fun remove(key: String?): SharedPreferences.Editor {
            key?.let { temp[it] = null }
            return this
        }

        override fun clear(): SharedPreferences.Editor {
            clear = true
            return this
        }

        override fun commit(): Boolean {
            apply()
            return true
        }

        override fun apply() {
            if (clear) parent.map.clear()
            for ((k, v) in temp) {
                if (v == null) parent.map.remove(k)
                else parent.map[k] = v
            }
        }
    }
}

class StreakManagerTest {

    private lateinit var fakeDao: FakeUserStatsDao
    private lateinit var fakePrefs: FakeSharedPreferences
    private lateinit var preferences: AppPreferences
    private lateinit var manager: StreakManager
    private val zone = ZoneId.systemDefault()

    @Before
    fun setup() {
        fakeDao = FakeUserStatsDao()
        fakePrefs = FakeSharedPreferences()
        preferences = AppPreferences(fakePrefs)
        preferences.gracePeriodHours = 0.0
        manager = StreakManager(fakeDao, preferences)
    }

    @Test
    fun testFirstStudyDayStartsStreakAtOne() = runBlocking {
        val today = LocalDate.of(2026, 10, 15)
        val todayMs = today.atStartOfDay(zone).toInstant().toEpochMilli()

        val stats = manager.recordStudyDay(todayMs)
        assertEquals(1, stats.currentStreak)
        assertEquals(1, stats.longestStreak)
        assertEquals(0, stats.freezeTokens)
    }

    @Test
    fun testSameDayStudyDoesNotIncrementStreak() = runBlocking {
        val today = LocalDate.of(2026, 10, 15)
        val morningMs = today.atTime(9, 0).atZone(zone).toInstant().toEpochMilli()
        val eveningMs = today.atTime(20, 0).atZone(zone).toInstant().toEpochMilli()

        manager.recordStudyDay(morningMs)
        val second = manager.recordStudyDay(eveningMs)
        assertEquals(1, second.currentStreak)
    }

    @Test
    fun testConsecutiveDayIncrementsStreak() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 15)
        val day2 = LocalDate.of(2026, 10, 16)
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()
        val day2Ms = day2.atStartOfDay(zone).toInstant().toEpochMilli()

        manager.recordStudyDay(day1Ms)
        val second = manager.recordStudyDay(day2Ms)
        assertEquals(2, second.currentStreak)
        assertEquals(2, second.longestStreak)
    }

    @Test
    fun testTwoDayGapConsumesFreezeToken() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 15)
        val day3 = LocalDate.of(2026, 10, 17) // 2-day gap (skipped 10-16)
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()
        val day3Ms = day3.atStartOfDay(zone).toInstant().toEpochMilli()

        // Set initial stats with 1 freeze token and 5 streak
        fakeDao.stats = UserStatsEntity(
            currentStreak = 5,
            longestStreak = 5,
            lastStudyDate = day1Ms,
            freezeTokens = 1
        )

        val updated = manager.recordStudyDay(day3Ms)
        assertEquals(6, updated.currentStreak)
        assertEquals(0, updated.freezeTokens)
        assertEquals("2026-10-17", preferences.lastFreezeUseDate)
    }

    @Test
    fun testTwoDayGapWithoutFreezeTokenResetsStreak() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 15)
        val day3 = LocalDate.of(2026, 10, 17)
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()
        val day3Ms = day3.atStartOfDay(zone).toInstant().toEpochMilli()

        fakeDao.stats = UserStatsEntity(
            currentStreak = 5,
            longestStreak = 5,
            lastStudyDate = day1Ms,
            freezeTokens = 0
        )

        val updated = manager.recordStudyDay(day3Ms)
        assertEquals(1, updated.currentStreak)
        assertEquals(5, updated.longestStreak)
    }

    @Test
    fun testTenStreakAwardsFreezeToken() = runBlocking {
        val day9 = LocalDate.of(2026, 10, 14)
        val day10 = LocalDate.of(2026, 10, 15)
        val day9Ms = day9.atStartOfDay(zone).toInstant().toEpochMilli()
        val day10Ms = day10.atStartOfDay(zone).toInstant().toEpochMilli()

        fakeDao.stats = UserStatsEntity(
            currentStreak = 9,
            longestStreak = 9,
            lastStudyDate = day9Ms,
            freezeTokens = 0
        )

        val updated = manager.recordStudyDay(day10Ms)
        assertEquals(10, updated.currentStreak)
        assertEquals(1, updated.freezeTokens)
    }

    @Test
    fun testEvaluateCurrentStreakKillsDeadStreak() = runBlocking {
        val day1 = LocalDate.of(2026, 10, 10)
        val today = LocalDate.of(2026, 10, 15) // 5 day gap
        val day1Ms = day1.atStartOfDay(zone).toInstant().toEpochMilli()
        val todayMs = today.atStartOfDay(zone).toInstant().toEpochMilli()

        fakeDao.stats = UserStatsEntity(
            currentStreak = 10,
            longestStreak = 10,
            lastStudyDate = day1Ms,
            freezeTokens = 1
        )

        val result = manager.evaluateCurrentStreak(todayMs)
        assertNotNull(result)
        assertEquals(0, result?.currentStreak)
    }
}
