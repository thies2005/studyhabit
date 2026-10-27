package de.schuelken.studyhabit.ui.stats

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.di.AppContainer
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

@Composable
fun StatsScreen(container: AppContainer) {
    val stats by container.database.userStatsDao().getUserStatsFlow().collectAsState(initial = UserStatsEntity())
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

    val allSessions by container.database.sessionDao().getAllSessionsFlow().collectAsState(initial = emptyList())
    val subjectIds = subjects.map { it.id }.toSet()
    val filteredSessions = if (effectiveProjectId != null) {
        allSessions.filter { subjectIds.contains(it.subjectId) }
    } else {
        allSessions
    }

    val zone = ZoneId.systemDefault()
    val totalMinutes = filteredSessions.sumOf { it.actualDurationMinutes }
    val totalHours = totalMinutes / 60.0

    // Group minutes by LocalDate for heatmap
    val dailyMinutes = mutableMapOf<LocalDate, Int>()
    for (s in filteredSessions) {
        val date = Instant.ofEpochMilli(s.startedAt).atZone(zone).toLocalDate()
        dailyMinutes[date] = (dailyMinutes[date] ?: 0) + s.actualDurationMinutes
    }

    // Weekly activity (Current week Mon-Sun)
    val today = LocalDate.now(zone)
    val monday = today.with(DayOfWeek.MONDAY)
    val weekdayMinutes = (0..6).map { d ->
        val day = monday.plusDays(d.toLong())
        dailyMinutes[day] ?: 0
    }
    val maxWeekMinutes = (weekdayMinutes.maxOrNull() ?: 60).coerceAtLeast(60)

    // Subject breakdown
    val subjectMinutesMap = mutableMapOf<String, Int>()
    for (s in filteredSessions) {
        subjectMinutesMap[s.subjectId] = (subjectMinutesMap[s.subjectId] ?: 0) + s.actualDurationMinutes
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Text(text = "Statistics & Analytics", style = MaterialTheme.typography.headlineMedium)
        }

        // Overview Metric Cards Row
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Card(
                    modifier = Modifier.weight(1f),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(text = "Study Hours", style = MaterialTheme.typography.labelMedium)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(text = "%.1fh".format(totalHours), style = MaterialTheme.typography.headlineMedium)
                    }
                }
                Card(
                    modifier = Modifier.weight(1f),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(text = "Total Sessions", style = MaterialTheme.typography.labelMedium)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(text = "${filteredSessions.size}", style = MaterialTheme.typography.headlineMedium)
                    }
                }
            }
        }

        // Weekly Activity Bar Chart
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = "This Week's Focus (Hours)", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(16.dp))
                    val barColor = MaterialTheme.colorScheme.primary
                    val trackColor = MaterialTheme.colorScheme.surface
                    val weeklyChartDescription = remember(weekdayMinutes) {
                        val dayNames = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
                        "Weekly focus chart: " + weekdayMinutes.mapIndexed { i, m ->
                            "${dayNames[i]}: ${m / 60} hours ${m % 60} minutes"
                        }.joinToString(", ")
                    }

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(140.dp)
                    ) {
                        Canvas(
                            modifier = Modifier
                                .fillMaxSize()
                                .semantics {
                                    contentDescription = weeklyChartDescription
                                }
                        ) {
                            val barWidth = size.width / 15f
                            val spacing = size.width / 7f

                            weekdayMinutes.forEachIndexed { index, min ->
                                val x = (index * spacing) + (spacing / 2) - (barWidth / 2)
                                val barHeight = (min.toFloat() / maxWeekMinutes.toFloat()) * (size.height - 30.dp.toPx())
                                val y = size.height - 20.dp.toPx() - barHeight

                                // Draw bar track
                                drawRoundRect(
                                    color = trackColor,
                                    topLeft = Offset(x, 0f),
                                    size = Size(barWidth, size.height - 20.dp.toPx()),
                                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(6f, 6f)
                                )

                                // Draw active bar
                                if (barHeight > 0) {
                                    drawRoundRect(
                                        color = barColor,
                                        topLeft = Offset(x, y),
                                        size = Size(barWidth, barHeight),
                                        cornerRadius = androidx.compose.ui.geometry.CornerRadius(6f, 6f)
                                    )
                                }
                            }
                        }
                    }

                    // Weekday labels
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceAround
                    ) {
                        listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun").forEach { day ->
                            Text(text = day, style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }
        }

        // 12-Week Monday-aligned Activity Heatmap
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Box(modifier = Modifier.padding(16.dp)) {
                    HeatmapComposable(dailyStudyMinutes = dailyMinutes, weeksCount = 12)
                }
            }
        }

        // Subject Breakdown
        item {
            Text(text = "Subject Breakdown", style = MaterialTheme.typography.titleLarge)
        }

        if (subjects.isEmpty()) {
            item {
                Text(text = "No subjects available.", style = MaterialTheme.typography.bodyMedium)
            }
        } else {
            items(subjects.size) { index ->
                val subj = subjects[index]
                val mins = subjectMinutesMap[subj.id] ?: 0
                val hours = mins / 60.0
                val color = Color(subj.colorValue)

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(modifier = Modifier.size(14.dp).clip(CircleShape).background(color))
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(text = subj.name, style = MaterialTheme.typography.titleMedium)
                        Text(
                            text = "${subj.xpTotal} XP",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Text(text = "%.1fh".format(hours), style = MaterialTheme.typography.titleMedium)
                }
                HorizontalDivider()
            }
        }

        item {
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}
