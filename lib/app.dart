import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class StudyTrackerApp extends ConsumerWidget {
  const StudyTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeSettings = ref.watch(themeSettingsProvider);

    return themeSettings.when(
      data: (settings) {
        final palette = AppTheme.paletteForStyle(settings.themeStyle);
        final presetSeed = AppTheme
            .presetSeeds[settings.seedColorIndex % AppTheme.presetSeeds.length];

        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
        final useDynamic =
                settings.useDynamicColor &&
                lightDynamic != null &&
                darkDynamic != null;

            final lightSeed =
                settings.themeStyle == AppThemeStyle.atmosphericTeal
                ? presetSeed
                : palette.seedColor;
            final darkSeed =
                settings.themeStyle == AppThemeStyle.atmosphericTeal
                ? presetSeed
                : palette.seedColor;

            final lightVariant = palette.dynamicSchemeVariant;
            final darkVariant = palette.dynamicSchemeVariant;

            final lightTheme = useDynamic
                ? AppTheme.themeFromColorScheme(lightDynamic)
                : AppTheme.light(lightSeed, variant: lightVariant);
            final darkTheme = useDynamic
                ? AppTheme.themeFromColorScheme(darkDynamic)
                : AppTheme.dark(darkSeed, variant: darkVariant);

            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(settings.fontScale)),
              child: MaterialApp.router(
                title: 'StudyTracker',
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: settings.themeMode,
                routerConfig: router,
              ),
            );
          },
        );
      },
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stackTrace) => const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Failed to load theme settings')),
        ),
      ),
    );
  }
}
