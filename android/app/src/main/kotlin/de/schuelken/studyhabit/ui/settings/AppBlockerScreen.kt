package de.schuelken.studyhabit.ui.settings

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.drawable.Drawable
import android.net.Uri
import android.provider.Settings
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PauseCircle
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
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
import androidx.core.graphics.drawable.toBitmap
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.service.BlockerPresets
import de.schuelken.studyhabit.core.service.StudyBlockerAccessibilityService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private enum class BlockerSettingsTarget {
    ACCESSIBILITY,
    USAGE_ACCESS,
    OVERLAY
}

data class InstalledAppItem(
    val packageName: String,
    val appName: String,
    val icon: Drawable?,
    val isSocial: Boolean = false,
    val isGame: Boolean = false
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun AppBlockerScreen(
    container: AppContainer,
    onNavigateBack: () -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    var isAccessibilityEnabled by remember {
        mutableStateOf(StudyBlockerAccessibilityService.isAccessibilityServiceEnabled(context))
    }
    var hasUsageStats by remember {
        mutableStateOf(StudyBlockerAccessibilityService.hasUsageStatsPermission(context))
    }
    var canDrawOverlays by remember {
        mutableStateOf(Settings.canDrawOverlays(context))
    }
    var disclosureAccepted by remember {
        mutableStateOf(container.preferences.blockerDisclosureAccepted)
    }
    var pendingSettingsTarget by remember { mutableStateOf<BlockerSettingsTarget?>(null) }

    fun openSystemSettings(target: BlockerSettingsTarget) {
        when (target) {
            BlockerSettingsTarget.ACCESSIBILITY -> {
                runCatching { context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
            }
            BlockerSettingsTarget.USAGE_ACCESS -> {
                val withPkg = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                    data = Uri.fromParts("package", context.packageName, null)
                }
                val opened = runCatching { context.startActivity(withPkg) }.isSuccess
                if (!opened) {
                    runCatching { context.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)) }
                        .onFailure {
                            runCatching {
                                context.startActivity(
                                    Intent(
                                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                        Uri.fromParts("package", context.packageName, null)
                                    )
                                )
                            }
                        }
                }
            }
            BlockerSettingsTarget.OVERLAY -> {
                val overlayIntent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.fromParts("package", context.packageName, null)
                )
                runCatching { context.startActivity(overlayIntent) }.onFailure {
                    runCatching { context.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)) }
                }
            }
        }
    }

    fun requestBlockerSettings(target: BlockerSettingsTarget) {
        if (disclosureAccepted) {
            openSystemSettings(target)
        } else {
            pendingSettingsTarget = target
        }
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                isAccessibilityEnabled = StudyBlockerAccessibilityService.isAccessibilityServiceEnabled(context)
                hasUsageStats = StudyBlockerAccessibilityService.hasUsageStatsPermission(context)
                canDrawOverlays = Settings.canDrawOverlays(context)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    var blockerEnabled by remember {
        mutableStateOf(container.preferences.appBlockerEnabled)
    }
    var onlyFocusPhase by remember {
        mutableStateOf(container.preferences.blockOnlyDuringFocusPhase)
    }
    var blockedPackages by remember {
        mutableStateOf(container.preferences.blockedAppPackages)
    }
    var searchQuery by remember { mutableStateOf("") }
    var installedApps by remember { mutableStateOf<List<InstalledAppItem>>(emptyList()) }
    var isLoadingApps by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            val pm = context.packageManager
            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val activities = pm.queryIntentActivities(intent, 0)
            val apps = activities
                .mapNotNull { it.activityInfo?.applicationInfo }
                .distinctBy { it.packageName }
                .filter { it.packageName !in setOf(context.packageName, "com.android.settings", "com.android.systemui") }
                .map { appInfo ->
                    InstalledAppItem(
                        packageName = appInfo.packageName,
                        appName = appInfo.loadLabel(pm).toString(),
                        icon = runCatching { appInfo.loadIcon(pm) }.getOrNull(),
                        isSocial = BlockerPresets.isSocial(appInfo.packageName, appInfo.category == ApplicationInfo.CATEGORY_SOCIAL),
                        isGame = appInfo.category == ApplicationInfo.CATEGORY_GAME || (appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0
                    )
                }
                .sortedBy { it.appName.lowercase() }
            installedApps = apps
            isLoadingApps = false
        }
    }

    val filteredApps = remember(installedApps, searchQuery) {
        if (searchQuery.isBlank()) installedApps
        else installedApps.filter {
            it.appName.contains(searchQuery, ignoreCase = true) ||
            it.packageName.contains(searchQuery, ignoreCase = true)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Focus App Blocker") },
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
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Spacer(modifier = Modifier.height(4.dp))
                // Blocker Protection & Permission Status
                val hasPermission = isAccessibilityEnabled || hasUsageStats
                if (!hasPermission) {
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.errorContainer
                        ),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Default.Warning,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.error
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "Blocker Permission Required",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.onErrorContainer
                                )
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "Grant Accessibility Service (instant blocking) or Usage Access (focus-timer fallback) so StudyHabit can detect when you open a blocked app during study sessions.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onErrorContainer
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            Button(
                                onClick = { requestBlockerSettings(BlockerSettingsTarget.ACCESSIBILITY) },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Enable Accessibility Service")
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                            OutlinedButton(
                                onClick = { requestBlockerSettings(BlockerSettingsTarget.USAGE_ACCESS) },
                                modifier = Modifier.fillMaxWidth(),
                                colors = ButtonDefaults.outlinedButtonColors(
                                    contentColor = MaterialTheme.colorScheme.onErrorContainer
                                ),
                                border = BorderStroke(
                                    1.dp,
                                    MaterialTheme.colorScheme.onErrorContainer.copy(alpha = 0.6f)
                                )
                            ) {
                                Text("Enable Usage Access (Fallback)")
                            }
                        }
                    }
                } else if (!blockerEnabled) {
                    val modeLabel = if (isAccessibilityEnabled) "Accessibility Service" else "Usage Access fallback"
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.secondaryContainer
                        ),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.PauseCircle,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSecondaryContainer
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = "App Blocker Paused",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.onSecondaryContainer
                                )
                                Text(
                                    text = "$modeLabel is granted, but Focus App Blocker is currently turned off below.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.85f)
                                )
                            }
                        }
                    }
                } else {
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer
                        ),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = "App Blocker Active",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer
                                    )
                                    Text(
                                        text = when {
                                            isAccessibilityEnabled ->
                                                "Accessibility service is running and protecting your focus."
                                            canDrawOverlays ->
                                                "Usage Access + Display Over Other Apps are active during focus sessions."
                                            else ->
                                                "Usage Access is granted, but Display Over Other Apps is needed on Android 10+ to show the lock screen."
                                        },
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                                    )
                                }
                            }
                            if (!isAccessibilityEnabled && !canDrawOverlays) {
                                Spacer(modifier = Modifier.height(10.dp))
                                Button(
                                    onClick = { requestBlockerSettings(BlockerSettingsTarget.OVERLAY) },
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text("Allow Display Over Other Apps")
                                }
                            }
                            if (!isAccessibilityEnabled) {
                                Spacer(modifier = Modifier.height(8.dp))
                                OutlinedButton(
                                    onClick = { requestBlockerSettings(BlockerSettingsTarget.ACCESSIBILITY) },
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text("Switch to Accessibility Service")
                                }
                            }
                        }
                    }
                }
            }

            item {
                // Toggles
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
                                    text = "Enable Focus App Blocker",
                                    style = MaterialTheme.typography.titleMedium
                                )
                                Text(
                                    text = "Block selected apps while a study timer is running",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Switch(
                                checked = blockerEnabled,
                                onCheckedChange = { checked ->
                                    blockerEnabled = checked
                                    container.preferences.appBlockerEnabled = checked
                                }
                            )
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Block only during Focus phases",
                                    style = MaterialTheme.typography.titleMedium
                                )
                                Text(
                                    text = "Allow using blocked apps during breaks and when the timer is paused",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Switch(
                                checked = onlyFocusPhase,
                                onCheckedChange = { checked ->
                                    onlyFocusPhase = checked
                                    container.preferences.blockOnlyDuringFocusPhase = checked
                                }
                            )
                        }
                    }
                }
            }

            item {
                Column {
                    Text(
                        text = "Select Apps to Block (${blockedPackages.size} selected)",
                        style = MaterialTheme.typography.titleMedium
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Presets add installed apps to your selection. Adjust individual apps afterward.", style = MaterialTheme.typography.bodySmall)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("All Apps" to installedApps, "Social Media" to installedApps.filter { it.isSocial }, "Games" to installedApps.filter { it.isGame }).forEach { (label, matches) ->
                            OutlinedButton(enabled = !isLoadingApps && matches.isNotEmpty(), onClick = {
                                val selection = BlockerPresets.select(blockedPackages, matches.map { it.packageName }.toSet())
                                blockedPackages = selection
                                container.preferences.blockedAppPackages = selection
                            }) { Text("$label (${matches.size})") }
                        }
                        OutlinedButton(enabled = blockedPackages.isNotEmpty(), onClick = {
                            blockedPackages = emptySet()
                            container.preferences.blockedAppPackages = emptySet()
                        }) { Text("Clear Selection") }
                    }
                    Text("Social presets use Android categories and known social apps; games use Android’s game category. Some apps need manual selection. Android Settings, your launcher and keyboards remain accessible.", style = MaterialTheme.typography.bodySmall)
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text("Search installed apps...") },
                        leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                        singleLine = true
                    )
                }
            }

            if (isLoadingApps) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("Loading installed apps...")
                    }
                }
            } else if (filteredApps.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("No matching apps found.")
                    }
                }
            } else {
                items(filteredApps, key = { it.packageName }) { app ->
                    val isChecked = app.packageName in blockedPackages
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                val newSet = if (isChecked) {
                                    blockedPackages - app.packageName
                                } else {
                                    blockedPackages + app.packageName
                                }
                                blockedPackages = newSet
                                container.preferences.blockedAppPackages = newSet
                            }
                            .padding(vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        if (app.icon != null) {
                            val bitmap = remember(app.icon) {
                                app.icon.toBitmap(96, 96).asImageBitmap()
                            }
                            Image(
                                bitmap = bitmap,
                                contentDescription = null,
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(RoundedCornerShape(8.dp))
                            )
                        } else {
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(RoundedCornerShape(8.dp)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = app.appName.take(1).uppercase(),
                                    style = MaterialTheme.typography.titleMedium
                                )
                            }
                        }
                        Spacer(modifier = Modifier.width(16.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = app.appName,
                                style = MaterialTheme.typography.bodyLarge
                            )
                            Text(
                                text = app.packageName,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Checkbox(
                            checked = isChecked,
                            onCheckedChange = { checked ->
                                val newSet = if (checked) {
                                    blockedPackages + app.packageName
                                } else {
                                    blockedPackages - app.packageName
                                }
                                blockedPackages = newSet
                                container.preferences.blockedAppPackages = newSet
                            }
                        )
                    }
                }
            }

            item {
                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }

    pendingSettingsTarget?.let { target ->
        AlertDialog(
            onDismissRequest = { pendingSettingsTarget = null },
            title = { Text("App Blocker Disclosure & Consent") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "What is observed: StudyHabit observes only the package name of the active foreground app. Screen contents, personal messages, and keystrokes are never read or recorded.",
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Text(
                        text = "Why it is needed: Foreground app detection is used solely to block distracting apps that you choose during your active study sessions.",
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Text(
                        text = "Local-only processing: Your blocked-app list and app-usage checks stay strictly on this device and are never synced, uploaded, or shared off-device.",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        container.preferences.blockerDisclosureAccepted = true
                        disclosureAccepted = true
                        pendingSettingsTarget = null
                        openSystemSettings(target)
                    }
                ) {
                    Text("Agree & Continue")
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingSettingsTarget = null }) {
                    Text("Decline")
                }
            }
        )
    }
}
