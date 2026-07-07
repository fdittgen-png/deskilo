// SPDX-License-Identifier: MIT
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/floor_plan_rules.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter_test/flutter_test.dart';

Office office(String id, GridRect rect) => Office(
      id: id,
      workspaceId: 'w',
      levelId: 'l',
      name: id,
      color: 0,
      bookableAsWhole: false,
      rect: rect,
    );

Desk desk(String id, GridRect rect, {String officeId = 'o1'}) => Desk(
      id: id,
      workspaceId: 'w',
      officeId: officeId,
      name: id,
      rect: rect,
    );

Seat seat(
  String id,
  int x,
  int y, {
  SeatOrientation orientation = SeatOrientation.n,
  String deskId = 'd1',
}) =>
    Seat(
      id: id,
      workspaceId: 'w',
      deskId: deskId,
      name: id,
      x: x,
      y: y,
      orientation: orientation,
      chair: '',
      amenities: const [],
    );

void main() {
  group('validateOfficePlacement', () {
    final existing = [office('o1', const GridRect(x: 0, y: 0, w: 10, h: 10))];

    test('rejects overlap, accepts adjacency, ignores self on move', () {
      expect(
        validateOfficePlacement(
          const GridRect(x: 5, y: 5, w: 10, h: 10),
          existing,
        ),
        PlacementProblem.overlapsSibling,
      );
      expect(
        validateOfficePlacement(
          const GridRect(x: 10, y: 0, w: 10, h: 10),
          existing,
        ),
        isNull,
      );
      expect(
        validateOfficePlacement(
          const GridRect(x: 0, y: 0, w: 12, h: 10),
          existing,
          ignoreId: 'o1',
        ),
        isNull,
      );
    });
  });

  group('validateDeskPlacement', () {
    final room = office('o1', const GridRect(x: 0, y: 0, w: 20, h: 20));
    final existing = [desk('d1', const GridRect(x: 2, y: 2, w: 6, h: 4))];

    test('desk must be inside the office', () {
      expect(
        validateDeskPlacement(
          const GridRect(x: 18, y: 18, w: 6, h: 4),
          room,
          existing,
        ),
        PlacementProblem.outsideParent,
      );
    });

    test('desk must not overlap a sibling desk', () {
      expect(
        validateDeskPlacement(
          const GridRect(x: 4, y: 4, w: 6, h: 4),
          room,
          existing,
        ),
        PlacementProblem.overlapsSibling,
      );
      expect(
        validateDeskPlacement(
          const GridRect(x: 10, y: 10, w: 6, h: 4),
          room,
          existing,
        ),
        isNull,
      );
    });
  });

  group('validateSeatPlacement', () {
    // A 12×4 desk hosts exactly two 6×4 north-facing seats side by side.
    final table = desk('d1', const GridRect(x: 0, y: 0, w: 12, h: 4));

    test('two seats fill a 12×4 desk; a third cannot fit', () {
      final first = seat('s1', 0, 0);
      final second = seat('s2', 6, 0);
      expect(validateSeatPlacement(first, table, const []), isNull);
      expect(validateSeatPlacement(second, table, [first]), isNull);

      final third = seat('s3', 3, 0);
      expect(
        validateSeatPlacement(third, table, [first, second]),
        PlacementProblem.overlapsSibling,
      );
    });

    test('seat footprint must stay on the desk', () {
      expect(
        validateSeatPlacement(seat('s1', 8, 0), table, const []),
        PlacementProblem.outsideParent,
      );
      // e/w rotates the footprint to 4×6 — too deep for a 4-deep desk.
      expect(
        validateSeatPlacement(
          seat('s1', 0, 0, orientation: SeatOrientation.e),
          table,
          const [],
        ),
        PlacementProblem.outsideParent,
      );
    });

    test('moving a seat ignores itself', () {
      final moved = seat('s1', 1, 0);
      expect(
        validateSeatPlacement(moved, table, [seat('s1', 0, 0)]),
        isNull,
      );
    });
  });

  group('validateSeatInPlan', () {
    test('unknown desk is outsideParent', () {
      const plan = FloorPlan(
        levelId: 'l',
        offices: [],
        desks: [],
        seats: [],
      );
      expect(
        validateSeatInPlan(plan, seat('s1', 0, 0, deskId: 'nope')),
        PlacementProblem.outsideParent,
      );
    });
  });
}
