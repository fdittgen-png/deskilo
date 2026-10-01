// SPDX-License-Identifier: AGPL-3.0-or-later
import 'notification_service.dart';

/// #2015 — local notifications must not hold the first frame. The app
/// starts with this service; until the platform service is [attach]ed it
/// answers like the no-op one, but keeps the LATEST reminder schedule and
/// pending-notice mirror and replays them on attach, so nothing asked for
/// during start-up is lost. A failed platform init never attaches, which
/// leaves the honest no-op behaviour (`notificationsEnabled` → false).
class DeferredNotificationService implements NotificationService {
  NotificationService? _inner;
  List<ReminderRequest>? _reminders;
  List<PendingNotice>? _notices;

  bool get attached => _inner != null;

  /// Hands over to [service] once, replaying what was asked meanwhile.
  Future<void> attach(NotificationService service) async {
    if (_inner != null) return;
    _inner = service;
    final reminders = _reminders;
    final notices = _notices;
    _reminders = null;
    _notices = null;
    if (reminders != null) await service.rescheduleCheckInReminders(reminders);
    if (notices != null) await service.syncPendingNotifications(notices);
  }

  @override
  Future<void> rescheduleCheckInReminders(List<ReminderRequest> reminders) {
    final inner = _inner;
    if (inner != null) return inner.rescheduleCheckInReminders(reminders);
    _reminders = List.of(reminders);
    return Future.value();
  }

  @override
  Future<void> syncPendingNotifications(List<PendingNotice> notices) {
    final inner = _inner;
    if (inner != null) return inner.syncPendingNotifications(notices);
    _notices = List.of(notices);
    return Future.value();
  }

  @override
  Future<void> showNow({required String title, required String body}) =>
      _inner?.showNow(title: title, body: body) ?? Future.value();

  @override
  Future<bool?> notificationsEnabled() =>
      _inner?.notificationsEnabled() ?? Future.value(false);
}
