// SPDX-License-Identifier: 0BSD
// #1094 — the shell schedules check-in reminders best-effort, and
// best-effort still has to be OBSERVABLE. The call was unawaited with no
// catch, so a failure completed into nothing: the member simply never
// got the reminder, and no trace point said why. #614 already cost this
// subsystem one real reminder-loss bug.
import 'package:deskilo/core/notifications/notification_service.dart';
import 'package:deskilo/core/notifications/reminder_sync.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingService implements NotificationService {
  int calls = 0;

  @override
  Future<void> rescheduleCheckInReminders(List<ReminderRequest> r) async {
    calls++;
    throw StateError('no notification plugin on this platform');
  }

  @override
  Future<void> showNow({required String title, required String body}) async {}

  @override
  Future<bool?> notificationsEnabled() async => true;

  @override
  Future<void> syncPendingNotifications(List<PendingNotice> n) async {}
}

void main() {
  setUp(() => TraceLogger.instance = TraceLogger());

  test('a failing reschedule is traced, not swallowed', () async {
    final service = _ThrowingService();

    await scheduleCheckInReminders(service, const []);

    expect(service.calls, 1);
    final traced = TraceLogger.instance.entries
        .where((e) => e.area == 'notifications')
        .toList();
    expect(traced, isNotEmpty,
        reason: 'a reminder that never scheduled must leave a breadcrumb');
    expect('${traced.first.error}', contains('no notification plugin'));
  });

  test('a successful reschedule traces nothing', () async {
    final service = _RecordingService();
    await scheduleCheckInReminders(service, const []);
    expect(service.calls, 1);
    expect(TraceLogger.instance.entries, isEmpty);
  });
}

class _RecordingService implements NotificationService {
  int calls = 0;

  @override
  Future<void> rescheduleCheckInReminders(List<ReminderRequest> r) async {
    calls++;
  }

  @override
  Future<void> showNow({required String title, required String body}) async {}

  @override
  Future<bool?> notificationsEnabled() async => true;

  @override
  Future<void> syncPendingNotifications(List<PendingNotice> n) async {}
}
