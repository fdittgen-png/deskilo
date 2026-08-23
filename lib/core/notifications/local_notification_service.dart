// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    try {
      await plugin.initialize(
        settings: const InitializationSettings(
          // Status-bar small icons are alpha-masked: the full-color
          // launcher mipmap rendered as a grey square (#219). Dedicated
          // white glyph — kept from the release shrinker by res/raw/
          // keep.xml (#442: it was stripped and this threw invalid_icon
          // on EVERY release boot, killing all notifications silently).
          android: AndroidInitializationSettings('@drawable/ic_stat_deskilo'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
        ),
      );
    } on PlatformException catch (e, st) {
      // Belt and braces (#442): a missing glyph must degrade to the
      // launcher icon, never to a dead notification service.
      debugPrint('notification glyph init failed, using launcher: $e\n$st');
      TraceLogger.instance.warn('notifications',
          'glyph init failed — falling back to launcher icon',
          error: e, stackTrace: st);
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
        ),
      );
    }
    // #442: the permission request is BEST-EFFORT — it must never take
    // the whole service down. When it threw here, main() fell back to
    // the Noop service and every notification (reminders, the badge
    // mirror) silently no-oped for the entire session.
    try {
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e, st) {
      debugPrint('notification permission request failed: $e\n$st');
      TraceLogger.instance.warn(
          'notifications', 'permission request failed (non-fatal)',
          error: e, stackTrace: st);
    }
    return LocalNotificationService(plugin);
  }

  /// Reminder ids scheduled by THIS run — cancelled selectively so the
  /// pending-confirmation mirror (#432) survives a reminder resync
  /// (cancelAll would wipe it).
  final _reminderIds = <int>{};

  @override
  Future<void> rescheduleCheckInReminders(
    List<ReminderRequest> reminders,
  ) async {
    try {
      // #614: two resyncs can overlap (realtime bursts) — iterating the
      // live set across awaits threw ConcurrentModificationError. Take
      // the stale snapshot and clear BEFORE the first await, so a
      // concurrent call never mutates a set mid-iteration.
      final stale = _reminderIds.toList();
      _reminderIds.clear();
      for (final id in stale) {
        await _plugin.cancel(id: id);
      }
      for (final reminder in reminders) {
        if (reminder.remindAt.isBefore(DateTime.now())) continue;
        _reminderIds.add(reminder.reservationId.hashCode);
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
  Future<bool?> notificationsEnabled() async {
    try {
      return await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    } catch (e, st) {
      debugPrint('notifications-enabled probe failed: $e\n$st');
      TraceLogger.instance.warn(
          'notifications', 'notifications-enabled probe failed',
          error: e, stackTrace: st);
      return null;
    }
  }

  /// Currently mirrored pending-confirmation notification ids (#432).
  final _pendingIds = <int>{};

  /// Stable id per event, in a range no other notification uses.
  static int _pendingIdOf(String eventId) =>
      0x20000000 | (eventId.hashCode & 0x0fffffff);

  /// One in-context permission re-request per app run (#436): the boot
  /// dialog fires over the splash and is easy to dismiss — when pending
  /// confirmations exist but Android says notifications are off, ask
  /// again at the moment the user can see why it matters.
  bool _permissionReasked = false;

  @override
  Future<void> syncPendingNotifications(List<PendingNotice> notices) async {
    try {
      if (notices.isNotEmpty &&
          !_permissionReasked &&
          await notificationsEnabled() == false) {
        _permissionReasked = true;
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      final wanted = {for (final n in notices) _pendingIdOf(n.id): n};
      for (final stale in _pendingIds.difference(wanted.keys.toSet())) {
        await _plugin.cancel(id: stale);
      }
      for (final entry in wanted.entries) {
        if (_pendingIds.contains(entry.key)) continue;
        await _plugin.show(
          id: entry.key,
          title: entry.value.title,
          body: entry.value.body,
          notificationDetails:
              const NotificationDetails(android: _pushChannel),
        );
      }
      _pendingIds
        ..clear()
        ..addAll(wanted.keys);
      // #436 diagnostics: the Developer trace names what the mirror did
      // and whether the system even allows posting.
      TraceLogger.instance.log(TraceLevel.info, 'notifications',
          'pending mirror: ${wanted.length} active, '
          'enabled=${await notificationsEnabled()}');
    } catch (e, st) {
      debugPrint('pending notification sync failed: $e\n$st');
      TraceLogger.instance.error(
          'notifications', 'pending notification sync failed',
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
