package de.schuelken.studyhabit.ui.timer

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.service.LevelProgress
import de.schuelken.studyhabit.core.service.TimerState
import de.schuelken.studyhabit.core.service.XpCalculator
import de.schuelken.studyhabit.ui.components.LevelUpDialog
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionReviewSheet(
    timerState: TimerState,
    container: AppContainer,
    onFinished: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    var confidenceRating by remember { mutableIntStateOf(3) }
    var notes by remember { mutableStateOf("") }
    var showLevelUp by remember { mutableStateOf(false) }
    var newLevelAwarded by remember { mutableIntStateOf(1) }

    val actualMinutes = (timerState.elapsedSeconds / 60).coerceAtLeast(1)
    val plannedMinutes = (timerState.totalSeconds / 60).coerceAtLeast(1)

    // XP calculation
    var xpEarned = 0
    if (timerState.pomodorosCompleted > 0) {
        xpEarned += timerState.pomodorosCompleted * XpCalculator.XP_COMPLETE_POMODORO
    } else if (timerState.elapsedSeconds >= (timerState.totalSeconds * 0.8)) {
        xpEarned += XpCalculator.XP_COMPLETE_POMODORO
    }
    if (actualMinutes >= 120) {
        xpEarned += XpCalculator.XP_LONG_SESSION
    }
    if (confidenceRating >= 4) {
        xpEarned += XpCalculator.XP_CONFIDENCE
    }

    ModalBottomSheet(
        onDismissRequest = onFinished,
        sheetState = sheetState
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 16.dp)
        ) {
            Text(text = "Session Complete!", style = MaterialTheme.typography.headlineMedium)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "${timerState.subjectName} • $actualMinutes minutes studied",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.height(16.dp))

            // XP Earned Banner
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                ),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(text = "XP Earned", style = MaterialTheme.typography.titleMedium)
                    Text(
                        text = "+$xpEarned XP",
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))

            // Confidence rating (1 to 5 stars)
            Text(text = "Confidence Rating", style = MaterialTheme.typography.titleSmall)
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                for (star in 1..5) {
                    Icon(
                        imageVector = if (star <= confidenceRating) Icons.Filled.Star else Icons.Outlined.Star,
                        contentDescription = "Star $star",
                        tint = if (star <= confidenceRating) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
                        modifier = Modifier
                            .size(40.dp)
                            .clickable { confidenceRating = star }
                            .padding(4.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))

            // Notes
            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("Notes (Optional)") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 2,
                maxLines = 4
            )
            Spacer(modifier = Modifier.height(24.dp))

            // Save and Finish Button
            Button(
                onClick = {
                    scope.launch {
                        val sessionEntity = StudySessionEntity(
                            id = timerState.sessionId.ifEmpty { java.util.UUID.randomUUID().toString() },
                            subjectId = timerState.subjectId,
                            topicId = timerState.topicId,
                            chapterId = timerState.chapterId,
                            startedAt = timerState.startedAt,
                            endedAt = System.currentTimeMillis(),
                            plannedDurationMinutes = plannedMinutes,
                            actualDurationMinutes = actualMinutes,
                            pomodorosCompleted = timerState.pomodorosCompleted,
                            confidenceRating = confidenceRating,
                            notes = notes.trim().ifEmpty { null },
                            xpEarned = xpEarned,
                            sourceId = timerState.sourceId,
                            isFreeTimer = timerState.timerType == de.schuelken.studyhabit.core.model.TimerType.FREE_TIMER,
                            updatedAt = System.currentTimeMillis()
                        )
                        container.database.sessionDao().upsert(sessionEntity)

                        // Update Subject XP
                        container.database.subjectDao().updateXp(timerState.subjectId, xpEarned)

                        // Update User Stats
                        val currentStats = container.database.userStatsDao().getUserStats()
                            ?: de.schuelken.studyhabit.core.database.UserStatsEntity()
                        val oldLevel = currentStats.currentLevel
                        val newTotalXp = currentStats.totalXp + xpEarned
                        val newLevel = XpCalculator.calculateLevel(newTotalXp)
                        val newTotalMinutes = currentStats.totalStudyMinutes + actualMinutes

                        val updatedStats = currentStats.copy(
                            totalXp = newTotalXp,
                            currentLevel = newLevel,
                            totalStudyMinutes = newTotalMinutes,
                            updatedAt = System.currentTimeMillis()
                        )
                        container.database.userStatsDao().upsert(updatedStats)

                        // Record study day and update streaks
                        container.streakManager.recordStudyDay()

                        // Check achievements
                        container.achievementEvaluator.checkAndUnlock()

                        // Trigger sync in background if logged in
                        if (!container.tokenStorage.getToken().isNullOrBlank()) {
                            container.syncEngine.scheduleDebouncedSync()
                        }

                        if (newLevel > oldLevel) {
                            newLevelAwarded = newLevel
                            showLevelUp = true
                        } else {
                            onFinished()
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Save Session")
            }
            Spacer(modifier = Modifier.height(24.dp))
        }
    }

    if (showLevelUp) {
        LevelUpDialog(newLevel = newLevelAwarded) {
            showLevelUp = false
            onFinished()
        }
    }
}
