// SPDX-License-Identifier: MIT
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan_rules.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'level_canvas_test.dart' show cellCenter, pumpCanvas, seedOffice;

void main() {
  group('clampSeatAnchor', () {
    const table = Desk(
      id: 'd1',
      workspaceId: 'w',
      officeId: 'o',
      name: '',
      rect: GridRect(x: 4, y: 4, w: 12, h: 4),
    );

    test('clamps the anchor so the footprint stays on the desk', () {
      expect(
        clampSeatAnchor(table, 14, 6, SeatOrientation.n),
        (x: 10, y: 4),
      );
      expect(
        clampSeatAnchor(table, 0, 0, SeatOrientation.n),
        (x: 4, y: 4),
      );
    });

    test('returns null when the desk is too small for the orientation', () {
      // e/w needs 6 cells of depth; this desk is only 4 deep.
      expect(clampSeatAnchor(table, 5, 5, SeatOrientation.e), isNull);
    });
  });

  group('seat tool on the canvas', () {
    testWidgets('tapping a desk stamps a clamped 6×4 seat', (tester) async {
      final plans = await pumpCanvas(
        tester,
        seed: (plans, levelId) async {
          await seedOffice(plans, levelId);
          await plans.createDesk(
            workspaceId: 'ws-1',
            officeId: plans.offices.single.id,
            name: 'Long desk',
            rect: const GridRect(x: 4, y: 4, w: 12, h: 4),
          );
        },
      );

      await tester.tap(find.text('Seat'));
      await tester.pumpAndSettle();
      await tester.tapAt(cellCenter(tester, 5, 5));
      await tester.pumpAndSettle();

      expect(plans.seats, hasLength(1));
      // Tapped (5,5): x=5 fits (desk spans 4..16), y clamps to the desk top.
      expect(
        plans.seats.single.footprint,
        const GridRect(x: 5, y: 4, w: 6, h: 4),
      );
    });

    testWidgets('a second overlapping seat is rejected', (tester) async {
      final plans = await pumpCanvas(
        tester,
        seed: (plans, levelId) async {
          await seedOffice(plans, levelId);
          final desk = await plans.createDesk(
            workspaceId: 'ws-1',
            officeId: plans.offices.single.id,
            name: 'Small desk',
            rect: const GridRect(x: 4, y: 4, w: 6, h: 4),
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

      await tester.tap(find.text('Seat'));
      await tester.pumpAndSettle();
      await tester.tapAt(cellCenter(tester, 6, 5));
      await tester.pumpAndSettle();

      expect(plans.seats, hasLength(1));
      expect(find.text('Overlaps an existing element.'), findsOneWidget);
    });

    testWidgets('seat tool outside a desk shows the hint', (tester) async {
      final plans = await pumpCanvas(tester, seed: seedOffice);

      await tester.tap(find.text('Seat'));
      await tester.pumpAndSettle();
      await tester.tapAt(cellCenter(tester, 35, 25));
      await tester.pumpAndSettle();

      expect(plans.seats, isEmpty);
      expect(
        find.text('Seats can only be placed on a desk.'),
        findsOneWidget,
      );
    });

    testWidgets('seat sheet edits chair, amenities and block', (tester) async {
      final plans = await pumpCanvas(
        tester,
        seed: (plans, levelId) async {
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
        },
      );

      // Select tool is active by default: first tap selects (#101),
      // second opens the property sheet.
      await tester.tapAt(cellCenter(tester, 5, 5));
      await tester.pumpAndSettle();
      await tester.tapAt(cellCenter(tester, 5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Sitting direction'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Chair type'),
        'Aeron',
      );
      await tester.tap(find.text('Monitor'));
      await tester.tap(find.text('Window seat'));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final saved = plans.seats.single;
      expect(saved.chair, 'Aeron');
      expect(saved.amenities, containsAll(['monitor', 'window']));
      expect(saved.isBlockedAt(DateTime.now()), isTrue);
    });

    testWidgets(
        'rotating a seat to e/w on a 4-deep desk is rejected on save',
        (tester) async {
      final plans = await pumpCanvas(
        tester,
        seed: (plans, levelId) async {
          await seedOffice(plans, levelId);
          final desk = await plans.createDesk(
            workspaceId: 'ws-1',
            officeId: plans.offices.single.id,
            name: 'Shallow desk',
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

      await tester.tapAt(cellCenter(tester, 5, 5)); // select (#101)
      await tester.pumpAndSettle();
      await tester.tapAt(cellCenter(tester, 5, 5)); // open properties
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(plans.seats.single.orientation, SeatOrientation.n);
      expect(find.text('Must be fully inside an office.'), findsOneWidget);
    });
  });
}
