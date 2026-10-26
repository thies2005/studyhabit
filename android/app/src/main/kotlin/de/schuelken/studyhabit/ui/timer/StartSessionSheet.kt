package de.schuelken.studyhabit.ui.timer

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.core.database.ChapterEntity
import de.schuelken.studyhabit.core.database.SourceEntity
import de.schuelken.studyhabit.core.database.SubjectEntity
import de.schuelken.studyhabit.core.database.TopicEntity
import de.schuelken.studyhabit.core.model.TimerType

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StartSessionSheet(
    subjects: List<SubjectEntity>,
    preselectedSubjectId: String? = null,
    onFetchHierarchy: suspend (String) -> Triple<List<TopicEntity>, List<ChapterEntity>, List<SourceEntity>>,
    onStartPomodoro: (subjectId: String, subjectName: String, topicId: String?, chapterId: String?, sourceId: String?, durationMinutes: Int) -> Unit,
    onStartFreeTimer: (subjectId: String, subjectName: String, topicId: String?, chapterId: String?, sourceId: String?) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var selectedSubjectId by remember {
        mutableStateOf(preselectedSubjectId ?: subjects.firstOrNull()?.id ?: "")
    }
    var timerType by remember { mutableStateOf(TimerType.POMODORO) }
    var durationMinutes by remember { mutableIntStateOf(25) }

    var topics by remember { mutableStateOf<List<TopicEntity>>(emptyList()) }
    var chapters by remember { mutableStateOf<List<ChapterEntity>>(emptyList()) }
    var sources by remember { mutableStateOf<List<SourceEntity>>(emptyList()) }

    var selectedTopicId by remember { mutableStateOf<String?>(null) }
    var selectedChapterId by remember { mutableStateOf<String?>(null) }
    var selectedSourceId by remember { mutableStateOf<String?>(null) }

    val selectedSubject = subjects.firstOrNull { it.id == selectedSubjectId }

    val filteredChapters = remember(chapters, selectedTopicId) {
        if (selectedTopicId != null) {
            chapters.filter { it.topicId == selectedTopicId }
        } else {
            chapters
        }
    }

    LaunchedEffect(selectedSubjectId) {
        if (selectedSubjectId.isNotEmpty()) {
            val (t, c, s) = onFetchHierarchy(selectedSubjectId)
            topics = t
            chapters = c
            sources = s
            selectedTopicId = null
            selectedChapterId = null
            selectedSourceId = null
            selectedSubject?.let { durationMinutes = it.defaultDurationMinutes }
        }
    }

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
            Text(text = "Start Study Session", style = MaterialTheme.typography.titleLarge)
            Spacer(modifier = Modifier.height(16.dp))

            // Timer Type Selection
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = timerType == TimerType.POMODORO,
                    onClick = { timerType = TimerType.POMODORO },
                    label = { Text("Pomodoro") }
                )
                FilterChip(
                    selected = timerType == TimerType.FREE_TIMER,
                    onClick = { timerType = TimerType.FREE_TIMER },
                    label = { Text("Free Timer") }
                )
            }
            Spacer(modifier = Modifier.height(16.dp))

            // Subject Selector
            Text(text = "Subject", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            LazyRow(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(subjects, key = { it.id }) { subj ->
                    FilterChip(
                        selected = subj.id == selectedSubjectId,
                        onClick = { selectedSubjectId = subj.id },
                        label = { Text(subj.name) }
                    )
                }
            }
            Spacer(modifier = Modifier.height(12.dp))

            // Topic Selector (if available)
            if (topics.isNotEmpty()) {
                Text(text = "Topic (Optional)", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(8.dp))
                LazyRow(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(topics, key = { it.id }) { topic ->
                        FilterChip(
                            selected = topic.id == selectedTopicId,
                            onClick = {
                                selectedTopicId = if (selectedTopicId == topic.id) null else topic.id
                                selectedChapterId = null
                            },
                            label = { Text(topic.name) }
                        )
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // Chapter Selector (if available, filtered by topic)
            if (filteredChapters.isNotEmpty()) {
                Text(text = "Chapter (Optional)", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(8.dp))
                LazyRow(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(filteredChapters, key = { it.id }) { chapter ->
                        FilterChip(
                            selected = chapter.id == selectedChapterId,
                            onClick = {
                                selectedChapterId = if (selectedChapterId == chapter.id) null else chapter.id
                            },
                            label = { Text(chapter.name) }
                        )
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // Source Selector (if available)
            if (sources.isNotEmpty()) {
                Text(text = "Study Source (Optional)", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(8.dp))
                LazyRow(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(sources, key = { it.id }) { source ->
                        FilterChip(
                            selected = source.id == selectedSourceId,
                            onClick = {
                                selectedSourceId = if (selectedSourceId == source.id) null else source.id
                            },
                            label = { Text(source.title) }
                        )
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // Duration Slider for Pomodoro
            if (timerType == TimerType.POMODORO) {
                Text(
                    text = "Duration: $durationMinutes minutes",
                    style = MaterialTheme.typography.titleMedium
                )
                Slider(
                    value = durationMinutes.toFloat(),
                    onValueChange = { durationMinutes = it.toInt() },
                    valueRange = 5f..120f,
                    steps = 22
                )
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Start Button
            Button(
                onClick = {
                    if (selectedSubject != null) {
                        if (timerType == TimerType.POMODORO) {
                            onStartPomodoro(
                                selectedSubject.id,
                                selectedSubject.name,
                                selectedTopicId,
                                selectedChapterId,
                                selectedSourceId,
                                durationMinutes
                            )
                        } else {
                            onStartFreeTimer(
                                selectedSubject.id,
                                selectedSubject.name,
                                selectedTopicId,
                                selectedChapterId,
                                selectedSourceId
                            )
                        }
                        onDismiss()
                    }
                },
                enabled = selectedSubject != null,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Start Focus Session")
            }
            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}
