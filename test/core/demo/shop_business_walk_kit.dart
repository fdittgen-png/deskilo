// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4365 (PR B) -- the walk behind demo_shop_business_journey_test.dart (a phone) and
// demo_shop_business_desk_journey_test.dart (a desk), one file each because the Demo keeps state between two walks
// in one process: Bruno enters the Épicerie du Marché from My spaces, finds goods already in its stock (the four
// items, not the first-run page), moves three mugs to a shelf by the screens, and the movement shows in THIS
// business's ledger (its own, mirrored from the reference business's: nothing else moved).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;

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

Future<void> _choose(WidgetTester tester, String key, String text) async {
  await _tap(tester, find.byKey(ValueKey(key)));
  await tester.tap(find.text(text).last);
  await _frames(tester);
}

Future<void> walkShopBusiness(WidgetTester tester, Size size) async {
  await pumpDemo(tester, persona: DemoPersona.member, openHub: false, size: size);
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first))..go('/me');
  await _frames(tester);
  final space = find.byKey(const ValueKey('me-space-ws-11'));
  await tester.scrollUntilVisible(space, 300, scrollable: find.byType(Scrollable).first);
  await _tap(tester, space);
  final container = ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));

  router.go('/stock');
  await _frames(tester);
  expect(find.byKey(const ValueKey('stock-first-run')), findsNothing, reason: 'the shop already keeps goods');
  final queries = container.read(stockQueriesProvider);
  final before = (await queries.movementsPage(demoShopSpaceId, limit: 200)).rows.length;
  expect(before, greaterThan(0), reason: 'its own ledger holds movements');

  router.go('/stock/transfers');
  await _frames(tester);
  await _tap(tester, find.byKey(const ValueKey('stock-move-open')));
  await _choose(tester, 'stock-move-item', 'Mugs');
  await _choose(tester, 'stock-move-from', 'MAIN · Main store');
  await _choose(tester, 'stock-move-to', 'MAIN-SHELF-A · Shelf A');
  await tester.enterText(find.byKey(const ValueKey('stock-move-quantity')), '3');
  await _tap(tester, find.byKey(const ValueKey('stock-move-submit')));
  final after = (await container.read(stockQueriesProvider).movementsPage(demoShopSpaceId, limit: 200)).rows;
  expect(after.length, before + 1, reason: 'the move is in the shop\'s ledger');
  expect(router.routeInformationProvider.value.uri.path, isNot('/reserve'));
}
