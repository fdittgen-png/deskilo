// SPDX-License-Identifier: 0BSD

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
/// One pending confirmation, ready to display (#432).
typedef PendingNotice = ({String id, String title, String body});

abstract class NotificationService {
  /// Replaces all scheduled check-in reminders with [reminders].
  Future<void> rescheduleCheckInReminders(List<ReminderRequest> reminders);

  /// Shows an immediate notification (#72 push pings).
  Future<void> showNow({required String title, required String body});

  /// Whether the SYSTEM currently lets this app post notifications
  /// (#436 diagnostics) — null when the platform cannot say.
  Future<bool?> notificationsEnabled();

  /// One ACTIVE notification per pending confirmation (#432): launchers
  /// that ignore app-set badge numbers (Samsung One UI) show the COUNT
  /// OF ACTIVE NOTIFICATIONS as the icon number — the Gmail-style
  /// badge. Reconciled by stable per-event ids: new pendings appear,
  /// resolved ones vanish.
  Future<void> syncPendingNotifications(List<PendingNotice> notices);
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

  @override
  Future<void> syncPendingNotifications(List<PendingNotice> notices) async {}

  // #442: the Noop fallback means notifications are DEAD this session —
  // report false so the Settings warning tile fires instead of silence.
  @override
  Future<bool?> notificationsEnabled() async => false;
}
