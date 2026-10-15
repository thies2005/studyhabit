package de.schuelken.studyhabit.ui.settings

import android.os.Build
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.BuildConfig
import de.schuelken.studyhabit.core.di.AppContainer

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiagnosticLogsScreen(
    container: AppContainer,
    onNavigateBack: () -> Unit
) {
    var projectCount by remember { mutableIntStateOf(0) }
    var subjectCount by remember { mutableIntStateOf(0) }
    var sessionCount by remember { mutableIntStateOf(0) }
    var sourceCount by remember { mutableIntStateOf(0) }
    var achievementCount by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        projectCount = container.database.projectDao().getAllProjects().size
        subjectCount = container.database.subjectDao().getAllSubjects().size
        sessionCount = container.database.sessionDao().getAllSessions().size
        sourceCount = container.database.sourceDao().getAllSources().size
        achievementCount = container.database.achievementDao().getAllAchievements().size
    }

    val hasToken = !container.tokenStorage.getToken().isNullOrBlank()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Diagnostic Logs") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(text = "App & System Info", style = MaterialTheme.typography.titleMedium)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(text = "App Version: ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
                        Text(text = "Device: ${Build.MANUFACTURER} ${Build.MODEL}")
                        Text(text = "Android OS: API ${Build.VERSION.SDK_INT} (${Build.VERSION.RELEASE})")
                        Text(text = "Auth Token Present: $hasToken")
                    }
                }
            }

            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(text = "Local Database Metrics", style = MaterialTheme.typography.titleMedium)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(text = "Projects: $projectCount")
                        Text(text = "Subjects: $subjectCount")
                        Text(text = "Study Sessions: $sessionCount")
                        Text(text = "Sources: $sourceCount")
                        Text(text = "Achievements Evaluated: $achievementCount")
                    }
                }
            }
        }
    }
}
