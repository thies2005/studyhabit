package de.schuelken.studyhabit.core.service

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import de.schuelken.studyhabit.core.preferences.AppPreferences
import java.util.concurrent.TimeUnit

class ReminderWorker(
    context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {
    override fun doWork(): Result {
        NotificationHelper.sendStudyReminderNotification(applicationContext)
        return Result.success()
    }
}

class ReminderScheduler(
    private val context: Context,
    private val preferences: AppPreferences,
) {
    fun scheduleStudyReminder(minutes: Int) {
        val workManager = WorkManager.getInstance(context)
        if (!preferences.studyReminderEnabled || minutes <= 0) {
            workManager.cancelUniqueWork("study_reminder_work")
            return
        }

        val workRequest = OneTimeWorkRequestBuilder<ReminderWorker>()
            .setInitialDelay(minutes.toLong(), TimeUnit.MINUTES)
            .build()

        workManager.enqueueUniqueWork(
            "study_reminder_work",
            ExistingWorkPolicy.REPLACE,
            workRequest
        )
    }

    fun cancelReminder() {
        WorkManager.getInstance(context).cancelUniqueWork("study_reminder_work")
    }
}
