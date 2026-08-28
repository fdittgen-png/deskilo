// SPDX-License-Identifier: 0BSD
//
// #614 — two reminder resyncs can overlap (realtime bursts): iterating
// the live reminder-id set across awaits threw
// ConcurrentModificationError, which the best-effort catch downgraded
// to a logged ERROR — and silently dropped the rest of that resync's
// reminders. The sweep now snapshots-and-clears before its first await.
//
// The real FlutterLocalNotificationsPlugin is a singleton with no
// generative constructor, so the interleave runs through its REAL
// Android method channel with a mocked handler that yields on every
// call — genuine suspension points, like the platform side.
import 'package:deskilo/core/notifications/local_notification_service.dart';
import 'package:deskilo/core/notifications/notification_service.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

ReminderRequest _reminder(String id) => ReminderRequest(
      reservationId: id,
      title: 'Check-in',
      body: 'Your seat awaits',
      remindAt: DateTime.now().add(const Duration(hours: 1)),
    );

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('overlapping resyncs complete without dropping reminders',
      () async {
    tzdata.initializeTimeZones();
    final calls = <String>[];
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      // Yield so overlapping sweeps genuinely interleave.
      await Future<void>.delayed(Duration.zero);
      calls.add(call.method);
      if (call.method == 'initialize') return true;
      return null;
    });
    addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel, null));

    // A bare test VM never runs the plugin registrar — install the
    // Android implementation by hand so the real dispatch runs.
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final service = LocalNotificationService(plugin);

    // Seed a first generation so the next sweeps have ids to cancel.
    await service
        .rescheduleCheckInReminders([_reminder('a'), _reminder('b')]);
    expect(calls.where((c) => c == 'zonedSchedule').length, 2);

    final errorsBefore = TraceLogger.instance.entries
        .where((e) => e.message == 'reminder scheduling failed')
        .length;

    // Two overlapping sweeps — pre-#614 the second's clear() blew up
    // the first's live-set iteration.
    await Future.wait([
      service.rescheduleCheckInReminders([_reminder('c'), _reminder('d')]),
      service.rescheduleCheckInReminders([_reminder('e'), _reminder('f')]),
    ]);

    expect(
      calls.where((c) => c == 'zonedSchedule').length,
      6,
      reason: 'both overlapping sweeps must schedule all their reminders',
    );
    final errorsAfter = TraceLogger.instance.entries
        .where((e) => e.message == 'reminder scheduling failed')
        .length;
    expect(errorsAfter, errorsBefore,
        reason: 'no sweep may die on a concurrent-modification error');
  });
}
