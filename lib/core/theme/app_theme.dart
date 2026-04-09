import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeStyle {
  atmosphericTeal,
  midnightSlate,
  forestSanctuary,
  royalPlum,
  amberHearth,
  vellumEmber,
  luminaMinimal,
}

class AppThemePalette {
  const AppThemePalette({
    required this.style,
    required this.name,
    required this.subtitle,
    required this.seedColor,
    required this.dynamicSchemeVariant,
  });

  final AppThemeStyle style;
  final String name;
  final String subtitle;
  final Color seedColor;
  final DynamicSchemeVariant dynamicSchemeVariant;
}

class AppTheme {
  static const List<Color> presetSeeds = [
    Color(0xFF006874),
    Color(0xFF6750A4),
    Color(0xFF0061A4),
    Color(0xFF006E1C),
    Color(0xFFB3261E),
    Color(0xFF984061),
    Color(0xFFAC3306),
    Color(0xFF7B5800),
    Color(0xFF386667),
    Color(0xFF343DFF),
    Color(0xFF1B6B46),
    Color(0xFF4A4458),
  ];

  static const List<AppThemePalette> curatedPalettes = [
    AppThemePalette(
      style: AppThemeStyle.atmosphericTeal,
      name: 'Atmospheric Teal',
      subtitle: 'Focused',
      seedColor: Color(0xFF006874),
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
    AppThemePalette(
      style: AppThemeStyle.midnightSlate,
      name: 'Midnight Slate',
      subtitle: 'OLED Dark',
      seedColor: Color(0xFF38BDF8),
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
    AppThemePalette(
      style: AppThemeStyle.forestSanctuary,
      name: 'Forest Sanctuary',
      subtitle: 'Organic',
      seedColor: Color(0xFF064E3B),
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
    AppThemePalette(
      style: AppThemeStyle.royalPlum,
      name: 'Royal Plum',
      subtitle: 'Deep Tint',
      seedColor: Color(0xFF4C1D95),
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
    AppThemePalette(
      style: AppThemeStyle.amberHearth,
      name: 'Amber Hearth',
      subtitle: 'Warm',
      seedColor: Color(0xFFC05E44),
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
    AppThemePalette(
      style: AppThemeStyle.vellumEmber,
      name: 'Vellum & Ember',
      subtitle: 'Editorial',
      seedColor: Color(0xFF8E5D4E),
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    ),
    AppThemePalette(
      style: AppThemeStyle.luminaMinimal,
      name: 'Lumina Minimal',
      subtitle: 'Light Neutral',
      seedColor: Color(0xFF1A1C1E),
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    ),
  ];

  static AppThemePalette paletteForStyle(AppThemeStyle style) {
    return curatedPalettes.firstWhere((palette) => palette.style == style);
  }

  static ThemeData light(
    Color seed, {
    DynamicSchemeVariant variant = DynamicSchemeVariant.fidelity,
  }) {
    return _themeFromScheme(
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
        dynamicSchemeVariant: variant,
      ),
      Brightness.light,
    );
  }

  static ThemeData dark(
    Color seed, {
    DynamicSchemeVariant variant = DynamicSchemeVariant.fidelity,
  }) {
    return _themeFromScheme(
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        dynamicSchemeVariant: variant,
      ),
      Brightness.dark,
    );
  }

  static ThemeData themeFromColorScheme(ColorScheme scheme) {
    return _themeFromScheme(scheme, scheme.brightness);
  }

  static ThemeData _themeFromScheme(ColorScheme scheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _buildTextTheme(brightness),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
        color: scheme.surfaceContainerLow,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer.withValues(alpha: 0.8),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(color: scheme.onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onSurface);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = ThemeData(brightness: brightness).textTheme;
    final textTheme = GoogleFonts.dmSansTextTheme(base);
    return textTheme.copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        textStyle: textTheme.displayLarge,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        textStyle: textTheme.displayMedium,
        fontWeight: FontWeight.w600,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        textStyle: textTheme.displaySmall,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        textStyle: textTheme.headlineLarge,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        textStyle: textTheme.headlineMedium,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        textStyle: textTheme.headlineSmall,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        textStyle: textTheme.titleLarge,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        textStyle: textTheme.titleMedium,
        fontWeight: FontWeight.w600,
      ),
      labelLarge: GoogleFonts.spaceGrotesk(
        textStyle: textTheme.labelLarge,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.spaceGrotesk(
        textStyle: textTheme.labelMedium,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.spaceGrotesk(
        textStyle: textTheme.labelSmall,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
