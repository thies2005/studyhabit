package de.schuelken.studyhabit.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.core.database.ProjectEntity
import de.schuelken.studyhabit.core.model.SyncStatus

enum class BottomNavDestination(val route: String, val title: String) {
    HOME("home", "Home"),
    SUBJECTS("subjects", "Subjects"),
    STATS("stats", "Stats"),
    ACHIEVEMENTS("achievements", "Badges")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppShellScaffold(
    currentRoute: String,
    onNavigateToRoute: (String) -> Unit,
    projects: List<ProjectEntity>,
    activeProject: ProjectEntity?,
    syncStatus: SyncStatus,
    onSyncClick: () -> Unit,
    onSelectProject: (String) -> Unit,
    onCreateProject: (String, String, Int) -> Unit,
    onOpenSettings: () -> Unit,
    content: @Composable () -> Unit
) {
    var showProjectSwitcher by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    OutlinedButton(
                        onClick = { showProjectSwitcher = true }
                    ) {
                        Text(text = activeProject?.icon ?: "📚")
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = activeProject?.name ?: "All Projects",
                            style = MaterialTheme.typography.titleMedium
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Icon(
                            imageVector = Icons.Default.UnfoldMore,
                            contentDescription = "Switch Project"
                        )
                    }
                },
                actions = {
                    SyncStatusIcon(status = syncStatus, onClick = onSyncClick)
                    IconButton(onClick = onOpenSettings) {
                        Icon(imageVector = Icons.Default.Settings, contentDescription = "Settings")
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        bottomBar = {
            NavigationBar {
                BottomNavDestination.entries.forEach { dest ->
                    val selected = currentRoute == dest.route
                    NavigationBarItem(
                        selected = selected,
                        onClick = { onNavigateToRoute(dest.route) },
                        icon = {
                            when (dest) {
                                BottomNavDestination.HOME -> Icon(Icons.Default.Home, contentDescription = dest.title)
                                BottomNavDestination.SUBJECTS -> Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = dest.title)
                                BottomNavDestination.STATS -> Icon(Icons.Default.BarChart, contentDescription = dest.title)
                                BottomNavDestination.ACHIEVEMENTS -> Icon(Icons.Default.EmojiEvents, contentDescription = dest.title)
                            }
                        },
                        label = { Text(dest.title) }
                    )
                }
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            content()

            if (showProjectSwitcher) {
                ProjectSwitcherSheet(
                    projects = projects,
                    activeProjectId = activeProject?.id,
                    onSelectProject = onSelectProject,
                    onCreateProject = onCreateProject,
                    onDismiss = { showProjectSwitcher = false }
                )
            }
        }
    }
}
