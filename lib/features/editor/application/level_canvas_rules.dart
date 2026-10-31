// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — what the level canvas decides, apart from what it paints.
//
// Which element a tap hits, what is selected and where its outline is,
// what a drag would make of the plan, where a marquee may go and where
// the armed tool may drop at all, and the first free spot for a copied
// seat. Plain Dart over the plan's own types: the screen asks and draws.
import '../../plan/domain/desk.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/floor_plan_editing.dart';
import '../../plan/domain/floor_plan_rules.dart';
import '../../plan/domain/grid_geometry.dart';
import '../../plan/domain/seat.dart';
import '../domain/editor_tool.dart';

/// A cell of the canvas grid.
typedef CanvasCell = ({int x, int y});

/// The grid's own measure: [cells] square cells of [cellSize] logical
/// pixels at scale 1.
class CanvasGrid {
  const CanvasGrid({required this.cells, required this.cellSize});

  final int cells;
  final double cellSize;

  /// The cell under a canvas position, clamped onto the grid.
  CanvasCell cellAt(double dx, double dy) => (
    x: (dx / cellSize).floor().clamp(0, cells - 1),
    y: (dy / cellSize).floor().clamp(0, cells - 1),
  );

  /// Edge hit-test in canvas pixels (tolerance ~half a cell each side).
  ResizeEdges edgesAt(GridRect rect, double dx, double dy) {
    final tol = cellSize * 0.55;
    final left = rect.x * cellSize;
    final top = rect.y * cellSize;
    final right = left + rect.w * cellSize;
    final bottom = top + rect.h * cellSize;
    final near =
        dx >= left - tol &&
        dx < right + tol &&
        dy >= top - tol &&
        dy < bottom + tol;
    if (!near) return const ResizeEdges();
    return ResizeEdges(
      left: (dx - left).abs() <= tol,
      right: (dx - right).abs() <= tol,
      top: (dy - top).abs() <= tol,
      bottom: (dy - bottom).abs() <= tol,
    );
  }
}

/// The rectangle a marquee spans between two cells, both included.
GridRect rectBetween(CanvasCell a, CanvasCell b) {
  final x = a.x < b.x ? a.x : b.x;
  final y = a.y < b.y ? a.y : b.y;
  return GridRect(
    x: x,
    y: y,
    w: (a.x - b.x).abs() + 1,
    h: (a.y - b.y).abs() + 1,
  );
}

/// A one-cell-thick wall along the drag's dominant axis, including both ends.
GridRect wallBetween(CanvasCell start, CanvasCell end) {
  final horizontal = (end.x - start.x).abs() >= (end.y - start.y).abs();
  return rectBetween(start, horizontal ? (x: end.x, y: start.y) : (x: start.x, y: end.y));
}

/// The outline of the selected element, or null when nothing (or
/// nothing that still exists) is selected.
GridRect? selectionRectOf(
  FloorPlan plan,
  ElementKind? kind,
  String? id,
) => switch (kind) {
  ElementKind.office => plan.offices.where((o) => o.id == id).firstOrNull?.rect,
  ElementKind.desk => plan.desks.where((d) => d.id == id).firstOrNull?.rect,
  ElementKind.seat =>
    plan.seats.where((s) => s.id == id).firstOrNull?.footprint,
  ElementKind.image => plan.images.where((i) => i.id == id).firstOrNull?.rect,
  null => null,
};

/// The selected element's kind and its own name (#1216). An image has no
/// name of its own: its name is null and the bar says what it is. Null
/// when nothing is selected.
({ElementKind kind, String? name})? selectedElementOf(
  FloorPlan plan,
  ElementKind? kind,
  String? id,
) {
  String? nameOf<T>(
    Iterable<T> all,
    String Function(T) idOf,
    String Function(T) name,
  ) => all.where((e) => idOf(e) == id).map(name).firstOrNull;
  final found = switch (kind) {
    ElementKind.office => nameOf(plan.offices, (o) => o.id, (o) => o.name),
    ElementKind.desk => nameOf(plan.desks, (d) => d.id, (d) => d.name),
    ElementKind.seat => nameOf(plan.seats, (s) => s.id, (s) => s.name),
    ElementKind.image => plan.images.any((i) => i.id == id) ? '' : null,
    null => null,
  };
  if (kind == null || found == null) return null;
  return (kind: kind, name: kind == ElementKind.image ? null : found);
}

/// What a tap on [cell] hits, topmost first: seat, desk, office, image.
(ElementKind, String)? hitAt(FloorPlan plan, CanvasCell cell) {
  final seat = plan.seatAtCell(cell.x, cell.y);
  if (seat != null) return (ElementKind.seat, seat.id);
  final desk = plan.deskAtCell(cell.x, cell.y);
  if (desk != null) return (ElementKind.desk, desk.id);
  final office = plan.officeAtCell(cell.x, cell.y);
  if (office != null) return (ElementKind.office, office.id);
  final image = plan.imageAtCell(cell.x, cell.y);
  if (image != null) return (ElementKind.image, image.id);
  return null;
}

/// The plan as it would be after dragging the selected element by
/// ([dx], [dy]) cells from [base], moving or resizing by [edges]. A seat
/// only moves.
FloorPlan dragDraft(
  FloorPlan plan, {
  required ({ElementKind kind, String id}) element,
  required GridRect base,
  required ResizeEdges edges,
  required CanvasCell delta,
}) {
  final id = element.id;
  if (element.kind == ElementKind.seat) {
    final moved = dragRect(base, const ResizeEdges(), delta.x, delta.y);
    return applySeatPosition(plan, id, moved.x, moved.y);
  }
  final next = dragRect(base, edges, delta.x, delta.y);
  return switch (element.kind) {
    ElementKind.office => applyOfficeRect(plan, id, next),
    ElementKind.image => applyImageRect(plan, id, next),
    _ => applyDeskRect(plan, id, next),
  };
}

/// Why the armed [tool] may not place [rect], or null when it may.
PlacementProblem? marqueeProblem(
  FloorPlan plan,
  EditorTool? tool,
  GridRect rect,
) {
  switch (tool) {
    case EditorTool.office:
      return validateOfficePlacement(rect, plan.offices);
    case EditorTool.desk:
      final office = plan.officeAtCell(rect.x, rect.y);
      if (office == null) return PlacementProblem.outsideParent;
      return validateDeskPlacement(rect, office, plan.desks);
    case EditorTool.seat || EditorTool.image || EditorTool.decor || null:
      return null;
  }
}

/// Where the armed tool may legally place its next element (#1216).
///
/// The rules already existed and were only ever spoken after a failed
/// drag: *"Must be fully inside an office."* Since the editor can
/// answer before the gesture, it does: an empty set is a meaningful
/// answer and null means no tool is armed.
Set<String>? dropTargetsFor(FloorPlan plan, EditorTool? tool) => switch (tool) {
  EditorTool.desk => {for (final o in plan.offices) o.id},
  EditorTool.seat => {for (final d in plan.desks) d.id},
  // An office may go anywhere on the floor, and an image too, so
  // dimming would be a lie about a rule that does not exist.
  EditorTool.office || EditorTool.image || EditorTool.decor || null => null,
};

/// A seat that would stand at [anchor] on [desk], for the placement rules.
Seat seatCandidate(
  Desk desk,
  CanvasCell anchor, {
  required String workspaceId,
  required SeatOrientation orientation,
  String chair = '',
}) => Seat(
  id: '',
  workspaceId: workspaceId,
  deskId: desk.id,
  name: '',
  x: anchor.x,
  y: anchor.y,
  orientation: orientation,
  chair: chair,
  amenities: const [],
);

/// #1216 — the first free cell of [seat]'s desk for a copy of it, row by
/// row from the desk's top-left; null when the desk is full.
CanvasCell? firstFreeSeatAnchor(FloorPlan plan, Desk desk, Seat seat) {
  final siblings = plan.seatsOf(desk.id);
  for (var y = desk.rect.y; y < desk.rect.y + desk.rect.h; y++) {
    for (var x = desk.rect.x; x < desk.rect.x + desk.rect.w; x++) {
      final anchor = clampSeatAnchor(desk, x, y, seat.orientation);
      if (anchor == null) continue;
      final candidate = seatCandidate(
        desk,
        anchor,
        workspaceId: seat.workspaceId,
        orientation: seat.orientation,
        chair: seat.chair,
      );
      if (validateSeatPlacement(candidate, desk, siblings) == null) {
        return anchor;
      }
    }
  }
  return null;
}
