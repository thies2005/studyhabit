package de.schuelken.studyhabit.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.navArgument
import de.schuelken.studyhabit.core.database.ProjectEntity
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.model.SyncStatus
import de.schuelken.studyhabit.core.model.TimerType
import de.schuelken.studyhabit.core.service.TimerForegroundService
import de.schuelken.studyhabit.ui.achievements.AchievementsScreen
import de.schuelken.studyhabit.ui.components.AppShellScaffold
import de.schuelken.studyhabit.ui.home.HomeScreen
import de.schuelken.studyhabit.ui.settings.AppBlockerScreen
import de.schuelken.studyhabit.ui.settings.BatteryOptimizationScreen
import de.schuelken.studyhabit.ui.settings.DiagnosticLogsScreen
import de.schuelken.studyhabit.ui.settings.LoginScreen
import de.schuelken.studyhabit.ui.settings.SettingsScreen
import de.schuelken.studyhabit.ui.settings.SyncSettingsScreen
import de.schuelken.studyhabit.ui.stats.StatsScreen
import de.schuelken.studyhabit.ui.subjects.SubjectDetailScreen
import de.schuelken.studyhabit.ui.subjects.SubjectsScreen
import de.schuelken.studyhabit.ui.timer.FreeTimerScreen
import de.schuelken.studyhabit.ui.timer.PdfViewerScreen
import de.schuelken.studyhabit.ui.timer.PomodoroScreen
import kotlinx.coroutines.launch
import java.util.UUID

@Composable
fun AppNavHost(
    navController: NavHostController,
    container: AppContainer,
    modifier: Modifier = Modifier,
    openStartSessionFromWidget: Boolean = false,
    onConsumeStartSessionFromWidget: () -> Unit = {}
) {
    val scope = rememberCoroutineScope()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route ?: "home"

    val projects by container.database.projectDao().getAllProjectsFlow().collectAsState(initial = emptyList())
    val activeProjectId by container.preferences.activeProjectId.collectAsState()
    val activeProject = projects.firstOrNull { it.id == activeProjectId } ?: projects.firstOrNull()

    val serverSyncStatus by container.syncEngine.syncStatus.collectAsState()
    val folderSyncStatus by container.folderSyncService.syncStatus.collectAsState()
    val syncStatus = when {
        serverSyncStatus == SyncStatus.SYNCING || folderSyncStatus == SyncStatus.SYNCING ->
            SyncStatus.SYNCING
        serverSyncStatus == SyncStatus.ERROR || folderSyncStatus == SyncStatus.ERROR ->
            SyncStatus.ERROR
        serverSyncStatus == SyncStatus.SYNCED || folderSyncStatus == SyncStatus.SYNCED ->
            SyncStatus.SYNCED
        else -> SyncStatus.IDLE
    }

    val timerState by TimerForegroundService.timerState.collectAsState()

    // Startup check: if a timer is currently active, redirect directly to that timer
    LaunchedEffect(Unit) {
        TimerForegroundService.restoreIfNeeded(navController.context)
        val active = TimerForegroundService.timerState.value
        if (active.isRunning && active.subjectId.isNotEmpty()) {
            if (active.timerType == TimerType.POMODORO) {
                navController.navigate("pomodoro/${active.subjectId}")
            } else {
                navController.navigate("free_timer/${active.subjectId}")
            }
        }
    }

    LaunchedEffect(openStartSessionFromWidget) {
        if (openStartSessionFromWidget) {
            val active = TimerForegroundService.timerState.value
            if (active.isRunning && active.subjectId.isNotEmpty()) {
                if (active.timerType == TimerType.POMODORO) {
                    navController.navigate("pomodoro/${active.subjectId}")
                } else {
                    navController.navigate("free_timer/${active.subjectId}")
                }
                onConsumeStartSessionFromWidget()
            } else if (currentRoute != "home") {
                navController.navigate("home") {
                    popUpTo("home") { inclusive = false }
                    launchSingleTop = true
                }
            }
        }
    }

    val isTopLevelDestination = currentRoute in listOf("home", "subjects", "stats", "achievements")

    AppShellScaffold(
        currentRoute = currentRoute,
        onNavigateToRoute = { route ->
            navController.navigate(route) {
                popUpTo("home") { saveState = true }
                launchSingleTop = true
                restoreState = true
            }
        },
        projects = projects,
        activeProject = activeProject,
        syncStatus = syncStatus,
        onSyncClick = {
            scope.launch {
                val hasServer = !container.tokenStorage.getToken().isNullOrBlank() && container.preferences.serverUrl.value.isNotBlank()
                val hasFolder = container.preferences.folderSyncEnabled.value && !container.preferences.folderSyncUri.value.isNullOrBlank()
                if (!hasServer && !hasFolder) {
                    navController.navigate("sync_settings")
                } else {
                    if (hasFolder) container.folderSyncService.syncWithFolder()
                    if (hasServer) container.syncEngine.syncNow()
                }
            }
        },
        onSelectProject = { pId ->
            container.preferences.setActiveProjectId(pId)
            scope.launch { container.database.projectDao().updateLastOpened(pId, System.currentTimeMillis()) }
        },
        onCreateProject = { name, icon, color ->
            scope.launch {
                val p = ProjectEntity(
                    id = UUID.randomUUID().toString(),
                    name = name,
                    icon = icon,
                    colorValue = color
                )
                container.database.projectDao().upsert(p)
                container.preferences.setActiveProjectId(p.id)
                container.triggerDataChangedSync()
            }
        },
        onRenameProject = { id, name, icon ->
            scope.launch {
                container.database.projectDao().renameProject(id, name, icon)
                container.triggerDataChangedSync()
            }
        },
        onOpenSettings = { navController.navigate("settings") },
        showNavigationBars = isTopLevelDestination
    ) {
        NavContent(
            navController = navController,
            container = container,
            openStartSessionFromWidget = openStartSessionFromWidget,
            onConsumeStartSessionFromWidget = onConsumeStartSessionFromWidget
        )
    }
}

@Composable
private fun NavContent(
    navController: NavHostController,
    container: AppContainer,
    openStartSessionFromWidget: Boolean = false,
    onConsumeStartSessionFromWidget: () -> Unit = {}
) {
    NavHost(
        navController = navController,
        startDestination = "home"
    ) {
        composable("home") {
            HomeScreen(
                container = container,
                onNavigateToPomodoro = { subjId -> navController.navigate("pomodoro/$subjId") },
                onNavigateToFreeTimer = { subjId -> navController.navigate("free_timer/$subjId") },
                onNavigateToSubjectDetail = { subjId -> navController.navigate("subject_detail/$subjId") },
                openStartSheetImmediately = openStartSessionFromWidget,
                onConsumeOpenStartSheet = onConsumeStartSessionFromWidget
            )
        }

        composable("subjects") {
            SubjectsScreen(
                container = container,
                onNavigateToSubjectDetail = { subjId -> navController.navigate("subject_detail/$subjId") }
            )
        }

        composable(
            route = "subject_detail/{subjectId}",
            arguments = listOf(navArgument("subjectId") { type = NavType.StringType })
        ) { backStackEntry ->
            val subjectId = backStackEntry.arguments?.getString("subjectId") ?: ""
            SubjectDetailScreen(
                subjectId = subjectId,
                container = container,
                onNavigateBack = { navController.popBackStack() },
                onNavigateToPdf = { srcId -> navController.navigate("pdf_viewer/$srcId") },
                onNavigateToPomodoro = { sId -> navController.navigate("pomodoro/$sId") },
                onNavigateToFreeTimer = { sId -> navController.navigate("free_timer/$sId") }
            )
        }

        composable("stats") {
            StatsScreen(container = container)
        }

        composable("achievements") {
            AchievementsScreen(container = container)
        }

        composable("settings") {
            SettingsScreen(
                container = container,
                onNavigateBack = { navController.popBackStack() },
                onNavigateToSync = { navController.navigate("sync_settings") },
                onNavigateToBattery = { navController.navigate("battery_optimization") },
                onNavigateToDiagnostics = { navController.navigate("diagnostic_logs") },
                onNavigateToAppBlocker = { navController.navigate("app_blocker") }
            )
        }

        composable("app_blocker") {
            AppBlockerScreen(
                container = container,
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable("login") {
            LoginScreen(
                container = container,
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable("sync_settings") {
            SyncSettingsScreen(
                container = container,
                onNavigateBack = { navController.popBackStack() },
                onNavigateToLogin = { navController.navigate("login") }
            )
        }

        composable("battery_optimization") {
            BatteryOptimizationScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable("diagnostic_logs") {
            DiagnosticLogsScreen(
                container = container,
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "pomodoro/{subjectId}",
            arguments = listOf(navArgument("subjectId") { type = NavType.StringType })
        ) {
            PomodoroScreen(
                container = container,
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "free_timer/{subjectId}",
            arguments = listOf(navArgument("subjectId") { type = NavType.StringType })
        ) {
            FreeTimerScreen(
                container = container,
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "pdf_viewer/{sourceId}",
            arguments = listOf(navArgument("sourceId") { type = NavType.StringType })
        ) { backStackEntry ->
            val sourceId = backStackEntry.arguments?.getString("sourceId") ?: ""
            PdfViewerScreen(
                sourceId = sourceId,
                container = container,
                onNavigateBack = { navController.popBackStack() }
            )
        }
    }
}
