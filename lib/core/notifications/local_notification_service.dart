// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../trace/trace_logger.dart';
import 'notification_service.dart';

/// flutter_local_notifications implementation. Scheduling converts absolute
/// instants with TZDateTime.from, so the device zone name is irrelevant.
class LocalNotificationService implements NotificationService {
  LocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _pushChannel = AndroidNotificationDetails(
    'pending_requests',
    'Pending requests',
    channelDescription: 'Someone needs your confirmation',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _channel = AndroidNotificationDetails(
    'check_in_reminders',
    'Check-in reminders',
    channelDescription: 'Reminds you shortly before your reservations start',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<LocalNotificationService> initialize() async {
    tzdata.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        // Status-bar small icons are alpha-masked: the full-color launcher
        // mipmap rendered as a grey square (#219). Dedicated white glyph.
        android: AndroidInitializationSettings('@drawable/ic_stat_deskilo'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return LocalNotificationService(plugin);
  }

  @override
  Future<void> rescheduleCheckInReminders(
    List<ReminderRequest> reminders,
  ) async {
    try {
      await _plugin.cancelAll();
      for (final reminder in reminders) {
        if (reminder.remindAt.isBefore(DateTime.now())) continue;
        await _plugin.zonedSchedule(
          id: reminder.reservationId.hashCode,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tz.TZDateTime.from(reminder.remindAt, tz.local),
          notificationDetails: const NotificationDetails(android: _channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e, st) {
      // Notifications are best-effort: booking flows must never fail on
      // notification-permission or platform errors.
      debugPrint('reminder scheduling failed: $e\n$st');
      TraceLogger.instance.error('notifications', 'reminder scheduling failed',
          error: e, stackTrace: st);
    }
  }

  @override
  Future<void> showNow({required String title, required String body}) async {
    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch & 0x3fffffff,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: _pushChannel),
      );
    } catch (e, st) {
      debugPrint('push notification display failed: $e\n$st');
      TraceLogger.instance.error(
          'notifications', 'push notification display failed',
          error: e, stackTrace: st);
    }
  }
}
