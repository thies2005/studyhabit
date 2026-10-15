package de.schuelken.studyhabit.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.DeleteForever
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
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

    val userEmail = container.tokenStorage.getUserEmail()
    val isLoggedIn = !container.tokenStorage.getToken().isNullOrBlank()

    var customUrl by remember { mutableStateOf(serverUrl) }
    var isSavingUrl by remember { mutableStateOf(false) }
    var showEraseDialog by remember { mutableStateOf(false) }
    var isErasing by remember { mutableStateOf(false) }

    val lastSyncedMs = container.preferences.lastSyncedAt
    val lastSyncedStr = if (lastSyncedMs > 0) {
        Instant.ofEpochMilli(lastSyncedMs)
            .atZone(ZoneId.systemDefault())
            .format(DateTimeFormatter.ofPattern("MMM d, yyyy HH:mm:ss"))
    } else "Never"

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
                    Text(text = "Synchronization", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(text = "Last synced: $lastSyncedStr", style = MaterialTheme.typography.bodyMedium)
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
                }
            }

            // Server URL Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = "Server Configuration", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = customUrl,
                        onValueChange = { customUrl = it },
                        label = { Text("Server Base URL") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(
                        onClick = {
                            container.preferences.setServerUrl(customUrl)
                        },
                        enabled = customUrl.isNotBlank() && customUrl != serverUrl,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Update Server URL")
                    }
                }
            }

            // Erase Cloud Data
            if (isLoggedIn) {
                Spacer(modifier = Modifier.height(16.dp))
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
