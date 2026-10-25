// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the level canvas's decisions, as a table.
import 'package:deskilo/features/editor/application/level_canvas_rules.dart';
import 'package:deskilo/features/editor/domain/editor_tool.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/floor_plan_editing.dart';
import 'package:deskilo/features/plan/domain/floor_plan_rules.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const grid = CanvasGrid(cells: 120, cellSize: 14);
  const office = Office(
    id: 'o1',
    workspaceId: 'ws-1',
    levelId: 'l1',
    name: 'Office',
    color: 0,
    bookableAsWhole: false,
    rect: GridRect(x: 0, y: 0, w: 40, h: 40),
  );
  const desk = Desk(
    id: 'd1',
    workspaceId: 'ws-1',
    officeId: 'o1',
    name: 'Desk',
    rect: GridRect(x: 2, y: 2, w: 12, h: 8),
  );
  const seat = Seat(
    id: 's1',
    workspaceId: 'ws-1',
    deskId: 'd1',
    name: 'Seat',
    x: 2,
    y: 2,
    orientation: SeatOrientation.n,
    chair: '',
    amenities: [],
  );
  const plan = FloorPlan(
    levelId: 'l1',
    offices: [office],
    desks: [desk],
    seats: [seat],
  );

  test('cellAt clamps onto the grid', () {
    for (final (dx, dy, x, y) in [
      (0.0, 0.0, 0, 0),
      (14.0, 27.9, 1, 1),
      (-5.0, 99999.0, 0, 119),
    ]) {
      expect(grid.cellAt(dx, dy), (x: x, y: y), reason: '($dx, $dy)');
    }
  });

  test('edgesAt: inside is a move, near an edge resizes, far is nothing', () {
    const rect = GridRect(x: 10, y: 10, w: 10, h: 10);
    expect(grid.edgesAt(rect, 210, 210).isEmpty, isTrue);
    expect(grid.edgesAt(rect, 140, 210).left, isTrue);
    expect(grid.edgesAt(rect, 280, 280).right, isTrue);
    expect(grid.edgesAt(rect, 280, 280).bottom, isTrue);
    expect(grid.edgesAt(rect, 1000, 1000).isEmpty, isTrue);
  });

  test('rectBetween spans both cells in any order', () {
    expect(
      rectBetween((x: 5, y: 1), (x: 2, y: 4)),
      const GridRect(x: 2, y: 1, w: 4, h: 4),
    );
    expect(
      rectBetween((x: 3, y: 3), (x: 3, y: 3)),
      const GridRect(x: 3, y: 3, w: 1, h: 1),
    );
  });

  test('hitAt: seat over desk over office, else nothing', () {
    expect(hitAt(plan, (x: 3, y: 3)), (ElementKind.seat, 's1'));
    expect(hitAt(plan, (x: 12, y: 8)), (ElementKind.desk, 'd1'));
    expect(hitAt(plan, (x: 30, y: 30)), (ElementKind.office, 'o1'));
    expect(hitAt(plan, (x: 80, y: 80)), isNull);
  });

  test('selection rect and selected element by kind', () {
    expect(selectionRectOf(plan, ElementKind.desk, 'd1'), desk.rect);
    expect(selectionRectOf(plan, ElementKind.office, 'gone'), isNull);
    expect(selectionRectOf(plan, null, 'd1'), isNull);
    expect(selectedElementOf(plan, ElementKind.office, 'o1'), (
      kind: ElementKind.office,
      name: 'Office',
    ));
    expect(selectedElementOf(plan, ElementKind.image, 'none'), isNull);
    expect(selectedElementOf(plan, null, null), isNull);
  });

  test('marquee problems and drop targets follow the armed tool', () {
    const outside = GridRect(x: 60, y: 60, w: 4, h: 4);
    expect(
      marqueeProblem(plan, EditorTool.desk, outside),
      PlacementProblem.outsideParent,
    );
    expect(marqueeProblem(plan, EditorTool.seat, outside), isNull);
    expect(marqueeProblem(plan, null, outside), isNull);
    expect(
      marqueeProblem(plan, EditorTool.office, outside),
      validateOfficePlacement(outside, plan.offices),
    );
    expect(dropTargetsFor(plan, EditorTool.desk), {'o1'});
    expect(dropTargetsFor(plan, EditorTool.seat), {'d1'});
    expect(dropTargetsFor(plan, EditorTool.office), isNull);
    expect(dropTargetsFor(plan, null), isNull);
  });

  test('dragDraft moves a seat and resizes a desk', () {
    final moved = dragDraft(
      plan,
      element: (kind: ElementKind.seat, id: 's1'),
      base: seat.footprint,
      edges: const ResizeEdges(right: true),
      delta: (x: 2, y: 1),
    );
    expect(moved.seats.single.x, 4);
    expect(moved.seats.single.y, 3);
    final wider = dragDraft(
      plan,
      element: (kind: ElementKind.desk, id: 'd1'),
      base: desk.rect,
      edges: const ResizeEdges(right: true),
      delta: (x: 3, y: 0),
    );
    expect(wider.desks.single.rect.w, 15);
  });

  test('firstFreeSeatAnchor finds a free spot, or none on a full desk', () {
    final free = firstFreeSeatAnchor(plan, desk, seat);
    expect(free, isNotNull);
    expect(free, isNot((x: seat.x, y: seat.y)));
    const tiny = Desk(
      id: 'd2',
      workspaceId: 'ws-1',
      officeId: 'o1',
      name: 'Tiny',
      rect: GridRect(x: 20, y: 20, w: 6, h: 4),
    );
    final taken = seat.copyWith(id: 's2', deskId: 'd2', x: 20, y: 20);
    final full = plan.copyWith(desks: [desk, tiny], seats: [seat, taken]);
    expect(firstFreeSeatAnchor(full, tiny, taken), isNull);
  });
}
