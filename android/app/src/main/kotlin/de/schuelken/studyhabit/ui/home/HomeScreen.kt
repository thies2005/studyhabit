package de.schuelken.studyhabit.ui.home

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import de.schuelken.studyhabit.core.service.SessionEditHelper
import de.schuelken.studyhabit.ui.components.EditSessionDialog
import kotlinx.coroutines.launch
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.database.SubjectEntity
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.model.TimerType
import de.schuelken.studyhabit.core.service.TimerForegroundService
import de.schuelken.studyhabit.core.service.XpCalculator
import de.schuelken.studyhabit.ui.timer.StartSessionSheet
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun HomeScreen(
    container: AppContainer,
    onNavigateToPomodoro: (String) -> Unit,
    onNavigateToFreeTimer: (String) -> Unit,
    onNavigateToSubjectDetail: (String) -> Unit,
    openStartSheetImmediately: Boolean = false,
    onConsumeOpenStartSheet: () -> Unit = {}
) {
    val context = LocalContext.current
    val stats by container.database.userStatsDao().getUserStatsFlow().collectAsState(initial = UserStatsEntity())
    val timerState by TimerForegroundService.timerState.collectAsState()

    val projects by container.database.projectDao().getAllProjectsFlow().collectAsState(initial = emptyList())
    val activeProjectId by container.preferences.activeProjectId.collectAsState()
    val activeProject = projects.firstOrNull { it.id == activeProjectId } ?: projects.firstOrNull()
    val effectiveProjectId = activeProject?.id

    val subjects by remember(effectiveProjectId) {
        if (effectiveProjectId != null) {
            container.database.subjectDao().getSubjectsForProjectFlow(effectiveProjectId)
        } else {
            container.database.subjectDao().getAllSubjectsFlow()
        }
    }.collectAsState(initial = emptyList())

    // Global map of all subjects so cross-project sessions NEVER fall back to "Subject"
    val allSubjects by container.database.subjectDao().getAllSubjectsFlow().collectAsState(initial = emptyList())
    val subjectMap = remember(allSubjects) { allSubjects.associateBy { it.id } }

    val zone = ZoneId.systemDefault()
    val today = LocalDate.now(zone)
    val todayStartMs = today.atStartOfDay(zone).toInstant().toEpochMilli()

    val recentSessions by remember(effectiveProjectId) {
        if (effectiveProjectId != null) {
            container.database.sessionDao().getRecentSessionsForProjectFlow(effectiveProjectId, 10)
        } else {
            container.database.sessionDao().getRecentSessionsFlow(10)
        }
    }.collectAsState(initial = emptyList())

    val todaySessions by remember(effectiveProjectId, todayStartMs) {
        if (effectiveProjectId != null) {
            container.database.sessionDao().getSessionsForProjectSinceFlow(effectiveProjectId, todayStartMs)
        } else {
            container.database.sessionDao().getSessionsSinceFlow(todayStartMs)
        }
    }.collectAsState(initial = emptyList())

    var showStartSheet by remember { mutableStateOf(false) }
    var editingSession by remember { mutableStateOf<StudySessionEntity?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(openStartSheetImmediately) {
        if (openStartSheetImmediately) {
            showStartSheet = true
            onConsumeOpenStartSheet()
        }
    }

    // Calculate today's studied minutes
    val todayMinutes = todaySessions.sumOf { it.actualDurationMinutes }

    val weekday = today.dayOfWeek.value // 1 = Monday .. 7 = Sunday
    val dailyGoalMinutes = container.preferences.getWeekdayGoalMinutes(weekday)
    val dailyProgress = if (dailyGoalMinutes > 0) {
        (todayMinutes.toFloat() / dailyGoalMinutes.toFloat()).coerceIn(0f, 1f)
    } else 0f

    val totalXp = stats?.totalXp ?: 0
    val levelProgress = XpCalculator.getLevelProgress(totalXp)

    Scaffold(
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { showStartSheet = true },
                icon = { Icon(Icons.Default.PlayArrow, contentDescription = null) },
                text = { Text("Start Focus") }
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
            if (timerState.isRunning && timerState.subjectId.isNotEmpty()) {
                item {
                    Spacer(modifier = Modifier.height(4.dp))
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                if (timerState.timerType == TimerType.POMODORO) {
                                    onNavigateToPomodoro(timerState.subjectId)
                                } else {
                                    onNavigateToFreeTimer(timerState.subjectId)
                                }
                            },
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.PlayArrow,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Active Focus: ${timerState.subjectName}",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = "Tap to return to timer",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                                )
                            }
                        }
                    }
                }
            }
            item {
                Spacer(modifier = Modifier.height(8.dp))
                // Streak & Level Overview Row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Streak Card
                    Card(
                        modifier = Modifier.weight(1f),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Default.LocalFireDepartment,
                                    contentDescription = "Streak",
                                    tint = MaterialTheme.colorScheme.primary
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(text = "Streak", style = MaterialTheme.typography.labelLarge)
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "${stats?.currentStreak ?: 0} days",
                                style = MaterialTheme.typography.headlineMedium
                            )
                            if ((stats?.freezeTokens ?: 0) > 0) {
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        imageVector = Icons.Default.AcUnit,
                                        contentDescription = "Freeze tokens",
                                        modifier = Modifier.width(14.dp),
                                        tint = MaterialTheme.colorScheme.tertiary
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = "${stats?.freezeTokens} freeze",
                                        style = MaterialTheme.typography.labelSmall
                                    )
                                }
                            }
                        }
                    }

                    // Level Card
                    Card(
                        modifier = Modifier.weight(1f),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(text = "Level ${levelProgress.currentLevel}", style = MaterialTheme.typography.labelLarge)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = levelProgress.levelName,
                                style = MaterialTheme.typography.titleLarge
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            LinearProgressIndicator(
                                progress = { levelProgress.progressPercent / 100f },
                                modifier = Modifier.fillMaxWidth()
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "${levelProgress.xpToNextLevel} XP to Lvl ${levelProgress.currentLevel + 1}",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            // Today's Goal Card
            item {
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
                            Text(text = "Today's Study Goal", style = MaterialTheme.typography.titleMedium)
                            Text(
                                text = "$todayMinutes / $dailyGoalMinutes min",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        Spacer(modifier = Modifier.height(10.dp))
                        LinearProgressIndicator(
                            progress = { dailyProgress },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            }

            // Recent Sessions Header
            item {
                Text(
                    text = "Recent Sessions",
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }

            if (recentSessions.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "No study sessions yet. Tap 'Start Focus' to begin!",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                items(recentSessions) { session ->
                    val subjName = subjectMap[session.subjectId]?.name ?: "Subject"
                    val dateStr = Instant.ofEpochMilli(session.startedAt)
                        .atZone(zone)
                        .format(DateTimeFormatter.ofPattern("MMM d, HH:mm"))

                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onNavigateToSubjectDetail(session.subjectId) }
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(text = subjName, style = MaterialTheme.typography.titleMedium)
                                Spacer(modifier = Modifier.height(2.dp))
                                val subtitleText = if (session.endPage != null && session.notes?.startsWith("AnkiDroid:") == true) {
                                    "$dateStr • ${session.actualDurationMinutes} min • ${session.endPage} cards"
                                } else {
                                    "$dateStr • ${session.actualDurationMinutes} min"
                                }
                                Text(
                                    text = subtitleText,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                session.notes?.let { n ->
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(
                                        text = n,
                                        style = MaterialTheme.typography.bodySmall,
                                        maxLines = 1
                                    )
                                }
                            }
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Column(horizontalAlignment = Alignment.End) {
                                    Text(
                                        text = "+${session.xpEarned} XP",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                    if (session.confidenceRating != null) {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            modifier = Modifier.semantics(mergeDescendants = true) {
                                                contentDescription = "Confidence rating: ${session.confidenceRating} out of 5 stars"
                                            }
                                        ) {
                                            Text(text = "${session.confidenceRating}", style = MaterialTheme.typography.labelSmall)
                                            Icon(
                                                imageVector = Icons.Default.Star,
                                                contentDescription = null,
                                                modifier = Modifier.width(14.dp),
                                                tint = MaterialTheme.colorScheme.primary
                                            )
                                        }
                                    }
                                }
                                IconButton(
                                    onClick = { editingSession = session }
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Edit,
                                        contentDescription = "Edit session",
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }
                }
            }

            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }

    if (showStartSheet) {
        StartSessionSheet(
            subjects = subjects,
            onFetchHierarchy = { subjId ->
                val topics = container.database.topicDao().getTopicsForSubject(subjId)
                val allChapters = mutableListOf<de.schuelken.studyhabit.core.database.ChapterEntity>()
                for (t in topics) {
                    allChapters.addAll(container.database.chapterDao().getChaptersForTopic(t.id))
                }
                val sources = container.database.sourceDao().getSourcesForSubject(subjId)
                Triple(topics, allChapters, sources)
            },
            onStartPomodoro = { subjId, subjName, topId, chapId, srcId, duration ->
                TimerForegroundService.startPomodoro(
                    context = context,
                    subjectId = subjId,
                    subjectName = subjName,
                    topicId = topId,
                    chapterId = chapId,
                    sourceId = srcId,
                    durationMinutes = duration
                )
                showStartSheet = false
                onNavigateToPomodoro(subjId)
            },
            onStartFreeTimer = { subjId, subjName, topId, chapId, srcId ->
                TimerForegroundService.startFreeTimer(
                    context = context,
                    subjectId = subjId,
                    subjectName = subjName,
                    topicId = topId,
                    chapterId = chapId,
                    sourceId = srcId
                )
                showStartSheet = false
                onNavigateToFreeTimer(subjId)
            },
            onDismiss = { showStartSheet = false }
        )
    }

    editingSession?.let { session ->
        EditSessionDialog(
            session = session,
            onDismiss = { editingSession = null },
            onSave = { newMins, newConf, newNotes ->
                scope.launch {
                    SessionEditHelper.updateSession(context, container, session, newMins, newConf, newNotes)
                }
                editingSession = null
            }
        )
    }
}
