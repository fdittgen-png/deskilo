// SPDX-License-Identifier: 0BSD
//
// #581 — the mixed notification feed: messages and events interleave
// date-sorted, filtered by category × read state, and the filter
// choice survives an app restart via the persisted store.
import 'package:deskilo/core/storage/notification_filter_store.dart';
import 'package:deskilo/features/events/domain/notification_feed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/notification_filter_providers.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvent _event(
  String id,
  DateTime at, {
  EventType type = EventType.reservation,
  Map<String, Object?> payload = const {},
}) =>
    WorkspaceEvent(
      id: id,
      workspaceId: 'ws-1',
      type: type,
      action: EventAction.created,
      status: EventStatus.applied,
      actorMemberId: 'member-1',
      subjectMemberId: 'member-1',
      payload: payload,
      createdAt: at,
    );

MemberNote _note(String id, DateTime at) => MemberNote(
      id: id,
      workspaceId: 'ws-1',
      fromMemberId: 'member-2',
      toMemberId: 'member-1',
      body: 'hello',
      createdAt: at,
    );

void main() {
  final t0 = DateTime.utc(2026, 5, 13, 8);

  test('notes and events interleave strictly by date, newest first', () {
    final feed = buildNotificationFeed(
      events: [
        _event('e-old', t0),
        _event('e-new', t0.add(const Duration(hours: 4))),
      ],
      notes: [_note('n-mid', t0.add(const Duration(hours: 2)))],
      unreadNoteIds: const {},
      eventsSeenBefore: null,
      filter: const NotificationFilterState(),
    );
    expect(feed, hasLength(3));
    expect(feed[0], isA<EventFeedItem>());
    expect((feed[0] as EventFeedItem).event.id, 'e-new');
    expect(feed[1], isA<NoteFeedItem>());
    expect((feed[2] as EventFeedItem).event.id, 'e-old');

    final oldestFirst = buildNotificationFeed(
      events: [
        _event('e-old', t0),
        _event('e-new', t0.add(const Duration(hours: 4))),
      ],
      notes: [_note('n-mid', t0.add(const Duration(hours: 2)))],
      unreadNoteIds: const {},
      eventsSeenBefore: null,
      filter:
          const NotificationFilterState(sort: FeedSort.oldestFirst),
    );
    expect((oldestFirst.first as EventFeedItem).event.id, 'e-old');
  });

  test('a check-in is its own category even though the DB records it as '
      'a reservation modification', () {
    expect(
      categoryOfEvent(_event('e', t0, payload: {'status': 'checked_in'})),
      NotificationCategory.checkIns,
    );
    expect(
      categoryOfEvent(_event('e', t0, payload: {'status': 'completed'})),
      NotificationCategory.checkIns,
    );
    expect(
      categoryOfEvent(_event('e', t0, payload: {'status': 'reserved'})),
      NotificationCategory.reservations,
    );
    expect(
      categoryOfEvent(_event('e', t0, type: EventType.payment)),
      NotificationCategory.money,
    );
    expect(
      categoryOfEvent(_event('e', t0, type: EventType.memberJoin)),
      NotificationCategory.members,
    );
  });

  test('category filter: selected categories combine, empty = all', () {
    final feed = buildNotificationFeed(
      events: [
        _event('res', t0),
        _event('pay', t0, type: EventType.payment),
      ],
      notes: [_note('n', t0)],
      unreadNoteIds: const {},
      eventsSeenBefore: null,
      filter: const NotificationFilterState(categories: {
        NotificationCategory.messages,
        NotificationCategory.money,
      }),
    );
    expect(feed, hasLength(2));
    expect(feed.any((i) => i is NoteFeedItem), isTrue);
    expect(
      feed.whereType<EventFeedItem>().single.event.id,
      'pay',
    );
  });

  test('read filter: events are new after the previous bell-open stamp; '
      'a device that never opened the bell treats history as read', () {
    final cutoff = t0.add(const Duration(hours: 1));
    final unread = buildNotificationFeed(
      events: [
        _event('before', t0),
        _event('after', t0.add(const Duration(hours: 2))),
      ],
      notes: [_note('n-unread', t0), _note('n-read', t0)],
      unreadNoteIds: const {'n-unread'},
      eventsSeenBefore: cutoff,
      filter: const NotificationFilterState(read: ReadFilter.unread),
    );
    expect(
      unread.map((i) => switch (i) {
        NoteFeedItem(:final note) => note.id,
        EventFeedItem(:final event) => event.id,
      }),
      unorderedEquals(['n-unread', 'after']),
    );

    final firstLaunch = buildNotificationFeed(
      events: [_event('before', t0)],
      notes: const [],
      unreadNoteIds: const {},
      eventsSeenBefore: null,
      filter: const NotificationFilterState(read: ReadFilter.unread),
    );
    expect(firstLaunch, isEmpty,
        reason: 'a fresh install must not shout "300 new"');
  });

  test('filter state round-trips through its wire form, and garbage '
      'decodes to the default instead of crashing', () {
    const state = NotificationFilterState(
      categories: {
        NotificationCategory.checkIns,
        NotificationCategory.messages,
      },
      read: ReadFilter.read,
      sort: FeedSort.oldestFirst,
    );
    final back = NotificationFilterState.decode(state.encode());
    expect(back.categories, state.categories);
    expect(back.read, state.read);
    expect(back.sort, state.sort);

    for (final garbage in [null, '', 'wat', 'a,b|c|d|e', '|||']) {
      final decoded = NotificationFilterState.decode(garbage);
      expect(decoded.categories, isEmpty);
      expect(decoded.read, ReadFilter.all);
      expect(decoded.sort, FeedSort.newestFirst);
    }
  });

  group('feed regrouping (#598)', () {
    List<FeedItem> feedOf({
      List<WorkspaceEvent> events = const [],
      List<MemberNote> notes = const [],
    }) =>
        buildNotificationFeed(
          events: events,
          notes: notes,
          unreadNoteIds: const {},
          eventsSeenBefore: null,
          filter: const NotificationFilterState(),
        );

    test('groupFeed by type folds by category, groups in feed order', () {
      final feed = feedOf(
        events: [
          _event('res-1', t0.add(const Duration(hours: 3))),
          _event('pay', t0.add(const Duration(hours: 2)),
              type: EventType.payment),
          _event('res-2', t0),
        ],
      );
      final groups = groupFeed(feed, FeedGrouping.type);
      expect(groups.map((g) => g.id),
          ['reservations', 'money']); // first-occurrence order
      expect(groups.first.key, NotificationCategory.reservations);
      expect(
        groups.first.items
            .map((i) => (i as EventFeedItem).event.id),
        ['res-1', 'res-2'],
      );
    });

    test('groupFeed by date folds by local calendar day', () {
      final feed = feedOf(
        events: [
          _event('day2-a', DateTime.utc(2026, 5, 14, 10)),
          _event('day2-b', DateTime.utc(2026, 5, 14, 8)),
          _event('day1', DateTime.utc(2026, 5, 13, 9)),
        ],
      );
      final groups = groupFeed(feed, FeedGrouping.date);
      expect(groups, hasLength(2));
      expect(groups.first.items, hasLength(2));
      final day = groups.first.key as DateTime;
      final local = DateTime.utc(2026, 5, 14, 10).toLocal();
      expect((day.year, day.month, day.day),
          (local.year, local.month, local.day));
    });

    test('groupFeed by user folds by acting member — note sender and '
        'event actor', () {
      final feed = feedOf(
        events: [_event('e', t0)], // actor member-1
        notes: [_note('n', t0.add(const Duration(minutes: 1)))],
      );
      final groups = groupFeed(feed, FeedGrouping.user);
      expect(groups.map((g) => g.id), ['member-2', 'member-1']);
      expect(feedItemActor(feed.first), 'member-2');
    });

    test('grouping none returns ONE group carrying the flat feed', () {
      final feed = feedOf(events: [_event('e', t0)]);
      final groups = groupFeed(feed, FeedGrouping.none);
      expect(groups, hasLength(1));
      expect(groups.single.items, same(feed));
    });

    test('the grouping choice rides the wire form; a pre-#598 stored '
        'value decodes to flat', () {
      const state = NotificationFilterState(grouping: FeedGrouping.date);
      expect(
        NotificationFilterState.decode(state.encode()).grouping,
        FeedGrouping.date,
      );
      expect(
        NotificationFilterState.decode('|all|newestFirst').grouping,
        FeedGrouping.none,
      );
      expect(
        NotificationFilterState.decode('|all|newestFirst|wat').grouping,
        FeedGrouping.none,
      );
    });
  });

  test('the filter provider loads the LAST persisted choice on build — '
      'the restart survival #581 asks for', () async {
    final store = InMemoryNotificationFilterStore()
      ..filter = const NotificationFilterState(
        categories: {NotificationCategory.reservations},
        read: ReadFilter.unread,
      ).encode();
    final container = ProviderContainer(overrides: [
      notificationFilterStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    final loaded =
        await container.read(notificationFilterProvider.future);
    expect(loaded.categories, {NotificationCategory.reservations});
    expect(loaded.read, ReadFilter.unread);

    // A change persists eagerly — the next session's build reads it.
    await container
        .read(notificationFilterProvider.notifier)
        .setRead(ReadFilter.all);
    expect(
      NotificationFilterState.decode(store.filter).read,
      ReadFilter.all,
    );
  });
}
