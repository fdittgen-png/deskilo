// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/notification_filter_store.dart';
import '../../../core/time/clock.dart';
import '../domain/notification_feed.dart';

part 'notification_filter_providers.g.dart';

/// The bell screen's filter, loaded from disk so the LAST choice greets
/// the user — across restarts (#581). Every change persists eagerly.
@Riverpod(keepAlive: true)
class NotificationFilter extends _$NotificationFilter {
  @override
  Future<NotificationFilterState> build() async =>
      NotificationFilterState.decode(
        await ref.watch(notificationFilterStoreProvider).readFilter(),
      );

  Future<void> _set(NotificationFilterState next) async {
    state = AsyncData(next);
    await ref.read(notificationFilterStoreProvider).writeFilter(
          next.encode(),
        );
  }

  Future<void> toggleCategory(NotificationCategory category) async {
    final current = state.value ?? const NotificationFilterState();
    final next = Set.of(current.categories);
    if (!next.remove(category)) next.add(category);
    await _set(current.copyWith(categories: next));
  }

  Future<void> clearCategories() async {
    final current = state.value ?? const NotificationFilterState();
    await _set(current.copyWith(categories: const {}));
  }

  Future<void> setRead(ReadFilter read) async {
    final current = state.value ?? const NotificationFilterState();
    await _set(current.copyWith(read: read));
  }

  Future<void> toggleSort() async {
    final current = state.value ?? const NotificationFilterState();
    await _set(current.copyWith(
      sort: current.sort == FeedSort.newestFirst
          ? FeedSort.oldestFirst
          : FeedSort.newestFirst,
    ));
  }
}

/// The events-seen cutoff for THIS visit: exposes the stamp from the
/// PREVIOUS bell open (what "new" is measured against) and, on
/// [markOpened], writes the current instant for the next visit — the
/// exposed value deliberately stays old so "new" rows do not vanish
/// mid-visit.
@Riverpod(keepAlive: true)
class EventsSeenCutoff extends _$EventsSeenCutoff {
  @override
  Future<DateTime?> build() =>
      ref.watch(notificationFilterStoreProvider).readEventsSeen();

  Future<void> markOpened() async {
    await ref.read(notificationFilterStoreProvider).writeEventsSeen(
          ref.read(clockProvider).now(),
        );
  }
}
