import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/app_logger.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the singleton NotificationService that the provider also returns
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

  // Schedule daily reminder only if BOTH master toggle AND daily reminder toggle are on
  if (themeSettings.notificationsEnabled && themeSettings.dailyReminderEnabled) {
    try {
      await notificationService.scheduleDailyReminder(
        hour: themeSettings.dailyReminderHour,
        minute: themeSettings.dailyReminderMinute,
      );
      AppLogger.i('App', 'Daily reminder scheduled at ${themeSettings.dailyReminderHour}:${themeSettings.dailyReminderMinute.toString().padLeft(2, '0')}');
    } catch (e) {
      AppLogger.e('App', 'Failed to schedule daily reminder', e);
    }
  } else {
    // Make sure no stale daily reminder is lingering
    try {
      await notificationService.cancelDailyReminder();
    } catch (e) {
      AppLogger.e('App', 'Failed to cancel daily reminder', e);
    }
  }

  runApp(UncontrolledProviderScope(
    container: container,
    child: const StudyTrackerApp(),
  ));
}

