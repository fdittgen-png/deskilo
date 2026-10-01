// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2015 — notifications never hold the first frame: until the platform
// service attaches, the deferred one answers as the no-op does and keeps
// the latest schedule and pending mirror, replayed once on attach.
import 'package:deskilo/core/notifications/deferred_notification_service.dart';
import 'package:deskilo/core/notifications/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recording implements NotificationService {
  final schedules = <List<ReminderRequest>>[];
  final syncs = <List<PendingNotice>>[];
  final shown = <String>[];
  @override
  Future<void> rescheduleCheckInReminders(List<ReminderRequest> r) async =>
      schedules.add(r);
  @override
  Future<void> syncPendingNotifications(List<PendingNotice> n) async =>
      syncs.add(n);
  @override
  Future<void> showNow({required String title, required String body}) async =>
      shown.add(title);
  @override
  Future<bool?> notificationsEnabled() async => true;
}

void main() {
  test('before attach: no-op answers, the latest asks are kept and '
      'replayed once', () async {
    final deferred = DeferredNotificationService();
    expect(await deferred.notificationsEnabled(), isFalse);
    await deferred.rescheduleCheckInReminders(const []);
    await deferred.rescheduleCheckInReminders(const []);
    await deferred.syncPendingNotifications(const []);
    await deferred.showNow(title: 'lost', body: '');

    final platform = _Recording();
    await deferred.attach(platform);
    expect(platform.schedules, hasLength(1), reason: 'only the latest');
    expect(platform.syncs, hasLength(1));
    expect(platform.shown, isEmpty);

    await deferred.attach(_Recording());
    await deferred.showNow(title: 'now', body: '');
    expect(platform.shown, ['now'], reason: 'the first attach wins');
    expect(await deferred.notificationsEnabled(), isTrue);
  });

  test('never attached (a failed platform init): honest no-op', () async {
    final deferred = DeferredNotificationService();
    expect(deferred.attached, isFalse);
    expect(await deferred.notificationsEnabled(), isFalse);
  });
}
