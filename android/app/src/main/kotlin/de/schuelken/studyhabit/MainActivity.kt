package de.schuelken.studyhabit

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.compose.rememberNavController
import de.schuelken.studyhabit.core.theme.AppTheme
import de.schuelken.studyhabit.ui.navigation.AppNavHost

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val app = application as StudyHabitApplication
        val container = app.container

        setContent {
            val themeMode by container.preferences.themeMode.collectAsState()
            val seedColorIndex by container.preferences.seedColorIndex.collectAsState()
            val themeStyleIndex by container.preferences.themeStyleIndex.collectAsState()
            val useDynamicColor by container.preferences.useDynamicColor.collectAsState()
            val fontScale by container.preferences.fontScale.collectAsState()

            AppTheme(
                themeMode = themeMode,
                seedColorIndex = seedColorIndex,
                themeStyleIndex = themeStyleIndex,
                useDynamicColor = useDynamicColor,
                fontScale = fontScale
            ) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    val navController = rememberNavController()
                    AppNavHost(
                        navController = navController,
                        container = container
                    )
                }
            }
        }
    }
}
