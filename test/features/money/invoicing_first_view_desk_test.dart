// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4059 — at desk width the invoicing home keeps its full cards: the debt
// card with its legend and the month's figures, and the open to-do list;
// the compact strip is for narrower windows only.
import 'package:deskilo/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;

void main() {
  testWidgets('at 1440 the full cards stay, and no strip', (tester) async {
    await pumpDemo(tester, openHub: false, size: const Size(1440, 900));
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .go('/invoices');
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('invoicing-owed')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoicing-todo')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoicing-summary')), findsNothing);
  });
}
