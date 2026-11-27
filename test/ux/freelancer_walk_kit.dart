// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 (B) -- the walk behind demo_freelancer_walk_test.dart (a phone) and
// demo_freelancer_desk_walk_test.dart (a desk): Bruno enters Kessler Conseil
// from My spaces, finds the entries of a business with no places on its
// overview (never the booking hub), and each one reaches its page with that
// business's own records: the quote his customer accepted, the three
// customers with no account, and the invoices he issued.
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/screens/demo_journeys.dart' show pumpDemo;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

bool _text(String text) =>
    find.textContaining(text, skipOffstage: false).evaluate().isNotEmpty;

Future<void> walkKessler(WidgetTester tester, Size size) async {
  await pumpDemo(
    tester,
    persona: DemoPersona.member,
    openHub: false,
    size: size,
  );
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first))
    ..go('/me');
  await _settle(tester);
  final tile = find.byKey(const ValueKey('me-space-ws-10'));
  await tester.scrollUntilVisible(
    tile,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(tile);
  await _settle(tester);

  expect(
    router.routeInformationProvider.value.uri.path,
    isNot('/reserve'),
    reason: 'a business with no places does not open on the booking hub',
  );
  final entries = find.byKey(const ValueKey('business-entries'));
  expect(entries, findsOneWidget);
  for (final key in ['quotes', 'engagements', 'customers', 'invoices', 'new-invoice', 'me']) {
    expect(
      find.byKey(ValueKey('business-entry-$key')),
      findsOneWidget,
      reason: key,
    );
  }

  // Each entry leads to its page, with this business's own records.
  Future<void> open(String key, String path) async {
    router.go('/');
    await _settle(tester);
    final entry = find.byKey(ValueKey('business-entry-$key'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await _settle(tester);
    expect(router.routeInformationProvider.value.uri.path, path, reason: key);
  }

  await open('quotes', '/money/quotes');
  // #4492 — one card on a phone, two columns of the records table on a desk
  expect(
    _text('QUO-0001 · Domaine des Aires') || (_text('QUO-0001') && _text('Domaine des Aires')),
    isTrue,
  );
  expect(_text('€642.00'), isTrue, reason: 'the accepted revision 2, VAT included');
  await open('customers', '/money/customers');
  for (final name in ['Domaine des Aires', 'Chiara', 'Lindner Beratung']) {
    expect(_text(name), isTrue, reason: name);
  }
  // the training engagement: done before its invoice, its history whole
  await open('engagements', '/money/engagements');
  expect(_text('3 day · Training day') || _text('Training day'), isTrue);
  expect(_text('Done'), isTrue);
  await tester.tap(find.textContaining('Training day').first);
  await _settle(tester);
  expect(find.byKey(const ValueKey('engagement-step-row-3')), findsOneWidget, reason: 'ordered, started, done');
  expect(find.byKey(const ValueKey('engagement-no-invoice')), findsOneWidget, reason: 'nothing was invoiced yet');
  await open('invoices', '/invoices');
  // the EUR 60.00 invoice is open under its customer, the EUR 108.00 one was
  // received, both in the business's own euros
  await _settle(tester);
  await _settle(tester);
  expect(_text('Chiara Bernard'), isTrue);
  expect(_text('€60.00'), isTrue);
  expect(_text('€108.00'), isTrue);
}
