package de.schuelken.studyhabit.ui.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import de.schuelken.studyhabit.MainActivity
import de.schuelken.studyhabit.R
import de.schuelken.studyhabit.core.database.AppDatabase
import de.schuelken.studyhabit.core.preferences.AppPreferences
import de.schuelken.studyhabit.core.service.TimerForegroundService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId

class StudyHabitWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_START_SESSION_FROM_WIDGET = "de.schuelken.studyhabit.START_SESSION_FROM_WIDGET"

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val componentName = ComponentName(context, StudyHabitWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                val intent = Intent(context, StudyHabitWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                }
                context.sendBroadcast(intent)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val db = AppDatabase.getInstance(context)
                val prefs = AppPreferences(context)
                val zone = ZoneId.systemDefault()
                val today = LocalDate.now(zone)
                val todayStartMs = today.atStartOfDay(zone).toInstant().toEpochMilli()

                val activeProjectId = prefs.activeProjectId.value
                val allSessions = db.sessionDao().getAllSessions()
                val todaySessions = allSessions.filter { it.startedAt >= todayStartMs && !it.isDeleted }
                val todayMinutes = if (activeProjectId.isNullOrBlank()) {
                    todaySessions.sumOf { it.actualDurationMinutes }
                } else {
                    val subjectsInProject = db.subjectDao().getSubjectsForProject(activeProjectId).map { it.id }.toSet()
                    todaySessions.filter { it.subjectId in subjectsInProject }.sumOf { it.actualDurationMinutes }
                }

                val goalMinutes = prefs.getWeekdayGoalMinutes(today.dayOfWeek.value)
                val userStats = db.userStatsDao().getUserStats()
                val streak = userStats?.currentStreak ?: 0
                val timerState = TimerForegroundService.timerState.value

                for (appWidgetId in appWidgetIds) {
                    val views = RemoteViews(context.packageName, R.layout.study_habit_widget)

                    val timeText = "$todayMinutes / $goalMinutes min"
                    views.setTextViewText(R.id.widget_time_text, timeText)

                    val progressPercent = if (goalMinutes > 0) {
                        ((todayMinutes.toFloat() / goalMinutes.toFloat()) * 100).toInt().coerceIn(0, 100)
                    } else {
                        if (todayMinutes > 0) 100 else 0
                    }
                    views.setProgressBar(R.id.widget_progress, 100, progressPercent, false)

                    val subtitle = if (timerState.isRunning && timerState.subjectName.isNotBlank()) {
                        "Focusing: ${timerState.subjectName}"
                    } else {
                        "🔥 $streak day streak"
                    }
                    views.setTextViewText(R.id.widget_subtitle_text, subtitle)

                    // Root click opens MainActivity
                    val rootIntent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val rootPendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        rootIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_root, rootPendingIntent)

                    // Plus button opens MainActivity with ACTION_START_SESSION_FROM_WIDGET
                    val addIntent = Intent(context, MainActivity::class.java).apply {
                        action = ACTION_START_SESSION_FROM_WIDGET
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val addPendingIntent = PendingIntent.getActivity(
                        context,
                        1,
                        addIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_add_button, addPendingIntent)

                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
            } catch (e: Exception) {
                // Ignore widget update failures
            } finally {
                pendingResult.finish()
            }
        }
    }
}
