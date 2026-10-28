package de.schuelken.studyhabit.ui.timer

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.model.TimerPhase
import de.schuelken.studyhabit.core.service.TimerForegroundService

@Composable
fun PomodoroScreen(
    container: AppContainer,
    onNavigateBack: () -> Unit
) {
    val context = LocalContext.current
    val timerState by TimerForegroundService.timerState.collectAsState()
    var showReviewSheet by remember { mutableStateOf(false) }

    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = 1.04f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse_scale"
    )

    val remaining = timerState.remainingSeconds
    val total = if (timerState.totalSeconds > 0) timerState.totalSeconds else 1
    val progress = (remaining.toFloat() / total.toFloat()).coerceIn(0f, 1f)

    val primaryColor = MaterialTheme.colorScheme.primary
    val trackColor = MaterialTheme.colorScheme.surfaceVariant

    Column(
        modifier = Modifier
            .fillMaxSize()
            .systemBarsPadding()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = timerState.subjectName.ifEmpty { "Focus Session" },
                style = MaterialTheme.typography.headlineMedium
            )
            Spacer(modifier = Modifier.height(4.dp))
            val phaseText = when {
                timerState.isOvertime -> "Continuous Focus (Overtime)"
                timerState.phase == TimerPhase.WORK -> "Focus Phase"
                timerState.phase == TimerPhase.SHORT_BREAK -> "Short Break"
                timerState.phase == TimerPhase.LONG_BREAK -> "Long Break"
                else -> "Paused"
            }
            Text(
                text = phaseText,
                style = MaterialTheme.typography.titleMedium,
                color = if (timerState.isOvertime) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.primary
            )
        }

        // Circular Timer Canvas
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(280.dp)
        ) {
            val progressPercent = (progress * 100).toInt()
            val phaseText = when {
                timerState.isOvertime -> "Continuous Focus (Overtime)"
                timerState.phase == TimerPhase.WORK -> "Focus Phase"
                timerState.phase == TimerPhase.SHORT_BREAK -> "Short Break"
                timerState.phase == TimerPhase.LONG_BREAK -> "Long Break"
                else -> "Paused"
            }
            Canvas(
                modifier = Modifier
                    .size(260.dp)
                    .semantics {
                        contentDescription = if (timerState.isOvertime) {
                            "Overtime focus: ${timerState.overtimeSeconds / 60} minutes ${timerState.overtimeSeconds % 60} seconds"
                        } else {
                            "$phaseText progress: $progressPercent%"
                        }
                    }
            ) {
                val strokeWidth = 16.dp.toPx()
                val radius = (size.minDimension - strokeWidth) / 2
                val center = Offset(size.width / 2, size.height / 2)

                // Track circle
                drawCircle(
                    color = trackColor,
                    radius = radius,
                    center = center,
                    style = Stroke(width = strokeWidth)
                )

                // Active progress arc
                val sweepAngle = progress * 360f
                drawArc(
                    color = if (timerState.isOvertime) Color(0xFFFFB599) else primaryColor,
                    startAngle = -90f,
                    sweepAngle = sweepAngle,
                    useCenter = false,
                    topLeft = Offset(center.x - radius, center.y - radius),
                    size = Size(radius * 2, radius * 2),
                    style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                )
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                val displayTime = if (timerState.isOvertime) {
                    val m = timerState.overtimeSeconds / 60
                    val s = timerState.overtimeSeconds % 60
                    "+%02d:%02d".format(m, s)
                } else {
                    val m = remaining / 60
                    val s = remaining % 60
                    "%02d:%02d".format(m, s)
                }
                Text(
                    text = displayTime,
                    fontSize = 48.sp,
                    style = MaterialTheme.typography.displayLarge
                )
                if (timerState.pomodorosCompleted > 0) {
                    Text(
                        text = "${timerState.pomodorosCompleted} completed",
                        style = MaterialTheme.typography.labelMedium
                    )
                }
            }
        }

        // Controls
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Stop button
            IconButton(
                onClick = {
                    TimerForegroundService.pause(context)
                    showReviewSheet = true
                },
                modifier = Modifier.size(56.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Stop,
                    contentDescription = "Stop",
                    modifier = Modifier.size(32.dp),
                    tint = MaterialTheme.colorScheme.error
                )
            }

            // Play / Pause button
            Button(
                onClick = {
                    if (timerState.isPaused) {
                        TimerForegroundService.resume(context)
                    } else {
                        TimerForegroundService.pause(context)
                    }
                },
                modifier = Modifier.size(72.dp),
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
            ) {
                Icon(
                    imageVector = if (timerState.isPaused) Icons.Default.PlayArrow else Icons.Default.Pause,
                    contentDescription = if (timerState.isPaused) "Resume" else "Pause",
                    modifier = Modifier.size(36.dp)
                )
            }

            // Skip Phase button
            IconButton(
                onClick = { TimerForegroundService.skipPhase(context) },
                modifier = Modifier.size(56.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.SkipNext,
                    contentDescription = "Skip Phase",
                    modifier = Modifier.size(32.dp)
                )
            }
        }
    }

    if (showReviewSheet) {
        SessionReviewSheet(
            timerState = timerState,
            container = container,
            onFinished = {
                TimerForegroundService.finishWithoutSaving(context)
                showReviewSheet = false
                onNavigateBack()
            }
        )
    }
}
