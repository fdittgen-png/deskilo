// SPDX-License-Identifier: MIT
import 'package:deskilo/core/notifications/notification_service.dart';

/// Captures reminder scheduling for assertions.
class FakeNotificationService implements NotificationService {
  final rescheduleCalls = <List<ReminderRequest>>[];

  List<ReminderRequest> get lastReminders =>
      rescheduleCalls.isEmpty ? const [] : rescheduleCalls.last;

  @override
  Future<void> rescheduleCheckInReminders(
    List<ReminderRequest> reminders,
  ) async {
    rescheduleCalls.add(reminders);
  }

  final shown = <({String title, String body})>[];

  @override
  Future<void> showNow({required String title, required String body}) async {
    shown.add((title: title, body: body));
  }
}
