package de.schuelken.studyhabit.ui.blocker

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.os.SystemClock
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.graphics.drawable.toBitmap
import de.schuelken.studyhabit.MainActivity
import de.schuelken.studyhabit.core.model.TimerType
import de.schuelken.studyhabit.core.service.StudyBlockerAccessibilityService
import de.schuelken.studyhabit.core.service.TimerForegroundService
import de.schuelken.studyhabit.core.theme.AppTheme

class BlockedAppActivity : ComponentActivity() {

    companion object {
        const val EXTRA_BLOCKED_PACKAGE = "extra_blocked_package"
    }

    private var blockedPackage by mutableStateOf("")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        blockedPackage = intent.getStringExtra(EXTRA_BLOCKED_PACKAGE) ?: ""

        setContent {
            AppTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val timerState by TimerForegroundService.timerState.collectAsState()

                    // If timer is no longer running, auto-finish
                    LaunchedEffect(timerState.isRunning) {
                        if (!timerState.isRunning) {
                            finish()
                        }
                    }

                    BackHandler {
                        val returnIntent = Intent(this@BlockedAppActivity, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                        startActivity(returnIntent)
                        finish()
                    }

                    BlockedAppContent(
                        blockedPackage = blockedPackage,
                        timerSubject = timerState.subjectName.ifBlank { "Study Session" },
                        timerType = timerState.timerType,
                        remainingSeconds = timerState.remainingSeconds,
                        elapsedSeconds = timerState.elapsedSeconds,
                        isPaused = timerState.isPaused,
                        onReturnToTimer = {
                            val returnIntent = Intent(this@BlockedAppActivity, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            }
                            startActivity(returnIntent)
                            finish()
                        },
                        onStopTimerAndOpen = {
                            StudyBlockerAccessibilityService.bypassUntilElapsedMs = SystemClock.elapsedRealtime() + 3000L
                            TimerForegroundService.stop(this@BlockedAppActivity)
                            finish()
                        }
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val newPkg = intent.getStringExtra(EXTRA_BLOCKED_PACKAGE)
        if (!newPkg.isNullOrBlank()) {
            blockedPackage = newPkg
        }
    }
}

@Composable
fun BlockedAppContent(
    blockedPackage: String,
    timerSubject: String,
    timerType: TimerType,
    remainingSeconds: Int,
    elapsedSeconds: Int,
    isPaused: Boolean,
    onReturnToTimer: () -> Unit,
    onStopTimerAndOpen: () -> Unit
) {
    val context = LocalContext.current
    val appInfo = remember(blockedPackage) {
        runCatching {
            val pm = context.packageManager
            val info = pm.getApplicationInfo(blockedPackage, 0)
            val label = pm.getApplicationLabel(info).toString()
            val icon = pm.getApplicationIcon(info)
            label to icon
        }.getOrNull()
    }
    val appName = appInfo?.first ?: blockedPackage
    val appIconDrawable = appInfo?.second

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // App Icon & Lock Badge
        Box(contentAlignment = Alignment.BottomEnd) {
            if (appIconDrawable != null) {
                val bitmap = remember(appIconDrawable) {
                    appIconDrawable.toBitmap(128, 128).asImageBitmap()
                }
                Image(
                    bitmap = bitmap,
                    contentDescription = appName,
                    modifier = Modifier
                        .size(80.dp)
                        .clip(RoundedCornerShape(16.dp))
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Lock,
                        contentDescription = null,
                        modifier = Modifier.size(40.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                }
            }

            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.error),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.onError
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "$appName is Blocked",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Stay focused! You have an active study session in progress.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Focus session status card
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer
            )
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Timer,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(32.dp)
                )
                Spacer(modifier = Modifier.width(16.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = timerSubject,
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    val timeDisplay = if (timerType == TimerType.POMODORO) {
                        val m = remainingSeconds / 60
                        val s = remainingSeconds % 60
                        "%02d:%02d remaining".format(m, s)
                    } else {
                        val m = elapsedSeconds / 60
                        val s = elapsedSeconds % 60
                        "%02d:%02d elapsed".format(m, s)
                    }
                    Text(
                        text = if (isPaused) "$timeDisplay (Paused)" else timeDisplay,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(36.dp))

        Button(
            onClick = onReturnToTimer,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Return to Study Timer", fontSize = 16.sp)
        }

        Spacer(modifier = Modifier.height(12.dp))

        OutlinedButton(
            onClick = onStopTimerAndOpen,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                text = "Stop Study Timer to Open App",
                color = MaterialTheme.colorScheme.error,
                fontSize = 14.sp
            )
        }
    }
}
