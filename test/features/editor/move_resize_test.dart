// SPDX-License-Identifier: MIT
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import 'level_canvas_test.dart'
    show cellCenter, dragCells, pumpCanvas, seedOffice;

Future<FakeFloorPlanRepository> pumpWithDeskAndSeat(
  WidgetTester tester,
) async {
  return pumpCanvas(
    tester,
    seed: (plans, levelId) async {
      await seedOffice(plans, levelId); // office (0,0) 40×30
      final desk = await plans.createDesk(
        workspaceId: 'ws-1',
        officeId: plans.offices.single.id,
        name: 'Desk',
        rect: const GridRect(x: 4, y: 4, w: 12, h: 4),
      );
      await plans.createSeat(
        workspaceId: 'ws-1',
        deskId: desk.id,
        name: 'A1',
        x: 4,
        y: 4,
        orientation: SeatOrientation.n,
      );
    },
  );
}

void main() {
  testWidgets('drag from the middle moves the desk and carries its seat',
      (tester) async {
    final plans = await pumpWithDeskAndSeat(tester);

    // Tap a desk cell not covered by the seat → selects the desk.
    await tester.tapAt(cellCenter(tester, 12, 5));
    await tester.pumpAndSettle();
    // Drag from the middle: down 5 cells.
    await dragCells(tester, (x: 12, y: 5), (x: 12, y: 10));

    expect(plans.desks.single.rect, const GridRect(x: 4, y: 9, w: 12, h: 4));
    expect(plans.seats.single.y, 9);
  });

  testWidgets('drag on the right edge stretches the desk', (tester) async {
    final plans = await pumpWithDeskAndSeat(tester);

    await tester.tapAt(cellCenter(tester, 12, 5));
    await tester.pumpAndSettle();
    // Cell 15 centre sits within the edge tolerance of the right border
    // (x = 16 cells): grabbing there resizes instead of moving.
    await dragCells(tester, (x: 15, y: 5), (x: 19, y: 5));

    expect(plans.desks.single.rect, const GridRect(x: 4, y: 4, w: 16, h: 4));
  });

  testWidgets('shrinking a desk below its seat footprint reverts',
      (tester) async {
    final plans = await pumpWithDeskAndSeat(tester);

    await tester.tapAt(cellCenter(tester, 12, 5));
    await tester.pumpAndSettle();
    await dragCells(tester, (x: 15, y: 5), (x: 7, y: 5));

    expect(plans.desks.single.rect, const GridRect(x: 4, y: 4, w: 12, h: 4));
    expect(find.text('Must be fully inside an office.'), findsOneWidget);
  });

  testWidgets('moving an office carries its desk and seat', (tester) async {
    final plans = await pumpWithDeskAndSeat(tester);

    // Tap an office cell outside the desk → selects the office.
    await tester.tapAt(cellCenter(tester, 30, 20));
    await tester.pumpAndSettle();
    await dragCells(tester, (x: 30, y: 20), (x: 32, y: 22));

    expect(plans.offices.single.rect, const GridRect(x: 2, y: 2, w: 40, h: 30));
    expect(plans.desks.single.rect, const GridRect(x: 6, y: 6, w: 12, h: 4));
    expect(plans.seats.single.x, 6);
    expect(plans.seats.single.y, 6);
  });

  testWidgets('a seat is movable on its desk but never resizable',
      (tester) async {
    final plans = await pumpWithDeskAndSeat(tester);

    // Seat covers (4,4)-(10,8): tap selects the seat, drag moves it.
    await tester.tapAt(cellCenter(tester, 5, 5));
    await tester.pumpAndSettle();
    await dragCells(tester, (x: 5, y: 5), (x: 11, y: 5));

    final seat = plans.seats.single;
    expect(seat.x, 10);
    expect(seat.footprint, const GridRect(x: 10, y: 4, w: 6, h: 4));
  });

  testWidgets('tapping the selected element again opens its properties',
      (tester) async {
    await pumpWithDeskAndSeat(tester);

    await tester.tapAt(cellCenter(tester, 12, 5));
    await tester.pumpAndSettle();
    await tester.tapAt(cellCenter(tester, 12, 5));
    await tester.pumpAndSettle();

    expect(find.text('Desk name'), findsOneWidget);
  });
}
