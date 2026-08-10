// SPDX-License-Identifier: 0BSD
//
// The kiosk under the presence/one-place rules (#430): the kiosk route
// lives OUTSIDE the shell, so it must arm the realtime invalidator
// itself — and its error mapping must speak the new pinned substrings
// instead of "Something went wrong".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_realtime_sync.dart';
import 'kiosk_screen_test.dart' show pumpKiosk, seatCenter;

void main() {
  testWidgets('the kiosk arms the realtime subscription itself (#430)',
      (tester) async {
    final realtime = FakeRealtimeSync();
    await pumpKiosk(tester, realtime: realtime);
    expect(realtime.watched, contains('ws-1'),
        reason: 'no shell on a kiosk device — the kiosk screen must '
            'subscribe, or phone changes never reach the wall tablet');
  });

  testWidgets(
      'a one-place refusal on the kiosk shows the mapped message, not '
      '"Something went wrong"', (tester) async {
    await pumpKiosk(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-check-in')));
    await tester.pumpAndSettle();

    // The busy-badge sentinel mirrors the 0079 trigger refusing a
    // walk-up while the badge member is active elsewhere.
    await tester.enterText(
      find.byKey(const ValueKey('kiosk-badge-field')),
      'busy-badge',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('one place at a time'),
      findsOneWidget,
      reason: 'the kiosk error switch delegates to bookingErrorText now',
    );
    expect(find.textContaining('Something went wrong'), findsNothing);
  });
}
