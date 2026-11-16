// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4059 — on a tablet held upright (768×844), below desk width, the
// invoicing home sums up in one compact block, so its first customer starts
// inside the first view.
import 'package:deskilo/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;

final _firstCustomer = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      RegExp(r'^invoicing-customer-[^-]')
          .hasMatch((w.key! as ValueKey<String>).value) &&
      !(w.key! as ValueKey<String>).value.contains('-action-') &&
      !(w.key! as ValueKey<String>).value.contains('-panel-'),
  skipOffstage: false,
);

void main() {
  for (final size in const [Size(768, 844)]) {
    testWidgets('at ${size.width.toInt()}×844 the first customer starts in '
        'the first view', (tester) async {
      await pumpDemo(tester, openHub: false, size: size);
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(routerProvider)
          .go('/invoices');
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      // Read whatever the finder's offstage rule says of the route at 768:
      // the page is the one on screen (its bar reads Invoices).
      final home = find.byKey(
        const ValueKey('invoicing-home'),
        skipOffstage: false,
      );
      expect(home, findsOneWidget);
      expect(find.text('Invoices'), findsWidgets);
      expect(
        find.byKey(const ValueKey('invoicing-summary'), skipOffstage: false),
        findsOneWidget,
      );
      expect(_firstCustomer, findsWidgets);
      final top = tester.getTopLeft(_firstCustomer.first).dy;
      expect(
        top,
        lessThan(tester.getRect(home).bottom),
        reason: 'the first customer is in the first view',
      );
    });
  }
}
