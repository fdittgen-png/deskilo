// SPDX-License-Identifier: 0BSD
//
// #622 — message the reserver from the Plan tab: tapping a seat held by
// ANOTHER member offers opening the conversation with them, the
// composer seeded with the blocking reservation's [res:] reference.
// Regular members get it instead of the dead-end info snack; admins get
// it ON TOP of their existing check-in/overrule actions. The affordance
// rides the messaging feature's own flag (memberNotifications).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plan_screen_test.dart'
    show pumpPlan, seatCenter, foreignReservation;

void main() {
  testWidgets(
      'a REGULAR member tapping another member\'s seat gets the '
      '"Message Ana Lima" sheet; the conversation opens seeded with '
      'the [res:] reference', (tester) async {
    await pumpPlan(
      tester,
      regularMember: true,
      seedReservations: (repo) =>
          repo.reservations.add(foreignReservation()),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    // The sheet still explains who has it…
    expect(find.textContaining('Reserved by Ana'), findsOneWidget);
    // …and offers the message thread.
    final tile = find.byKey(const ValueKey('blocked-message-reserver'));
    expect(tile, findsOneWidget);
    expect(find.textContaining('Message Ana Lima'), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('conversation-sheet')), findsOneWidget);
    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('member-note-body')),
    );
    expect(composer.controller!.text, startsWith('[res:res-foreign|'));
  });

  testWidgets(
      'memberNotifications OFF: the regular member keeps the plain '
      'info snack — no message sheet', (tester) async {
    await pumpPlan(
      tester,
      regularMember: true,
      featureFlags: const {'memberNotifications': false},
      seedReservations: (repo) =>
          repo.reservations.add(foreignReservation()),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reserved by Ana'), findsOneWidget);
    expect(find.byKey(const ValueKey('blocked-message-reserver')),
        findsNothing);
  });

  testWidgets(
      'an ADMIN keeps the existing actions PLUS the message tile; '
      'tapping it opens the conversation', (tester) async {
    await pumpPlan(
      tester,
      seedReservations: (repo) =>
          repo.reservations.add(foreignReservation()),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    // The admin sheet: overrule stays, the message tile joins it.
    expect(find.textContaining('Remove reservation'), findsOneWidget);
    final tile = find.byKey(const ValueKey('admin-message-reserver'));
    expect(tile, findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('conversation-sheet')), findsOneWidget);
    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('member-note-body')),
    );
    expect(composer.controller!.text, contains('[res:res-foreign|'));
  });
}
