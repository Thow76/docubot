import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/document.dart';
import '../models/reminder.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'docsafe_reminders';
  static const String _channelName = 'Document Reminders';
  static const String _channelDescription =
      'Reminders for actionable dates in your documents';

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
  );

  /// Initialises the notifications plugin, timezone database, and requests
  /// notification permissions on Android 13+.
  Future<void> init() async {
    tz.initializeTimeZones();
    final localTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimeZone));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // Request POST_NOTIFICATIONS permission (Android 13+)
    await Permission.notification.request();
  }

  /// Schedules a local notification for [reminder] at 9:00 AM on
  /// (actionableDate − notifyDaysBefore). Skips silently if that date is in
  /// the past.
  Future<void> scheduleReminder(Reminder reminder, String documentTitle) async {
    // DEBUG: REMOVE BEFORE RELEASE
    debugPrint('DEBUG: scheduleReminder() called for reminder ${reminder.id} ("$documentTitle")');
    debugPrint('DEBUG:   actionableDate = ${reminder.actionableDate}');
    debugPrint('DEBUG:   notifyDaysBefore = ${reminder.notifyDaysBefore}');

    final notifyDate = reminder.actionableDate.subtract(
      Duration(days: reminder.notifyDaysBefore),
    );

    // DEBUG: REMOVE BEFORE RELEASE
    debugPrint('DEBUG:   calculated fire date = $notifyDate');

    final now = DateTime.now();
    if (notifyDate.isBefore(now)) {
      // DEBUG: REMOVE BEFORE RELEASE
      debugPrint('DEBUG WARNING: Fire date is in the past — notification will not be delivered (fireDate=$notifyDate, now=$now)');
      return;
    }

    final scheduledDate = tz.TZDateTime(
      tz.local,
      notifyDate.year,
      notifyDate.month,
      notifyDate.day,
      9, // 9:00 AM
    );

    // DEBUG: REMOVE BEFORE RELEASE
    debugPrint('DEBUG:   TZDateTime to pass to zonedSchedule = $scheduledDate');

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      // DEBUG: REMOVE BEFORE RELEASE
      debugPrint('DEBUG WARNING: Fire date is in the past — notification will not be delivered (scheduledDate=$scheduledDate)');
      return;
    }

    try {
      await _plugin.zonedSchedule(
        _reminderNotificationId(reminder.id),
        'DocuBot Reminder',
        '$documentTitle — ${reminder.contextReason}',
        scheduledDate,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      // DEBUG: REMOVE BEFORE RELEASE
      debugPrint('DEBUG: zonedSchedule() completed for reminder ${reminder.id} at $scheduledDate');
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  /// Cancels the scheduled notification for [reminderId].
  Future<void> cancelReminder(String reminderId) async {
    try {
      await _plugin.cancel(_reminderNotificationId(reminderId));
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }

  /// Cancels the existing notification for [reminder] then schedules a new one.
  Future<void> rescheduleReminder(
    Reminder reminder,
    String documentTitle,
  ) async {
    await cancelReminder(reminder.id);
    await scheduleReminder(reminder, documentTitle);
  }

  /// Cancels all existing notifications and re-schedules every active
  /// (non-completed) reminder. Call this on app startup.
  Future<void> rescheduleAllReminders(
    List<Reminder> reminders,
    List<Document> documents,
  ) async {
    // DEBUG: REMOVE BEFORE RELEASE
    final activeReminders = reminders.where((r) => !r.isCompleted).toList();
    debugPrint('DEBUG: rescheduleAllReminders() called — ${reminders.length} total reminders, ${activeReminders.length} active');

    await _plugin.cancelAll();
    // DEBUG: REMOVE BEFORE RELEASE
    debugPrint('DEBUG: cancelAll() completed');

    final docMap = {for (final d in documents) d.id: d};

    // DEBUG: REMOVE BEFORE RELEASE
    int scheduled = 0;
    int skippedCompleted = 0;
    int skippedNoDoc = 0;

    for (final reminder in reminders) {
      if (reminder.isCompleted) {
        // DEBUG: REMOVE BEFORE RELEASE
        skippedCompleted++;
        debugPrint('DEBUG:   Skipping reminder ${reminder.id} — marked completed');
        continue;
      }
      final doc = docMap[reminder.documentId];
      if (doc == null) {
        // DEBUG: REMOVE BEFORE RELEASE
        skippedNoDoc++;
        debugPrint('DEBUG:   Skipping reminder ${reminder.id} — no matching document (documentId=${reminder.documentId})');
        continue;
      }
      await scheduleReminder(reminder, doc.title);
      // DEBUG: REMOVE BEFORE RELEASE
      scheduled++;
    }

    // DEBUG: REMOVE BEFORE RELEASE
    debugPrint('DEBUG: rescheduleAllReminders() finished — attempted=$scheduled, skippedCompleted=$skippedCompleted, skippedNoDoc=$skippedNoDoc');
  }

  // DEBUG: REMOVE BEFORE RELEASE
  Future<void> showTestNotification() async {
    debugPrint('DEBUG: Attempting immediate test notification');
    await _plugin.show(
      0,
      'DocuBot Test',
      'If you see this, notifications are working',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'docsafe_reminders',
          'Document Reminders',
          channelDescription: 'Reminders for document deadlines',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    debugPrint('DEBUG: plugin.show() completed');
  }

  // DEBUG: REMOVE BEFORE RELEASE
  Future<void> showScheduledTestNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    final fireDate = now.add(const Duration(minutes: 1));
    debugPrint('DEBUG: Scheduling test notification for $fireDate');

    await _plugin.zonedSchedule(
      99999,
      'DocuBot Scheduled Test',
      'Scheduled notification is working',
      fireDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'docsafe_reminders',
          'Document Reminders',
          channelDescription: 'Reminders for document deadlines',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('DEBUG: zonedSchedule() completed for $fireDate');
  }

  /// Converts a reminder UUID string to a stable non-negative int suitable
  /// for use as a notification ID.
  int _reminderNotificationId(String reminderId) =>
      reminderId.hashCode.abs() % 2147483647;
}
