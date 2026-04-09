import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/app_logger.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.e('FlutterError', details.exceptionAsString(), details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('PlatformError', error.toString(), error, stack);
    return true;
  };

  AppLogger.i('App', 'StudyTracker starting up...');

  final container = ProviderContainer();
  final themeSettings = await container.read(themeSettingsProvider.future);
  if (themeSettings.notificationsEnabled) {
    try {
      await notificationService.scheduleDailyReminder(
        hour: themeSettings.dailyReminderHour,
        minute: themeSettings.dailyReminderMinute,
      );
    } catch (e) {
      AppLogger.e('App', 'Failed to schedule daily reminder', e);
    }
  }

  runApp(UncontrolledProviderScope(
    container: container,
    child: const StudyTrackerApp(),
  ));
}
