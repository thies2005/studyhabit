package de.schuelken.studyhabit.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.core.service.XpCalculator

@Composable
fun LevelUpDialog(
    newLevel: Int,
    onDismiss: () -> Unit
) {
    val levelName = XpCalculator.levelName(newLevel)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = "🎉 Level Up!",
                style = MaterialTheme.typography.headlineMedium
            )
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "Level $newLevel",
                    style = MaterialTheme.typography.displayLarge,
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = levelName,
                    style = MaterialTheme.typography.titleLarge
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "Congratulations! Keep up the great work and maintain your study habit.",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        },
        confirmButton = {
            Button(onClick = onDismiss) {
                Text("Awesome!")
            }
        }
    )
}
