// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3286 — a notice belongs to the context it was raised in. In the Demo, a
// visitor books a desk; the booking's notice offers to open it. Once the
// visitor goes to another business, or becomes someone else, that notice
// and its action are gone: an action of the old context never acts in the
// new one.
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart' show pumpDemo;
import '../helpers/screens/reserve_hub.dart' show seatCenter;

const _open = ValueKey('booking-feedback-open-details');

/// Books the seat in the middle of the plan; its notice is on screen.
Future<void> _book(WidgetTester tester) async {
  await tester.tapAt(seatCenter(tester));
  // The plan also listens for a double tap: a single tap lands after it.
  await tester.pump(kDoubleTapTimeout);
  await tester.pumpAndSettle();
  expect(find.byType(BookingSheet), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('booking-confirm')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(
    find.byKey(_open),
    findsOneWidget,
    reason: 'the booking says itself, with the way to open it',
  );
}

void main() {
  testWidgets('a booking\'s notice is gone once the visitor goes to another '
      'business', (tester) async {
    await pumpDemo(tester);
    await _book(tester);

    await tester.tap(find.byKey(const ValueKey('shell-back-to-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-space-$demoSecondSpaceId')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(_open),
      findsNothing,
      reason: 'the old business\'s action cannot open anything in this one',
    );
  });

  testWidgets('a booking\'s notice is gone once the visitor becomes someone '
      'else', (tester) async {
    await pumpDemo(tester);
    await _book(tester);

    // The Demo bar's persona control: the visitor is someone else now.
    await tester.tap(find.byKey(DemoControls.viewAsKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_open), findsNothing);
  });

  testWidgets('a booking\'s notice is gone once the visitor resets the '
      'Demo', (tester) async {
    await pumpDemo(tester);
    await _book(tester);

    await tester.tap(find.byKey(DemoControls.resetKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_open), findsNothing);
  });
}
