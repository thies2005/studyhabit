package de.schuelken.studyhabit.ui.subjects

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.core.database.SubjectEntity
import de.schuelken.studyhabit.core.theme.AppThemeTokens
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateSubjectSheet(
    projectId: String,
    existingSubject: SubjectEntity? = null,
    onSave: (SubjectEntity) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var name by remember { mutableStateOf(existingSubject?.name ?: "") }
    var description by remember { mutableStateOf(existingSubject?.description ?: "") }
    var selectedColorArgb by remember {
        mutableIntStateOf(existingSubject?.colorValue ?: AppThemeTokens.presetSeeds[0].toArgb())
    }
    var hierarchyMode by remember { mutableStateOf(existingSubject?.hierarchyMode ?: "flat") }
    var completenessMode by remember { mutableStateOf(existingSubject?.completenessMode ?: "none") }
    var defaultDurationMinutes by remember { mutableIntStateOf(existingSubject?.defaultDurationMinutes ?: 25) }
    var defaultBreakMinutes by remember { mutableIntStateOf(existingSubject?.defaultBreakMinutes ?: 5) }
    var targetHours by remember { mutableStateOf(existingSubject?.targetHours?.toString() ?: "") }
    var targetWeeklyHours by remember { mutableStateOf(existingSubject?.targetWeeklyHours?.toString() ?: "") }

    var hierarchyExpanded by remember { mutableStateOf(false) }
    var completenessExpanded by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
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
            Text(
                text = if (existingSubject == null) "New Subject" else "Edit Subject",
                style = MaterialTheme.typography.titleLarge
            )
            Spacer(modifier = Modifier.height(16.dp))

            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Subject Name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = description,
                onValueChange = { description = it },
                label = { Text("Description (Optional)") },
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(modifier = Modifier.height(16.dp))

            // Color Selector
            Text(text = "Color", style = MaterialTheme.typography.titleSmall)
            Spacer(modifier = Modifier.height(8.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(AppThemeTokens.presetSeeds.indices.toList()) { index ->
                    val color = AppThemeTokens.presetSeeds[index]
                    val argb = color.toArgb()
                    val isSelected = argb == selectedColorArgb
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .semantics {
                                role = Role.RadioButton
                                selected = isSelected
                                contentDescription = "Color option ${index + 1}"
                            }
                            .clickable { selectedColorArgb = argb },
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(color)
                                .then(
                                    if (isSelected) Modifier.border(3.dp, MaterialTheme.colorScheme.onSurface, CircleShape)
                                    else Modifier
                                )
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(16.dp))

            // Focus Duration Slider
            Text(
                text = "Default Focus Duration: $defaultDurationMinutes min",
                style = MaterialTheme.typography.titleSmall
            )
            Slider(
                value = defaultDurationMinutes.toFloat(),
                onValueChange = { defaultDurationMinutes = it.toInt() },
                valueRange = 5f..120f,
                steps = 22
            )
            Spacer(modifier = Modifier.height(12.dp))

            // Break Duration Slider
            Text(
                text = "Default Break Duration: $defaultBreakMinutes min",
                style = MaterialTheme.typography.titleSmall
            )
            Slider(
                value = defaultBreakMinutes.toFloat(),
                onValueChange = { defaultBreakMinutes = it.toInt() },
                valueRange = 1f..30f,
                steps = 28
            )
            Spacer(modifier = Modifier.height(12.dp))

            // Hierarchy Mode Dropdown
            ExposedDropdownMenuBox(
                expanded = hierarchyExpanded,
                onExpandedChange = { hierarchyExpanded = it }
            ) {
                OutlinedTextField(
                    value = when (hierarchyMode) {
                        "twoLevel" -> "Topics Only (2 levels)"
                        "threeLevel" -> "Topics & Chapters (3 levels)"
                        else -> "Flat (No sub-levels)"
                    },
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Hierarchy Mode") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = hierarchyExpanded) },
                    modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable).fillMaxWidth()
                )
                ExposedDropdownMenu(
                    expanded = hierarchyExpanded,
                    onDismissRequest = { hierarchyExpanded = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("Flat (No sub-levels)") },
                        onClick = { hierarchyMode = "flat"; hierarchyExpanded = false }
                    )
                    DropdownMenuItem(
                        text = { Text("Topics Only (2 levels)") },
                        onClick = { hierarchyMode = "twoLevel"; hierarchyExpanded = false }
                    )
                    DropdownMenuItem(
                        text = { Text("Topics & Chapters (3 levels)") },
                        onClick = { hierarchyMode = "threeLevel"; hierarchyExpanded = false }
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = targetHours,
                    onValueChange = { targetHours = it.filter { ch -> ch.isDigit() } },
                    label = { Text("Target Hours") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.weight(1f)
                )
                OutlinedTextField(
                    value = targetWeeklyHours,
                    onValueChange = { targetWeeklyHours = it.filter { ch -> ch.isDigit() } },
                    label = { Text("Weekly Target") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.weight(1f)
                )
            }
            Spacer(modifier = Modifier.height(16.dp))

            Button(
                onClick = {
                    if (name.isNotBlank()) {
                        val entity = if (existingSubject != null) {
                            existingSubject.copy(
                                name = name.trim(),
                                description = description.trim().ifEmpty { null },
                                colorValue = selectedColorArgb,
                                hierarchyMode = hierarchyMode,
                                completenessMode = completenessMode,
                                defaultDurationMinutes = defaultDurationMinutes,
                                defaultBreakMinutes = defaultBreakMinutes,
                                targetHours = targetHours.toIntOrNull(),
                                targetWeeklyHours = targetWeeklyHours.toIntOrNull(),
                                updatedAt = System.currentTimeMillis()
                            )
                        } else {
                            SubjectEntity(
                                id = UUID.randomUUID().toString(),
                                projectId = projectId,
                                name = name.trim(),
                                description = description.trim().ifEmpty { null },
                                colorValue = selectedColorArgb,
                                hierarchyMode = hierarchyMode,
                                completenessMode = completenessMode,
                                defaultDurationMinutes = defaultDurationMinutes,
                                defaultBreakMinutes = defaultBreakMinutes,
                                targetHours = targetHours.toIntOrNull(),
                                targetWeeklyHours = targetWeeklyHours.toIntOrNull(),
                                updatedAt = System.currentTimeMillis()
                            )
                        }
                        onSave(entity)
                        onDismiss()
                    }
                },
                enabled = name.isNotBlank(),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(if (existingSubject == null) "Create Subject" else "Save Changes")
            }
            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}
