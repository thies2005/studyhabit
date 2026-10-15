package de.schuelken.studyhabit.ui.subjects

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Card
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.core.database.ProjectEntity
import de.schuelken.studyhabit.core.database.SubjectEntity
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.service.XpCalculator
import kotlinx.coroutines.launch
import java.util.UUID

@Composable
fun SubjectsScreen(
    container: AppContainer,
    onNavigateToSubjectDetail: (String) -> Unit
) {
    val activeProjectId by container.preferences.activeProjectId.collectAsState()
    val allProjects by container.database.projectDao().getAllProjectsFlow().collectAsState(initial = emptyList())
    val activeProject = allProjects.firstOrNull { it.id == activeProjectId } ?: allProjects.firstOrNull()

    val subjects by if (activeProject != null) {
        container.database.subjectDao().getSubjectsForProjectFlow(activeProject.id).collectAsState(initial = emptyList())
    } else {
        container.database.subjectDao().getAllSubjectsFlow().collectAsState(initial = emptyList())
    }

    val scope = rememberCoroutineScope()
    var showCreateSheet by remember { mutableStateOf(false) }

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(
                onClick = {
                    if (allProjects.isEmpty()) {
                        scope.launch {
                            val defaultProj = ProjectEntity(
                                id = UUID.randomUUID().toString(),
                                name = "General Studies",
                                icon = "📚",
                                colorValue = 0xFF006874.toInt()
                            )
                            container.database.projectDao().upsert(defaultProj)
                            container.preferences.setActiveProjectId(defaultProj.id)
                            showCreateSheet = true
                        }
                    } else {
                        showCreateSheet = true
                    }
                }
            ) {
                Icon(Icons.Default.Add, contentDescription = "Add Subject")
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            if (subjects.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No subjects in this project. Tap '+' to create one!",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(subjects) { subject ->
                        val color = Color(subject.colorValue)
                        val level = XpCalculator.calculateLevel(subject.xpTotal)
                        val levelName = XpCalculator.levelName(level)

                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onNavigateToSubjectDetail(subject.id) }
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(16.dp)
                                            .clip(CircleShape)
                                            .background(color)
                                    )
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = subject.name,
                                            style = MaterialTheme.typography.titleLarge
                                        )
                                        Text(
                                            text = "Level $level • $levelName (${subject.xpTotal} XP)",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                    Icon(
                                        imageVector = Icons.Default.ChevronRight,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }

                                if (subject.targetHours != null && subject.targetHours > 0) {
                                    Spacer(modifier = Modifier.height(12.dp))
                                    val progress = (subject.xpTotal / (subject.targetHours * 100f)).coerceIn(0f, 1f)
                                    LinearProgressIndicator(
                                        progress = { progress },
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                }
                            }
                        }
                    }
                    item {
                        Spacer(modifier = Modifier.height(80.dp))
                    }
                }
            }

            if (showCreateSheet) {
                val pId = activeProject?.id ?: allProjects.firstOrNull()?.id ?: ""
                CreateSubjectSheet(
                    projectId = pId,
                    onSave = { newSubj ->
                        scope.launch {
                            container.database.subjectDao().upsert(newSubj)
                            if (!container.tokenStorage.getToken().isNullOrBlank()) {
                                container.syncEngine.scheduleDebouncedSync()
                            }
                        }
                    },
                    onDismiss = { showCreateSheet = false }
                )
            }
        }
    }
}
