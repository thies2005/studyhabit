package de.schuelken.studyhabit.ui.timer

import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Composable
fun FocusTimerLayout(
    header: @Composable () -> Unit,
    timer: @Composable (Dp) -> Unit,
    controls: @Composable () -> Unit
) {
    BoxWithConstraints(Modifier.fillMaxSize().systemBarsPadding().padding(24.dp)) {
        val availableHeight = maxHeight
        val availableWidth = maxWidth
        if (maxWidth > maxHeight) {
            Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                    timer(minOf(280.dp, availableHeight, (availableWidth - 24.dp) / 2))
                }
                Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).heightIn(min = availableHeight),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.SpaceBetween) {
                    header()
                    Spacer(Modifier.height(24.dp))
                    controls()
                }
            }
        } else {
            Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = availableHeight),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.SpaceBetween) {
                header()
                Spacer(Modifier.height(24.dp))
                timer(minOf(280.dp, availableWidth))
                Spacer(Modifier.height(24.dp))
                controls()
            }
        }
    }
}
