// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350 -- the goods ledger in the Demo's reference business, through the real routed app at a phone and a
// desk width, by the screens and not by the commands: the owner opens Stock, keeps a service of the
// business in stock as a NEW ITEM, adds a PLACE, receives a delivery of a purchase order into stock,
// moves goods to a shelf and takes one out. Each step shows in the ledger the pages read.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

final _en = AppLocalizationsEn();

Future<ProviderContainer> _open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start();
  addTearDown(journey.dispose);
  journey.root.read(pendingDemoLinkProvider.notifier).hold(DemoLink.parse({'space': 'pezenas', 'persona': 'owner', 'to': '/stock'}));
  await tester.pumpWidget(UncontrolledProviderScope(container: journey.root, child: const DeskiloRoot()));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
}

/// Frames enough for a page or a sheet to arrive (bounded: a page that keeps a spinner never settles).
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

void main() {
  for (final (name, size) in [('phone', const Size(390, 2400)), ('desk', const Size(1440, 2400))]) {
    testWidgets('on a $name: the owner keeps a service as an item, adds a place, receives a delivery, moves goods to a shelf and takes one out', (tester) async {
      final container = await _open(tester, size);
      final router = container.read(routerProvider);
      expect(find.byKey(const ValueKey('stock-first-run')), findsNothing, reason: 'the shop already holds stock');

      // an item: a service of the business that is not kept in stock yet
      router.go('/stock/items');
      await _frames(tester);
      final before = (await container.read(stockQueriesProvider).items(demoFirstSpaceId)).length;
      await _tap(tester, find.byKey(const ValueKey('stock-item-add')));
      final candidate = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('stock-item-candidate-'));
      expect(candidate, findsWidgets, reason: 'the business has services that are not items yet');
      await _tap(tester, candidate.first);
      await _tap(tester, find.byKey(const ValueKey('stock-item-save')));
      final items = await container.read(stockQueriesProvider).items(demoFirstSpaceId);
      expect(items.length, before + 1, reason: 'the service is an item now');

      // a place
      router.go('/stock/places');
      await _frames(tester);
      await _tap(tester, find.byKey(const ValueKey('stock-place-add')));
      await tester.enterText(find.byKey(const ValueKey('stock-place-code')), 'BACK-2');
      await _tap(tester, find.byKey(const ValueKey('stock-place-save')));
      final places = await container.read(stockConfigCommandsProvider).places(demoFirstSpaceId);
      expect(places.any((p) => p.code == 'BACK-2'), isTrue, reason: 'the place was added');

      // a delivery of a purchase order, put away by the screen
      final orders = container.read(purchaseOrderRepositoryProvider) as FakePurchaseOrderRepository;
      final order = orders.orders.firstWhere((o) => o.lines.any((l) => l.serviceId == 'demo-item-beans' && l.receivedQuantity < l.quantity));
      router.go('/money/purchase-orders/order/${order.id}');
      await _frames(tester);
      await _tap(tester, find.byKey(ValueKey('purchase-order-receive-${order.reference}')));
      await tester.enterText(find.byKey(const ValueKey('purchase-order-receive-line-1')), '10');
      await _tap(tester, find.byKey(const ValueKey('purchase-order-receive-also')));
      await _tap(tester, find.byKey(const ValueKey('purchase-order-receive-confirm')));
      final receipts = (await container.read(stockQueriesProvider).movementsPage(demoFirstSpaceId)).rows.where((m) => m.reason == 'receipt').length;
      expect(receipts, greaterThan(1), reason: 'the delivery is put away into stock');

      // goods moved to a shelf, and one taken out
      router.go('/stock/transfers');
      await _frames(tester);
      await _tap(tester, find.byKey(const ValueKey('stock-move-open')));
      await _choose(tester, 'stock-move-item', 'Mugs');
      await _choose(tester, 'stock-move-from', 'MAIN · Main store');
      await _choose(tester, 'stock-move-to', 'MAIN-SHELF-A · Shelf A');
      await tester.enterText(find.byKey(const ValueKey('stock-move-quantity')), '3');
      await _tap(tester, find.byKey(const ValueKey('stock-move-submit')));
      await _tap(tester, find.byKey(const ValueKey('stock-takeout-open')));
      await _tap(tester, find.text(_en.stockTakeOutLoss));
      await _choose(tester, 'stock-move-item', 'Coffee beans');
      await _choose(tester, 'stock-move-from', 'MAIN · Main store');
      await tester.enterText(find.byKey(const ValueKey('stock-move-quantity')), '0.5');
      await _choose(tester, 'stock-move-cause', _en.stockLossCauseDamaged);
      await _tap(tester, find.byKey(const ValueKey('stock-move-submit')));
      final reasons = (await container.read(stockQueriesProvider).movementsPage(demoFirstSpaceId)).rows.map((m) => m.reason).toList();
      expect(reasons.first, 'loss', reason: 'the take-out is the newest movement');
      expect(reasons, contains('transfer'), reason: 'the move to the shelf');
    });
  }
}
