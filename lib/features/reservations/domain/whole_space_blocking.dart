// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1825 — what keeps a desk, office or level from being reserved as a
// whole in a window: the blocking RESERVATION (not a bool), so a surface
// can name its holder. One rule for the plan's space sheet and the
// reserve list; moved here unchanged from space_scan (#622, #1087). The
// server re-checks everything (offices/levels elsewhere, series, races).
import '../../plan/domain/desk.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/seat.dart';
import 'reservation.dart';
import 'space_code.dart';

/// The reservation blocking [kind] (desk [deskId] in office [officeId] on
/// level [levelId]; office [officeId] on level [levelId]; level
/// [levelId]) in [from, to), or null when it can be reserved whole.
Reservation? wholeSpaceBlocking({
  required SpaceKind kind,
  required FloorPlan? plan,
  required Iterable<Reservation> reservations,
  required DateTime from,
  required DateTime to,
  String? deskId,
  String? officeId,
  String? levelId,
}) {
  bool inWindow(Reservation r) => r.coversRange(from, to);
  bool same(String? a, String? b) => b != null && a == b;
  final desks = plan?.desks ?? const <Desk>[];
  final seats = plan?.seats ?? const <Seat>[];
  final seatIds = switch (kind) {
    SpaceKind.desk => {
      for (final s in seats)
        if (s.deskId == deskId) s.id,
    },
    SpaceKind.office => () {
      final ids = {
        for (final d in desks)
          if (d.officeId == officeId) d.id,
      };
      return {
        for (final s in seats)
          if (ids.contains(s.deskId)) s.id,
      };
    }(),
    _ => const <String>{},
  };
  final seatBlocking = reservations
      .where(
        (r) => r.seatId != null && seatIds.contains(r.seatId) && inWindow(r),
      )
      .firstOrNull;
  return switch (kind) {
    SpaceKind.desk =>
      seatBlocking ??
          reservations
              .where(
                (r) =>
                    (same(r.deskId, deskId) ||
                        same(r.officeId, officeId) ||
                        same(r.levelId, levelId)) &&
                    inWindow(r),
              )
              .firstOrNull,
    SpaceKind.office =>
      seatBlocking ??
          reservations
              .where(
                (r) =>
                    (same(r.officeId, officeId) ||
                        same(r.levelId, levelId) ||
                        // #1087 — a whole-desk booking blocks this office only
                        // if the desk IS in this office.
                        (r.deskId != null &&
                            desks.any(
                              (d) => d.id == r.deskId && d.officeId == officeId,
                            ))) &&
                    inWindow(r),
              )
              .firstOrNull,
    _ =>
      reservations
          .where((r) => same(r.levelId, levelId) && inWindow(r))
          .firstOrNull,
  };
}
