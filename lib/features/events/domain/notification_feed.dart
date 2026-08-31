// SPDX-License-Identifier: 0BSD
//
// #581 — ONE mixed, date-sorted notification feed. Messages (member
// notes) and workspace events used to live in two separate blocks; now
// both become [FeedItem]s filtered by CATEGORY × READ STATE and sorted
// chronologically. All of it is pure so the exact mixing/filter rules
// are unit-testable without a widget tree.
import '../../workspace/domain/member_note.dart';
import 'workspace_event.dart';

/// What kind of notification a feed row is — the user-facing filter
/// axis. Coarser than [EventType] on purpose: twelve type chips were
/// noise, five categories are a choice.
enum NotificationCategory {
  messages('messages'),
  reservations('reservations'),
  checkIns('check_ins'),
  money('money'),
  members('members');

  const NotificationCategory(this.wire);

  /// Stable id used in the persisted filter — enum NAMES may be
  /// renamed by a refactor, the stored preference must survive it.
  final String wire;

  static NotificationCategory? fromWire(String value) {
    for (final category in values) {
      if (category.wire == value) return category;
    }
    return null;
  }
}

/// The read-state axis: everything, only new, only already-read.
enum ReadFilter { all, unread, read }

/// The optional regrouping axis (#598): the flat feed can fold into
/// groups by category, calendar day or acting member. `none` is the
/// default — exactly the pre-#598 flat list.
enum FeedGrouping { none, type, date, user }

/// Sort direction of the mixed feed.
enum FeedSort { newestFirst, oldestFirst }

/// The persisted filter choice (#581): survives app restarts so the
/// bell opens exactly the way it was left. Empty [categories] = all.
class NotificationFilterState {
  const NotificationFilterState({
    this.categories = const {},
    this.read = ReadFilter.all,
    this.sort = FeedSort.newestFirst,
    this.grouping = FeedGrouping.none,
  });

  final Set<NotificationCategory> categories;
  final ReadFilter read;
  final FeedSort sort;
  final FeedGrouping grouping;

  NotificationFilterState copyWith({
    Set<NotificationCategory>? categories,
    ReadFilter? read,
    FeedSort? sort,
    FeedGrouping? grouping,
  }) =>
      NotificationFilterState(
        categories: categories ?? this.categories,
        read: read ?? this.read,
        sort: sort ?? this.sort,
        grouping: grouping ?? this.grouping,
      );

  /// Wire form: `messages,reservations|unread|newestFirst|type`.
  String encode() => [
        categories.map((c) => c.wire).join(','),
        read.name,
        sort.name,
        grouping.name,
      ].join('|');

  /// Tolerant of anything: an unknown or mangled stored value falls
  /// back to the default rather than crashing the bell screen.
  static NotificationFilterState decode(String? raw) {
    if (raw == null || raw.isEmpty) return const NotificationFilterState();
    final parts = raw.split('|');
    final categories = <NotificationCategory>{
      for (final wire in parts.first.split(','))
        ?NotificationCategory.fromWire(wire),
    };
    final read = parts.length > 1
        ? ReadFilter.values
                .where((r) => r.name == parts[1])
                .firstOrNull ??
            ReadFilter.all
        : ReadFilter.all;
    final sort = parts.length > 2
        ? FeedSort.values.where((s) => s.name == parts[2]).firstOrNull ??
            FeedSort.newestFirst
        : FeedSort.newestFirst;
    // A pre-#598 stored value has three parts — it simply stays flat.
    final grouping = parts.length > 3
        ? FeedGrouping.values
                .where((g) => g.name == parts[3])
                .firstOrNull ??
            FeedGrouping.none
        : FeedGrouping.none;
    return NotificationFilterState(
      categories: categories,
      read: read,
      sort: sort,
      grouping: grouping,
    );
  }
}

/// The category a workspace event belongs to. A check-in/check-out is a
/// reservation MODIFICATION whose payload status moved to
/// checked_in/completed (0007's trigger records the new status), so the
/// payload — not the type — distinguishes it.
NotificationCategory categoryOfEvent(WorkspaceEvent event) {
  switch (event.type) {
    case EventType.reservation:
    case EventType.spaceReservation:
      final status = event.payload['status'] as String?;
      if (status == 'checked_in' || status == 'completed') {
        return NotificationCategory.checkIns;
      }
      return NotificationCategory.reservations;
    case EventType.reservationDelete:
    case EventType.quota:
      return NotificationCategory.reservations;
    case EventType.payment:
    case EventType.expenseSchedule:
    case EventType.expense:
    case EventType.adjustment:
    case EventType.serviceCharge:
    case EventType.invoicePayment:
    case EventType.invoiceWriteoff:
    case EventType.invoiceReminder:
    case EventType.priceNegotiation:
      return NotificationCategory.money;
    case EventType.roleChange:
    case EventType.memberJoin:
      return NotificationCategory.members;
  }
}

/// One row of the mixed feed. [unread] is per-device: notes ride the
/// server read receipts (#539), events compare against the last time
/// this device opened the bell.
sealed class FeedItem {
  const FeedItem({
    required this.at,
    required this.unread,
    required this.category,
  });

  final DateTime at;
  final bool unread;
  final NotificationCategory category;
}

class NoteFeedItem extends FeedItem {
  const NoteFeedItem(this.note, {required super.at, required super.unread})
      : super(category: NotificationCategory.messages);

  final MemberNote note;
}

class EventFeedItem extends FeedItem {
  const EventFeedItem(
    this.event, {
    required super.at,
    required super.unread,
    required super.category,
  });

  final WorkspaceEvent event;
}

/// Mixes notes and events into one date-sorted feed under the user's
/// filter. [eventsSeenBefore] is the previous bell-open stamp: events
/// created after it count as unread; a device that never opened the
/// bell (null) treats history as read — a first launch must not shout
/// "300 new".
List<FeedItem> buildNotificationFeed({
  required List<WorkspaceEvent> events,
  required List<MemberNote> notes,
  required Set<String> unreadNoteIds,
  required DateTime? eventsSeenBefore,
  required NotificationFilterState filter,
}) {
  final items = <FeedItem>[
    for (final note in notes)
      NoteFeedItem(
        note,
        at: note.createdAt,
        unread: unreadNoteIds.contains(note.id),
      ),
    for (final event in events)
      EventFeedItem(
        event,
        at: event.createdAt,
        unread: eventsSeenBefore != null &&
            event.createdAt.isAfter(eventsSeenBefore),
        category: categoryOfEvent(event),
      ),
  ];
  final filtered = items.where((item) {
    if (filter.categories.isNotEmpty &&
        !filter.categories.contains(item.category)) {
      return false;
    }
    return switch (filter.read) {
      ReadFilter.all => true,
      ReadFilter.unread => item.unread,
      ReadFilter.read => !item.unread,
    };
  }).toList()
    ..sort(
      (a, b) => filter.sort == FeedSort.newestFirst
          ? b.at.compareTo(a.at)
          : a.at.compareTo(b.at),
    );
  return filtered;
}

/// One fold of the grouped feed (#598). [key] is what the group IS —
/// a [NotificationCategory] (type), a local-midnight [DateTime] (date)
/// or a member id [String] (user); [id] is its stable widget-key form.
class FeedGroup {
  const FeedGroup({required this.id, required this.key, required this.items});

  final String id;
  final Object key;
  final List<FeedItem> items;
}

/// The acting member of a row: who sent the note / who did the thing.
String feedItemActor(FeedItem item) => switch (item) {
      NoteFeedItem(:final note) => note.fromMemberId,
      EventFeedItem(:final event) => event.actorMemberId,
    };

/// Folds an already-sorted feed into groups (#598). Group order follows
/// first occurrence, so the date sort keeps steering the screen; within
/// a group the feed order survives untouched. `none` returns ONE group
/// carrying the whole feed — the caller just skips the headers.
List<FeedGroup> groupFeed(List<FeedItem> feed, FeedGrouping grouping) {
  if (grouping == FeedGrouping.none) {
    return [FeedGroup(id: 'all', key: 'all', items: feed)];
  }
  (String, Object) keyOf(FeedItem item) {
    switch (grouping) {
      case FeedGrouping.type:
        return (item.category.wire, item.category);
      case FeedGrouping.date:
        final local = item.at.toLocal();
        final day = DateTime(local.year, local.month, local.day);
        return (day.toIso8601String().split('T').first, day);
      case FeedGrouping.user:
        final actor = feedItemActor(item);
        return (actor, actor);
      case FeedGrouping.none:
        return ('all', 'all');
    }
  }

  final groups = <String, FeedGroup>{};
  for (final item in feed) {
    final (id, key) = keyOf(item);
    (groups[id] ??= FeedGroup(id: id, key: key, items: []))
        .items
        .add(item);
  }
  return groups.values.toList();
}
