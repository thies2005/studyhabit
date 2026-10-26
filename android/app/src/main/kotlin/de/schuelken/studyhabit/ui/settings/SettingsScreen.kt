package de.schuelken.studyhabit.ui.settings

import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.BatteryChargingFull
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.Upload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.model.ImportMode
import de.schuelken.studyhabit.core.model.SyncStatus
import de.schuelken.studyhabit.core.model.ThemeMode
import de.schuelken.studyhabit.core.theme.AppThemeTokens
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    container: AppContainer,
    onNavigateBack: () -> Unit,
    onNavigateToSync: () -> Unit,
    onNavigateToBattery: () -> Unit,
    onNavigateToDiagnostics: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val currentMode by container.preferences.themeMode.collectAsState()
    val seedColorIndex by container.preferences.seedColorIndex.collectAsState()
    val fontScale by container.preferences.fontScale.collectAsState()
    val useDynamicColor by container.preferences.useDynamicColor.collectAsState()

    val syncStatus by container.syncEngine.syncStatus.collectAsState()
    val lastSyncedMs by container.preferences.lastSyncedAtFlow.collectAsState()
    val lastSyncSummary by container.preferences.lastSyncSummary.collectAsState()
    val lastSyncError by container.preferences.lastSyncError.collectAsState()
    val isLoggedIn = !container.tokenStorage.getToken().isNullOrBlank()

    var workDuration by remember { mutableIntStateOf(container.preferences.workDuration) }
    var shortBreak by remember { mutableIntStateOf(container.preferences.shortBreakDuration) }
    var longBreak by remember { mutableIntStateOf(container.preferences.longBreakDuration) }
    var autoStartBreaks by remember { mutableStateOf(container.preferences.autoStartBreaks) }
    var autoStartWork by remember { mutableStateOf(container.preferences.autoStartWork) }
    var vibration by remember { mutableStateOf(container.preferences.vibrationEnabled) }
    var continuousFocus by remember { mutableStateOf(container.preferences.continuousFocus) }
    var dailyGoalMinutes by remember { mutableIntStateOf(container.preferences.dailyGoalMinutes) }

    var importPendingJson by remember { mutableStateOf<String?>(null) }
    var importStatusMessage by remember { mutableStateOf<String?>(null) }

    val filePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let {
            scope.launch {
                try {
                    val jsonStr = context.contentResolver.openInputStream(it)?.bufferedReader()?.use { r -> r.readText() }
                    importPendingJson = jsonStr
                } catch (e: Exception) {
                    importStatusMessage = "Failed to read file: ${e.message}"
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Quick Links Row
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onNavigateToSync() }
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = when (syncStatus) {
                                    SyncStatus.ERROR -> Icons.Default.CloudOff
                                    SyncStatus.SYNCED -> Icons.Default.CloudDone
                                    SyncStatus.SYNCING -> Icons.Default.Sync
                                    else -> Icons.Default.Cloud
                                },
                                contentDescription = null,
                                tint = if (syncStatus == SyncStatus.ERROR) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(text = "Cloud Sync & Account", style = MaterialTheme.typography.titleMedium)
                                val syncSummaryText = if (!isLoggedIn) {
                                    "Offline local mode"
                                } else if (syncStatus == SyncStatus.SYNCING) {
                                    "Syncing..."
                                } else if (syncStatus == SyncStatus.ERROR && !lastSyncError.isNullOrBlank()) {
                                    "Error: $lastSyncError"
                                } else if (lastSyncSummary.isNotBlank()) {
                                    lastSyncSummary
                                } else if (lastSyncedMs > 0L) {
                                    "Up to date"
                                } else {
                                    "Not synced yet"
                                }
                                Text(
                                    text = syncSummaryText,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = if (syncStatus == SyncStatus.ERROR) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Icon(Icons.Default.ChevronRight, contentDescription = null)
                        }
                        HorizontalDivider()
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onNavigateToBattery() }
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.BatteryChargingFull, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(text = "Battery & Background Reliability", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                            Icon(Icons.Default.ChevronRight, contentDescription = null)
                        }
                        HorizontalDivider()
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onNavigateToDiagnostics() }
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Info, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(text = "Diagnostic Logs", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                            Icon(Icons.Default.ChevronRight, contentDescription = null)
                        }
                    }
                }
            }

            // Appearance Section
            item {
                Text(text = "Appearance & Theme", style = MaterialTheme.typography.titleLarge)
                Spacer(modifier = Modifier.height(8.dp))
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(text = "Theme Mode", style = MaterialTheme.typography.titleSmall)
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            ThemeMode.entries.forEach { mode ->
                                FilterChip(
                                    selected = currentMode == mode,
                                    onClick = { container.preferences.setThemeMode(mode) },
                                    label = { Text(mode.name.lowercase().replaceFirstChar { it.uppercase() }) }
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(16.dp))

                        Text(text = "Theme Palette Seed", style = MaterialTheme.typography.titleSmall)
                        Spacer(modifier = Modifier.height(8.dp))
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(AppThemeTokens.presetSeeds.indices.toList()) { index ->
                                val color = AppThemeTokens.presetSeeds[index]
                                val isSelected = index == seedColorIndex
                                Box(
                                    modifier = Modifier
                                        .size(36.dp)
                                        .clip(CircleShape)
                                        .background(color)
                                        .clickable { container.preferences.setSeedColorIndex(index) }
                                        .then(
                                            if (isSelected) Modifier.border(3.dp, MaterialTheme.colorScheme.onSurface, CircleShape)
                                            else Modifier
                                        )
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(16.dp))

                        Text(text = "Font Scale (${"%.2fx".format(fontScale)})", style = MaterialTheme.typography.titleSmall)
                        Slider(
                            value = fontScale,
                            onValueChange = { container.preferences.setFontScale(it) },
                            valueRange = 0.85f..1.30f,
                            steps = 3
                        )
                    }
                }
            }

            // Daily Study Goals
            item {
                Text(text = "Daily Goals", style = MaterialTheme.typography.titleLarge)
                Spacer(modifier = Modifier.height(8.dp))
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(text = "Default Daily Focus: $dailyGoalMinutes min", style = MaterialTheme.typography.titleSmall)
                        Slider(
                            value = dailyGoalMinutes.toFloat(),
                            onValueChange = {
                                dailyGoalMinutes = it.toInt()
                                container.preferences.dailyGoalMinutes = dailyGoalMinutes
                            },
                            valueRange = 10f..240f,
                            steps = 22
                        )
                    }
                }
            }

            // Pomodoro & Timer Section
            item {
                Text(text = "Timer & Focus Preferences", style = MaterialTheme.typography.titleLarge)
                Spacer(modifier = Modifier.height(8.dp))
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(text = "Focus Duration: $workDuration min", style = MaterialTheme.typography.titleSmall)
                        Slider(
                            value = workDuration.toFloat(),
                            onValueChange = {
                                workDuration = it.toInt()
                                container.preferences.workDuration = workDuration
                            },
                            valueRange = 5f..120f,
                            steps = 22
                        )
                        Spacer(modifier = Modifier.height(12.dp))

                        Text(text = "Short Break: $shortBreak min", style = MaterialTheme.typography.titleSmall)
                        Slider(
                            value = shortBreak.toFloat(),
                            onValueChange = {
                                shortBreak = it.toInt()
                                container.preferences.shortBreakDuration = shortBreak
                            },
                            valueRange = 1f..30f,
                            steps = 28
                        )
                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(text = "Continuous Focus (Overtime tracking)", style = MaterialTheme.typography.titleSmall)
                            Switch(
                                checked = continuousFocus,
                                onCheckedChange = {
                                    continuousFocus = it
                                    container.preferences.continuousFocus = it
                                }
                            )
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(text = "Vibration Alerts", style = MaterialTheme.typography.titleSmall)
                            Switch(
                                checked = vibration,
                                onCheckedChange = {
                                    vibration = it
                                    container.preferences.vibrationEnabled = it
                                }
                            )
                        }
                    }
                }
            }

            // Backup & Data Management
            item {
                Text(text = "Backup & Data", style = MaterialTheme.typography.titleLarge)
                Spacer(modifier = Modifier.height(8.dp))
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Button(
                            onClick = {
                                scope.launch {
                                    try {
                                        val file = container.exportImportService.exportToJson()
                                        val uri = FileProvider.getUriForFile(
                                            context,
                                            "${context.packageName}.fileprovider",
                                            file
                                        )
                                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                            type = "application/json"
                                            putExtra(Intent.EXTRA_STREAM, uri)
                                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        }
                                        context.startActivity(Intent.createChooser(sendIntent, "Export StudyHabit Backup"))
                                    } catch (e: Exception) {
                                        importStatusMessage = "Export failed: ${e.message}"
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Icon(Icons.Default.Download, contentDescription = null)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Export Backup JSON")
                        }
                        Spacer(modifier = Modifier.height(12.dp))

                        OutlinedButton(
                            onClick = { filePickerLauncher.launch("application/json") },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Icon(Icons.Default.Upload, contentDescription = null)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Import Backup JSON")
                        }

                        importStatusMessage?.let { msg ->
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(text = msg, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }

            item {
                Spacer(modifier = Modifier.height(40.dp))
            }
        }
    }

    if (importPendingJson != null) {
        AlertDialog(
            onDismissRequest = { importPendingJson = null },
            title = { Text("Import Data Mode") },
            text = { Text("Would you like to Merge with existing data, or Replace all current data on this device?") },
            confirmButton = {
                Button(
                    onClick = {
                        val json = importPendingJson!!
                        importPendingJson = null
                        scope.launch {
                            val res = container.exportImportService.importFromJson(json, ImportMode.MERGE)
                            importStatusMessage = "Imported ${res.subjectCount} subjects and ${res.sessionCount} sessions."
                        }
                    }
                ) {
                    Text("Merge")
                }
            },
            dismissButton = {
                Button(
                    onClick = {
                        val json = importPendingJson!!
                        importPendingJson = null
                        scope.launch {
                            val res = container.exportImportService.importFromJson(json, ImportMode.REPLACE)
                            importStatusMessage = "Replaced data: ${res.subjectCount} subjects, ${res.sessionCount} sessions."
                        }
                    }
                ) {
                    Text("Replace All")
                }
            }
        )
    }
}
