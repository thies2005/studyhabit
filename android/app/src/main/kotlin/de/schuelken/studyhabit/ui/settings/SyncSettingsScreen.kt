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
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.material.icons.filled.Warning
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.documentfile.provider.DocumentFile
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.model.SyncStatus
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
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
    val manualFileSummary by container.folderSyncService.manualFileSummary.collectAsState()

    val userEmail = container.tokenStorage.getUserEmail()
    val isLoggedIn = !container.tokenStorage.getToken().isNullOrBlank()

    val context = LocalContext.current
    val largeText = LocalDensity.current.fontScale >= 1.3f
    var customUrl by remember(serverUrl) { mutableStateOf(serverUrl) }
    var urlError by remember { mutableStateOf<String?>(null) }
    var showEraseDialog by remember { mutableStateOf(false) }
    var showLogoutDialog by remember { mutableStateOf(false) }
    var isErasing by remember { mutableStateOf(false) }
    var eraseError by remember { mutableStateOf<String?>(null) }
    var eraseFeedback by remember { mutableStateOf<String?>(null) }
    val folderStatus by container.folderSyncService.syncStatus.collectAsState()
    val isFolderSyncing = folderStatus == SyncStatus.SYNCING

    var folderDisplayName by remember(folderSyncUri) {
        mutableStateOf(
            folderSyncUri?.let { raw ->
                val decoded = runCatching { Uri.decode(raw) }.getOrDefault(raw)
                decoded.substringAfterLast('/').substringAfterLast(':').ifBlank { decoded }
            }
        )
    }
    LaunchedEffect(folderSyncUri) {
        val raw = folderSyncUri ?: return@LaunchedEffect
        val docName = withContext(Dispatchers.IO) {
            runCatching {
                DocumentFile.fromTreeUri(context, Uri.parse(raw))?.name
            }.getOrNull()
        }
        if (!docName.isNullOrBlank()) {
            folderDisplayName = docName
        }
    }

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
            scope.launch {
                if (container.folderSyncService.bindSyncFolder(it)) container.scheduleFolderSync()
            }
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
                            onClick = { showLogoutDialog = true },
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
                                container.ankiDroidService.syncLinkedDecks(syncPastDays = true)
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
                        onValueChange = {
                            customUrl = it
                            urlError = null
                        },
                        label = { Text("Server Base URL") },
                        placeholder = { Text("https://your-server.example.com") },
                        isError = urlError != null,
                        supportingText = urlError?.let { err -> { Text(err) } },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    if (customUrl.trim().startsWith("http://", ignoreCase = true)) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
                        ) {
                            Row(
                                modifier = Modifier.padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Warning,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.error
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "Warning: http:// sends data and credentials unencrypted. Use https:// for remote servers; http:// is only intended for trusted local/LAN servers.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onErrorContainer
                                )
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = {
                                val trimmed = customUrl.trim().removeSuffix("/")
                                if (trimmed.isEmpty()) {
                                    urlError = null
                                    container.preferences.setServerUrl("")
                                } else {
                                    val lower = trimmed.lowercase()
                                    val validScheme = lower.startsWith("https://") || lower.startsWith("http://")
                                    val parsed = trimmed.toHttpUrlOrNull()
                                    if (!validScheme || parsed == null) {
                                        urlError = "Enter a valid URL starting with https:// or http://"
                                    } else {
                                        urlError = null
                                        container.preferences.setServerUrl(trimmed)
                                        customUrl = trimmed
                                    }
                                }
                            },
                            enabled = customUrl.trim().removeSuffix("/") != serverUrl,
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Save Server URL")
                        }
                        OutlinedButton(
                            onClick = {
                                customUrl = ""
                                urlError = null
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

            // Device-to-device sync through the selected Android folder
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
                                text = "Folder Sync",
                                style = MaterialTheme.typography.titleMedium
                            )
                            Text(
                                text = "Choose the same Google Drive folder on each device. Update StudyHabit on every device before syncing.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = folderSyncEnabled,
                            enabled = !folderSyncUri.isNullOrBlank(),
                            onCheckedChange = { enabled ->
                                container.preferences.setFolderSyncEnabled(enabled)
                                if (enabled && !folderSyncUri.isNullOrBlank()) {
                                    container.scheduleFolderSync()
                                    scope.launch { container.folderSyncService.syncWithFolder() }
                                }
                            }
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    Text(
                        text = "Folder: ${folderDisplayName ?: "No folder selected"}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 4.dp)
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    val selectFolderButton: @Composable (Modifier) -> Unit = { btnModifier ->
                        Button(
                            onClick = { folderPickerLauncher.launch(null) },
                            modifier = btnModifier,
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 10.dp)
                        ) {
                            Icon(Icons.Default.FolderOpen, contentDescription = null)
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Select Folder", maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                    }
                    val syncFolderButton: @Composable (Modifier) -> Unit = { btnModifier ->
                        Button(
                            onClick = {
                                scope.launch {
                                    container.ankiDroidService.syncLinkedDecks(syncPastDays = true)
                                    container.folderSyncService.syncWithFolder()
                                }
                            },
                            enabled = folderSyncEnabled && !folderSyncUri.isNullOrBlank() && !isFolderSyncing,
                            modifier = btnModifier,
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 10.dp)
                        ) {
                            Icon(Icons.Default.Sync, contentDescription = null)
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                if (isFolderSyncing) "Syncing..." else "Sync Folder Now",
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                    if (largeText) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            selectFolderButton(Modifier.fillMaxWidth())
                            syncFolderButton(Modifier.fillMaxWidth())
                        }
                    } else {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            selectFolderButton(Modifier.weight(1f))
                            syncFolderButton(Modifier.weight(1f))
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
                                    text = "Last folder check: $folderLastSyncedStr",
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

                    Text(
                        text = "Use these buttons to exchange a copy manually. Save to a separate file so you don’t replace an existing backup.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )

                    val saveFileButton: @Composable (Modifier) -> Unit = { btnModifier ->
                        OutlinedButton(
                            onClick = { saveFileLauncher.launch("studyhabit_backup_${System.currentTimeMillis()}.json") },
                            modifier = btnModifier,
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 10.dp)
                        ) {
                            Icon(Icons.Default.Save, contentDescription = null)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Save File...", maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                    }
                    val mergeFileButton: @Composable (Modifier) -> Unit = { btnModifier ->
                        OutlinedButton(
                            onClick = { mergeFileLauncher.launch(arrayOf("application/json", "*/*")) },
                            modifier = btnModifier,
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 10.dp)
                        ) {
                            Icon(Icons.Default.FileOpen, contentDescription = null)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Merge File...", maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                    }
                    if (largeText) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            saveFileButton(Modifier.fillMaxWidth())
                            mergeFileButton(Modifier.fillMaxWidth())
                        }
                    } else {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            saveFileButton(Modifier.weight(1f))
                            mergeFileButton(Modifier.weight(1f))
                        }
                    }
                    manualFileSummary?.let {
                        Text(it, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }

            // Erase Cloud Data
            if (isLoggedIn) {
                Spacer(modifier = Modifier.height(8.dp))
                Button(
                    onClick = {
                        eraseError = null
                        eraseFeedback = null
                        showEraseDialog = true
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(Icons.Default.DeleteForever, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Erase Cloud Data")
                }
                eraseFeedback?.let { feedback ->
                    Text(
                        text = feedback,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }
    }

    if (showEraseDialog) {
        AlertDialog(
            onDismissRequest = { if (!isErasing) showEraseDialog = false },
            title = { Text("Erase All Cloud Data?") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("This permanently deletes all your study projects, subjects, sessions, and stats stored in the cloud. This action cannot be undone.")
                    eraseError?.let { err ->
                        Text(
                            text = err,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        isErasing = true
                        eraseError = null
                        scope.launch {
                            try {
                                container.api.eraseData()
                                container.preferences.lastSyncedAt = 0L
                                container.preferences.setLastSyncSummary("")
                                container.preferences.setLastSyncError(null)
                                eraseFeedback = "All cloud data has been erased."
                                showEraseDialog = false
                            } catch (e: CancellationException) {
                                throw e
                            } catch (e: Exception) {
                                eraseError = "Erase failed: ${e.message ?: "Unable to reach server"}"
                            } finally {
                                isErasing = false
                            }
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                    enabled = !isErasing
                ) {
                    Text(if (isErasing) "Erasing..." else "Erase Everything")
                }
            },
            dismissButton = {
                OutlinedButton(
                    onClick = { showEraseDialog = false },
                    enabled = !isErasing
                ) {
                    Text("Cancel")
                }
            }
        )
    }

    if (showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = { Text("Log Out") },
            text = {
                Text("Would you like to keep an offline copy of your study data on this device, or log out and clear all local data?")
            },
            confirmButton = {
                Button(
                    onClick = {
                        scope.launch {
                            container.syncEngine.clearLocalData()
                            container.tokenStorage.clear()
                            showLogoutDialog = false
                            onNavigateBack()
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Log Out & Clear Local Data")
                }
            },
            dismissButton = {
                OutlinedButton(
                    onClick = {
                        container.tokenStorage.clear()
                        showLogoutDialog = false
                        onNavigateBack()
                    }
                ) {
                    Text("Log Out & Keep Offline Copy")
                }
            }
        )
    }
}
