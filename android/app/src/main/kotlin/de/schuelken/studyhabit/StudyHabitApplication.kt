package de.schuelken.studyhabit

import android.app.Application
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.service.NotificationHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class StudyHabitApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
        NotificationHelper.createNotificationChannels(this)

        val appScope = CoroutineScope(Dispatchers.IO)
        appScope.launch {
            // Clean up any sessions that were active across unexpected process death (> 2 hours old)
            container.database.sessionDao().cleanupOrphanedSessions(
                System.currentTimeMillis() - (2 * 3600_000L)
            )
            // Evaluate streak deadness
            container.streakManager.evaluateCurrentStreak()

            // Schedule sync if authenticated
            if (!container.tokenStorage.getToken().isNullOrBlank()) {
                container.syncEngine.scheduleDebouncedSync()
            }
        }
    }
}
