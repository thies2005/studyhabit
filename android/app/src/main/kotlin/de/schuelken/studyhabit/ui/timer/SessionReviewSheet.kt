package de.schuelken.studyhabit.ui.timer

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SheetValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.core.database.AchievementEntity
import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.model.TimerType
import de.schuelken.studyhabit.core.service.LevelProgress
import de.schuelken.studyhabit.core.service.TimerState
import de.schuelken.studyhabit.core.service.XpCalculator
import de.schuelken.studyhabit.ui.achievements.AchievementsMetadata
import de.schuelken.studyhabit.ui.components.AchievementUnlockBanner
import de.schuelken.studyhabit.ui.components.LevelUpDialog
import de.schuelken.studyhabit.ui.widget.StudyHabitWidgetProvider
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionReviewSheet(
    timerState: TimerState,
    container: AppContainer,
    onFinished: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { it != SheetValue.Hidden }
    )
    val scope = rememberCoroutineScope()

    var confidenceRating by remember { mutableIntStateOf(3) }
    var notes by remember { mutableStateOf("") }
    var showLevelUp by remember { mutableStateOf(false) }
    var newLevelAwarded by remember { mutableIntStateOf(1) }
    var unlockedAchievements by remember { mutableStateOf<List<AchievementEntity>>(emptyList()) }
    var showDiscardConfirmDialog by remember { mutableStateOf(false) }

    val studiedSeconds = if (timerState.timerType == TimerType.POMODORO) {
        timerState.totalWorkSeconds.coerceAtLeast(timerState.elapsedSeconds)
    } else {
        timerState.elapsedSeconds
    }
    val initialMinutes = (studiedSeconds / 60).coerceAtLeast(1)
    var editableMinutes by remember { mutableIntStateOf(initialMinutes) }
    var minutesText by remember { mutableStateOf(initialMinutes.toString()) }
    val plannedMinutes = if (timerState.timerType == TimerType.FREE_TIMER) 0 else (timerState.totalSeconds / 60).coerceAtLeast(1)

    val effectivePomodoros = if (editableMinutes != initialMinutes) {
        de.schuelken.studyhabit.core.service.SessionEditHelper.calculateEffectivePomodoros(
            isFreeTimer = timerState.timerType == TimerType.FREE_TIMER,
            plannedDurationMinutes = plannedMinutes,
            actualMinutes = editableMinutes
        )
    } else {
        timerState.pomodorosCompleted
    }

    // XP calculation updates live
    val xpEarned = XpCalculator.calculateSessionXp(
        actualMinutes = editableMinutes,
        confidence = confidenceRating,
        isPomodoro = timerState.timerType == TimerType.POMODORO,
        pomodorosCompleted = effectivePomodoros,
        plannedSeconds = timerState.totalSeconds,
        studiedSeconds = editableMinutes * 60
    )

    ModalBottomSheet(
        onDismissRequest = { showDiscardConfirmDialog = true },
        sheetState = sheetState
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .imePadding()
                .padding(horizontal = 24.dp, vertical = 16.dp)
        ) {
            Text(text = "Session Complete!", style = MaterialTheme.typography.headlineMedium)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "${timerState.subjectName} • $editableMinutes minutes studied",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.height(16.dp))

            // Duration Adjustment
            Text(text = "Study Duration (Minutes)", style = MaterialTheme.typography.titleSmall)
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                val chipDeltas = listOf(-15, -5, -1, 1, 5)
                chipDeltas.forEach { delta ->
                    AssistChip(
                        onClick = {
                            val next = (editableMinutes + delta).coerceIn(1, 720)
                            editableMinutes = next
                            minutesText = next.toString()
                        },
                        label = { Text(if (delta > 0) "+${delta}m" else "${delta}m") },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = minutesText,
                onValueChange = { input ->
                    val filtered = input.filter { it.isDigit() }
                    minutesText = filtered
                    filtered.toIntOrNull()?.let {
                        editableMinutes = it.coerceIn(1, 720)
                    }
                },
                label = { Text("Duration (minutes)") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Number
                )
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
                    val isSelected = star == confidenceRating
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .semantics {
                                role = Role.RadioButton
                                selected = isSelected
                                contentDescription = "$star star${if (star > 1) "s" else ""}"
                            }
                            .clickable { confidenceRating = star },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = if (star <= confidenceRating) Icons.Filled.Star else Icons.Outlined.Star,
                            contentDescription = null,
                            tint = if (star <= confidenceRating) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
                            modifier = Modifier.size(32.dp)
                        )
                    }
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
                            id = timerState.sessionId.ifEmpty { UUID.randomUUID().toString() },
                            subjectId = timerState.subjectId,
                            topicId = timerState.topicId,
                            chapterId = timerState.chapterId,
                            startedAt = timerState.startedAt,
                            endedAt = timerState.startedAt + editableMinutes * 60_000L,
                            plannedDurationMinutes = plannedMinutes,
                            actualDurationMinutes = editableMinutes,
                            pomodorosCompleted = effectivePomodoros,
                            confidenceRating = confidenceRating,
                            notes = notes.trim().ifEmpty { null },
                            xpEarned = xpEarned,
                            sourceId = timerState.sourceId,
                            isFreeTimer = timerState.timerType == TimerType.FREE_TIMER,
                            updatedAt = System.currentTimeMillis()
                        )
                        container.database.sessionDao().upsert(sessionEntity)

                        // Update Subject XP
                        container.database.subjectDao().updateXp(timerState.subjectId, xpEarned)

                        // Record study day and calculate streak bonus XP
                        var bonusXp = 0
                        container.streakManager.recordStudyDay { reason ->
                            bonusXp += XpCalculator.xpForReason(reason)
                        }

                        // Daily goal check
                        val zone = ZoneId.systemDefault()
                        val today = LocalDate.now(zone)
                        val todayStr = today.toString()
                        val todayStartMs = today.atStartOfDay(zone).toInstant().toEpochMilli()

                        val allSessions = container.database.sessionDao().getAllSessions()
                        val todayMinutes = allSessions
                            .filter { it.startedAt >= todayStartMs && !it.isDeleted }
                            .sumOf { it.actualDurationMinutes }

                        val goalMinutes = container.preferences.getWeekdayGoalMinutes(today.dayOfWeek.value)
                        if (todayMinutes >= goalMinutes && container.preferences.lastDailyGoalAwardDate != todayStr) {
                            bonusXp += XpCalculator.XP_DAILY_GOAL
                            container.preferences.lastDailyGoalAwardDate = todayStr
                        }

                        // Update User Stats
                        val currentStats = container.database.userStatsDao().getUserStats()
                            ?: de.schuelken.studyhabit.core.database.UserStatsEntity()
                        val oldLevel = currentStats.currentLevel
                        val totalAwardedXp = xpEarned + bonusXp
                        val newTotalXp = currentStats.totalXp + totalAwardedXp
                        val newLevel = XpCalculator.calculateLevel(newTotalXp)
                        val newTotalMinutes = currentStats.totalStudyMinutes + editableMinutes

                        val updatedStats = currentStats.copy(
                            totalXp = newTotalXp,
                            currentLevel = newLevel,
                            totalStudyMinutes = newTotalMinutes,
                            updatedAt = System.currentTimeMillis()
                        )
                        container.database.userStatsDao().upsert(updatedStats)

                        // Check achievements
                        val newlyUnlocked = container.achievementEvaluator.checkAndUnlock()

                        // Update widgets
                        StudyHabitWidgetProvider.updateAllWidgets(container.context)

                        // Trigger sync in background (Cloud Folder Sync & Server Sync)
                        container.triggerDataChangedSync()

                        if (newlyUnlocked.isNotEmpty()) {
                            unlockedAchievements = newlyUnlocked
                        }

                        if (newLevel > oldLevel) {
                            newLevelAwarded = newLevel
                            showLevelUp = true
                        } else if (newlyUnlocked.isEmpty()) {
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
            if (unlockedAchievements.isEmpty()) {
                onFinished()
            }
        }
    }

    if (unlockedAchievements.isNotEmpty() && !showLevelUp) {
        val achievement = unlockedAchievements.first()
        val meta = AchievementsMetadata.ALL.firstOrNull { it.key == achievement.key }
        AlertDialog(
            onDismissRequest = {
                unlockedAchievements = unlockedAchievements.drop(1)
                if (unlockedAchievements.isEmpty()) {
                    onFinished()
                }
            },
            title = { Text("Achievement Unlocked!") },
            text = {
                AchievementUnlockBanner(
                    title = meta?.title ?: achievement.key,
                    description = meta?.description ?: "Congratulations!",
                    icon = meta?.icon ?: "🏆"
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        unlockedAchievements = unlockedAchievements.drop(1)
                        if (unlockedAchievements.isEmpty()) {
                            onFinished()
                        }
                    }
                ) {
                    Text("Awesome!")
                }
            }
        )
    }

    if (showDiscardConfirmDialog) {
        AlertDialog(
            onDismissRequest = { showDiscardConfirmDialog = false },
            title = { Text("Discard Session?") },
            text = { Text("Are you sure you want to discard this completed study session without saving?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDiscardConfirmDialog = false
                        onFinished()
                    }
                ) {
                    Text("Discard", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDiscardConfirmDialog = false }) {
                    Text("Keep Editing")
                }
            }
        )
    }
}
