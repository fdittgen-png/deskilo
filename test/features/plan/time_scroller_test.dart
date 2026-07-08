// SPDX-License-Identifier: MIT
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plan_screen_test.dart' show foreignReservation, pumpPlan, seatCenter;

void main() {
  testWidgets('scrolling to a future time books a reservation, not a walk-up',
      (tester) async {
    final env = await pumpPlan(tester);

    // Drag the time slider far right → browse mode at a late hour.
    await tester.drag(find.byType(Slider), const Offset(600, 0));
    await tester.pumpAndSettle();

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.textContaining('Starts at'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final created = env.reservations.reservations.single;
    expect(created.status, ReservationStatus.reserved);
    expect(created.checkedInAt, isNull);
  });

  testWidgets('Now snaps back to live mode', (tester) async {
    await pumpPlan(tester);

    await tester.drag(find.byType(Slider), const Offset(600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Now'));
    await tester.pumpAndSettle();

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.textContaining('Starts now'), findsOneWidget);
  });

  testWidgets('list view shows every seat with its live state (#104)',
      (tester) async {
    await pumpPlan(
      tester,
      seedReservations: (repo) =>
          repo.reservations.add(foreignReservation()),
    );

    await tester.tap(find.byIcon(Icons.list));
    await tester.pumpAndSettle();

    expect(find.text('A1'), findsOneWidget);
    expect(find.textContaining('Reserved by Ana Lima'), findsOneWidget);
  });

  testWidgets('list view shows free seats instead of an empty page',
      (tester) async {
    await pumpPlan(tester);

    await tester.tap(find.byIcon(Icons.list));
    await tester.pumpAndSettle();

    expect(find.text('A1'), findsOneWidget);
    expect(find.textContaining('Free'), findsOneWidget);
  });
}
