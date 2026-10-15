package de.schuelken.studyhabit.core.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import de.schuelken.studyhabit.core.model.ThemeMode

data class CuratedPalette(
    val name: String,
    val subtitle: String,
    val seedColor: Color,
)

object AppThemeTokens {
    val presetSeeds = listOf(
        Color(0xFF006874), // Deep Teal
        Color(0xFF6750A4), // Purple
        Color(0xFF0061A4), // Blue
        Color(0xFF006E1C), // Green
        Color(0xFFB3261E), // Red
        Color(0xFF984061), // Pink
        Color(0xFFAC3306), // Orange
        Color(0xFF7B5800), // Brown/Amber
        Color(0xFF386667), // Cyan
        Color(0xFF343DFF), // Indigo
        Color(0xFF1B6B46), // Forest
        Color(0xFF4A4458), // Slate
    )

    val curatedPalettes = listOf(
        CuratedPalette("Atmospheric Teal", "Focused", Color(0xFF006874)),
        CuratedPalette("Midnight Slate", "OLED Dark", Color(0xFF38BDF8)),
        CuratedPalette("Forest Sanctuary", "Organic", Color(0xFF064E3B)),
        CuratedPalette("Royal Plum", "Deep Tint", Color(0xFF4C1D95)),
        CuratedPalette("Amber Hearth", "Warm", Color(0xFFC05E44)),
        CuratedPalette("Vellum & Ember", "Editorial", Color(0xFF8E5D4E)),
        CuratedPalette("Lumina Minimal", "Light Neutral", Color(0xFF1A1C1E)),
    )
}

@Composable
fun AppTheme(
    themeMode: ThemeMode = ThemeMode.SYSTEM,
    seedColorIndex: Int = 0,
    themeStyleIndex: Int = 0,
    useDynamicColor: Boolean = false,
    fontScale: Float = 1.0f,
    content: @Composable () -> Unit
) {
    val darkTheme = when (themeMode) {
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
    }

    val context = LocalContext.current
    val colorScheme = when {
        useDynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        else -> {
            val seed = AppThemeTokens.presetSeeds.getOrElse(seedColorIndex) { AppThemeTokens.presetSeeds[0] }
            if (darkTheme) {
                darkColorScheme(
                    primary = seed,
                    primaryContainer = seed.copy(alpha = 0.4f),
                    onPrimary = Color.White,
                    background = Color(0xFF0F1416),
                    surface = Color(0xFF111416),
                    surfaceVariant = Color(0xFF192023),
                    onBackground = Color(0xFFE1E3E4),
                    onSurface = Color(0xFFE1E3E4),
                    onSurfaceVariant = Color(0xFFBFC8CA),
                    outline = Color(0xFF899295),
                )
            } else {
                lightColorScheme(
                    primary = seed,
                    primaryContainer = seed.copy(alpha = 0.2f),
                    onPrimary = Color.White,
                    background = Color(0xFFF5FAFB),
                    surface = Color(0xFFEFF4F6),
                    surfaceVariant = Color(0xFFE3EAEB),
                    onBackground = Color(0xFF171C1E),
                    onSurface = Color(0xFF171C1E),
                    onSurfaceVariant = Color(0xFF3F484B),
                    outline = Color(0xFF6F797B),
                )
            }
        }
    }

    val currentDensity = LocalDensity.current
    val customDensity = Density(
        density = currentDensity.density,
        fontScale = currentDensity.fontScale * fontScale
    )

    CompositionLocalProvider(LocalDensity provides customDensity) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = Typography,
            content = content
        )
    }
}
