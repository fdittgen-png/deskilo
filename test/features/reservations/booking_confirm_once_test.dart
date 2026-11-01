// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3061 — confirming the booking sheet twice in a row (a double tap, or a
// tap during the closing animation) is ONE answer: the sheet closes once
// and the screen under it is still there, not popped with it.
import 'package:deskilo/features/reservations/presentation/screens/reserve_screen.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/reserve_hub.dart';

void main() {
  testWidgets('a second tap on Reserve books once and keeps the screen', (
    tester,
  ) async {
    final repo = await pumpHub(tester, size: const Size(390, 844));
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const ValueKey('booking-confirm'));
    expect(confirm, findsOneWidget);

    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 20));
    // The sheet is closing; its button can still be hit.
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BookingSheet), findsNothing);
    expect(find.byType(ReserveScreen), findsOneWidget);
    expect(repo.reservations.length, 1, reason: 'one booking, not two');
  });
}
