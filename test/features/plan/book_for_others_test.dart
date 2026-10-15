// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #106 — owners book a seat for another member; booking for yourself stays
// a walk-up; workers get no picker.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/book_for_others.dart' show pumpPlanWithRoster;
import '../../helpers/screens/plan_screen.dart' show chooseCheckInNow, seatCenter;



void main() {
  testWidgets('an owner books a seat for another member (#106)',
      (tester) async {
    final env = await pumpPlanWithRoster(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    // The admin-only picker defaults to self.
    await tester.ensureVisible(find.byKey(const ValueKey('booking-for-member')));
    await tester.tap(find.byKey(const ValueKey('booking-for-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Lima').last);
    await tester.pumpAndSettle();

    // Booking for someone else is a confirmation request, not a check-in.
    expect(find.widgetWithText(FilledButton, 'Check in'), findsNothing);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send for confirmation'),
    );
    await tester.pumpAndSettle();

    final call = env.reservations.bookedForOthers.single;
    expect(call.subjectMemberId, 'member-2');
    expect(call.seatId, 'seat-4');
    expect(
      find.text('Sent to Ana Lima for confirmation.'),
      findsOneWidget,
    );
  });

  testWidgets('booking for yourself through the picker stays a walk-up',
      (tester) async {
    final env = await pumpPlanWithRoster(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await chooseCheckInNow(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    expect(env.reservations.bookedForOthers, isEmpty);
    expect(env.reservations.reservations.single.memberId, 'member-1');
  });

  testWidgets('workers get no member picker', (tester) async {
    await pumpPlanWithRoster(tester, viewerIsOwner: false);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.text('Book for'), findsNothing);
  });
}
