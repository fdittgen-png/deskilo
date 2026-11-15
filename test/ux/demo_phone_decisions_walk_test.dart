// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4055 — the Demo on a phone: the calendar's view bar and date come first,
// the decisions waiting are one row "Decisions (n)", the row opens the
// Alerts view, and a decision accepted there is recorded (it leaves the
// list once its quorum is reached).
import 'package:deskilo/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart' show pumpDemo;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

int _decisions(WidgetTester tester) => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'pending-decisions-section-event-accept-',
          ),
      skipOffstage: false,
    )
    .evaluate()
    .length;

void main() {
  testWidgets('on a phone the decisions are one row that opens Alerts, '
      'where one is accepted', (tester) async {
    const size = Size(390, 844);
    final journey = await pumpDemo(tester, openHub: false, size: size);
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .go('/calendar');
    await _settle(tester);

    for (final key in ['calendar-view-switch', 'calendar-date-button']) {
      expect(
        tester.getRect(find.byKey(ValueKey(key)).first).bottom,
        lessThanOrEqualTo(size.height),
        reason: '$key comes first',
      );
    }
    expect(find.byKey(const ValueKey('pending-decisions')), findsNothing);
    final entry = find.byKey(const ValueKey('calendar-decisions-entry'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await _settle(tester);

    expect(
      _decisions(tester),
      greaterThan(0),
      reason: 'the Demo has decisions',
    );
    final accept = find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'pending-decisions-section-event-accept-',
              ),
        )
        .first;
    final id = (tester.widget(accept).key! as ValueKey<String>).value.substring(
      'pending-decisions-section-event-accept-'.length,
    );
    // Centred: at the end of the view the bottom bar covers the row.
    await Scrollable.ensureVisible(tester.element(accept), alignment: 0.5);
    await _settle(tester);
    await tester.tap(accept);
    await _settle(tester);
    expect(
      journey.fixture.events.decisions.where(
        (d) => d.eventId == id && d.accept,
      ),
      isNotEmpty,
      reason: 'the acceptance is recorded',
    );
  });
}
