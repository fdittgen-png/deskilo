// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 (B) -- the walk behind demo_freelancer_customer_walk_test.dart (a
// phone) and demo_freelancer_customer_desk_walk_test.dart (a desk): Ada opens
// Me › Finances and finds, apart from what she owes herself, the invoice
// Kessler Conseil made out to Lindner Beratung, read through the grant she
// accepted, and not the invoice of another of its customers.
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/screens/demo_journeys.dart' show pumpDemo;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// The card's key names the business qualified by its installation.
final _card = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('billed-open-') &&
      (w.key! as ValueKey<String>).value.endsWith(
        'ws-10-kessler-customer-lindner',
      ),
  skipOffstage: false,
);

Future<void> walkLindnerReads(WidgetTester tester, Size size) async {
  // The Demo starts as Ada, the owner of the head and of the practice.
  expect(initialDemoPersona, DemoPersona.owner);
  await pumpDemo(tester, openHub: false, size: size);
  GoRouter.of(tester.element(find.byType(Scaffold).first))
      .go('/me/data?view=finances');
  await _settle(tester);

  // The list builds lazily on a phone: scroll it until the card is built.
  final card = _card;
  for (var i = 0; i < 30 && card.evaluate().isEmpty; i++) {
    final lists = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    if (lists.evaluate().isEmpty) break;
    await tester.drag(lists.last, const Offset(0, -300), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(card, findsOneWidget, reason: 'read through her grant');
  await tester.ensureVisible(card);
  await tester.pump();
  expect(
    tester.widget<Text>(card).data,
    AppLocalizationsEn().billingAccessGroupSettled,
    reason: 'the EUR 108.00 is paid: nothing of it is open',
  );
  expect(
    find.byKey(
      const ValueKey('billed-invoice-kessler-a3'),
      skipOffstage: false,
    ),
    findsOneWidget,
  );
  expect(
    find.textContaining('KC-2026-0003', skipOffstage: false),
    findsOneWidget,
  );
  expect(
    find.byKey(
      const ValueKey('billed-invoice-kessler-a2'),
      skipOffstage: false,
    ),
    findsNothing,
    reason: "Chiara's invoice is hers to read, not Ada's",
  );
  expect(tester.takeException(), isNull);
}
