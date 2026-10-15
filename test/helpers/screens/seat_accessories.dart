// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in seat_accessories_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_floor_plan_repository.dart';
import 'level_canvas.dart' show cellCenter, seedOffice;

/// Seeds one office, one desk and one seat; returns nothing — the seat is
/// `plans.seats.single` afterwards.
Future<void> seedSeat(FakeFloorPlanRepository plans, String levelId) async {
  await seedOffice(plans, levelId);
  final desk = await plans.createDesk(
    workspaceId: 'ws-1',
    officeId: plans.offices.single.id,
    name: 'Desk',
    rect: const GridRect(x: 4, y: 4, w: 12, h: 8),
  );
  await plans.createSeat(
    workspaceId: 'ws-1',
    deskId: desk.id,
    name: 'A1',
    x: 4,
    y: 4,
    orientation: SeatOrientation.n,
  );
}

/// Opens the seat sheet: first tap selects (#101), second opens properties.
Future<void> openSeatSheet(WidgetTester tester) async {
  await tester.tapAt(cellCenter(tester, 5, 5));
  await tester.pumpAndSettle();
  await tester.tapAt(cellCenter(tester, 5, 5));
  await tester.pumpAndSettle();
  expect(find.text('Sitting direction'), findsOneWidget);
}
