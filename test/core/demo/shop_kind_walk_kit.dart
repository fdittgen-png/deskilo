// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4365 (G16) -- the walk behind demo_shop_kind_journey_test.dart (a phone) and
// demo_shop_kind_desk_journey_test.dart (a desk), one file each because the Demo keeps state between two
// walks in one process: a new shop owner, in the Demo, at a phone and a desk width: Bruno owns Kessler Conseil, a
// business of the kind freelancer with no stock. He opens the business settings, changes its kind to Shop, chooses
// the type Bakery, reads what the kind proposes (the stock among it), saves, and finds the Stock page, which says
// "Add your first place" because nothing is there yet. Nothing is typed into a database: the kind, the type and the
// features are the ones the app's own commands write.
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;

final _en = AppLocalizationsEn();

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _frames(tester);
}

Future<void> walkShopKind(WidgetTester tester, Size size) async {
  await pumpDemo(tester, persona: DemoPersona.member, openHub: false, size: size);
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first))..go('/me');
  await _frames(tester);
  final space = find.byKey(const ValueKey('me-space-ws-10'));
  await tester.scrollUntilVisible(space, 300, scrollable: find.byType(Scrollable).first);
  await _tap(tester, space);
  router.go('/workspace-settings');
  await _frames(tester);
  await _frames(tester);
  await _tap(tester, find.descendant(of: find.byKey(const ValueKey('business-kind-tile')), matching: find.text(_en.settingLabelBusinessKind)));
  // the kinds and the profile are read before the sheet opens
  await _frames(tester);
  await _frames(tester);
  final shop = find.byKey(const ValueKey('business-kind-shop'));
  await tester.scrollUntilVisible(shop, 200, scrollable: find.byType(Scrollable).last);
  expect(shop, findsOneWidget);
  await _tap(tester, shop);
  await _tap(tester, find.byKey(const ValueKey('business-kind-shop-type')));
  await tester.tap(find.text(_en.shopTypeBakery).last);
  await _frames(tester);
  // the stock asks for consent: the owner reads it among the proposals and ticks it
  final consent = find.byKey(const ValueKey('business-kind-consent-stockManagement'));
  await tester.scrollUntilVisible(consent, 200, scrollable: find.byType(Scrollable).last);
  await _tap(tester, consent);
  await _tap(tester, find.byKey(const ValueKey('business-kind-save')));

  router.go('/stock');
  await _frames(tester);
  expect(find.byKey(const ValueKey('stock-first-run')), findsOneWidget, reason: 'a new shop has no place and no item yet');

}
