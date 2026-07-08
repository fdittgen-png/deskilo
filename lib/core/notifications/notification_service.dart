// SPDX-License-Identifier: MIT

/// A scheduled local reminder (spec §4.3 check-in reminder).
class ReminderRequest {
  const ReminderRequest({
    required this.reservationId,
    required this.remindAt,
    required this.title,
    required this.body,
  });

  final String reservationId;
  final DateTime remindAt;
  final String title;
  final String body;
}

/// Local-notification boundary. The UnifiedPush transport (#72, v1.1)
/// will implement the same surface for closed-app delivery.
abstract class NotificationService {
  /// Replaces all scheduled check-in reminders with [reminders].
  Future<void> rescheduleCheckInReminders(List<ReminderRequest> reminders);

  /// Shows an immediate notification (#72 push pings).
  Future<void> showNow({required String title, required String body});
}

/// Fallback when platform notification init fails (#86): the app must boot
/// and work fully without reminders rather than not boot at all.
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> rescheduleCheckInReminders(
    List<ReminderRequest> reminders,
  ) async {}

  @override
  Future<void> showNow({required String title, required String body}) async {}
}
