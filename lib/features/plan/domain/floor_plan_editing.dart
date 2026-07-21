// SPDX-License-Identifier: 0BSD
//
// Pure move/resize transformations for the editor (#101). All functions
// return a NEW plan; the canvas keeps a draft during the drag and either
// persists the diff or discards it on validation failure.
import 'floor_plan.dart';
import 'floor_plan_rules.dart';
import 'grid_geometry.dart';

enum ElementKind { office, desk, seat, image }

/// Applies [rect] to an office. A pure translation carries the office's
/// desks and seats along; a resize leaves the contents in place (they are
/// re-validated by [validateElement]).
FloorPlan applyOfficeRect(FloorPlan plan, String officeId, GridRect rect) {
  final office = plan.offices.firstWhere((o) => o.id == officeId);
  final isMove = rect.w == office.rect.w && rect.h == office.rect.h;
  final dx = rect.x - office.rect.x;
  final dy = rect.y - office.rect.y;

  final deskIds = plan.desksOf(officeId).map((d) => d.id).toSet();
  return plan.copyWith(
    offices: [
      for (final o in plan.offices)
        o.id == officeId ? o.copyWith(rect: rect) : o,
    ],
    desks: [
      for (final d in plan.desks)
        isMove && deskIds.contains(d.id)
            ? d.copyWith(
                rect: d.rect.copyWith(x: d.rect.x + dx, y: d.rect.y + dy),
              )
            : d,
    ],
    seats: [
      for (final s in plan.seats)
        isMove && deskIds.contains(s.deskId)
            ? s.copyWith(x: s.x + dx, y: s.y + dy)
            : s,
    ],
  );
}

/// Applies [rect] to a desk. A pure translation carries the desk's seats
/// along; a resize leaves them in place.
FloorPlan applyDeskRect(FloorPlan plan, String deskId, GridRect rect) {
  final desk = plan.desks.firstWhere((d) => d.id == deskId);
  final isMove = rect.w == desk.rect.w && rect.h == desk.rect.h;
  final dx = rect.x - desk.rect.x;
  final dy = rect.y - desk.rect.y;

  return plan.copyWith(
    desks: [
      for (final d in plan.desks) d.id == deskId ? d.copyWith(rect: rect) : d,
    ],
    seats: [
      for (final s in plan.seats)
        isMove && s.deskId == deskId
            ? s.copyWith(x: s.x + dx, y: s.y + dy)
            : s,
    ],
  );
}

/// Moves a seat's 6×4 footprint anchor (seats are never resized — the
/// footprint is normative, spec §3).
FloorPlan applySeatPosition(FloorPlan plan, String seatId, int x, int y) {
  return plan.copyWith(
    seats: [
      for (final s in plan.seats)
        s.id == seatId ? s.copyWith(x: x, y: y) : s,
    ],
  );
}

/// Applies [rect] to an illustration image (0037): free move/resize, no
/// children, no containment — images may overlap anything.
FloorPlan applyImageRect(FloorPlan plan, String imageId, GridRect rect) {
  return plan.copyWith(
    images: [
      for (final i in plan.images)
        i.id == imageId ? i.copyWith(rect: rect) : i,
    ],
  );
}

/// Full validation of one element inside [plan] after a move/resize:
/// sibling overlap plus every child still fully contained.
PlacementProblem? validateElement(
  FloorPlan plan,
  ElementKind kind,
  String id,
) {
  switch (kind) {
    case ElementKind.office:
      final office = plan.offices.firstWhere((o) => o.id == id);
      final problem = validateOfficePlacement(
        office.rect,
        plan.offices,
        ignoreId: id,
      );
      if (problem != null) return problem;
      for (final desk in plan.desksOf(id)) {
        if (!office.rect.containsRect(desk.rect)) {
          return PlacementProblem.outsideParent;
        }
      }
      return null;
    case ElementKind.desk:
      final desk = plan.desks.firstWhere((d) => d.id == id);
      final office =
          plan.offices.where((o) => o.id == desk.officeId).firstOrNull;
      if (office == null) return PlacementProblem.outsideParent;
      final problem = validateDeskPlacement(
        desk.rect,
        office,
        plan.desks.where((d) => d.officeId == desk.officeId),
        ignoreId: id,
      );
      if (problem != null) return problem;
      for (final seat in plan.seatsOf(id)) {
        if (!desk.rect.containsRect(seat.footprint)) {
          return PlacementProblem.outsideParent;
        }
      }
      return null;
    case ElementKind.seat:
      final seat = plan.seats.firstWhere((s) => s.id == id);
      return validateSeatInPlan(plan, seat);
    case ElementKind.image:
      // Illustrations float freely — the only rule is staying on the
      // grid (dragRect already clamps to bounds), so nothing to reject.
      return null;
  }
}

/// Resize edges being dragged. Empty set = move.
class ResizeEdges {
  const ResizeEdges({
    this.left = false,
    this.right = false,
    this.top = false,
    this.bottom = false,
  });

  final bool left;
  final bool right;
  final bool top;
  final bool bottom;

  bool get isEmpty => !left && !right && !top && !bottom;
}

/// Applies a drag delta (grid cells) to [rect] as a move (empty [edges])
/// or an edge/corner resize clamped to ≥ 1×1 within the canvas origin.
GridRect dragRect(GridRect rect, ResizeEdges edges, int dx, int dy) {
  if (edges.isEmpty) {
    return rect.copyWith(
      x: (rect.x + dx) < 0 ? 0 : rect.x + dx,
      y: (rect.y + dy) < 0 ? 0 : rect.y + dy,
    );
  }
  var x = rect.x;
  var y = rect.y;
  var w = rect.w;
  var h = rect.h;
  if (edges.left) {
    final nx = (x + dx).clamp(0, x + w - 1);
    w = w + (x - nx);
    x = nx;
  }
  if (edges.right) {
    w = (w + dx) < 1 ? 1 : w + dx;
  }
  if (edges.top) {
    final ny = (y + dy).clamp(0, y + h - 1);
    h = h + (y - ny);
    y = ny;
  }
  if (edges.bottom) {
    h = (h + dy) < 1 ? 1 : h + dy;
  }
  return GridRect(x: x, y: y, w: w, h: h);
}
