package de.schuelken.studyhabit.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import de.schuelken.studyhabit.core.database.StudySessionEntity

@Composable
fun EditSessionDialog(
    session: StudySessionEntity,
    onDismiss: () -> Unit,
    onSave: (newMinutes: Int, newConfidence: Int?, newNotes: String?) -> Unit
) {
    var minutes by remember { mutableIntStateOf(session.actualDurationMinutes.coerceIn(1, 720)) }
    var minutesText by remember { mutableStateOf(minutes.toString()) }
    var confidenceRating by remember { mutableStateOf(session.confidenceRating ?: 3) }
    var notes by remember { mutableStateOf(session.notes ?: "") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Edit Study Session") },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
            ) {
                Text(
                    text = "Study Duration (Minutes)",
                    style = MaterialTheme.typography.titleSmall
                )
                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val chipDeltas = listOf(-15, -5, -1, 1, 5)
                    chipDeltas.forEach { delta ->
                        AssistChip(
                            onClick = {
                                val next = (minutes + delta).coerceIn(1, 720)
                                minutes = next
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
                            minutes = it.coerceIn(1, 720)
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

                Text(
                    text = "Confidence Rating",
                    style = MaterialTheme.typography.titleSmall
                )
                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center
                ) {
                    for (star in 1..5) {
                        val isSelected = star == confidenceRating
                        Box(
                            modifier = Modifier
                                .size(40.dp)
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
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notes") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                    maxLines = 4
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val finalMinutes = minutes.coerceIn(1, 720)
                    onSave(finalMinutes, confidenceRating, notes.trim().ifEmpty { null })
                }
            ) {
                Text("Save")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
