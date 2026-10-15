package de.schuelken.studyhabit.core.service

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import de.schuelken.studyhabit.MainActivity
import de.schuelken.studyhabit.R

object NotificationHelper {
    const val CHANNEL_TIMER_ID = "studyhabit_timer_channel"
    const val CHANNEL_REMINDERS_ID = "studyhabit_reminders_channel"
    const val TIMER_NOTIFICATION_ID = 1001
    const val REMINDER_NOTIFICATION_ID = 1002

    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val timerChannel = NotificationChannel(
                CHANNEL_TIMER_ID,
                "Study Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Ongoing study timer notification"
                setShowBadge(false)
            }

            val remindersChannel = NotificationChannel(
                CHANNEL_REMINDERS_ID,
                "Study Reminders",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Reminders to study and maintain streaks"
            }

            notificationManager.createNotificationChannel(timerChannel)
            notificationManager.createNotificationChannel(remindersChannel)
        }
    }

    fun sendStudyReminderNotification(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ActivityCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            return
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_REMINDERS_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Time to Study!")
            .setContentText("Keep your streak alive and make progress on your goals.")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(REMINDER_NOTIFICATION_ID, notification)
    }
}
