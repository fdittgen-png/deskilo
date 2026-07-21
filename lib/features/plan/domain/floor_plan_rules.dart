// SPDX-License-Identifier: 0BSD
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
}) {
  final collision = siblings.any(
    (o) => o.id != ignoreId && o.rect.overlaps(rect),
  );
  return collision ? PlacementProblem.overlapsSibling : null;
}

/// A desk must sit fully inside its office and not over a sibling desk of
/// the same level.
PlacementProblem? validateDeskPlacement(
  GridRect rect,
  Office office,
  Iterable<Desk> siblings, {
  String? ignoreId,
}) {
  if (!office.rect.containsRect(rect)) return PlacementProblem.outsideParent;
  final collision = siblings.any(
    (d) => d.id != ignoreId && d.rect.overlaps(rect),
  );
  return collision ? PlacementProblem.overlapsSibling : null;
}

/// A seat footprint must sit fully ON its desk (the 6×4 slot is the space
/// on the desk reservable by one worker) and not overlap another seat of
/// the same desk.
PlacementProblem? validateSeatPlacement(
  Seat seat,
  Desk desk,
  Iterable<Seat> siblings,
) {
  if (!desk.rect.containsRect(seat.footprint)) {
    return PlacementProblem.outsideParent;
  }
  final collision = siblings.any(
    (s) => s.id != seat.id && s.footprint.overlaps(seat.footprint),
  );
  return collision ? PlacementProblem.overlapsSibling : null;
}

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
