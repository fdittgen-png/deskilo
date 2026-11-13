// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3832 - the Demo user sees Leipzig, Zurich and Milan in My spaces, enters
// each by a tap, and finds that space's own money in its own currency. The
// expected amounts come from the seed's facts, worked by hand below:
//
// A member's monthly invoice is 18000 (half-time) or 36000 (full-time) plus
// nine catalogue items at the prices 250, 200, 150, 200, 400, 15, 50, 20, 500
// in the quantities (i+m)%5, (i+m)%3, (2i+m)%6, (i+m)%4, (i+m)%3, (3i+m)%25,
// (i+m)%8, (i+m)%6, (i+m)%2 for the member's place i in the list and the
// month m. The Demo opens on 13 May 2026, so the last billed month is April
// and the one still open is Bruno's March (i = 1, half-time):
//   4*250 + 1*200 + 5*150 + 0*200 + 1*400 + 6*15 + 4*50 + 4*20 + 0*500
//   = 2720, plus 18000 = 20720  ->  207.20 in the city's currency.
// Ada's (i = 0, full-time) April invoice is paid:
//   4*250 + 1*200 + 4*150 + 0 + 1*400 + 4*15 + 4*50 + 4*20 + 0 = 2540,
//   plus 36000 = 38540  ->  385.40.
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/screens/demo_journeys.dart' show pumpDemo;

const _openMarch = 20720;
const _adaApril = 38540;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

bool _text(String text) =>
    find.textContaining(text, skipOffstage: false).evaluate().isNotEmpty;

String _money(String currency, int minor) =>
    MoneyFormat(currency, locale: null, spaceAlphabetic: true, distinct: true)
        .formatMinor(minor);

void main() {
  testWidgets('the Demo user enters Leipzig, Zurich and Milan from My spaces',
      (tester) async {
    await pumpDemo(tester);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/me');
    await _settle(tester);

    const spaces = [
      ('ws-2', 'Kontorhaus Plagwitz', null, 'Europe/Berlin'),
      ('ws-5', 'Limmat Cowork Zurich', 'CHF', 'Europe/Zurich'),
      ('ws-6', 'Navigli Coworking Milano', 'EUR', 'Europe/Rome'),
    ];
    for (final (id, name, _, _) in spaces) {
      expect(find.text(name, skipOffstage: false), findsOneWidget, reason: name);
      expect(find.byKey(ValueKey('me-space-$id'), skipOffstage: false),
          findsOneWidget);
    }

    for (final (id, name, currency, zone) in spaces) {
      router.go('/me');
      await _settle(tester);
      final tile = find.byKey(ValueKey('me-space-$id'));
      await tester.scrollUntilVisible(tile, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(tile);
      await _settle(tester);
      // No refusal: the shell is in the space the tile names.
      expect(router.routeInformationProvider.value.uri.path, '/reserve',
          reason: name);
      expect(_text('($zone)'), isTrue, reason: '$name: the shell is on its clock');

      router.go('/invoices');
      await _settle(tester);
      expect(find.byKey(const ValueKey('invoicing-home')), findsOneWidget,
          reason: name);
      if (currency != null) {
        expect(_text(_money(currency, _openMarch)), isTrue,
            reason: '$name: March, the one open invoice');
      }
    }
  });

  testWidgets('Me lists the Demo user\'s own paid documents in francs and euros, '
      'never added', (tester) async {
    await pumpDemo(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/account-activity');
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('finances-tab-paid')));
    await _settle(tester);
    // Amounts wait behind a reveal (the currency stays): open Ada's April
    // invoice of Zurich and of Milan, her own, by the key the seed gives it.
    for (final (id, currency) in [
      ('ch-invoice-2026-04-0', 'CHF'),
      ('it-invoice-2026-04-0', 'EUR'),
    ]) {
      final amount = find.byKey(ValueKey('finances-amount-$id'));
      await tester.scrollUntilVisible(amount, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(amount);
      await tester.pump();
      expect(_text(_money(currency, _adaApril)), isTrue, reason: id);
    }
    // The two are never one figure: no text carries both currencies.
    final both = find
        .byType(Text, skipOffstage: false)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((t) => t.contains('CHF') && (t.contains('€') || t.contains('EUR')));
    expect(both, isEmpty);
  });
}
