// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// #711 — latest_ALL, links included. The trimmed database dropped every
// zone tzdata 2022b turned into a link — Europe/Amsterdam, Luxembourg,
// Copenhagen, Stockholm, Oslo among them — so a workspace in any of
// those silently kept time on the device clock.
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../trace/trace_logger.dart';
import 'notification_service.dart';
import 'notification_taps.dart';

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

  /// #2559 C2 — no permission prompt at start: Darwin is told not to ask
  /// on initialize, and Android's request moved to [requestPermission],
  /// which runs only after the person deliberately asked for
  /// notifications. A tapped notification's payload goes to [taps].
  static Future<LocalNotificationService> initialize({
    NotificationTaps? taps,
  }) async {
    tzdata.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    void onResponse(NotificationResponse response) =>
        _handOn(taps, response.id, response.payload);
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await plugin.initialize(
        settings: const InitializationSettings(
          // Status-bar small icons are alpha-masked: the full-color
          // launcher mipmap rendered as a grey square (#219). Dedicated
          // white glyph — kept from the release shrinker by res/raw/
          // keep.xml (#442: it was stripped and this threw invalid_icon
          // on EVERY release boot, killing all notifications silently).
          android: AndroidInitializationSettings('@drawable/ic_stat_deskilo'),
          iOS: darwin,
          macOS: darwin,
        ),
        onDidReceiveNotificationResponse: onResponse,
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
          iOS: darwin,
          macOS: darwin,
        ),
        onDidReceiveNotificationResponse: onResponse,
      );
    }
    // The tap that launched the app.
    try {
      final launch = await plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null) {
        onResponse(response);
      }
    } on Object catch (e, st) {
      TraceLogger.instance.warn('notifications', 'launch details unreadable',
          error: e, stackTrace: st);
    }
    return LocalNotificationService(plugin);
  }

  static void _handOn(NotificationTaps? taps, int? id, String? payload) {
    final data = NotificationTap.decodePayload(payload);
    if (taps == null || data == null) return;
    taps.add(NotificationTap(id: 'local:$id:$payload', data: data));
  }

  @override
  Future<bool?> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
            alert: true, badge: true, sound: true);
      }
      return await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } on Object catch (e, st) {
      // Best-effort (#442): a failed request leaves the app usable.
      debugPrint('notification permission request failed: $e\n$st');
      TraceLogger.instance.warn(
          'notifications', 'permission request failed (non-fatal)',
          error: e, stackTrace: st);
      return null;
    }
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
    } on Object catch (e, st) {
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
    } on Object catch (e, st) {
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

  @override
  Future<void> syncPendingNotifications(List<PendingNotice> notices) async {
    try {
      // #2559 C2 — no automatic re-ask (#436 asked here): the prompt is
      // the person's deliberate choice, in Settings.
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
    } on Object catch (e, st) {
      debugPrint('pending notification sync failed: $e\n$st');
      TraceLogger.instance.error(
          'notifications', 'pending notification sync failed',
          error: e, stackTrace: st);
    }
  }

  @override
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch & 0x3fffffff,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: _pushChannel),
        payload: payload,
      );
    } on Object catch (e, st) {
      debugPrint('push notification display failed: $e\n$st');
      TraceLogger.instance.error(
          'notifications', 'push notification display failed',
          error: e, stackTrace: st);
    }
  }
}
