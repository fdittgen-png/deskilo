// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1301 S3 — the booking sheet answers "place · date · time · confirm"
// without scrolling past what a member rarely needs, and a booking ends
// on the reservation itself, one tap away.
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/reservations/presentation/widgets/reservation_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reserve_hub_test.dart' show pumpHub, seatCenter;

void main() {
  testWidgets('operator actions wait behind More options; confirm stays in view',
      (tester) async {
    await pumpHub(tester);
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.byType(BookingSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-confirm')), findsOneWidget);
    expect(find.text('Make not reservable'), findsNothing,
        reason: 'taking a seat out of service is not part of booking it');

    final more = find.byKey(const ValueKey('booking-more-options'));
    expect(more, findsOneWidget);
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Make not reservable'), findsOneWidget);
  });

  testWidgets('a booking ends on the reservation: Details opens its sheet',
      (tester) async {
    final repo = await pumpHub(tester);
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-confirm')));
    await tester.pumpAndSettle();

    expect(repo.reservations, hasLength(1));
    final details = find.descendant(
        of: find.byType(SnackBar), matching: find.text('Details'));
    expect(details, findsOneWidget);

    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.byType(ReservationDetailSheet), findsOneWidget);
  });
}
