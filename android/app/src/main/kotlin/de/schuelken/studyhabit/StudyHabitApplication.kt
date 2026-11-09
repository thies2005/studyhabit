package de.schuelken.studyhabit

import android.app.Application
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.service.NotificationHelper
import de.schuelken.studyhabit.core.service.TimerForegroundService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class StudyHabitApplication : Application() {
    lateinit var container: AppContainer
        private set

    val appScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
        NotificationHelper.createNotificationChannels(this)
        TimerForegroundService.restoreIfNeeded(this)
        container.scheduleFolderSync()

        appScope.launch {
            container.database.sessionDao().cleanupOrphanedSessions(
                System.currentTimeMillis() - (2 * 3600_000L)
            )
        }

        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                appScope.launch {
                    container.ankiDroidService.syncLinkedDecks(syncPastDays = true)

                    val folderSynced = if (container.preferences.folderSyncEnabled.value &&
                        !container.preferences.folderSyncUri.value.isNullOrBlank()
                    ) {
                        container.folderSyncService.syncWithFolder()
                    } else {
                        false
                    }

                    val serverSynced = if (!container.tokenStorage.getToken().isNullOrBlank() &&
                        container.preferences.serverUrl.value.isNotBlank()
                    ) {
                        container.syncEngine.syncNow()
                    } else {
                        false
                    }

                    if (folderSynced || serverSynced) {
                        container.ankiDroidService.syncLinkedDecks(syncPastDays = false)
                    }

                    container.streakManager.evaluateCurrentStreak()
                    container.achievementEvaluator.checkAndUnlock()
                }
            }

            override fun onStop(owner: LifecycleOwner) {
                appScope.launch {
                    if (container.preferences.folderSyncEnabled.value &&
                        !container.preferences.folderSyncUri.value.isNullOrBlank()
                    ) {
                        container.folderSyncService.syncWithFolder()
                    }
                    if (!container.tokenStorage.getToken().isNullOrBlank() &&
                        container.preferences.serverUrl.value.isNotBlank()
                    ) {
                        container.syncEngine.syncNow()
                    }
                }
            }
        })
    }
}
