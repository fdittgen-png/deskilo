// SPDX-License-Identifier: 0BSD
//
// #1247 — the UX score, as a build output.
//
// The issue asks for the counterweight to the rest of the #1225
// programme: the backend gets more sophisticated, the interface gets
// LESS. And it names the measurement itself —
//
//   "count the taps from app open to booked, and from app open to a
//    decision made. Those two numbers are the UX score."
//
// So here they are, counted rather than estimated, and ratcheted: a
// number may go DOWN freely and may only go up with a reason in the diff.
// That is the same mechanism as `file_length_test` and `_pairBudget`,
// pointed at the thing a member actually experiences.
//
// A design pass comes before the decision surface the issue proposes
// (and this file is not it). What this does is establish what the paths
// cost TODAY, so the redesign has a number to beat instead of an
// impression to argue with.
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/events/events_screen_test.dart' show pumpEvents, event;
import '../features/reservations/reserve_hub_test.dart'
    show pumpHub, seatCenter;
import 'package:deskilo/features/events/domain/workspace_event.dart';

/// Counts the taps a path costs.
///
/// Every deliberate touch is one, whether it lands on a widget or at a
/// point on the canvas — a member does not care which. Scrolling is not
/// counted: it is a cost, but it is not a decision, and conflating the
/// two would let a redesign "win" by replacing three taps with a long
/// scroll.
class Taps {
  int count = 0;

  Future<void> at(WidgetTester tester, Offset point) async {
    count++;
    await tester.tapAt(point);
    await tester.pumpAndSettle();
  }

  Future<void> on(WidgetTester tester, Finder finder) async {
    count++;
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

void main() {
  // The two numbers. Lower them when a path gets shorter; raising one
  // needs a sentence in the pull request saying what the member got in
  // exchange.
  //
  // Both counts EXCLUDE the tap that opens the destination from the
  // shell, because the pump helpers do it — and the app boots onto the
  // hub anyway, so for booking it is not a real tap at all. Each test
  // says what it is counting.
  const bookingBudget = 2;
  const decisionBudget = 1;

  testWidgets('app open to booked: the member takes the default window '
      'and taps the seat', (tester) async {
    // pumpHub boots the app and presses Reserve — the destination the
    // app already opens on.
    final repo = await pumpHub(tester);
    final taps = Taps();

    await taps.at(tester, seatCenter(tester));
    expect(find.byType(BookingSheet), findsOneWidget,
        reason: 'tapping a free seat opens the sheet');

    await taps.on(tester, find.byKey(const ValueKey('booking-confirm')));

    expect(repo.reservations, hasLength(1),
        reason: 'the booking was actually made — a tap budget over a path '
            'that does not complete measures nothing');
    expect(
      taps.count,
      lessThanOrEqualTo(bookingBudget),
      reason: 'booking a seat for the default window took ${taps.count} '
          'taps, budget $bookingBudget. This is the path the app exists '
          'for and the first number of the UX score (#1247). Lower the '
          'budget when it gets shorter; raising it needs a sentence '
          'saying what the member got in exchange.',
    );
  });

  testWidgets('app open to a decision made: the pending thing is pinned, '
      'and deciding it is one tap', (tester) async {
    // pumpEvents boots the app and opens the alerts face — where the
    // bell badge already sends somebody who has something waiting.
    final repo = await pumpEvents(
      tester,
      seed: [
        event(
          actor: 'member-2',
          subject: 'member-1',
          status: EventStatus.pending,
        ),
      ],
    );
    final taps = Taps();

    expect(find.text('Waiting for your confirmation'), findsOneWidget,
        reason: 'the thing needing a decision is PINNED rather than found '
            '— that is what makes the next tap the last one');

    await taps.on(tester, find.text('Accept'));

    expect(repo.events.single.status, EventStatus.confirmed,
        reason: 'the decision actually took effect');
    expect(
      taps.count,
      lessThanOrEqualTo(decisionBudget),
      reason: 'deciding a pending request took ${taps.count} taps, budget '
          '$decisionBudget. This is the second number of the UX score '
          '(#1247): what an administrator has to do to clear the thing '
          'that was waiting on them.',
    );
  });

  testWidgets('and the budgets are not vacuous — a path that completes in '
      'ZERO taps would mean the test never exercised it', (tester) async {
    expect(bookingBudget, greaterThan(0));
    expect(decisionBudget, greaterThan(0));
  });
}
