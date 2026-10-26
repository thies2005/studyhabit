package de.schuelken.studyhabit.ui.settings

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.DeleteForever
import androidx.compose.material.icons.filled.FileOpen
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.Save
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.model.SyncStatus
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SyncSettingsScreen(
    container: AppContainer,
    onNavigateBack: () -> Unit,
    onNavigateToLogin: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val serverUrl by container.preferences.serverUrl.collectAsState()
    val syncStatus by container.syncEngine.syncStatus.collectAsState()

    val lastSyncedMs by container.preferences.lastSyncedAtFlow.collectAsState()
    val lastSyncSummary by container.preferences.lastSyncSummary.collectAsState()
    val lastSyncError by container.preferences.lastSyncError.collectAsState()

    val folderSyncUri by container.preferences.folderSyncUri.collectAsState()
    val folderSyncEnabled by container.preferences.folderSyncEnabled.collectAsState()
    val folderLastSyncedMs by container.preferences.folderLastSyncedAtFlow.collectAsState()
    val folderLastSummary by container.preferences.folderLastSummary.collectAsState()

    val userEmail = container.tokenStorage.getUserEmail()
    val isLoggedIn = !container.tokenStorage.getToken().isNullOrBlank()

    var customUrl by remember(serverUrl) { mutableStateOf(serverUrl) }
    var showEraseDialog by remember { mutableStateOf(false) }
    var isErasing by remember { mutableStateOf(false) }
    var isFolderSyncing by remember { mutableStateOf(false) }

    val lastSyncedStr = if (lastSyncedMs > 0) {
        Instant.ofEpochMilli(lastSyncedMs)
            .atZone(ZoneId.systemDefault())
            .format(DateTimeFormatter.ofPattern("MMM d, yyyy HH:mm:ss"))
    } else "Never"

    val folderLastSyncedStr = if (folderLastSyncedMs > 0) {
        Instant.ofEpochMilli(folderLastSyncedMs)
            .atZone(ZoneId.systemDefault())
            .format(DateTimeFormatter.ofPattern("MMM d, yyyy HH:mm:ss"))
    } else "Never"

    val folderPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocumentTree()
    ) { uri ->
        uri?.let {
            container.folderSyncService.bindSyncFolder(it)
        }
    }

    val saveFileLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/json")
    ) { uri ->
        uri?.let {
            scope.launch {
                container.folderSyncService.saveToDocumentUri(it)
            }
        }
    }

    val mergeFileLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        uri?.let {
            scope.launch {
                container.folderSyncService.mergeFromDocumentUri(it)
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Cloud Sync & Server") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Account Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = "Account Status", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(8.dp))
                    if (isLoggedIn) {
                        Text(text = "Logged in as:", style = MaterialTheme.typography.bodySmall)
                        Text(text = userEmail ?: "User", style = MaterialTheme.typography.titleMedium)
                        Spacer(modifier = Modifier.height(12.dp))
                        OutlinedButton(
                            onClick = {
                                container.tokenStorage.clear()
                                container.preferences.lastSyncedUserId = null
                                onNavigateBack()
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Icon(Icons.AutoMirrored.Filled.Logout, contentDescription = null)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Log Out")
                        }
                    } else {
                        Text(text = "You are currently using local offline mode.", style = MaterialTheme.typography.bodyMedium)
                        Spacer(modifier = Modifier.height(12.dp))
                        Button(onClick = onNavigateToLogin, modifier = Modifier.fillMaxWidth()) {
                            Text("Sign In or Register")
                        }
                    }
                }
            }

            // Sync Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = "Cloud Synchronization", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(12.dp))

                    Button(
                        onClick = {
                            scope.launch {
                                container.syncEngine.syncNow()
                            }
                        },
                        enabled = isLoggedIn && syncStatus != SyncStatus.SYNCING,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Default.Sync, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(if (syncStatus == SyncStatus.SYNCING) "Syncing..." else "Sync Now")
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Live Status Card directly under "Sync Now"
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(
                            containerColor = when (syncStatus) {
                                SyncStatus.ERROR -> MaterialTheme.colorScheme.errorContainer
                                SyncStatus.SYNCED -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
                                SyncStatus.SYNCING -> MaterialTheme.colorScheme.secondaryContainer
                                else -> MaterialTheme.colorScheme.surface
                            }
                        )
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            if (syncStatus == SyncStatus.SYNCING) {
                                val infiniteTransition = rememberInfiniteTransition(label = "syncSpin")
                                val angle by infiniteTransition.animateFloat(
                                    initialValue = 0f,
                                    targetValue = 360f,
                                    animationSpec = infiniteRepeatable(
                                        animation = tween(1000, easing = LinearEasing),
                                        repeatMode = RepeatMode.Restart
                                    ),
                                    label = "syncSpin"
                                )
                                Icon(
                                    imageVector = Icons.Default.Sync,
                                    contentDescription = "Syncing",
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.rotate(angle)
                                )
                            } else if (syncStatus == SyncStatus.ERROR) {
                                Icon(
                                    imageVector = Icons.Default.CloudOff,
                                    contentDescription = "Error",
                                    tint = MaterialTheme.colorScheme.error
                                )
                            } else {
                                Icon(
                                    imageVector = Icons.Default.CloudDone,
                                    contentDescription = "Synced",
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            }

                            Spacer(modifier = Modifier.width(12.dp))

                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Last synced: $lastSyncedStr",
                                    style = MaterialTheme.typography.bodyMedium
                                )
                                val displaySummary = if (syncStatus == SyncStatus.ERROR && !lastSyncError.isNullOrBlank()) {
                                    lastSyncError ?: "Sync error occurred"
                                } else if (lastSyncSummary.isNotBlank()) {
                                    lastSyncSummary
                                } else if (lastSyncedMs > 0L) {
                                    "✓ Already up to date — no new changes"
                                } else {
                                    "Not synced yet"
                                }
                                Text(
                                    text = displaySummary,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = if (syncStatus == SyncStatus.ERROR) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }

            // Server URL Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = "Server Configuration", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Configure your self-hosted or remote StudyHabit API server.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    OutlinedTextField(
                        value = customUrl,
                        onValueChange = { customUrl = it },
                        label = { Text("Server Base URL") },
                        placeholder = { Text("https://your-server.example.com") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = {
                                container.preferences.setServerUrl(customUrl)
                            },
                            enabled = customUrl.trim() != serverUrl,
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Save Server URL")
                        }
                        OutlinedButton(
                            onClick = {
                                customUrl = ""
                                container.preferences.setServerUrl("")
                            },
                            enabled = customUrl.isNotBlank() || serverUrl.isNotBlank()
                        ) {
                            Icon(Icons.Default.Clear, contentDescription = null)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Clear")
                        }
                    }
                }
            }

            // Safe to Synced Folder Section (iCloud Drive / Google Drive / File Manager)
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Synced Folder (File Manager)",
                                style = MaterialTheme.typography.titleMedium
                            )
                            Text(
                                text = "Local / iCloud / Google Drive bidirectional sync",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = folderSyncEnabled,
                            onCheckedChange = { enabled ->
                                container.preferences.setFolderSyncEnabled(enabled)
                                if (enabled && !folderSyncUri.isNullOrBlank()) {
                                    scope.launch { container.folderSyncService.syncWithFolder() }
                                }
                            }
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    val displayUri = folderSyncUri?.let {
                        runCatching { Uri.decode(it) }.getOrDefault(it)
                    } ?: "No folder selected"

                    Text(
                        text = "Folder: $displayUri",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 4.dp)
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = { folderPickerLauncher.launch(null) },
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Default.FolderOpen, contentDescription = null)
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Select Folder")
                        }

                        Button(
                            onClick = {
                                scope.launch {
                                    isFolderSyncing = true
                                    try {
                                        container.folderSyncService.syncWithFolder()
                                    } finally {
                                        isFolderSyncing = false
                                    }
                                }
                            },
                            enabled = folderSyncEnabled && !folderSyncUri.isNullOrBlank() && !isFolderSyncing,
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Default.Sync, contentDescription = null)
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(if (isFolderSyncing) "Syncing..." else "Sync Folder Now")
                        }
                    }

                    // Folder Sync Status Indicator directly under "Sync Folder Now"
                    Spacer(modifier = Modifier.height(12.dp))
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.Folder,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Last synced: $folderLastSyncedStr",
                                    style = MaterialTheme.typography.bodyMedium
                                )
                                Text(
                                    text = folderLastSummary.ifEmpty { "No folder sync performed yet" },
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = { saveFileLauncher.launch("studyhabit_sync.json") },
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Default.Save, contentDescription = null)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Save File...")
                        }

                        OutlinedButton(
                            onClick = { mergeFileLauncher.launch(arrayOf("application/json", "*/*")) },
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Default.FileOpen, contentDescription = null)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Merge File...")
                        }
                    }
                }
            }

            // Erase Cloud Data
            if (isLoggedIn) {
                Spacer(modifier = Modifier.height(8.dp))
                Button(
                    onClick = { showEraseDialog = true },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(Icons.Default.DeleteForever, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Erase Cloud Data")
                }
            }
        }
    }

    if (showEraseDialog) {
        AlertDialog(
            onDismissRequest = { showEraseDialog = false },
            title = { Text("Erase All Cloud Data?") },
            text = {
                Text("This permanently deletes all your study projects, subjects, sessions, and stats stored in the cloud. This action cannot be undone.")
            },
            confirmButton = {
                Button(
                    onClick = {
                        isErasing = true
                        scope.launch {
                            try {
                                container.api.eraseData()
                                showEraseDialog = false
                            } catch (e: Exception) {
                                // Handled
                            } finally {
                                isErasing = false
                            }
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                    enabled = !isErasing
                ) {
                    Text("Erase Everything")
                }
            },
            dismissButton = {
                Button(onClick = { showEraseDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
