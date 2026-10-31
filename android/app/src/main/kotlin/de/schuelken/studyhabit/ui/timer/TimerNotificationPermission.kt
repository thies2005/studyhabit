package de.schuelken.studyhabit.ui.timer

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.platform.LocalContext
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner

/** Both start-session entry points share this permission and denial flow. */
@Composable
fun rememberNotificationAwareStart(): (() -> Unit) -> Unit {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var pendingStart by remember { mutableStateOf<(() -> Unit)?>(null) }
    var requested by rememberSaveable { mutableStateOf(false) }
    var notificationsEnabled by remember { mutableStateOf(NotificationManagerCompat.from(context).areNotificationsEnabled()) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        requested = true
        notificationsEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        if (granted && notificationsEnabled) {
            val start = pendingStart
            pendingStart = null
            start?.invoke()
        }
    }
    DisposableEffect(lifecycleOwner, context) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                notificationsEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    if (pendingStart != null) AlertDialog(
        onDismissRequest = { pendingStart = null },
        title = { Text(if (notificationsEnabled) "Notifications enabled" else "Timer notifications are off") },
        text = { Text(if (notificationsEnabled) "Your timer can now show notification controls." else
            "Without notification permission, timer controls and study alerts will not appear outside StudyHabit. You can enable notifications or continue using the in-app timer.") },
        confirmButton = {
            TextButton(onClick = {
                if (notificationsEnabled) {
                    val start = pendingStart; pendingStart = null; start?.invoke()
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
                    !requested) {
                    launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    runCatching {
                        context.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName))
                    }
                }
            }) { Text(if (notificationsEnabled) "Start Focus" else if (requested) "Open Notification Settings" else "Enable Notifications") }
        },
        dismissButton = {
            TextButton(onClick = {
                val start = pendingStart; pendingStart = null; start?.invoke()
            }) { Text("Continue Without Notifications") }
        }
    )
    return { start ->
        notificationsEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        if (notificationsEnabled) start() else pendingStart = start
    }
}
