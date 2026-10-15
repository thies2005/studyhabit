package de.schuelken.studyhabit.ui.timer

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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.service.TimerForegroundService

@Composable
fun FreeTimerScreen(
    container: AppContainer,
    onNavigateBack: () -> Unit
) {
    val context = LocalContext.current
    val timerState by TimerForegroundService.timerState.collectAsState()
    var showReviewSheet by remember { mutableStateOf(false) }

    val elapsed = timerState.elapsedSeconds
    val primaryColor = MaterialTheme.colorScheme.primary
    val trackColor = MaterialTheme.colorScheme.surfaceVariant

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = timerState.subjectName.ifEmpty { "Free Focus Session" },
                style = MaterialTheme.typography.headlineMedium
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = if (timerState.isPaused) "Paused" else "Focusing",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary
            )
        }

        // Circular Timer Canvas
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(280.dp)
        ) {
            Canvas(modifier = Modifier.size(260.dp)) {
                val strokeWidth = 16.dp.toPx()
                val radius = (size.minDimension - strokeWidth) / 2
                val center = Offset(size.width / 2, size.height / 2)

                drawCircle(
                    color = trackColor,
                    radius = radius,
                    center = center,
                    style = Stroke(width = strokeWidth)
                )

                val sweepAngle = ((elapsed % 3600) / 3600f) * 360f
                drawArc(
                    color = primaryColor,
                    startAngle = -90f,
                    sweepAngle = sweepAngle,
                    useCenter = false,
                    topLeft = Offset(center.x - radius, center.y - radius),
                    size = androidx.compose.ui.geometry.Size(radius * 2, radius * 2),
                    style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                )
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                val h = elapsed / 3600
                val m = (elapsed % 3600) / 60
                val s = elapsed % 60
                val displayTime = if (h > 0) "%02d:%02d:%02d".format(h, m, s) else "%02d:%02d".format(m, s)
                Text(
                    text = displayTime,
                    fontSize = 44.sp,
                    style = MaterialTheme.typography.displayLarge
                )
            }
        }

        // Controls
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
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
        }
    }

    if (showReviewSheet) {
        SessionReviewSheet(
            timerState = timerState,
            container = container,
            onFinished = {
                TimerForegroundService.stop(context)
                showReviewSheet = false
                onNavigateBack()
            }
        )
    }
}
