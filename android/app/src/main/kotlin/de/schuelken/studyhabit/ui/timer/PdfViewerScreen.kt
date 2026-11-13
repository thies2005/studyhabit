package de.schuelken.studyhabit.ui.timer

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import android.content.Intent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import de.schuelken.studyhabit.core.service.PdfSourceAccess
import kotlinx.coroutines.CancellationException
import androidx.compose.runtime.rememberCoroutineScope
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import de.schuelken.studyhabit.StudyHabitApplication
import de.schuelken.studyhabit.core.database.SourceEntity
import de.schuelken.studyhabit.core.di.AppContainer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PdfViewerScreen(
    sourceId: String,
    container: AppContainer,
    onNavigateBack: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var reloadKey by remember { mutableIntStateOf(0) }
    var source by remember { mutableStateOf<SourceEntity?>(null) }
    var pdfRenderer by remember { mutableStateOf<PdfRenderer?>(null) }
    var fileDescriptor by remember { mutableStateOf<ParcelFileDescriptor?>(null) }
    var pageCount by remember { mutableIntStateOf(0) }
    var currentPage by remember { mutableIntStateOf(0) }
    var currentBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    var scale by remember { mutableFloatStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }

    val transformState = rememberTransformableState { zoomChange, offsetChange, _ ->
        val newScale = (scale * zoomChange).coerceIn(1f, 5f)
        scale = newScale
        if (newScale > 1f) {
            offset += offsetChange
        } else {
            offset = Offset.Zero
        }
    }

    LaunchedEffect(currentPage) {
        scale = 1f
        offset = Offset.Zero
    }

    val relinkLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) scope.launch {
            isLoading = true
            try {
                withContext(Dispatchers.IO) {
                    PdfSourceAccess.validate(context, uri.toString())
                    context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    val existing = container.database.sourceDao().getSourceById(sourceId)
                        ?: error("This source no longer exists.")
                    container.database.sourceDao().upsert(existing.copy(
                        filePath = uri.toString(), currentPage = 0, progressPercent = 0.0,
                        updatedAt = System.currentTimeMillis()
                    ))
                }
                container.triggerDataChangedSync()
                reloadKey++
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                errorMessage = e.message ?: "Could not relink this PDF."
            } finally { isLoading = false }
        }
    }

    LaunchedEffect(sourceId, reloadKey) {
        isLoading = true
        errorMessage = null
        runCatching { pdfRenderer?.close() }
        runCatching { fileDescriptor?.close() }
        pdfRenderer = null
        fileDescriptor = null
        currentBitmap = null
        pageCount = 0
        val s = container.database.sourceDao().getSourceById(sourceId)
        source = s
        if (s == null || s.filePath.isNullOrBlank()) {
            errorMessage = "PDF source or file path not found."
            isLoading = false
            return@LaunchedEffect
        }

        withContext(Dispatchers.IO) {
            try {
                val pfd = PdfSourceAccess.open(context, s.filePath)

                fileDescriptor = pfd
                val renderer = PdfRenderer(pfd)
                pdfRenderer = renderer
                pageCount = renderer.pageCount
                currentPage = (s.currentPage ?: 1).coerceIn(1, renderer.pageCount)
                isLoading = false
            } catch (e: Exception) {
                errorMessage = "Failed to load PDF: ${e.message}"
                isLoading = false
            }
        }
    }

    // Render page at 2x scale when currentPage changes
    LaunchedEffect(currentPage, pdfRenderer) {
        val renderer = pdfRenderer ?: return@LaunchedEffect
        if (currentPage in 1..pageCount) {
            withContext(Dispatchers.IO) {
                try {
                    renderer.openPage(currentPage - 1).use { page ->
                    val scaleFactor = 2
                    val bitmap = Bitmap.createBitmap(page.width * scaleFactor, page.height * scaleFactor, Bitmap.Config.ARGB_8888)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    currentBitmap = bitmap
                    }
                } catch (e: Throwable) {
                    // Fallback to 1x scale if memory allocation fails
                    try {
                        renderer.openPage(currentPage - 1).use { page ->
                        val bitmap = Bitmap.createBitmap(page.width, page.height, Bitmap.Config.ARGB_8888)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        currentBitmap = bitmap
                        }
                    } catch (e2: Throwable) {
                        errorMessage = "Failed to render page: ${e2.message}"
                    }
                }
            }
        }
    }

    // Debounced page progress save (sync triggers once when closing the PDF to avoid spamming cloud files)
    LaunchedEffect(currentPage) {
        delay(3000)
        if (source != null && pageCount > 0) {
            val progressPercent = (currentPage.toDouble() / pageCount.toDouble()) * 100.0
            container.database.sourceDao().updatePageProgress(
                sourceId,
                currentPage,
                progressPercent,
                System.currentTimeMillis()
            )
        }
    }

    val latestCurrentPage by rememberUpdatedState(currentPage)
    val latestPageCount by rememberUpdatedState(pageCount)

    DisposableEffect(sourceId) {
        onDispose {
            try {
                pdfRenderer?.close()
                fileDescriptor?.close()
            } catch (e: Exception) {
                // Ignore close error
            }
            val p = latestCurrentPage
            val count = latestPageCount
            if (p > 0 && count > 0) {
                val progressPercent = (p.toDouble() / count.toDouble()) * 100.0
                val app = context.applicationContext as? StudyHabitApplication
                val appScope = app?.appScope ?: CoroutineScope(Dispatchers.IO)
                appScope.launch {
                    container.database.sourceDao().updatePageProgress(
                        sourceId,
                        p,
                        progressPercent,
                        System.currentTimeMillis()
                    )
                    container.triggerDataChangedSync()
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(source?.title ?: "PDF Reader") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        bottomBar = {
            if (pageCount > 0) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.surface)
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = { if (currentPage > 1) currentPage-- },
                        enabled = currentPage > 1
                    ) {
                        Icon(Icons.Default.ChevronLeft, contentDescription = "Previous Page")
                    }
                    Text(
                        text = "Page $currentPage / $pageCount",
                        style = MaterialTheme.typography.titleMedium
                    )
                    IconButton(
                        onClick = { if (currentPage < pageCount) currentPage++ },
                        enabled = currentPage < pageCount
                    ) {
                        Icon(Icons.Default.ChevronRight, contentDescription = "Next Page")
                    }
                }
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(Color.DarkGray)
                .clipToBounds(),
            contentAlignment = Alignment.Center
        ) {
            when {
                isLoading -> CircularProgressIndicator()
                errorMessage != null -> Column(
                    Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(text = errorMessage ?: "", color = MaterialTheme.colorScheme.onSurface)
                    Spacer(Modifier.height(16.dp))
                    if (source != null) Button(onClick = { relinkLauncher.launch(arrayOf("application/pdf")) }) {
                        Text("Choose PDF Again")
                    }
                }
                currentBitmap != null -> {
                    Image(
                        bitmap = currentBitmap!!.asImageBitmap(),
                        contentDescription = "PDF Page $currentPage",
                        modifier = Modifier
                            .fillMaxSize()
                            .graphicsLayer(
                                scaleX = scale,
                                scaleY = scale,
                                translationX = offset.x,
                                translationY = offset.y
                            )
                            .transformable(state = transformState)
                    )
                }
            }
        }
    }
}
