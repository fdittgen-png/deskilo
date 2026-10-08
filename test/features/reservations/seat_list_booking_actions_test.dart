// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A list seat has the same booking consumer as its plan counterpart;
// feedback targets must never replace the row's primary action (#2268).
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/reservations/presentation/widgets/place_feedback_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reserve_hub_test.dart' show pumpHub;

void main() {
  testWidgets('free list-seat body opens booking, feedback stays separate',
      (tester) async {
    final repo = await pumpHub(tester);
    await tester.tap(find.byKey(const ValueKey('reserve-seat-view-switch')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('list-seat-seat-4'));
    await tester.tap(find.descendant(of: row, matching: find.text('A1')));
    await tester.pumpAndSettle();
    expect(find.byType(BookingSheet), findsOneWidget);
    expect(repo.createCalls, 0);
    Navigator.of(tester.element(find.byType(BookingSheet))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PlaceFeedbackChip.rateKey('seat-4')));
    await tester.pumpAndSettle();
    expect(find.byType(BookingSheet), findsNothing);
    expect(find.byKey(PlaceFeedbackBar.starKey('seat-4', 5)), findsOneWidget);
    expect(repo.createCalls, 0);
  });

  testWidgets('free list seats have a visible booking action', (tester) async {
    final repo = await pumpHub(tester);
    await tester.tap(find.byKey(const ValueKey('reserve-seat-view-switch')));
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('list-seat-action-seat-4'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(BookingSheet), findsOneWidget);
    expect(repo.createCalls, 0);
    await tester.tap(find.byKey(const ValueKey('booking-confirm')));
    await tester.pumpAndSettle();
    expect(repo.createCalls, 1);
    expect(repo.reservations.single.seatId, 'seat-4');
    expect(find.byType(BookingSheet), findsNothing);
    expect(find.textContaining('Yours'), findsWidgets);
  });

  testWidgets('list actions fit on a narrow screen at large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHub(tester, size: const Size(360, 640));
    final toggle = find.byKey(const ValueKey('reserve-seat-view-switch'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final action = find.byKey(const ValueKey('list-seat-action-seat-4'));
    await tester.scrollUntilVisible(action, 100, scrollable: find.descendant(
        of: find.byKey(const ValueKey('reserve-list-view')),
        matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(BookingSheet), findsOneWidget);
  });
}
