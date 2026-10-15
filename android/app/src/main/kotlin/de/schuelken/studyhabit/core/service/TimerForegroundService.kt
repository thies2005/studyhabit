package de.schuelken.studyhabit.core.service

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import de.schuelken.studyhabit.MainActivity
import de.schuelken.studyhabit.R
import de.schuelken.studyhabit.core.model.TimerPhase
import de.schuelken.studyhabit.core.model.TimerType
import de.schuelken.studyhabit.core.preferences.AppPreferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID

@Serializable
data class TimerPersistedState(
    val timerType: String,
    val phase: String,
    val isRunning: Boolean,
    val isPaused: Boolean,
    val subjectId: String,
    val subjectName: String,
    val topicId: String? = null,
    val chapterId: String? = null,
    val sourceId: String? = null,
    val totalSeconds: Int,
    val remainingSeconds: Int,
    val elapsedSeconds: Int,
    val overtimeSeconds: Int,
    val isOvertime: Boolean,
    val pomodorosCompleted: Int,
    val startedAt: Long,
    val sessionId: String,
)

data class TimerState(
    val timerType: TimerType = TimerType.POMODORO,
    val phase: TimerPhase = TimerPhase.IDLE,
    val isRunning: Boolean = false,
    val isPaused: Boolean = false,
    val subjectId: String = "",
    val subjectName: String = "",
    val topicId: String? = null,
    val chapterId: String? = null,
    val sourceId: String? = null,
    val totalSeconds: Int = 0,
    val remainingSeconds: Int = 0,
    val elapsedSeconds: Int = 0,
    val overtimeSeconds: Int = 0,
    val isOvertime: Boolean = false,
    val pomodorosCompleted: Int = 0,
    val startedAt: Long = 0L,
    val sessionId: String = "",
)

class TimerForegroundService : Service() {

    companion object {
        const val ACTION_START_POMODORO = "de.schuelken.studyhabit.START_POMODORO"
        const val ACTION_START_FREE_TIMER = "de.schuelken.studyhabit.START_FREE_TIMER"
        const val ACTION_PAUSE = "de.schuelken.studyhabit.PAUSE"
        const val ACTION_RESUME = "de.schuelken.studyhabit.RESUME"
        const val ACTION_SKIP_PHASE = "de.schuelken.studyhabit.SKIP_PHASE"
        const val ACTION_STOP = "de.schuelken.studyhabit.STOP"

        const val EXTRA_SUBJECT_ID = "subject_id"
        const val EXTRA_SUBJECT_NAME = "subject_name"
        const val EXTRA_TOPIC_ID = "topic_id"
        const val EXTRA_CHAPTER_ID = "chapter_id"
        const val EXTRA_SOURCE_ID = "source_id"
        const val EXTRA_WORK_DURATION_MINUTES = "work_duration_minutes"

        private val _timerState = MutableStateFlow(TimerState())
        val timerState: StateFlow<TimerState> = _timerState.asStateFlow()

        fun startPomodoro(
            context: Context,
            subjectId: String,
            subjectName: String,
            topicId: String? = null,
            chapterId: String? = null,
            sourceId: String? = null,
            durationMinutes: Int = 25
        ) {
            val intent = Intent(context, TimerForegroundService::class.java).apply {
                action = ACTION_START_POMODORO
                putExtra(EXTRA_SUBJECT_ID, subjectId)
                putExtra(EXTRA_SUBJECT_NAME, subjectName)
                putExtra(EXTRA_TOPIC_ID, topicId)
                putExtra(EXTRA_CHAPTER_ID, chapterId)
                putExtra(EXTRA_SOURCE_ID, sourceId)
                putExtra(EXTRA_WORK_DURATION_MINUTES, durationMinutes)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun startFreeTimer(
            context: Context,
            subjectId: String,
            subjectName: String,
            topicId: String? = null,
            chapterId: String? = null,
            sourceId: String? = null
        ) {
            val intent = Intent(context, TimerForegroundService::class.java).apply {
                action = ACTION_START_FREE_TIMER
                putExtra(EXTRA_SUBJECT_ID, subjectId)
                putExtra(EXTRA_SUBJECT_NAME, subjectName)
                putExtra(EXTRA_TOPIC_ID, topicId)
                putExtra(EXTRA_CHAPTER_ID, chapterId)
                putExtra(EXTRA_SOURCE_ID, sourceId)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun pause(context: Context) {
            context.startService(Intent(context, TimerForegroundService::class.java).apply { action = ACTION_PAUSE })
        }

        fun resume(context: Context) {
            context.startService(Intent(context, TimerForegroundService::class.java).apply { action = ACTION_RESUME })
        }

        fun skipPhase(context: Context) {
            context.startService(Intent(context, TimerForegroundService::class.java).apply { action = ACTION_SKIP_PHASE })
        }

        fun stop(context: Context) {
            context.startService(Intent(context, TimerForegroundService::class.java).apply { action = ACTION_STOP })
        }
    }

    private val serviceScope = CoroutineScope(Dispatchers.Default)
    private var tickerJob: Job? = null
    private var baseElapsedRealtime: Long = 0L
    private var accumulatedElapsedSeconds: Int = 0
    private lateinit var preferences: AppPreferences

    override fun onCreate() {
        super.onCreate()
        preferences = AppPreferences(applicationContext)
        NotificationHelper.createNotificationChannels(this)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_POMODORO -> {
                val subjectId = intent.getStringExtra(EXTRA_SUBJECT_ID) ?: ""
                val subjectName = intent.getStringExtra(EXTRA_SUBJECT_NAME) ?: "Subject"
                val topicId = intent.getStringExtra(EXTRA_TOPIC_ID)
                val chapterId = intent.getStringExtra(EXTRA_CHAPTER_ID)
                val sourceId = intent.getStringExtra(EXTRA_SOURCE_ID)
                val duration = intent.getIntExtra(EXTRA_WORK_DURATION_MINUTES, preferences.workDuration)
                initPomodoro(subjectId, subjectName, topicId, chapterId, sourceId, duration)
            }
            ACTION_START_FREE_TIMER -> {
                val subjectId = intent.getStringExtra(EXTRA_SUBJECT_ID) ?: ""
                val subjectName = intent.getStringExtra(EXTRA_SUBJECT_NAME) ?: "Subject"
                val topicId = intent.getStringExtra(EXTRA_TOPIC_ID)
                val chapterId = intent.getStringExtra(EXTRA_CHAPTER_ID)
                val sourceId = intent.getStringExtra(EXTRA_SOURCE_ID)
                initFreeTimer(subjectId, subjectName, topicId, chapterId, sourceId)
            }
            ACTION_PAUSE -> pauseTimer()
            ACTION_RESUME -> resumeTimer()
            ACTION_SKIP_PHASE -> skipToNextPhase()
            ACTION_STOP -> stopTimer()
        }
        return START_NOT_STICKY
    }

    private fun initPomodoro(
        subjectId: String,
        subjectName: String,
        topicId: String?,
        chapterId: String?,
        sourceId: String?,
        durationMinutes: Int
    ) {
        val totalSec = durationMinutes * 60
        accumulatedElapsedSeconds = 0
        baseElapsedRealtime = SystemClock.elapsedRealtime()

        val state = TimerState(
            timerType = TimerType.POMODORO,
            phase = TimerPhase.WORK,
            isRunning = true,
            isPaused = false,
            subjectId = subjectId,
            subjectName = subjectName,
            topicId = topicId,
            chapterId = chapterId,
            sourceId = sourceId,
            totalSeconds = totalSec,
            remainingSeconds = totalSec,
            elapsedSeconds = 0,
            overtimeSeconds = 0,
            isOvertime = false,
            pomodorosCompleted = 0,
            startedAt = System.currentTimeMillis(),
            sessionId = UUID.randomUUID().toString(),
        )
        _timerState.value = state
        persistState(state)
        startForegroundWithNotification(state)
        startTicker()
    }

    private fun initFreeTimer(
        subjectId: String,
        subjectName: String,
        topicId: String?,
        chapterId: String?,
        sourceId: String?
    ) {
        accumulatedElapsedSeconds = 0
        baseElapsedRealtime = SystemClock.elapsedRealtime()

        val state = TimerState(
            timerType = TimerType.FREE_TIMER,
            phase = TimerPhase.WORK,
            isRunning = true,
            isPaused = false,
            subjectId = subjectId,
            subjectName = subjectName,
            topicId = topicId,
            chapterId = chapterId,
            sourceId = sourceId,
            totalSeconds = 0,
            remainingSeconds = 0,
            elapsedSeconds = 0,
            overtimeSeconds = 0,
            isOvertime = false,
            pomodorosCompleted = 0,
            startedAt = System.currentTimeMillis(),
            sessionId = UUID.randomUUID().toString(),
        )
        _timerState.value = state
        persistState(state)
        startForegroundWithNotification(state)
        startTicker()
    }

    private fun pauseTimer() {
        if (!_timerState.value.isRunning || _timerState.value.isPaused) return
        val currentRunningSec = ((SystemClock.elapsedRealtime() - baseElapsedRealtime) / 1000).toInt()
        accumulatedElapsedSeconds += currentRunningSec
        val updated = _timerState.value.copy(isPaused = true)
        _timerState.value = updated
        persistState(updated)
        tickerJob?.cancel()
        updateNotification(updated)
    }

    private fun resumeTimer() {
        if (!_timerState.value.isRunning || !_timerState.value.isPaused) return
        baseElapsedRealtime = SystemClock.elapsedRealtime()
        val updated = _timerState.value.copy(isPaused = false)
        _timerState.value = updated
        persistState(updated)
        startTicker()
        updateNotification(updated)
    }

    private fun skipToNextPhase() {
        val curr = _timerState.value
        if (curr.timerType != TimerType.POMODORO) return

        accumulatedElapsedSeconds = 0
        baseElapsedRealtime = SystemClock.elapsedRealtime()

        val (nextPhase, nextDuration) = when (curr.phase) {
            TimerPhase.WORK -> {
                val completed = curr.pomodorosCompleted + 1
                if (completed % preferences.longBreakEvery == 0) {
                    TimerPhase.LONG_BREAK to (preferences.longBreakDuration * 60)
                } else {
                    TimerPhase.SHORT_BREAK to (preferences.shortBreakDuration * 60)
                }
            }
            TimerPhase.SHORT_BREAK, TimerPhase.LONG_BREAK -> {
                TimerPhase.WORK to (preferences.workDuration * 60)
            }
            TimerPhase.IDLE -> TimerPhase.WORK to (preferences.workDuration * 60)
        }

        val updated = curr.copy(
            phase = nextPhase,
            totalSeconds = nextDuration,
            remainingSeconds = nextDuration,
            elapsedSeconds = 0,
            overtimeSeconds = 0,
            isOvertime = false,
            pomodorosCompleted = if (curr.phase == TimerPhase.WORK) curr.pomodorosCompleted + 1 else curr.pomodorosCompleted,
            isPaused = false,
        )
        _timerState.value = updated
        persistState(updated)
        updateNotification(updated)
    }

    private fun stopTimer() {
        tickerJob?.cancel()
        val stopped = _timerState.value.copy(isRunning = false, isPaused = false)
        _timerState.value = stopped
        preferences.clearActiveTimers()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startTicker() {
        tickerJob?.cancel()
        tickerJob = serviceScope.launch {
            while (isActive) {
                delay(1000)
                val curr = _timerState.value
                if (!curr.isRunning || curr.isPaused) continue

                val runningSec = ((SystemClock.elapsedRealtime() - baseElapsedRealtime) / 1000).toInt()
                val totalElapsed = accumulatedElapsedSeconds + runningSec

                if (curr.timerType == TimerType.FREE_TIMER) {
                    val updated = curr.copy(elapsedSeconds = totalElapsed)
                    _timerState.value = updated
                    updateNotification(updated)
                } else {
                    // Pomodoro mode
                    if (totalElapsed < curr.totalSeconds) {
                        val remaining = curr.totalSeconds - totalElapsed
                        val updated = curr.copy(
                            elapsedSeconds = totalElapsed,
                            remainingSeconds = remaining,
                            isOvertime = false,
                            overtimeSeconds = 0,
                        )
                        _timerState.value = updated
                        updateNotification(updated)
                    } else {
                        // Work phase completed or in overtime
                        if (preferences.continuousFocus && curr.phase == TimerPhase.WORK) {
                            val overtime = totalElapsed - curr.totalSeconds
                            val updated = curr.copy(
                                elapsedSeconds = totalElapsed,
                                remainingSeconds = 0,
                                isOvertime = true,
                                overtimeSeconds = overtime,
                            )
                            _timerState.value = updated
                            updateNotification(updated)
                        } else {
                            // Automatically transition or wait
                            skipToNextPhase()
                        }
                    }
                }
            }
        }
    }

    private fun persistState(state: TimerState) {
        val json = Json.encodeToString(
            TimerPersistedState(
                timerType = state.timerType.value,
                phase = state.phase.value,
                isRunning = state.isRunning,
                isPaused = state.isPaused,
                subjectId = state.subjectId,
                subjectName = state.subjectName,
                topicId = state.topicId,
                chapterId = state.chapterId,
                sourceId = state.sourceId,
                totalSeconds = state.totalSeconds,
                remainingSeconds = state.remainingSeconds,
                elapsedSeconds = state.elapsedSeconds,
                overtimeSeconds = state.overtimeSeconds,
                isOvertime = state.isOvertime,
                pomodorosCompleted = state.pomodorosCompleted,
                startedAt = state.startedAt,
                sessionId = state.sessionId,
            )
        )
        preferences.activeTimerType = state.timerType.value
        if (state.timerType == TimerType.POMODORO) {
            preferences.pomodoroStateJson = json
        } else {
            preferences.freeTimerStateJson = json
        }
    }

    private fun startForegroundWithNotification(state: TimerState) {
        val notification = buildNotification(state)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NotificationHelper.TIMER_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NotificationHelper.TIMER_NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(state: TimerState) {
        val notification = buildNotification(state)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        manager.notify(NotificationHelper.TIMER_NOTIFICATION_ID, notification)
    }

    private fun buildNotification(state: TimerState): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openPending = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = when {
            state.isOvertime -> "Overtime Focus: ${state.subjectName}"
            state.phase == TimerPhase.WORK -> "Focus: ${state.subjectName}"
            state.phase == TimerPhase.SHORT_BREAK -> "Short Break"
            state.phase == TimerPhase.LONG_BREAK -> "Long Break"
            else -> "StudyHabit Timer"
        }

        val text = when {
            state.timerType == TimerType.FREE_TIMER -> "Elapsed: ${formatTime(state.elapsedSeconds)}"
            state.isOvertime -> "+${formatTime(state.overtimeSeconds)} extra"
            else -> "${formatTime(state.remainingSeconds)} remaining"
        }

        val builder = NotificationCompat.Builder(this, NotificationHelper.CHANNEL_TIMER_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(openPending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)

        // Add pause/resume action
        if (state.isPaused) {
            val resumeIntent = Intent(this, TimerForegroundService::class.java).apply { action = ACTION_RESUME }
            val resumePending = PendingIntent.getService(this, 1, resumeIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            builder.addAction(android.R.drawable.ic_media_play, "Resume", resumePending)
        } else {
            val pauseIntent = Intent(this, TimerForegroundService::class.java).apply { action = ACTION_PAUSE }
            val pausePending = PendingIntent.getService(this, 2, pauseIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            builder.addAction(android.R.drawable.ic_media_pause, "Pause", pausePending)
        }

        // Add stop action
        val stopIntent = Intent(this, TimerForegroundService::class.java).apply { action = ACTION_STOP }
        val stopPending = PendingIntent.getService(this, 3, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPending)

        return builder.build()
    }

    private fun formatTime(seconds: Int): String {
        val m = seconds / 60
        val s = seconds % 60
        return "%02d:%02d".format(m, s)
    }

    override fun onDestroy() {
        tickerJob?.cancel()
        super.onDestroy()
    }
}
