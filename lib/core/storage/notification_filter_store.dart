// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'prefs_stores.dart';

part 'notification_filter_store.g.dart';

/// Per-device persistence for the bell screen (#581): the last filter
/// choice (so the bell reopens exactly as it was left, across app
/// restarts) and the last time the bell was OPENED (events newer than
/// that stamp count as unread — notes have server read receipts,
/// events do not).
abstract class NotificationFilterStore {
  Future<String?> readFilter();
  Future<void> writeFilter(String encoded);
  Future<DateTime?> readEventsSeen();
  Future<void> writeEventsSeen(DateTime value);
}

class PrefsNotificationFilterStore implements NotificationFilterStore {
  const PrefsNotificationFilterStore();

  static const _filter = PrefsStringStore('notification_filter');
  static const _seen = PrefsStringStore('events_seen_until');

  @override
  Future<String?> readFilter() => _filter.read();

  @override
  Future<void> writeFilter(String encoded) => _filter.write(encoded);

  @override
  Future<DateTime?> readEventsSeen() async =>
      DateTime.tryParse(await _seen.read() ?? '');

  @override
  Future<void> writeEventsSeen(DateTime value) =>
      _seen.write(value.toUtc().toIso8601String());
}

/// Test double — also handy for platforms without SharedPreferences.
class InMemoryNotificationFilterStore implements NotificationFilterStore {
  String? filter;
  DateTime? eventsSeen;

  @override
  Future<String?> readFilter() async => filter;
  @override
  Future<void> writeFilter(String encoded) async => filter = encoded;
  @override
  Future<DateTime?> readEventsSeen() async => eventsSeen;
  @override
  Future<void> writeEventsSeen(DateTime value) async => eventsSeen = value;
}

@Riverpod(keepAlive: true)
NotificationFilterStore notificationFilterStore(Ref ref) =>
    const PrefsNotificationFilterStore();
