// SPDX-License-Identifier: MIT
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plan_screen_test.dart' show pumpPlan, seatCenter;

Future<void> openFutureBookingSheet(WidgetTester tester) async {
  await tester.drag(find.byType(Slider), const Offset(600, 0));
  await tester.pumpAndSettle();
  await tester.tapAt(seatCenter(tester));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('weekly series books 5 instances over the default 28 days',
      (tester) async {
    final env = await pumpPlan(tester);
    await openFutureBookingSheet(tester);

    await tester.tap(find.text('Does not repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    expect(find.text('5 bookings created'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final series = env.reservations.reservations
        .where((r) => r.seriesId != null)
        .toList();
    expect(series, hasLength(5));
    expect(series.map((r) => r.seriesId).toSet(), hasLength(1));
    expect(
      series.every((r) => r.status == ReservationStatus.reserved),
      isTrue,
    );
  });

  testWidgets('conflicting instances are reported as skipped, not silent',
      (tester) async {
    final now = DateTime.now();
    final env = await pumpPlan(
      tester,
      seedReservations: (repo) {
        // Block the whole day one week out — whatever time the slider picks,
        // the second weekly instance collides.
        final dayStart = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 7));
        repo.reservations.add(
          Reservation(
            id: 'res-blocker',
            workspaceId: 'ws-1',
            seatId: 'seat-4',
            memberId: 'member-2',
            startsAt: dayStart,
            endsAt: dayStart.add(const Duration(days: 1)),
            status: ReservationStatus.reserved,
          ),
        );
      },
    );
    await openFutureBookingSheet(tester);

    await tester.tap(find.text('Does not repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    expect(find.text('4 bookings created'), findsOneWidget);
    expect(find.text('Skipped (already taken):'), findsOneWidget);

    final mine = env.reservations.reservations
        .where((r) => r.seriesId != null)
        .toList();
    expect(mine, hasLength(4));
  });
}
