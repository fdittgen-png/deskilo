// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #168 — the seat sheet assigns catalogue accessories and keeps the
// assignment unless it is changed.
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_accessory_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import 'level_canvas_test.dart' show cellCenter, pumpCanvas, seedOffice;

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

void main() {
  group('seat sheet accessories (#168)', () {
    testWidgets(
        'lists active catalog accessories, pre-checks the assignment and '
        'persists toggles via setSeatAccessories', (tester) async {
      final accessories = FakeAccessoryRepository()..seedSmallCatalog();
      final monitor =
          accessories.accessories.singleWhere((a) => a.name == 'Monitor');
      final standingDesk = accessories.accessories
          .singleWhere((a) => a.name == 'Standing desk');
      final plans = await pumpCanvas(
        tester,
        accessories: accessories,
        seed: (plans, levelId) async {
          await seedSeat(plans, levelId);
          // Existing assignment (as migration 0022's backfill would leave).
          accessories.seatAccessories[plans.seats.single.id] = {monitor.id};
        },
      );
      final seatId = plans.seats.single.id;

      await openSeatSheet(tester);

      // Active accessories appear; the deactivated one does not.
      expect(find.textContaining('Monitor'), findsOneWidget);
      expect(find.text('Standing desk'), findsOneWidget);
      expect(find.textContaining('Docking station'), findsNothing);
      // The monitor's supplement (> 0) is shown after its name.
      expect(find.textContaining('Monitor (+'), findsOneWidget);

      FilterChip chipContaining(String text) => tester.widget<FilterChip>(
            find.ancestor(
              of: find.textContaining(text),
              matching: find.byType(FilterChip),
            ),
          );
      expect(chipContaining('Monitor').selected, isTrue);
      expect(chipContaining('Standing desk').selected, isFalse);

      // Toggle monitor OFF and standing desk ON, then save.
      await tester.tap(find.textContaining('Monitor'));
      await tester.tap(find.text('Standing desk'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(accessories.seatAccessories[seatId], {standingDesk.id});
      // The editor no longer writes seat.amenities (#168).
      expect(plans.seats.single.amenities, isEmpty);
    });

    testWidgets('saving without touching the chips keeps the assignment',
        (tester) async {
      final accessories = FakeAccessoryRepository()..seedSmallCatalog();
      final monitor =
          accessories.accessories.singleWhere((a) => a.name == 'Monitor');
      final plans = await pumpCanvas(
        tester,
        accessories: accessories,
        seed: (plans, levelId) async {
          await seedSeat(plans, levelId);
          accessories.seatAccessories[plans.seats.single.id] = {monitor.id};
        },
      );
      final seatId = plans.seats.single.id;

      await openSeatSheet(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(accessories.seatAccessories[seatId], {monitor.id});
    });

    // #1216 — a LINK, not an instruction. Naming the screen and making
    // the reader walk there themselves costs two taps and a memory of
    // the sentence; this costs one, and the sheet closes behind it.
    testWidgets('empty catalog offers the way to set them up',
        (tester) async {
      await pumpCanvas(tester, seed: seedSeat);

      await openSeatSheet(tester);

      expect(find.byType(FilterChip), findsNothing);
      final link = find.byKey(const ValueKey('seat-add-accessories'));
      expect(link, findsOneWidget);
      expect(
        tester.widget<TextButton>(link).onPressed,
        isNotNull,
        reason: 'an instruction you cannot follow from here is where '
            'this started',
      );
    });
  });
}
