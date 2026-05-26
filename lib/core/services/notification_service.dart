import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app_logger.dart';

part 'notification_service.g.dart';

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    // Set the local timezone based on the device's UTC offset
    _setLocalTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        AppLogger.d('NotificationService', 'Notification tapped: ${response.payload}');
      },
    );

    _initialized = true;
  }

  /// Determines the local timezone from the device's UTC offset and sets it
  /// for the tz library. This ensures scheduled notifications fire at the
  /// correct local time.
  void _setLocalTimezone() {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;

      // Try to find a matching timezone from the database
      String? matchedLocation;
      for (final name in tz.timeZoneDatabase.locations.keys) {
        final location = tz.getLocation(name);
        final tzNow = tz.TZDateTime.now(location);
        if (tzNow.timeZoneOffset == offset) {
          matchedLocation = name;
          break;
        }
      }

      if (matchedLocation != null) {
        tz.setLocalLocation(tz.getLocation(matchedLocation));
        AppLogger.d('NotificationService', 'Timezone set to: $matchedLocation');
      } else {
        // Fallback: use UTC offset to construct a fixed-offset location
        AppLogger.w('NotificationService', 'Could not match timezone, using UTC offset: $offset');
      }
    } catch (e) {
      AppLogger.e('NotificationService', 'Error setting local timezone', e);
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  Future<void> showSessionComplete({
    required int durationMinutes,
    required int pomodorosCompleted,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'study_session_complete',
        'Session Complete',
        channelDescription: 'Notifications when study sessions complete',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _plugin.show(
        0,
        'Session Complete! 🎉',
        'You studied for $durationMinutes minutes and completed $pomodorosCompleted pomodoro${pomodorosCompleted != 1 ? 's' : ''}!',
        details,
      );
    } catch (e) {
      AppLogger.e('NotificationService', 'Error showing session complete notification', e);
    }
  }

  Future<void> scheduleStudyReminder({
    required Duration delay,
    required String subjectName,
  }) async {
    try {
      // Cancel existing reminders
      await _plugin.cancel(1);

      const androidDetails = AndroidNotificationDetails(
        'study_reminder',
        'Study Reminders',
        channelDescription: 'Reminders to continue studying',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _plugin.zonedSchedule(
        1,
        'Time to Study! 📚',
        'You studied $subjectName earlier. Ready for another session?',
        tz.TZDateTime.now(tz.local).add(delay),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      AppLogger.e('NotificationService', 'Error scheduling study reminder', e);
    }
  }

  Future<void> cancelReminder() async {
    try {
      await _plugin.cancel(1);
    } catch (e) {
      AppLogger.e('NotificationService', 'Error cancelling reminder', e);
    }
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    try {
      await _plugin.cancel(2);

      const androidDetails = AndroidNotificationDetails(
        'daily_reminder',
        'Daily Reminders',
        channelDescription: 'Daily study goal reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        2,
        'Daily Study Goal 🎯',
        'Don\'t forget to complete your study session today!',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      AppLogger.e('NotificationService', 'Error scheduling daily reminder', e);
    }
  }

  Future<void> cancelDailyReminder() async {
    try {
      await _plugin.cancel(2);
    } catch (e) {
      AppLogger.e('NotificationService', 'Error cancelling daily reminder', e);
    }
  }
}
