import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
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
      debugPrint('Error showing session complete notification: $e');
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
      debugPrint('Error scheduling study reminder: $e');
    }
  }

  Future<void> cancelReminder() async {
    try {
      await _plugin.cancel(1);
    } catch (e) {
      debugPrint('Error cancelling reminder: $e');
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
      debugPrint('Error scheduling daily reminder: $e');
    }
  }

  Future<void> cancelDailyReminder() async {
    try {
      await _plugin.cancel(2);
    } catch (e) {
      debugPrint('Error cancelling daily reminder: $e');
    }
  }
}
