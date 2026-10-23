// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Pure placement rules for the workspace editor (spec §10). All functions
// are side-effect-free and unit-tested — the editor UI only relays results.
import 'desk.dart';
import 'floor_plan.dart';
import 'grid_geometry.dart';
import 'office.dart';
import 'seat.dart';

enum PlacementProblem {
  overlapsSibling,
  outsideParent,
}

/// An office may be placed anywhere on the level but not over another office.
PlacementProblem? validateOfficePlacement(
  GridRect rect,
  Iterable<Office> siblings, {
  String? ignoreId,
}) =>
    validateOfficeRect(
        rect, siblings.where((o) => o.id != ignoreId).map((o) => o.rect));

/// A desk must sit fully inside its office and not over a sibling desk of
/// the same level.
PlacementProblem? validateDeskPlacement(
  GridRect rect,
  Office office,
  Iterable<Desk> siblings, {
  String? ignoreId,
}) =>
    validateDeskRect(rect, office.rect,
        siblings.where((d) => d.id != ignoreId).map((d) => d.rect));

/// A seat footprint must sit fully ON its desk (the 6×4 slot is the space
/// on the desk reservable by one worker) and not overlap another seat of
/// the same desk.
PlacementProblem? validateSeatPlacement(
  Seat seat,
  Desk desk,
  Iterable<Seat> siblings,
) =>
    validateSeatRect(seat.footprint, desk.rect,
        siblings.where((s) => s.id != seat.id).map((s) => s.footprint));

/// The office rule on geometry alone: [rect] overlaps none of [siblings]
/// (the other offices of the level, the moved one already left out).
PlacementProblem? validateOfficeRect(
  GridRect rect,
  Iterable<GridRect> siblings,
) =>
    siblings.any((s) => s.overlaps(rect))
        ? PlacementProblem.overlapsSibling
        : null;

/// The desk rule on geometry alone: [rect] lies inside [office] and
/// overlaps none of [siblings] (the level's other desks).
PlacementProblem? validateDeskRect(
  GridRect rect,
  GridRect office,
  Iterable<GridRect> siblings,
) =>
    office.containsRect(rect)
        ? validateOfficeRect(rect, siblings)
        : PlacementProblem.outsideParent;

/// The seat rule on geometry alone: [footprint] lies on [desk] and
/// overlaps none of [siblings] (the desk's other seat footprints).
PlacementProblem? validateSeatRect(
  GridRect footprint,
  GridRect desk,
  Iterable<GridRect> siblings,
) =>
    validateDeskRect(footprint, desk, siblings);

/// Convenience for the editor: validates a seat against a whole plan.
PlacementProblem? validateSeatInPlan(FloorPlan plan, Seat seat) {
  final desk = plan.desks.where((d) => d.id == seat.deskId).firstOrNull;
  if (desk == null) return PlacementProblem.outsideParent;
  return validateSeatPlacement(seat, desk, plan.seatsOf(desk.id));
}

/// Clamps a seat anchor so the footprint of [orientation] fits on [desk]
/// as close to the tapped cell as possible. Null when the desk is smaller
/// than the footprint in that orientation.
({int x, int y})? clampSeatAnchor(
  Desk desk,
  int tappedX,
  int tappedY,
  SeatOrientation orientation,
) {
  final horizontal =
      orientation == SeatOrientation.n || orientation == SeatOrientation.s;
  final w = horizontal ? SeatFootprint.length : SeatFootprint.depth;
  final h = horizontal ? SeatFootprint.depth : SeatFootprint.length;
  if (desk.rect.w < w || desk.rect.h < h) return null;
  final x = tappedX.clamp(desk.rect.x, desk.rect.right - w);
  final y = tappedY.clamp(desk.rect.y, desk.rect.bottom - h);
  return (x: x, y: y);
}
