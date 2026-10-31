package de.schuelken.studyhabit.core.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance

internal fun contrastRatio(a: Color, b: Color): Float {
    val first = a.luminance()
    val second = b.luminance()
    return (maxOf(first, second) + .05f) / (minOf(first, second) + .05f)
}

internal fun seedColorScheme(seed: Color, dark: Boolean): ColorScheme {
    val background = if (dark) Color(0xFF0F1416) else Color(0xFFF5FAFB)
    val surface = if (dark) Color(0xFF111416) else Color(0xFFEFF4F6)
    val variant = if (dark) Color(0xFF192023) else Color(0xFFE3EAEB)
    val container = lerp(seed, if (dark) background else Color.White, .9f)
    val target = if (dark) Color.White else Color.Black
    var primary = seed
    for (step in 0..100) {
        primary = lerp(seed, target, step / 100f)
        if (listOf(background, surface, variant, container).all { contrastRatio(primary, it) >= 4.5f }) break
    }
    val onPrimary = if (contrastRatio(primary, Color.White) >= contrastRatio(primary, Color.Black)) Color.White else Color.Black
    return if (dark) darkColorScheme(
        primary = primary, onPrimary = onPrimary,
        primaryContainer = container, onPrimaryContainer = primary,
        background = background, surface = surface, surfaceVariant = variant,
        onBackground = Color(0xFFE1E3E4), onSurface = Color(0xFFE1E3E4),
        onSurfaceVariant = Color(0xFFBFC8CA), outline = Color(0xFF899295)
    ) else lightColorScheme(
        primary = primary, onPrimary = onPrimary,
        primaryContainer = container, onPrimaryContainer = primary,
        background = background, surface = surface, surfaceVariant = variant,
        onBackground = Color(0xFF171C1E), onSurface = Color(0xFF171C1E),
        onSurfaceVariant = Color(0xFF3F484B), outline = Color(0xFF6F797B)
    )
}
