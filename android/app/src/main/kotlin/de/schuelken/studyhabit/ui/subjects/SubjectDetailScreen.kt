package de.schuelken.studyhabit.ui.subjects

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Sync
import androidx.compose.runtime.LaunchedEffect
import de.schuelken.studyhabit.core.service.AnkiDeck
import de.schuelken.studyhabit.core.service.SessionEditHelper
import de.schuelken.studyhabit.ui.components.EditSessionDialog
import de.schuelken.studyhabit.ui.widget.StudyHabitWidgetProvider
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.core.database.ChapterEntity
import de.schuelken.studyhabit.core.database.SkillLabelEntity
import de.schuelken.studyhabit.core.database.SourceEntity
import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.database.SubjectEntity
import de.schuelken.studyhabit.core.database.TopicEntity
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.core.model.SkillLevel
import de.schuelken.studyhabit.core.service.TimerForegroundService
import de.schuelken.studyhabit.core.service.XpCalculator
import de.schuelken.studyhabit.ui.timer.StartSessionSheet
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SubjectDetailScreen(
    subjectId: String,
    container: AppContainer,
    onNavigateBack: () -> Unit,
    onNavigateToPdf: (String) -> Unit,
    onNavigateToPomodoro: (String) -> Unit,
    onNavigateToFreeTimer: (String) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val subject by container.database.subjectDao().getSubjectByIdFlow(subjectId).collectAsState(initial = null)
    val sessions by container.database.sessionDao().getSessionsForSubjectFlow(subjectId).collectAsState(initial = emptyList())
    val sources by container.database.sourceDao().getSourcesForSubjectFlow(subjectId).collectAsState(initial = emptyList())
    val topics by container.database.topicDao().getTopicsForSubjectFlow(subjectId).collectAsState(initial = emptyList())
    val skillLabels by container.database.skillLabelDao().getSkillLabelsForSubjectFlow(subjectId).collectAsState(initial = emptyList())

    LaunchedEffect(subjectId) {
        container.ankiDroidService.syncLinkedDecks(subjectId)
    }

    var selectedTab by remember { mutableIntStateOf(0) }
    val tabs = listOf("Timeline", "Sources", "Topics")

    var showStartSheet by remember { mutableStateOf(false) }
    var showAddSourceDialog by remember { mutableStateOf(false) }
    var showAddTopicDialog by remember { mutableStateOf(false) }
    var editingSession by remember { mutableStateOf<StudySessionEntity?>(null) }

    // Dialog state for skill selector
    var skillSelectorTopicId by remember { mutableStateOf<String?>(null) }
    var skillSelectorChapterId by remember { mutableStateOf<String?>(null) }
    var showSkillSheet by remember { mutableStateOf(false) }

    val currentSubj = subject ?: return

    val totalStudyMinutes = sessions.sumOf { it.actualDurationMinutes }
    val totalStudyHours = totalStudyMinutes / 60.0
    val totalAnkiCards = sessions.filter {
        it.notes?.startsWith("AnkiDroid:") == true || sources.any { s -> s.id == it.sourceId && s.type == "anki" }
    }.sumOf { it.endPage ?: 0 }
    val level = XpCalculator.calculateLevel(currentSubj.xpTotal)
    val levelName = XpCalculator.levelName(level)
    val color = Color(currentSubj.colorValue)

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(modifier = Modifier.size(12.dp).clip(CircleShape).background(color))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(currentSubj.name)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { showStartSheet = true }) {
                        Icon(Icons.Default.PlayArrow, contentDescription = "Start Focus")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Stats summary card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceAround
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(text = "Total Hours", style = MaterialTheme.typography.labelMedium)
                        Text(text = "%.1fh".format(totalStudyHours), style = MaterialTheme.typography.titleLarge)
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(text = "Rank", style = MaterialTheme.typography.labelMedium)
                        Text(text = levelName, style = MaterialTheme.typography.titleLarge)
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(text = "XP Total", style = MaterialTheme.typography.labelMedium)
                        Text(text = "${currentSubj.xpTotal}", style = MaterialTheme.typography.titleLarge)
                    }
                    if (totalAnkiCards > 0) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(text = "Anki Cards", style = MaterialTheme.typography.labelMedium)
                            Text(text = "$totalAnkiCards", style = MaterialTheme.typography.titleLarge)
                        }
                    }
                }
            }

            // Tabs
            TabRow(selectedTabIndex = selectedTab) {
                tabs.forEachIndexed { index, title ->
                    Tab(
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        text = { Text(title) }
                    )
                }
            }

            when (selectedTab) {
                0 -> TimelineTab(
                    sessions = sessions,
                    onEditSession = { session -> editingSession = session },
                    onDeleteSession = { session ->
                        scope.launch {
                            container.database.sessionDao().softDelete(session.id)
                            container.database.subjectDao().updateXp(currentSubj.id, -session.xpEarned)
                            val stats = container.database.userStatsDao().getUserStats()
                            if (stats != null) {
                                val newXp = (stats.totalXp - session.xpEarned).coerceAtLeast(0)
                                val newMins = (stats.totalStudyMinutes - session.actualDurationMinutes).coerceAtLeast(0)
                                container.database.userStatsDao().upsert(
                                    stats.copy(
                                        totalXp = newXp,
                                        currentLevel = XpCalculator.calculateLevel(newXp),
                                        totalStudyMinutes = newMins,
                                        updatedAt = System.currentTimeMillis()
                                    )
                                )
                            }
                            StudyHabitWidgetProvider.updateAllWidgets(context)
                            container.triggerDataChangedSync()
                        }
                    }
                )
                1 -> SourcesTab(
                    sources = sources,
                    onAddSourceClick = { showAddSourceDialog = true },
                    onSyncAnkiDecks = {
                        scope.launch {
                            container.ankiDroidService.syncLinkedDecks(subjectId)
                        }
                    },
                    onOpenSource = { src ->
                        if (src.type.equals("anki", ignoreCase = true)) {
                            val deckId = src.filePath?.removePrefix("anki://deck/")?.toLongOrNull()
                            val intent = if (deckId != null) {
                                Intent(Intent.ACTION_VIEW).apply {
                                    data = Uri.parse("anki://deck/$deckId")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                            } else {
                                context.packageManager.getLaunchIntentForPackage("com.ichi2.anki")
                            }
                            runCatching {
                                if (intent != null) context.startActivity(intent)
                            }.onFailure {
                                val fallback = context.packageManager.getLaunchIntentForPackage("com.ichi2.anki")
                                if (fallback != null) runCatching { context.startActivity(fallback) }
                            }
                        } else if (src.type.equals("pdf", ignoreCase = true)) {
                            onNavigateToPdf(src.id)
                        } else if (!src.url.isNullOrBlank()) {
                            val raw = src.url.trim()
                            val normalized = if (!raw.contains("://")) "https://$raw" else raw
                            val uri = runCatching { Uri.parse(normalized) }.getOrNull()
                            val scheme = uri?.scheme?.lowercase()
                            if (uri != null && (scheme == "https" || scheme == "http")) {
                                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                                    addCategory(Intent.CATEGORY_BROWSABLE)
                                }
                                runCatching { context.startActivity(intent) }
                            }
                        }
                    }
                )
                2 -> TopicsTab(
                    container = container,
                    subjectId = currentSubj.id,
                    topics = topics,
                    skillLabels = skillLabels,
                    onAddTopicClick = { showAddTopicDialog = true },
                    onSelectSkillLabel = { tId, cId ->
                        skillSelectorTopicId = tId
                        skillSelectorChapterId = cId
                        showSkillSheet = true
                    }
                )
            }
        }
    }

    if (showStartSheet) {
        StartSessionSheet(
            subjects = listOf(currentSubj),
            preselectedSubjectId = currentSubj.id,
            onFetchHierarchy = { _ ->
                val allChapters = mutableListOf<ChapterEntity>()
                for (t in topics) {
                    allChapters.addAll(container.database.chapterDao().getChaptersForTopic(t.id))
                }
                Triple(topics, allChapters, sources)
            },
            onStartPomodoro = { subjId, subjName, topId, chapId, srcId, duration ->
                TimerForegroundService.startPomodoro(
                    context = context,
                    subjectId = subjId,
                    subjectName = subjName,
                    topicId = topId,
                    chapterId = chapId,
                    sourceId = srcId,
                    durationMinutes = duration
                )
                showStartSheet = false
                onNavigateToPomodoro(subjId)
            },
            onStartFreeTimer = { subjId, subjName, topId, chapId, srcId ->
                TimerForegroundService.startFreeTimer(
                    context = context,
                    subjectId = subjId,
                    subjectName = subjName,
                    topicId = topId,
                    chapterId = chapId,
                    sourceId = srcId
                )
                showStartSheet = false
                onNavigateToFreeTimer(subjId)
            },
            onDismiss = { showStartSheet = false }
        )
    }

    if (showAddSourceDialog) {
        AddSourceDialog(
            subjectId = currentSubj.id,
            container = container,
            onSave = { src ->
                scope.launch {
                    container.database.sourceDao().upsert(src)
                    container.triggerDataChangedSync()
                    showAddSourceDialog = false
                }
            },
            onDismiss = { showAddSourceDialog = false }
        )
    }

    if (showAddTopicDialog) {
        AddTopicDialog(
            subjectId = currentSubj.id,
            nextOrder = topics.size + 1,
            onSave = { t ->
                scope.launch {
                    container.database.topicDao().upsert(t)
                    container.triggerDataChangedSync()
                    showAddTopicDialog = false
                }
            },
            onDismiss = { showAddTopicDialog = false }
        )
    }

    if (showSkillSheet) {
        SkillLabelSheet(
            onSelectLevel = { level ->
                scope.launch {
                    val existingLabel = skillLabels.firstOrNull {
                        it.topicId == skillSelectorTopicId && it.chapterId == skillSelectorChapterId
                    }
                    val labelEntity = SkillLabelEntity(
                        id = existingLabel?.id ?: UUID.randomUUID().toString(),
                        subjectId = currentSubj.id,
                        topicId = skillSelectorTopicId,
                        chapterId = skillSelectorChapterId,
                        label = level.value,
                        updatedAt = System.currentTimeMillis()
                    )
                    container.database.skillLabelDao().upsert(labelEntity)
                    container.triggerDataChangedSync()
                    showSkillSheet = false
                }
            },
            onDismiss = { showSkillSheet = false }
        )
    }

    editingSession?.let { session ->
        EditSessionDialog(
            session = session,
            onDismiss = { editingSession = null },
            onSave = { newMins, newConf, newNotes ->
                scope.launch {
                    SessionEditHelper.updateSession(context, container, session, newMins, newConf, newNotes)
                }
                editingSession = null
            }
        )
    }
}

@Composable
fun TimelineTab(
    sessions: List<StudySessionEntity>,
    onEditSession: (StudySessionEntity) -> Unit,
    onDeleteSession: (StudySessionEntity) -> Unit
) {
    val zone = ZoneId.systemDefault()
    var sessionToDelete by remember { mutableStateOf<StudySessionEntity?>(null) }

    if (sessionToDelete != null) {
        AlertDialog(
            onDismissRequest = { sessionToDelete = null },
            title = { Text("Delete Session") },
            text = { Text("Are you sure you want to delete this study session? This action cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        val session = sessionToDelete
                        sessionToDelete = null
                        if (session != null) {
                            onDeleteSession(session)
                        }
                    }
                ) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { sessionToDelete = null }) {
                    Text("Cancel")
                }
            }
        )
    }

    if (sessions.isEmpty()) {
        Box(
            modifier = Modifier.fillMaxSize().padding(32.dp),
            contentAlignment = Alignment.Center
        ) {
            Text("No study sessions recorded yet for this subject.")
        }
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(sessions) { session ->
                val dateStr = Instant.ofEpochMilli(session.startedAt)
                    .atZone(zone)
                    .format(DateTimeFormatter.ofPattern("EEE, MMM d, yyyy • HH:mm"))

                Card(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(text = dateStr, style = MaterialTheme.typography.labelMedium)
                            Spacer(modifier = Modifier.height(4.dp))
                            val durationAndCards = if (session.endPage != null && (session.notes?.startsWith("AnkiDroid:") == true || session.endPage > 0)) {
                                "${session.actualDurationMinutes} min • ${session.endPage} cards"
                            } else {
                                "${session.actualDurationMinutes} minutes studied"
                            }
                            Text(
                                text = durationAndCards,
                                style = MaterialTheme.typography.titleMedium
                            )
                            session.notes?.let { n ->
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(text = n, style = MaterialTheme.typography.bodySmall)
                            }
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconButton(onClick = { onEditSession(session) }) {
                                Icon(
                                    imageVector = Icons.Default.Edit,
                                    contentDescription = "Edit session",
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            IconButton(onClick = { sessionToDelete = session }) {
                                Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun SourcesTab(
    sources: List<SourceEntity>,
    onAddSourceClick: () -> Unit,
    onSyncAnkiDecks: () -> Unit,
    onOpenSource: (SourceEntity) -> Unit
) {
    val hasAnki = sources.any { it.type.equals("anki", ignoreCase = true) }
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Button(onClick = onAddSourceClick, modifier = Modifier.weight(1f)) {
                Icon(Icons.Default.Add, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Add Source")
            }
            if (hasAnki) {
                OutlinedButton(onClick = onSyncAnkiDecks) {
                    Icon(Icons.Default.Sync, contentDescription = null)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Sync Anki")
                }
            }
        }
        Spacer(modifier = Modifier.height(16.dp))

        if (sources.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("No sources added yet.")
            }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(sources) { src ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onOpenSource(src) }
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = when (src.type.lowercase()) {
                                    "pdf" -> Icons.Default.Description
                                    "videourl" -> Icons.Default.PlayCircle
                                    "anki" -> Icons.Default.Sync
                                    else -> Icons.Default.Link
                                },
                                contentDescription = null,
                                modifier = Modifier.size(32.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                            Spacer(modifier = Modifier.width(16.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(text = src.title, style = MaterialTheme.typography.titleMedium)
                                val subtext = if (src.type.lowercase() == "anki") {
                                    "Studied today: ${src.currentPage ?: 0} cards • Due: ${src.totalPages ?: 0}"
                                } else if (src.currentPage != null) {
                                    "Page ${src.currentPage}"
                                } else {
                                    src.url ?: src.filePath ?: ""
                                }
                                Text(text = subtext, style = MaterialTheme.typography.bodySmall, maxLines = 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun TopicsTab(
    container: AppContainer,
    subjectId: String,
    topics: List<TopicEntity>,
    skillLabels: List<SkillLabelEntity>,
    onAddTopicClick: () -> Unit,
    onSelectSkillLabel: (String, String?) -> Unit
) {
    val scope = rememberCoroutineScope()
    var showAddChapterTopicId by remember { mutableStateOf<String?>(null) }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Button(onClick = onAddTopicClick, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Default.Add, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("Add Topic")
        }
        Spacer(modifier = Modifier.height(16.dp))

        if (topics.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("No topics defined.")
            }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(topics) { topic ->
                    val chapters by container.database.chapterDao().getChaptersForTopicFlow(topic.id).collectAsState(initial = emptyList())
                    var expanded by remember { mutableStateOf(false) }
                    val label = skillLabels.firstOrNull { it.topicId == topic.id && it.chapterId == null }?.label ?: "beginner"

                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(text = topic.name, style = MaterialTheme.typography.titleMedium)
                                }
                                FilterChip(
                                    selected = true,
                                    onClick = { onSelectSkillLabel(topic.id, null) },
                                    label = { Text(label.replaceFirstChar { it.uppercase() }) }
                                )
                                IconButton(onClick = { expanded = !expanded }) {
                                    Icon(
                                        if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                                        contentDescription = if (expanded) "Collapse chapters for ${topic.name}" else "Expand chapters for ${topic.name}"
                                    )
                                }
                            }

                            if (expanded) {
                                Spacer(modifier = Modifier.height(8.dp))
                                chapters.forEach { chapter ->
                                    val chapLabel = skillLabels.firstOrNull { it.chapterId == chapter.id }?.label ?: "beginner"
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(start = 16.dp, top = 4.dp, bottom = 4.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text(text = "• ${chapter.name}", modifier = Modifier.weight(1f))
                                        FilterChip(
                                            selected = true,
                                            onClick = { onSelectSkillLabel(topic.id, chapter.id) },
                                            label = { Text(chapLabel.replaceFirstChar { it.uppercase() }) }
                                        )
                                    }
                                }
                                Spacer(modifier = Modifier.height(8.dp))
                                Button(
                                    onClick = { showAddChapterTopicId = topic.id },
                                    modifier = Modifier.padding(start = 16.dp)
                                ) {
                                    Icon(Icons.Default.Add, contentDescription = null)
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Add Chapter")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showAddChapterTopicId != null) {
        val topicId = showAddChapterTopicId!!
        AddChapterDialog(
            topicId = topicId,
            onSave = { c ->
                scope.launch {
                    container.database.chapterDao().upsert(c)
                    container.triggerDataChangedSync()
                    showAddChapterTopicId = null
                }
            },
            onDismiss = { showAddChapterTopicId = null }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddSourceDialog(
    subjectId: String,
    container: AppContainer,
    onSave: (SourceEntity) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    var title by remember { mutableStateOf("") }
    var type by remember { mutableStateOf("pdf") }
    var pathOrUrl by remember { mutableStateOf("") }
    var ankiDecks by remember { mutableStateOf<List<AnkiDeck>>(emptyList()) }
    var selectedAnkiDeck by remember { mutableStateOf<AnkiDeck?>(null) }
    var hasAnkiPermission by remember { mutableStateOf(container.ankiDroidService.hasAnkiPermission()) }
    val isAnkiInstalled = remember { container.ankiDroidService.isAnkiInstalled() }

    val ankiPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasAnkiPermission = granted
        if (granted) {
            ankiDecks = container.ankiDroidService.getDecks()
        }
    }

    LaunchedEffect(type) {
        if (type == "anki" && hasAnkiPermission) {
            ankiDecks = container.ankiDroidService.getDecks()
        }
    }

    val pdfPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            runCatching {
                context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            pathOrUrl = uri.toString()
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add Source") },
        text = {
            Column {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("Title") },
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    FilterChip(selected = type == "pdf", onClick = { type = "pdf" }, label = { Text("PDF") })
                    FilterChip(selected = type == "url", onClick = { type = "url" }, label = { Text("URL") })
                    FilterChip(selected = type == "videoUrl", onClick = { type = "videoUrl" }, label = { Text("Video") })
                    FilterChip(selected = type == "anki", onClick = { type = "anki" }, label = { Text("Anki") })
                }
                if (type == "pdf") {
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(
                        onClick = { pdfPickerLauncher.launch(arrayOf("application/pdf")) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Select PDF Document")
                    }
                }
                if (type == "anki") {
                    Spacer(modifier = Modifier.height(8.dp))
                    if (!isAnkiInstalled) {
                        Text(
                            text = "AnkiDroid is not installed on this device.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error
                        )
                    } else if (!hasAnkiPermission) {
                        Button(
                            onClick = { ankiPermissionLauncher.launch("com.ichi2.anki.permission.READ_WRITE_DATABASE") },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Grant AnkiDroid Permission")
                        }
                    } else if (ankiDecks.isEmpty()) {
                        Text(
                            text = "No decks found in AnkiDroid.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    } else {
                        var deckDropdownExpanded by remember { mutableStateOf(false) }
                        ExposedDropdownMenuBox(
                            expanded = deckDropdownExpanded,
                            onExpandedChange = { deckDropdownExpanded = !deckDropdownExpanded }
                        ) {
                            OutlinedTextField(
                                value = selectedAnkiDeck?.deckName ?: "Choose an Anki deck...",
                                onValueChange = {},
                                readOnly = true,
                                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = deckDropdownExpanded) },
                                modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable).fillMaxWidth()
                            )
                            ExposedDropdownMenu(
                                expanded = deckDropdownExpanded,
                                onDismissRequest = { deckDropdownExpanded = false }
                            ) {
                                ankiDecks.forEach { deck ->
                                    DropdownMenuItem(
                                        text = { Text("${deck.deckName} (${deck.dueCount} due)") },
                                        onClick = {
                                            selectedAnkiDeck = deck
                                            if (title.isBlank()) {
                                                title = deck.deckName
                                            }
                                            deckDropdownExpanded = false
                                        }
                                    )
                                }
                            }
                        }
                    }
                } else {
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = pathOrUrl,
                        onValueChange = { pathOrUrl = it },
                        label = { Text(if (type == "pdf") "File Path or URI" else "URL") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (type == "anki") {
                        val deck = selectedAnkiDeck
                        if (deck != null) {
                            val entity = SourceEntity(
                                id = UUID.randomUUID().toString(),
                                subjectId = subjectId,
                                title = if (title.isNotBlank()) title.trim() else deck.deckName,
                                type = "anki",
                                filePath = "anki://deck/${deck.deckId}",
                                url = null,
                                totalPages = deck.dueCount,
                                addedAt = System.currentTimeMillis(),
                                updatedAt = System.currentTimeMillis()
                            )
                            onSave(entity)
                        }
                    } else if (title.isNotBlank()) {
                        val entity = SourceEntity(
                            id = UUID.randomUUID().toString(),
                            subjectId = subjectId,
                            title = title.trim(),
                            type = type,
                            filePath = if (type == "pdf") pathOrUrl.trim() else null,
                            url = if (type != "pdf") pathOrUrl.trim() else null,
                            addedAt = System.currentTimeMillis(),
                            updatedAt = System.currentTimeMillis()
                        )
                        onSave(entity)
                    }
                },
                enabled = if (type == "anki") selectedAnkiDeck != null else title.isNotBlank()
            ) {
                Text("Add")
            }
        },
        dismissButton = {
            Button(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

@Composable
fun AddTopicDialog(
    subjectId: String,
    nextOrder: Int,
    onSave: (TopicEntity) -> Unit,
    onDismiss: () -> Unit
) {
    var name by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add Topic") },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Topic Name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
        },
        confirmButton = {
            Button(
                onClick = {
                    if (name.isNotBlank()) {
                        onSave(
                            TopicEntity(
                                id = UUID.randomUUID().toString(),
                                subjectId = subjectId,
                                name = name.trim(),
                                order = nextOrder,
                                updatedAt = System.currentTimeMillis()
                            )
                        )
                    }
                },
                enabled = name.isNotBlank()
            ) {
                Text("Add")
            }
        },
        dismissButton = {
            Button(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

@Composable
fun AddChapterDialog(
    topicId: String,
    onSave: (ChapterEntity) -> Unit,
    onDismiss: () -> Unit
) {
    var name by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add Chapter") },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Chapter Name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
        },
        confirmButton = {
            Button(
                onClick = {
                    if (name.isNotBlank()) {
                        onSave(
                            ChapterEntity(
                                id = UUID.randomUUID().toString(),
                                topicId = topicId,
                                name = name.trim(),
                                order = 0,
                                updatedAt = System.currentTimeMillis()
                            )
                        )
                    }
                },
                enabled = name.isNotBlank()
            ) {
                Text("Add")
            }
        },
        dismissButton = {
            Button(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SkillLabelSheet(
    onSelectLevel: (SkillLevel) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState()
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(24.dp)) {
            Text("Select Skill Level", style = MaterialTheme.typography.titleLarge)
            Spacer(modifier = Modifier.height(16.dp))
            SkillLevel.entries.forEach { level ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onSelectLevel(level) }
                        .padding(vertical = 12.dp)
                ) {
                    Text(
                        text = level.value.replaceFirstChar { it.uppercase() },
                        style = MaterialTheme.typography.titleMedium
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
