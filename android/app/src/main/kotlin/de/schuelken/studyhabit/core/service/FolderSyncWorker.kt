package de.schuelken.studyhabit.core.service

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import de.schuelken.studyhabit.StudyHabitApplication
import java.util.concurrent.TimeUnit

class FolderSyncWorker(context: Context, parameters: WorkerParameters) :
    CoroutineWorker(context, parameters) {

    override suspend fun doWork(): Result {
        val container = (applicationContext as StudyHabitApplication).container
        val preferences = container.preferences
        if (!preferences.folderSyncEnabled.value || preferences.folderSyncUri.value.isNullOrBlank()) {
            return Result.success()
        }
        return if (container.folderSyncService.syncWithFolder()) Result.success() else Result.retry()
    }

    companion object {
        private const val PERIODIC = "folder-sync-periodic"
        private const val SOON = "folder-sync-soon"
        private val connected = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        fun ensureScheduled(context: Context) {
            val request = PeriodicWorkRequestBuilder<FolderSyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(connected)
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                PERIODIC, ExistingPeriodicWorkPolicy.KEEP, request
            )
        }

        fun requestSoon(context: Context) {
            // Keep a pending attempt when offline or when the process stops.
            // Foreground sync and periodic work cover edits arriving during this attempt.
            val request = OneTimeWorkRequestBuilder<FolderSyncWorker>()
                .setConstraints(connected)
                .setInitialDelay(10, TimeUnit.SECONDS)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(SOON, ExistingWorkPolicy.KEEP, request)
        }
    }
}
