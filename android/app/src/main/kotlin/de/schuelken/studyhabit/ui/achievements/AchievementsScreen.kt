package de.schuelken.studyhabit.ui.achievements

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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.schuelken.studyhabit.core.database.AchievementEntity
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.service.XpCalculator
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun AchievementsScreen(container: AppContainer) {
    val stats by container.database.userStatsDao().getUserStatsFlow().collectAsState(initial = UserStatsEntity())
    val achievements by container.database.achievementDao().getAllAchievementsFlow().collectAsState(initial = emptyList())
    val achievementMap = achievements.associateBy { it.key }

    val categories = listOf("All", "Streaks", "Pomodoros", "Hours", "Sessions", "Subjects", "Special")
    var selectedCategoryIndex by remember { mutableIntStateOf(0) }
    var selectedBadge by remember { mutableStateOf<Pair<AchievementMetadata, AchievementEntity?>?>(null) }

    val levelProgress = XpCalculator.getLevelProgress(stats?.totalXp ?: 0)

    val currentCategory = categories[selectedCategoryIndex]
    val displayedBadges = if (currentCategory == "All") {
        AchievementsMetadata.ALL
    } else {
        AchievementsMetadata.ALL.filter { it.category == currentCategory }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(text = "Achievements & Badges", style = MaterialTheme.typography.headlineMedium)
        Spacer(modifier = Modifier.height(12.dp))

        // Level Header Card
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
                    Text(
                        text = "Level ${levelProgress.currentLevel} • ${levelProgress.levelName}",
                        style = MaterialTheme.typography.titleMedium
                    )
                    Text(
                        text = "${stats?.totalXp ?: 0} XP",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { levelProgress.progressPercent / 100f },
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "${levelProgress.xpToNextLevel} XP needed for Level ${levelProgress.currentLevel + 1}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Spacer(modifier = Modifier.height(16.dp))

        // Category Tabs
        ScrollableTabRow(selectedTabIndex = selectedCategoryIndex, edgePadding = 0.dp) {
            categories.forEachIndexed { index, cat ->
                Tab(
                    selected = selectedCategoryIndex == index,
                    onClick = { selectedCategoryIndex = index },
                    text = { Text(cat) }
                )
            }
        }
        Spacer(modifier = Modifier.height(12.dp))

        // Badges Grid
        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxSize()
        ) {
            items(displayedBadges) { meta ->
                val entity = achievementMap[meta.key]
                val isUnlocked = (entity?.progress ?: 0.0) >= 1.0 || entity?.unlockedAt != null
                val progress = (entity?.progress ?: 0.0).toFloat().coerceIn(0f, 1f)

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { selectedBadge = Pair(meta, entity) }
                        .alpha(if (isUnlocked) 1.0f else 0.55f),
                    colors = CardDefaults.cardColors(
                        containerColor = if (isUnlocked) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(text = meta.icon, fontSize = 28.sp)
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = meta.title,
                            style = MaterialTheme.typography.labelMedium,
                            maxLines = 1
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        LinearProgressIndicator(
                            progress = { progress },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            }
        }
    }

    selectedBadge?.let { (meta, entity) ->
        val isUnlocked = (entity?.progress ?: 0.0) >= 1.0 || entity?.unlockedAt != null
        val percent = ((entity?.progress ?: 0.0) * 100).toInt().coerceIn(0, 100)
        val zone = ZoneId.systemDefault()
        val unlockedDateStr = entity?.unlockedAt?.let {
            Instant.ofEpochMilli(it).atZone(zone).format(DateTimeFormatter.ofPattern("MMM d, yyyy"))
        }

        AlertDialog(
            onDismissRequest = { selectedBadge = null },
            icon = { Text(meta.icon, fontSize = 48.sp) },
            title = { Text(meta.title, style = MaterialTheme.typography.titleLarge) },
            text = {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    Text(text = meta.description, style = MaterialTheme.typography.bodyMedium)
                    Spacer(modifier = Modifier.height(12.dp))
                    if (isUnlocked) {
                        Text(
                            text = "Unlocked on ${unlockedDateStr ?: "recently"}",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.primary
                        )
                    } else {
                        Text(
                            text = "Progress: $percent%",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        LinearProgressIndicator(
                            progress = { (percent / 100f).coerceIn(0f, 1f) },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            },
            confirmButton = {
                Button(onClick = { selectedBadge = null }) {
                    Text("Close")
                }
            }
        )
    }
}
