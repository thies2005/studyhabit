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

private fun contrastAdjustedAccent(base: Color, backgrounds: List<Color>, target: Color): Color {
    var result = base
    for (step in 0..100) {
        result = lerp(base, target, step / 100f)
        if (backgrounds.all { contrastRatio(result, it) >= 4.5f }) break
    }
    return result
}

private fun accessibleOnColor(background: Color): Color =
    if (contrastRatio(background, Color.White) >= contrastRatio(background, Color.Black)) Color.White else Color.Black

internal fun seedColorScheme(seed: Color, dark: Boolean): ColorScheme {
    val background = if (dark) Color(0xFF0F1416) else Color(0xFFF5FAFB)
    val surface = if (dark) Color(0xFF111416) else Color(0xFFEFF4F6)
    val variant = if (dark) Color(0xFF192023) else Color(0xFFE3EAEB)
    val container = lerp(seed, if (dark) background else Color.White, .9f)
    val target = if (dark) Color.White else Color.Black

    val primary = contrastAdjustedAccent(seed, listOf(background, surface, variant, container), target)
    val onPrimary = accessibleOnColor(primary)

    val tertiarySeed = if (seed.red > 0.55f && seed.blue < 0.35f) Color(0xFF007A87) else Color(0xFFD85C27)
    val tertiaryContainer = lerp(tertiarySeed, if (dark) background else Color.White, .9f)
    val tertiary = contrastAdjustedAccent(
        tertiarySeed,
        listOf(background, surface, variant, container, tertiaryContainer),
        target
    )
    val onTertiary = accessibleOnColor(tertiary)

    return if (dark) darkColorScheme(
        primary = primary, onPrimary = onPrimary,
        primaryContainer = container, onPrimaryContainer = primary,
        tertiary = tertiary, onTertiary = onTertiary,
        tertiaryContainer = tertiaryContainer, onTertiaryContainer = tertiary,
        background = background, surface = surface, surfaceVariant = variant,
        onBackground = Color(0xFFE1E3E4), onSurface = Color(0xFFE1E3E4),
        onSurfaceVariant = Color(0xFFBFC8CA), outline = Color(0xFF899295)
    ) else lightColorScheme(
        primary = primary, onPrimary = onPrimary,
        primaryContainer = container, onPrimaryContainer = primary,
        tertiary = tertiary, onTertiary = onTertiary,
        tertiaryContainer = tertiaryContainer, onTertiaryContainer = tertiary,
        background = background, surface = surface, surfaceVariant = variant,
        onBackground = Color(0xFF171C1E), onSurface = Color(0xFF171C1E),
        onSurfaceVariant = Color(0xFF3F484B), outline = Color(0xFF6F797B)
    )
}
