// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/floor_plan_editing.dart';
import 'package:deskilo/features/plan/domain/floor_plan_rules.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter_test/flutter_test.dart';

FloorPlan plan() => const FloorPlan(
      levelId: 'l',
      offices: [
        Office(
          id: 'o1',
          workspaceId: 'w',
          levelId: 'l',
          name: 'Office',
          color: 0,
          bookableAsWhole: false,
          rect: GridRect(x: 2, y: 2, w: 20, h: 16),
        ),
      ],
      desks: [
        Desk(
          id: 'd1',
          workspaceId: 'w',
          officeId: 'o1',
          name: 'Desk',
          rect: GridRect(x: 4, y: 4, w: 12, h: 4),
        ),
      ],
      seats: [
        Seat(
          id: 's1',
          workspaceId: 'w',
          deskId: 'd1',
          name: 'A1',
          x: 4,
          y: 4,
          orientation: SeatOrientation.n,
          chair: '',
          amenities: [],
        ),
      ],
    );

void main() {
  group('dragRect', () {
    const rect = GridRect(x: 5, y: 5, w: 6, h: 4);

    test('move translates and clamps at the origin', () {
      expect(
        dragRect(rect, const ResizeEdges(), 3, -2),
        const GridRect(x: 8, y: 3, w: 6, h: 4),
      );
      expect(
        dragRect(rect, const ResizeEdges(), -99, 0).x,
        0,
      );
    });

    test('edge resize moves only that edge and keeps ≥1 cell', () {
      expect(
        dragRect(rect, const ResizeEdges(right: true), 4, 0),
        const GridRect(x: 5, y: 5, w: 10, h: 4),
      );
      expect(
        dragRect(rect, const ResizeEdges(left: true), 2, 0),
        const GridRect(x: 7, y: 5, w: 4, h: 4),
      );
      // Collapsing below 1 cell is clamped.
      expect(
        dragRect(rect, const ResizeEdges(right: true), -99, 0).w,
        1,
      );
    });

    test('corner resize combines two edges', () {
      expect(
        dragRect(
          rect,
          const ResizeEdges(right: true, bottom: true),
          2,
          3,
        ),
        const GridRect(x: 5, y: 5, w: 8, h: 7),
      );
    });
  });

  group('applyOfficeRect', () {
    test('a pure move carries desks and seats along', () {
      final moved = applyOfficeRect(
        plan(),
        'o1',
        const GridRect(x: 12, y: 7, w: 20, h: 16),
      );
      expect(moved.desks.single.rect, const GridRect(x: 14, y: 9, w: 12, h: 4));
      expect(moved.seats.single.x, 14);
      expect(moved.seats.single.y, 9);
      expect(validateElement(moved, ElementKind.office, 'o1'), isNull);
    });

    test('a resize leaves contents in place and validates containment', () {
      final shrunk = applyOfficeRect(
        plan(),
        'o1',
        const GridRect(x: 2, y: 2, w: 10, h: 4),
      );
      expect(shrunk.desks.single.rect, const GridRect(x: 4, y: 4, w: 12, h: 4));
      expect(
        validateElement(shrunk, ElementKind.office, 'o1'),
        PlacementProblem.outsideParent,
      );
    });
  });

  group('applyDeskRect', () {
    test('a pure move carries seats along and stays valid inside the office',
        () {
      final moved =
          applyDeskRect(plan(), 'd1', const GridRect(x: 6, y: 10, w: 12, h: 4));
      expect(moved.seats.single.x, 6);
      expect(moved.seats.single.y, 10);
      expect(validateElement(moved, ElementKind.desk, 'd1'), isNull);
    });

    test('shrinking below the seat footprint is rejected', () {
      final shrunk =
          applyDeskRect(plan(), 'd1', const GridRect(x: 4, y: 4, w: 4, h: 4));
      expect(
        validateElement(shrunk, ElementKind.desk, 'd1'),
        PlacementProblem.outsideParent,
      );
    });

    test('moving outside the office is rejected', () {
      final out =
          applyDeskRect(plan(), 'd1', const GridRect(x: 0, y: 0, w: 12, h: 4));
      expect(
        validateElement(out, ElementKind.desk, 'd1'),
        PlacementProblem.outsideParent,
      );
    });
  });

  group('applySeatPosition', () {
    test('moves the fixed footprint and validates on the desk', () {
      final moved = applySeatPosition(plan(), 's1', 10, 4);
      expect(moved.seats.single.footprint,
          const GridRect(x: 10, y: 4, w: 6, h: 4));
      expect(validateElement(moved, ElementKind.seat, 's1'), isNull);

      final off = applySeatPosition(plan(), 's1', 13, 4);
      expect(
        validateElement(off, ElementKind.seat, 's1'),
        PlacementProblem.outsideParent,
      );
    });
  });
}
