// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350 -- a NEW item made from the Stock page in the Demo's reference business, at a phone and a desk
// width, by the screens: the owner chooses "Create a new item", fills its name, price, unit and barcode and
// saves (the service and its stock settings together); the item is then ordered (a purchase order for it),
// its delivery received and put away from the order's page, and moved to a shelf.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

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
    testWidgets('on a $name: a new item from the Stock page is ordered, received and moved to a shelf', (tester) async {
      final container = await _open(tester, size);
      final router = container.read(routerProvider)..go('/stock/items');
      await _frames(tester);
      await _tap(tester, find.byKey(const ValueKey('stock-item-add')));
      await _tap(tester, find.byKey(const ValueKey('stock-item-new')));
      await tester.enterText(find.byKey(const ValueKey('stock-new-item-name')), 'Oat bar');
      await tester.enterText(find.byKey(const ValueKey('stock-new-item-price')), '2.50');
      await tester.enterText(find.byKey(const ValueKey('stock-new-item-barcode')), '7612345678900');
      await _tap(tester, find.byKey(const ValueKey('stock-new-item-save')));
      final items = await container.read(stockQueriesProvider).items(demoFirstSpaceId);
      final item = items.where((i) => i.name == 'Oat bar').firstOrNull;
      expect(item, isNotNull, reason: 'the service and its stock settings were saved together');
      expect(item!.unit, 'piece');

      // an order for it, sent
      final orders = container.read(purchaseOrderRepositoryProvider) as FakePurchaseOrderRepository;
      final supplier = orders.suppliers().firstWhere((s) => s.isActive);
      final saved = await orders.save(
        demoFirstSpaceId,
        'req-oat-order',
        PurchaseOrderDraft(
          supplierId: supplier.id,
          lines: [PurchaseOrderLineDraft(serviceId: item.id, description: 'Oat bar', quantity: 12, unit: 'piece', unitPriceCents: 100)],
        ),
      );
      final sent = await orders.markSent(demoFirstSpaceId, saved.id, saved.revision, 'req-oat-sent');

      // received and put away by the order's page
      router.go('/money/purchase-orders/order/${sent.id}');
      await _frames(tester);
      await _tap(tester, find.byKey(ValueKey('purchase-order-receive-${sent.reference}')));
      await tester.enterText(find.byKey(const ValueKey('purchase-order-receive-line-1')), '12');
      await _tap(tester, find.byKey(const ValueKey('purchase-order-receive-also')));
      await _tap(tester, find.byKey(const ValueKey('purchase-order-receive-confirm')));
      final onHand = await container.read(stockQueriesProvider).onHandPage(demoFirstSpaceId, itemId: item.id);
      expect(onHand.rows.fold<num>(0, (n, r) => n + num.parse(r.quantity.text)), 12, reason: 'the 12 are on hand');

      // moved to a shelf
      router.go('/stock/transfers');
      await _frames(tester);
      await _tap(tester, find.byKey(const ValueKey('stock-move-open')));
      await _choose(tester, 'stock-move-item', 'Oat bar');
      await _choose(tester, 'stock-move-from', onHand.rows.first.locationCode == 'MAIN' ? 'MAIN · Main store' : onHand.rows.first.locationCode);
      await _choose(tester, 'stock-move-to', 'MAIN-SHELF-A · Shelf A');
      await tester.enterText(find.byKey(const ValueKey('stock-move-quantity')), '5');
      await _tap(tester, find.byKey(const ValueKey('stock-move-submit')));
      final after = await container.read(stockQueriesProvider).onHandPage(demoFirstSpaceId, itemId: item.id);
      final onShelf = after.rows.where((r) => r.locationCode == 'SHELF-A').fold<num>(0, (n, r) => n + num.parse(r.quantity.text));
      expect(onShelf, 5, reason: 'five were moved to the shelf');
    });
  }
}
