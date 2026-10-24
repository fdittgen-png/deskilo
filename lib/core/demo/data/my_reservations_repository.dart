// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C1 -- the Demo's own-reservations read: the fixture is one
// installation holding two spaces, so the page gathers the acting member's
// bookings of both, exactly as `my_reservations_page_v1` does on a host,
// and pages them by the registry's defaults.
import 'package:deskilo/core/settings/setting_defaults.g.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';

import 'floor_plan_repository.dart';
import 'reservation_repository.dart';

/// One space of the fixture, as the read needs it: its plan (for the
/// names of the booked places) and its bookings.
typedef DemoReservationSource = ({
  FakeFloorPlanRepository floorPlan,
  FakeReservationRepository reservations,
});

class DemoMyReservationsRepository implements MyReservationsRepository {
  const DemoMyReservationsRepository({
    required this.installationId,
    required this.spaces,
    required this.workspaceName,
    this.workspaceZone,
    this.pageSize = SettingDefaults.personalReservationPageSize,
  });

  final String installationId;
  final List<DemoReservationSource> spaces;

  /// The name of a space by its id, read when a page is built: the list of
  /// spaces moves with the session (a link, a persona, a reset).
  final String Function(String workspaceId) workspaceName;

  /// #2553 C2 — the zone of a space, as its workspace row holds it.
  final String? Function(String workspaceId)? workspaceZone;
  final int pageSize;

  @override
  Future<MyReservationsLimits> limits() async => const MyReservationsLimits(
        windowDays: SettingDefaults.personalReservationWindowDays,
        maxDays: SettingDefaults.personalReservationMaxWindowDays,
        concurrency: SettingDefaults.personalReadConcurrency,
        timeout: Duration(seconds: SettingDefaults.personalReadTimeoutSeconds),
      );

  /// The fixture is one installation: a source naming another holds none
  /// of its bookings, and is answered with an empty page, as a host
  /// holding none of mine would.
  @override
  Future<MyReservationsPage> page(
    MyReservationsSource source,
    MyReservationsQuery query,
  ) async {
    if (source.installationId != installationId) {
      return MyReservationsPage(
        source: source.installationId,
        items: const [],
        next: null,
        hasMore: false,
      );
    }
    final own = <MyReservationItem>[];
    for (final space in spaces) {
      final mine = space.reservations.myMemberId;
      final rows = [
        for (final r in space.reservations.reservations)
          if (r.memberId == mine && r.startsAt.isBefore(query.to) && r.endsAt.isAfter(query.from)) r,
      ];
      final names = <String, Map<String, String>>{};
      for (final id in rows.map((r) => r.workspaceId).toSet()) {
        names[id] = await space.floorPlan.fetchTargetNames(id);
      }
      own.addAll([for (final r in rows) _itemOf(r, names[r.workspaceId] ?? const {})]);
    }
    final ascending = query.direction == MyReservationsDirection.ascending;
    own.sort((a, b) => ascending ? _keysetOrder(a, b) : _keysetOrder(b, a));
    final after = query.after;
    final rest = after == null
        ? own
        : own.where((r) => ascending ? _afterCursor(r, after) > 0 : _afterCursor(r, after) < 0).toList();
    final hasMore = rest.length > pageSize;
    final items = rest.take(pageSize).toList();
    return MyReservationsPage(
      source: installationId,
      items: List.unmodifiable(items),
      next: hasMore
          ? MyReservationsCursor(afterStart: items.last.startsAt, afterId: items.last.id)
          : null,
      hasMore: hasMore,
      zones: {
        for (final i in items)
          if (workspaceZone?.call(i.workspaceId) case final String zone)
            i.workspaceId: zone,
      },
    );
  }

  /// (starts_at, id): the host's keyset order.
  static int _keysetOrder(MyReservationItem a, MyReservationItem b) {
    final byStart = a.startsAt.compareTo(b.startsAt);
    return byStart != 0 ? byStart : a.id.compareTo(b.id);
  }

  /// Where [r] stands against the cursor in keyset order.
  static int _afterCursor(MyReservationItem r, MyReservationsCursor after) {
    final byStart = r.startsAt.compareTo(after.afterStart);
    return byStart != 0 ? byStart : r.id.compareTo(after.afterId);
  }

  MyReservationItem _itemOf(Reservation r, Map<String, String> names) => MyReservationItem(
        id: r.id,
        workspaceId: r.workspaceId,
        workspaceName: workspaceName(r.workspaceId),
        placeKind: r.seatId != null
            ? MyReservationPlaceKind.seat
            : r.deskId != null
                ? MyReservationPlaceKind.desk
                : r.officeId != null
                    ? MyReservationPlaceKind.office
                    : MyReservationPlaceKind.level,
        placeId: r.seatId ?? r.deskId ?? r.officeId ?? r.levelId,
        placeLabel: r.spaceNameFrom(names),
        startsAt: r.startsAt,
        endsAt: r.endsAt,
        status: r.status,
        checkedInAt: r.checkedInAt,
        checkedOutAt: r.checkedOutAt,
      );
}

/// #2553 C3 -- the Demo's row actions: the booking is changed in the space
/// of the one fixture installation that holds it, and View reads it again
/// through the same read a host answers. A source naming another
/// installation is a host this device cannot reach.
class DemoMyReservationActions implements MyReservationActions {
  const DemoMyReservationActions(this.pages);

  final DemoMyReservationsRepository pages;

  void _ownHost(MyReservationsSource source) {
    if (source.installationId != pages.installationId) {
      throw MyReservationsRefused(
        MyReservationsFailure.hostUnavailable,
        detail: '${source.installationId} is not the demo installation',
      );
    }
  }

  FakeReservationRepository _spaceOf(MyReservationItem item) {
    for (final space in pages.spaces) {
      if (space.reservations.reservations.any((r) => r.id == item.id)) {
        return space.reservations;
      }
    }
    throw MyReservationsRefused(MyReservationsFailure.gone, detail: item.id);
  }

  @override
  Future<MyReservationItem> view(
    MyReservationsSource source,
    MyReservationItem item,
  ) async {
    _ownHost(source);
    final page = await pages.page(source, myReservationLookup(item));
    for (final found in page.items) {
      if (found.id == item.id) return found;
    }
    throw MyReservationsRefused(MyReservationsFailure.gone, detail: item.id);
  }

  @override
  Future<void> cancel(MyReservationsSource source, MyReservationItem item) async {
    _ownHost(source);
    await _spaceOf(item).cancel(item.id);
  }

  @override
  Future<void> checkIn(MyReservationsSource source, MyReservationItem item) async {
    _ownHost(source);
    await _spaceOf(item).checkIn(item.id);
  }
}
