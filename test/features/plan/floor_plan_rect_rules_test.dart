// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The placement rules on geometry alone: a rect, its parent's rect and the
// siblings' rects (#2927). The model-taking rules are these plus the id to
// leave out, so both must answer alike over the same cells.
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan_rules.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter_test/flutter_test.dart';

const _room = GridRect(x: 0, y: 0, w: 20, h: 10);

Office _office(String id, GridRect rect) => Office(
  id: id,
  workspaceId: 'w',
  levelId: 'l',
  name: id,
  color: 0,
  bookableAsWhole: false,
  rect: rect,
);

Desk _desk(String id, GridRect rect) =>
    Desk(id: id, workspaceId: 'w', officeId: 'o', name: id, rect: rect);

Seat _seat(String id, int x, int y, SeatOrientation orientation) => Seat(
  id: id,
  workspaceId: 'w',
  deskId: 'd',
  name: id,
  x: x,
  y: y,
  orientation: orientation,
  chair: '',
  amenities: const [],
);

void main() {
  test('validateOfficeRect: overlap is refused, adjacency is not', () {
    const placed = [GridRect(x: 0, y: 0, w: 10, h: 10)];
    expect(
      validateOfficeRect(const GridRect(x: 5, y: 5, w: 10, h: 10), placed),
      PlacementProblem.overlapsSibling,
    );
    expect(
      validateOfficeRect(const GridRect(x: 10, y: 0, w: 10, h: 10), placed),
      isNull,
    );
    expect(validateOfficeRect(_room, const []), isNull);
  });

  test('validateDeskRect: outside the office wins over an overlap', () {
    const placed = [GridRect(x: 0, y: 0, w: 6, h: 4)];
    expect(
      validateDeskRect(const GridRect(x: 16, y: 0, w: 6, h: 4), _room, placed),
      PlacementProblem.outsideParent,
    );
    expect(
      validateDeskRect(const GridRect(x: 3, y: 0, w: 6, h: 4), _room, placed),
      PlacementProblem.overlapsSibling,
    );
    expect(
      validateDeskRect(const GridRect(x: 6, y: 0, w: 6, h: 4), _room, placed),
      isNull,
    );
  });

  test('validateSeatRect reads the footprint seatFootprintAt gives', () {
    const desk = GridRect(x: 0, y: 0, w: 12, h: 4);
    final north = seatFootprintAt(x: 0, y: 0, orientation: SeatOrientation.n);
    final east = seatFootprintAt(x: 6, y: 0, orientation: SeatOrientation.e);
    expect(north, const GridRect(x: 0, y: 0, w: 6, h: 4));
    expect(east, const GridRect(x: 6, y: 0, w: 4, h: 6));
    expect(validateSeatRect(north, desk, const []), isNull);
    expect(
      validateSeatRect(east, desk, [north]),
      PlacementProblem.outsideParent,
    );
    final second = seatFootprintAt(x: 4, y: 0, orientation: SeatOrientation.s);
    expect(
      validateSeatRect(second, desk, [north]),
      PlacementProblem.overlapsSibling,
    );
  });

  test('the model rules answer as the geometry rules over the same cells, '
      'leaving out the id they ignore', () {
    final offices = [_office('a', const GridRect(x: 0, y: 0, w: 10, h: 10))];
    const moved = GridRect(x: 5, y: 5, w: 10, h: 10);
    expect(
      validateOfficePlacement(moved, offices),
      validateOfficeRect(moved, [offices.single.rect]),
    );
    expect(validateOfficePlacement(moved, offices, ignoreId: 'a'), isNull);

    final office = _office('o', _room);
    final desks = [_desk('d1', const GridRect(x: 0, y: 0, w: 6, h: 4))];
    const deskRect = GridRect(x: 3, y: 0, w: 6, h: 4);
    expect(
      validateDeskPlacement(deskRect, office, desks),
      validateDeskRect(deskRect, _room, [desks.single.rect]),
    );
    expect(
      validateDeskPlacement(deskRect, office, desks, ignoreId: 'd1'),
      isNull,
    );

    final desk = _desk('d', const GridRect(x: 0, y: 0, w: 12, h: 4));
    final first = _seat('s1', 0, 0, SeatOrientation.n);
    final second = _seat('s2', 4, 0, SeatOrientation.n);
    expect(
      validateSeatPlacement(second, desk, [first, second]),
      validateSeatRect(second.footprint, desk.rect, [first.footprint]),
    );
    expect(
      second.footprint,
      seatFootprintAt(x: 4, y: 0, orientation: SeatOrientation.n),
    );
  });
}
