// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C2 -- My reservations composed across every host my account names.
// Each host is a slot with its own state (reading, read, failed); one that
// fails or cannot be reached never hides the others. The pages of all
// slots merge by start time, and an item is shown only up to the horizon:
// the last row of every slot that still has more, so a later page of a
// slower host can never land above what is already on screen. Pure Dart.
//
// C3: a composition walks one way (a past period newest first); the tabs
// (Upcoming, Past, Cancelled) and the source filter select from it; a row
// an action changed is replaced in place; a card's times are its
// workspace's wall clock, with the zone named when it is not the device's.
//
// C4: the cache identity is (principal, installation, query): a
// composition names the account it was read for, a slot its host, the
// family its query. A host read again keeps what it showed before, marked
// stale, through an outage; a refusal that withdraws it, a host no longer
// named and another account purge it.
import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/i18n/time_zones.dart';
import 'my_reservations.dart';
import 'reservation.dart';

/// Where one host's read stands.
enum MyReservationsSlotState { reading, read, failed }

/// One host's part of the composition: its pages so far, where the next one
/// starts, and why the last read did not come.
@immutable
class MyReservationsSlot {
  const MyReservationsSlot._({
    required this.source,
    required this.state,
    this.items = const [],
    this.next,
    this.hasMore = false,
    this.zones = const {},
    this.loadingMore = false,
    this.failure,
    this.stale = false,
  });

  /// The first page of [source] is being read.
  const MyReservationsSlot.reading(MyReservationsSource source)
      : this._(source: source, state: MyReservationsSlotState.reading);

  /// The first page of [source] did not come: [failure] says why.
  const MyReservationsSlot.failed(MyReservationsSource source, Object failure)
      : this._(
          source: source,
          state: MyReservationsSlotState.failed,
          failure: failure,
        );

  /// #2553 C4 -- [prior]'s host read again: what it showed stays, marked
  /// stale, until the host answers; a plain first read when it showed
  /// nothing.
  factory MyReservationsSlot.refreshing(MyReservationsSlot prior) =>
      prior.items.isEmpty
          ? MyReservationsSlot.reading(prior.source)
          : MyReservationsSlot._(
              source: prior.source,
              state: MyReservationsSlotState.reading,
              items: prior.items,
              next: prior.next,
              hasMore: prior.hasMore,
              zones: prior.zones,
              stale: true,
            );

  /// The first page of [source].
  factory MyReservationsSlot.firstPage(
    MyReservationsSource source,
    MyReservationsPage page,
  ) =>
      MyReservationsSlot._(
        source: source,
        state: MyReservationsSlotState.read,
        items: page.items,
        next: page.next,
        hasMore: page.hasMore,
        zones: page.zones,
      );

  final MyReservationsSource source;
  final MyReservationsSlotState state;
  final List<MyReservationItem> items;
  final MyReservationsCursor? next;
  final bool hasMore;
  final Map<String, String> zones;
  final bool loadingMore;

  /// For a failed slot, why its first page did not come; for a read one,
  /// why its last further page did not (its pages stay).
  final Object? failure;

  /// #2553 C4 -- [items] are what the host answered before, kept through an
  /// outage while it is read again or does not answer.
  final bool stale;

  /// #2553 C4 -- this slot's bookings for the host as [source] names it
  /// now, read again: a workspace no longer named loses its rows.
  MyReservationsSlot carriedTo(MyReservationsSource source) {
    final kept = [
      for (final i in items)
        if (source.workspaceIds.contains(i.workspaceId)) i,
    ];
    return MyReservationsSlot.refreshing(MyReservationsSlot._(
      source: source,
      state: state,
      items: List.unmodifiable(kept),
      next: kept.length == items.length ? next : null,
      hasMore: kept.length == items.length && hasMore,
      zones: zones,
    ));
  }

  /// #2553 C4 -- the host did not answer the read again: what it showed
  /// stays, stale, beside [error].
  MyReservationsSlot outage(Object error) => MyReservationsSlot._(
        source: source,
        state: MyReservationsSlotState.failed,
        items: items,
        next: next,
        hasMore: hasMore,
        zones: zones,
        failure: error,
        stale: true,
      );

  String get installationId => source.installationId;

  /// The next page is being read.
  MyReservationsSlot get readingMore => MyReservationsSlot._(
        source: source,
        state: state,
        items: items,
        next: next,
        hasMore: hasMore,
        zones: zones,
        loadingMore: true,
      );

  /// [page] appended after the pages so far.
  MyReservationsSlot appended(MyReservationsPage page) => MyReservationsSlot._(
        source: source,
        state: MyReservationsSlotState.read,
        items: List.unmodifiable([...items, ...page.items]),
        next: page.next,
        hasMore: page.hasMore,
        zones: Map.unmodifiable({...zones, ...page.zones}),
      );

  /// The further page did not come; the pages so far stay.
  MyReservationsSlot moreFailed(Object error) => MyReservationsSlot._(
        source: source,
        state: state,
        items: items,
        next: next,
        hasMore: hasMore,
        zones: zones,
        failure: error,
      );

  /// #2553 C3 -- the booking [id] as [item] now; removed when [item] is
  /// null (its host no longer lists it for me).
  MyReservationsSlot withItem(String id, MyReservationItem? item) =>
      MyReservationsSlot._(
        source: source,
        state: state,
        items: List.unmodifiable([
          for (final i in items)
            if (i.id != id) i else ?item,
        ]),
        next: next,
        hasMore: hasMore,
        zones: zones,
        loadingMore: loadingMore,
        failure: failure,
        stale: stale,
      );
}

/// #2553 C4 -- whether [failure] withdraws what a host showed before: it
/// refused me, it cannot be reached with its own verified client (not
/// connected here, quarantined, another installation), or nobody is
/// signed in. Anything else -- a lost network, a timeout, an answer this
/// app cannot read -- is an outage: what was read stays, marked stale.
bool _revoked(Object failure) =>
    failure is MyReservationsRefused &&
    switch (failure.failure) {
      MyReservationsFailure.forbidden ||
      MyReservationsFailure.hostUnavailable ||
      MyReservationsFailure.noContext =>
        true,
      _ => false,
    };

/// One booking in the composed list, with the host it came from and the
/// zone of its workspace.
@immutable
class MyReservationEntry {
  const MyReservationEntry({required this.item, required this.source, this.zone});

  final MyReservationItem item;

  /// The installation the booking was read from.
  final String source;

  /// The IANA zone of the booking's workspace; null when its host named
  /// none.
  final String? zone;

  /// The calendar day the booking starts on in its workspace's own zone;
  /// on the device's calendar only when the host named no known zone.
  DateTime get day {
    final local = wall(item.startsAt);
    return DateTime(local.year, local.month, local.day);
  }

  /// #2553 C3 -- [instant] on the wall clock of the booking's workspace;
  /// the device's when its host named no known zone.
  DateTime wall(DateTime instant) {
    final name = zone;
    if (name != null && TimeZones.isKnown(name)) {
      return tz.TZDateTime.from(instant, tz.getLocation(name));
    }
    return instant.toLocal();
  }

  /// #2553 C3 -- the workspace's zone when its wall clock differs from the
  /// device's at the booking's start; null when they agree or none is
  /// known. A card then names the zone its times are in.
  String? get foreignZone {
    final name = zone;
    if (name == null || !TimeZones.isKnown(name)) return null;
    final there = tz.TZDateTime.from(item.startsAt, tz.getLocation(name));
    return there.timeZoneOffset == item.startsAt.toLocal().timeZoneOffset
        ? null
        : name;
  }
}

/// (start, host, id): the order of the composed list, total and stable.
int _order(MyReservationEntry a, MyReservationEntry b) {
  final byStart = a.item.startsAt.compareTo(b.item.startsAt);
  if (byStart != 0) return byStart;
  final bySource = a.source.compareTo(b.source);
  return bySource != 0 ? bySource : a.item.id.compareTo(b.item.id);
}

/// #2553 C3 -- the three views of a person's bookings, by their actual
/// status and end.
enum MyReservationsTab {
  /// Reserved or checked in, and not yet ended.
  upcoming,

  /// Ended, completed or released.
  past,

  /// Cancelled.
  cancelled;

  /// The tab [item] belongs to at [now].
  static MyReservationsTab of(MyReservationItem item, DateTime now) {
    if (item.status == ReservationStatus.cancelled) return cancelled;
    final open = item.status == ReservationStatus.reserved ||
        item.status == ReservationStatus.checkedIn;
    return open && item.endsAt.isAfter(now) ? upcoming : past;
  }

  /// The direction its period is read in: the past newest first.
  MyReservationsDirection get direction => this == past
      ? MyReservationsDirection.descending
      : MyReservationsDirection.ascending;
}

/// #2553 C3 -- what one tab shows of a composition, for every source or
/// the one [MyReservationsSelection.source] names.
@immutable
class MyReservationsSelection {
  MyReservationsSelection(
    MyReservationsComposition composition, {
    required this.tab,
    required DateTime now,
    this.source,
  })  : slots = List.unmodifiable([
          for (final s in composition.slots)
            if (source == null || s.installationId == source) s,
        ]),
        entries = List.unmodifiable([
          for (final e in composition.visible)
            if ((source == null || e.source == source) &&
                MyReservationsTab.of(e.item, now) == tab)
              e,
        ]);

  final MyReservationsTab tab;

  /// The installation shown alone; null for every source.
  final String? source;

  /// The slots the selection reads from.
  final List<MyReservationsSlot> slots;

  /// The bookings of the tab, in the composition's order.
  final List<MyReservationEntry> entries;

  /// One of the selected hosts still has a further page.
  bool get hasMore =>
      slots.any((s) => s.state == MyReservationsSlotState.read && s.hasMore);

  /// Every selected host answered all of its pages and none holds a
  /// booking of this tab: only then is the tab empty.
  bool get empty =>
      entries.isEmpty &&
      slots.every((s) => s.state == MyReservationsSlotState.read && !s.hasMore);
}

/// Every host's slot, in the order the sources were named.
@immutable
class MyReservationsComposition {
  MyReservationsComposition(
    this.slots, {
    this.direction = MyReservationsDirection.ascending,
    this.principal,
  });

  final List<MyReservationsSlot> slots;

  /// #2553 C4 -- the account the composition was read for: shown only to
  /// it, carried into a read again only for it.
  final String? principal;

  /// #2553 C3 -- the way the period is walked: the merge, the horizon and
  /// the pages all follow it.
  final MyReservationsDirection direction;

  int _ordered(MyReservationEntry a, MyReservationEntry b) =>
      direction == MyReservationsDirection.ascending ? _order(a, b) : _order(b, a);

  /// [slot] in place of the one of the same host.
  MyReservationsComposition replacing(MyReservationsSlot slot) =>
      MyReservationsComposition(
        List.unmodifiable(
          slots.map((s) => s.installationId == slot.installationId ? slot : s),
        ),
        direction: direction,
        principal: principal,
      );

  /// #2553 C3 -- the booking [id] of host [installationId] as [item] now,
  /// or removed when [item] is null.
  MyReservationsComposition withItem(
    String installationId,
    String id,
    MyReservationItem? item,
  ) {
    final slot = slotOf(installationId);
    return slot == null ? this : replacing(slot.withItem(id, item));
  }

  /// [source]'s answer placed in its slot: its first [page] (or the
  /// [failure] of it) when [first], else a further page appended (or its
  /// failure beside the pages so far). A host no slot names is ignored.
  MyReservationsComposition answered(
    MyReservationsSource source, {
    required bool first,
    MyReservationsPage? page,
    Object? failure,
  }) {
    final slot = slotOf(source.installationId);
    if (slot == null) return this;
    final error = failure ?? StateError('no page and no failure');
    // C4 -- a refusal that withdraws the host's rows purges them; an
    // outage keeps them, stale.
    final revoked = _revoked(error);
    final MyReservationsSlot answer;
    if (page != null) {
      answer = first ? MyReservationsSlot.firstPage(source, page) : slot.appended(page);
    } else if (revoked || (first && slot.items.isEmpty)) {
      answer = MyReservationsSlot.failed(source, error);
    } else {
      answer = first ? slot.outage(error) : slot.moreFailed(error);
    }
    return replacing(answer);
  }

  /// Every read host that has a further page, marked as reading it, and
  /// where each one continues; only host [only] when it is given.
  (MyReservationsComposition, List<(MyReservationsSource, MyReservationsCursor)>)
      askingMore({String? only}) {
    var next = this;
    final asks = <(MyReservationsSource, MyReservationsCursor)>[];
    for (final slot in slots) {
      final cursor = slot.next;
      if ((only != null && slot.installationId != only) ||
          slot.state != MyReservationsSlotState.read ||
          !slot.hasMore ||
          slot.loadingMore ||
          cursor == null) {
        continue;
      }
      next = next.replacing(slot.readingMore);
      asks.add((slot.source, cursor));
    }
    return (next, asks);
  }

  MyReservationsSlot? slotOf(String installationId) {
    for (final s in slots) {
      if (s.installationId == installationId) return s;
    }
    return null;
  }

  /// The merged bookings that can be shown now: every read slot's items,
  /// and (C4) a stale slot's, up to the horizon, the smallest last row of a
  /// slot that has more.
  late final List<MyReservationEntry> visible = _visible();

  List<MyReservationEntry> _visible() {
    final all = <MyReservationEntry>[];
    MyReservationEntry? horizon;
    for (final s in slots) {
      if (s.state != MyReservationsSlotState.read && !s.stale) continue;
      for (final item in s.items) {
        all.add(MyReservationEntry(
          item: item,
          source: s.installationId,
          zone: s.zones[item.workspaceId],
        ));
      }
      if (s.hasMore && s.items.isNotEmpty) {
        final last = MyReservationEntry(item: s.items.last, source: s.installationId);
        if (horizon == null || _ordered(last, horizon) < 0) horizon = last;
      }
    }
    all.sort(_ordered);
    final h = horizon;
    if (h == null) return List.unmodifiable(all);
    return List.unmodifiable(all.where((e) => _ordered(e, h) <= 0));
  }

  /// A host still has a further page.
  bool get hasMore => slots.any((s) => s.state == MyReservationsSlotState.read && s.hasMore);

  bool get loadingMore => slots.any((s) => s.loadingMore);

  /// A host's first page is still being read.
  bool get reading => slots.any((s) => s.state == MyReservationsSlotState.reading);

  /// The hosts whose first page did not come.
  List<MyReservationsSlot> get failed => [
        for (final s in slots)
          if (s.state == MyReservationsSlotState.failed) s,
      ];

  /// Every host answered, all of its pages are read and none holds a
  /// booking of the period: only then is the period empty.
  bool get empty =>
      slots.every((s) => s.state == MyReservationsSlotState.read && !s.hasMore) &&
      visible.isEmpty;
}
