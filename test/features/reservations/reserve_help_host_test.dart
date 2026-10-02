// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1853 A — the Reserve hub shows ONE help card. Before, the tip carousel
// (formHelpHints, #606) and the Get started card (memberGettingStarted,
// #1654) were two siblings in the header, both eligible for an ordinary
// member, and both rendered. Now one host picks: the current next step
// outranks the generic tips. Dismissals keep their own keys; nothing is
// re-enabled by the merge, and the plan stays usable.
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'getting_started_card_test.dart' show pumpCard;
import 'reserve_hub_test.dart' show seatCenter;

const _gettingStarted = ValueKey('getting-started-card');
const _tips = ValueKey('help-hint-reserve');

int _cards() =>
    find.byKey(_gettingStarted).evaluate().length +
    find.byKey(_tips).evaluate().length;

void main() {
  testWidgets('both old features eligible: exactly one card, the next step, '
      'and the plan still books', (tester) async {
    await pumpCard(
      tester,
      featureFlags: {'formHelpHints': true, 'memberGettingStarted': true},
    );
    expect(_cards(), 1, reason: 'one form-aware host, not two help systems');
    expect(
      find.byKey(_gettingStarted),
      findsOneWidget,
      reason: 'the current step outranks the generic tips',
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.byType(BookingSheet), findsOneWidget);
  });

  testWidgets('the four old flag combinations each keep their meaning', (
    tester,
  ) async {
    for (final (tips, start, expected) in [
      (true, true, _gettingStarted),
      (true, false, _tips),
      (false, true, _gettingStarted),
      (false, false, null),
    ]) {
      await pumpCard(
        tester,
        featureFlags: {'formHelpHints': tips, 'memberGettingStarted': start},
      );
      final label = 'formHelpHints=$tips memberGettingStarted=$start';
      expect(_cards(), expected == null ? 0 : 1, reason: label);
      if (expected != null) {
        expect(find.byKey(expected), findsOneWidget, reason: label);
      }
    }
  });

  testWidgets('Not now hands the slot to the tips without touching their '
      'dismissal; a dismissed tip carousel stays dismissed', (tester) async {
    final hub = await pumpCard(
      tester,
      featureFlags: {'formHelpHints': true, 'memberGettingStarted': true},
    );
    await tester.tap(find.byKey(const ValueKey('getting-started-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(_gettingStarted), findsNothing);
    expect(find.byKey(_tips), findsOneWidget);
    expect(hub.hints.dismissed.where((k) => k == 'reserve'), isEmpty);

    await tester.tap(find.byKey(const ValueKey('help-hint-dismiss-reserve')));
    await tester.pumpAndSettle();
    expect(_cards(), 0);
    expect(hub.hints.dismissed, contains('reserve'));
    expect(
      hub.hints.dismissed.where((k) => k.startsWith('getting-started:')),
      hasLength(1),
    );
  });
}
