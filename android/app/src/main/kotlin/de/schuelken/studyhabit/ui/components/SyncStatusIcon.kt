package de.schuelken.studyhabit.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import de.schuelken.studyhabit.core.model.SyncStatus

@Composable
fun SyncStatusIcon(
    status: SyncStatus,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "sync_spin")
    val angle by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "sync_angle"
    )

    IconButton(onClick = onClick, modifier = modifier) {
        when (status) {
            SyncStatus.SYNCING -> {
                Icon(
                    imageVector = Icons.Default.Sync,
                    contentDescription = "Syncing",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.rotate(angle)
                )
            }
            SyncStatus.SYNCED -> {
                Icon(
                    imageVector = Icons.Default.CloudDone,
                    contentDescription = "Synced",
                    tint = MaterialTheme.colorScheme.primary
                )
            }
            SyncStatus.ERROR -> {
                Icon(
                    imageVector = Icons.Default.CloudOff,
                    contentDescription = "Sync Error",
                    tint = MaterialTheme.colorScheme.error
                )
            }
            SyncStatus.IDLE -> {
                Icon(
                    imageVector = Icons.Default.Cloud,
                    contentDescription = "Sync Idle",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
