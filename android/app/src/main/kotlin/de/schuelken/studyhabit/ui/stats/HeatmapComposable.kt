package de.schuelken.studyhabit.ui.stats

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import java.time.DayOfWeek
import java.time.LocalDate

@Composable
fun HeatmapComposable(
    dailyStudyMinutes: Map<LocalDate, Int>,
    weeksCount: Int = 12,
    modifier: Modifier = Modifier
) {
    val today = LocalDate.now()
    // Find the Monday of (weeksCount - 1) weeks ago
    val currentMonday = today.with(DayOfWeek.MONDAY)
    val startMonday = currentMonday.minusWeeks((weeksCount - 1).toLong())

    val dayLabels = listOf("M", "T", "W", "T", "F", "S", "S")

    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = "Activity Heatmap (Last 12 Weeks)",
            style = MaterialTheme.typography.titleMedium
        )
        Spacer(modifier = Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            // Day of week labels column
            Column(
                verticalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.padding(end = 6.dp)
            ) {
                dayLabels.forEach { label ->
                    Box(
                        modifier = Modifier.size(16.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // 12 week columns
            for (w in 0 until weeksCount) {
                val weekMonday = startMonday.plusWeeks(w.toLong())
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    for (d in 0..6) {
                        val date = weekMonday.plusDays(d.toLong())
                        val minutes = dailyStudyMinutes[date] ?: 0
                        val isFuture = date.isAfter(today)

                        val cellColor = when {
                            isFuture -> Color.Transparent
                            minutes == 0 -> MaterialTheme.colorScheme.surfaceVariant
                            minutes < 30 -> MaterialTheme.colorScheme.primary.copy(alpha = 0.35f)
                            minutes < 60 -> MaterialTheme.colorScheme.primary.copy(alpha = 0.60f)
                            minutes < 120 -> MaterialTheme.colorScheme.primary.copy(alpha = 0.85f)
                            else -> MaterialTheme.colorScheme.primary
                        }

                        val cellDescription = if (isFuture) {
                            "Future date $date"
                        } else {
                            "$date: $minutes minutes studied"
                        }

                        Box(
                            modifier = Modifier
                                .size(16.dp)
                                .clip(RoundedCornerShape(3.dp))
                                .background(cellColor)
                                .semantics {
                                    contentDescription = cellDescription
                                }
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
        // Legend
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(text = "Less", style = MaterialTheme.typography.labelSmall)
            Spacer(modifier = Modifier.width(4.dp))
            listOf(
                MaterialTheme.colorScheme.surfaceVariant,
                MaterialTheme.colorScheme.primary.copy(alpha = 0.35f),
                MaterialTheme.colorScheme.primary.copy(alpha = 0.60f),
                MaterialTheme.colorScheme.primary.copy(alpha = 0.85f),
                MaterialTheme.colorScheme.primary
            ).forEach { col ->
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(col)
                )
                Spacer(modifier = Modifier.width(3.dp))
            }
            Text(text = "More", style = MaterialTheme.typography.labelSmall)
        }
    }
}
