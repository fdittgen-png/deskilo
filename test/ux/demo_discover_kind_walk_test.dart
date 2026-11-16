// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3554 PR 1 — the Demo walked on Discover: a search for "massage" finds the
// practice near Atelier du Marché by its service, and the Practices chip
// finds it without a word typed, Atelier left out. Its card names its kind,
// its town and three of its four services, each in euros with its own tax
// word, beside the Zurich house's francs: nothing added or converted.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart';
import '../helpers/screens/desk_calendar.dart' show goTo;

void main() {
  testWidgets('"massage" finds the Demo practice by its service; the Practices '
      'chip finds it alone', (tester) async {
    await pumpDemo(tester, openHub: false, size: const Size(1440, 1600));
    await goTo(tester, '/discover');

    await tester.enterText(
      find.byKey(const ValueKey('directory-portal-search-2')),
      'massage',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Cabinet Garrigue'), findsOneWidget);
    expect(find.text('Atelier du Marché'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('directory-portal-search-2')),
      '',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('directory-kind-practice')));
    await tester.pumpAndSettle();

    expect(find.text('Cabinet Garrigue'), findsOneWidget);
    expect(find.text('Atelier du Marché'), findsNothing);
    expect(find.text('Pézenas · Practice'), findsOneWidget);
    expect(find.textContaining('Relaxing massage · 60 min · '), findsOneWidget);
    expect(find.textContaining('· no tax'), findsNWidgets(3));
    expect(find.textContaining('Five massages'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('directory-kind-all')));
    await tester.pumpAndSettle();
    final zurich = tester
        .widget<Text>(find.textContaining('Hot desk day'))
        .data!;
    expect(zurich, contains('CHF'));
  });
}
