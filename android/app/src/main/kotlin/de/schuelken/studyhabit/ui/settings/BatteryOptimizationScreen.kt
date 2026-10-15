package de.schuelken.studyhabit.ui.settings

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BatteryOptimizationScreen(onNavigateBack: () -> Unit) {
    val context = LocalContext.current
    val manufacturer = Build.MANUFACTURER.lowercase()

    val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    val isIgnoringOptimizations = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        powerManager.isIgnoringBatteryOptimizations(context.packageName)
    } else true

    val oemGuide = when {
        manufacturer.contains("samsung") -> listOf(
            "1. Open device Settings > Apps > StudyHabit.",
            "2. Tap 'Battery' and select 'Unrestricted'.",
            "3. Ensure StudyHabit is removed from 'Sleeping apps' and 'Deep sleeping apps' in Device Care."
        )
        manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> listOf(
            "1. Open device Settings > Apps > Manage Apps > StudyHabit.",
            "2. Enable 'Autostart'.",
            "3. Tap 'Battery saver' and select 'No restrictions'."
        )
        manufacturer.contains("huawei") || manufacturer.contains("honor") -> listOf(
            "1. Open Settings > Battery > App launch.",
            "2. Find StudyHabit, disable 'Manage automatically'.",
            "3. Enable 'Auto-launch', 'Secondary launch', and 'Run in background'."
        )
        manufacturer.contains("oneplus") -> listOf(
            "1. Open Settings > Battery > Battery optimization.",
            "2. Find StudyHabit and select 'Don't optimize'.",
            "3. In Recent Apps, lock StudyHabit so it remains resident in memory."
        )
        else -> listOf(
            "1. Open device Settings > Apps > StudyHabit > Battery.",
            "2. Select 'Unrestricted' so background focus timers and alarms are never delayed or killed by Doze mode."
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Background & Battery") },
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
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = if (isIgnoringOptimizations) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = if (isIgnoringOptimizations) "✓ Battery Optimization Disabled" else "Battery Optimization Active",
                            style = MaterialTheme.typography.titleMedium
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = if (isIgnoringOptimizations) "StudyHabit has permission to run uninterrupted timers in the background."
                            else "Android may pause or kill foreground timers while your screen is locked unless optimization is turned off.",
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }

            item {
                Button(
                    onClick = {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                context.startActivity(intent)
                            } catch (e: Exception) {
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.fromParts("package", context.packageName, null)
                                }
                                context.startActivity(intent)
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Open System Battery Settings")
                }
            }

            item {
                Text(
                    text = "Recommended Steps for ${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }}:",
                    style = MaterialTheme.typography.titleMedium
                )
            }

            items(oemGuide.size) { index ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Text(
                        text = oemGuide[index],
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(14.dp)
                    )
                }
            }
        }
    }
}
