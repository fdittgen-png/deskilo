// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4173 (B3) -- the end of the goods walkthrough, through the real routed app at a phone and a desk width, by the
// screens: from the Demo's delivery of 54 mugs, three are taken out, one of them is put back by a correction (the take-out's
// page), four go back to the supplier (the delivery's page), one of the two mugs the shop sold from its shelf comes back
// from the customer to the shelf (the sale's page), and a count of the beans corrects the book. After every step each
// place's quantity equals the signed sum of its movements, and the movements list says what each was (a take-out, a
// correction, a supplier return, a customer return, an adjustment). No payment is made by a return: the sheet says so.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
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

/// Every on-hand row equals the signed sum of the movements that touch its item and place.
Future<void> _reconciled(ProviderContainer c) async {
  final queries = c.read(stockQueriesProvider);
  final onHand = (await queries.onHandPage(demoFirstSpaceId, limit: 200)).rows;
  final moves = (await queries.movementsPage(demoFirstSpaceId, limit: 200)).rows;
  for (final row in onHand) {
    var sum = row.quantity - row.quantity;
    for (final m in moves) {
      if (m.itemId != row.itemId || m.variantId != row.variantId) continue;
      if (m.toLocationId == row.locationId) sum = sum + m.quantity;
      if (m.fromLocationId == row.locationId) sum = sum - m.quantity;
    }
    expect(sum.text, row.quantity.text, reason: '${row.itemName} at ${row.locationCode}');
  }
}

Future<String> _quantity(ProviderContainer c, String item, String place) async {
  final rows = (await c.read(stockQueriesProvider).onHandPage(demoFirstSpaceId, itemId: item, limit: 200)).rows;
  return rows.where((r) => r.locationId == place).map((r) => r.quantity.text).firstOrNull ?? '0';
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 2400)), ('desk', const Size(1440, 2400))]) {
    testWidgets('on a $name: a take-out, a correction, a supplier return, a customer return and a count, each reconciled', (tester) async {
      final container = await _open(tester, size);
      final router = container.read(routerProvider);
      await _reconciled(container);

      // three mugs are taken out
      router.go('/stock/transfers');
      await _frames(tester);
      await _tap(tester, find.byKey(const ValueKey('stock-takeout-open')));
      await _choose(tester, 'stock-move-item', 'Mugs');
      await _choose(tester, 'stock-move-from', 'MAIN · Main store');
      await tester.enterText(find.byKey(const ValueKey('stock-move-quantity')), '3');
      await _tap(tester, find.byKey(const ValueKey('stock-move-submit')));
      expect(await _quantity(container, 'demo-item-mugs', 'demo-place-main'), '33');
      final takeOut = (await container.read(stockQueriesProvider).movementsPage(demoFirstSpaceId, limit: 1)).rows.single;
      await _reconciled(container);

      // one of the three goes back: a correction of the take-out, from its own page (the place is the take-out's)
      router.go('/stock/movements/${takeOut.id}');
      await _frames(tester);
      await _tap(tester, find.byKey(const ValueKey('stock-reversal-open')));
      expect(find.byKey(const ValueKey('stock-reversal-no-money')), findsOneWidget, reason: 'a correction pays nothing');
      await tester.enterText(find.byKey(const ValueKey('stock-reversal-quantity')), '1');
      await _tap(tester, find.byKey(const ValueKey('stock-reversal-submit')));
      expect(await _quantity(container, 'demo-item-mugs', 'demo-place-main'), '34');
      await _reconciled(container);

      // four go back to the supplier: the delivery's page
      router.go('/stock/movements/demo-stock-movement-3');
      await _frames(tester);
      await _tap(tester, find.byKey(const ValueKey('stock-reversal-open')));
      await _choose(tester, 'stock-move-place', 'MAIN · Main store');
      await tester.enterText(find.byKey(const ValueKey('stock-reversal-quantity')), '4');
      await _tap(tester, find.byKey(const ValueKey('stock-reversal-submit')));
      expect(await _quantity(container, 'demo-item-mugs', 'demo-place-main'), '30');
      expect(find.textContaining(_en.stockReversalKindSupplier), findsOneWidget);
      await _reconciled(container);

      // one of the two mugs sold from the shelf comes back from the customer, to the shelf: the sale's page
      expect(await _quantity(container, 'demo-item-mugs', 'demo-place-shelf'), '10');
      router.go('/stock/movements/demo-stock-movement-9');
      await _frames(tester);
      expect(find.text(_en.stockReversalCustomerOpen), findsOneWidget, reason: 'a sale is returned by its customer');
      await _tap(tester, find.byKey(const ValueKey('stock-reversal-open')));
      expect(find.byKey(const ValueKey('stock-reversal-no-money')), findsOneWidget, reason: 'a customer return refunds nothing');
      await _choose(tester, 'stock-move-place', 'SHELF-A · Shelf A');
      await tester.enterText(find.byKey(const ValueKey('stock-reversal-quantity')), '1');
      await _tap(tester, find.byKey(const ValueKey('stock-reversal-submit')));
      expect(await _quantity(container, 'demo-item-mugs', 'demo-place-shelf'), '11');
      expect(await _quantity(container, 'demo-item-mugs', 'demo-place-main'), '30', reason: 'the return names the shelf, not the store');
      expect(find.textContaining(_en.stockReversalKindCustomer), findsOneWidget);
      final customerReturn = (await container.read(stockQueriesProvider).movementsPage(demoFirstSpaceId, limit: 1)).rows.single;
      expect(
        (customerReturn.reason, customerReturn.fromLocationId, customerReturn.toLocationId, customerReturn.quantity.text),
        ('return_in', 'demo-place-customer', 'demo-place-shelf', '1'),
      );
      await _reconciled(container);
      router.go('/stock/movements');
      await _frames(tester);
      final returnTile = find.byKey(ValueKey('stock-movement-${customerReturn.id}'));
      expect(returnTile, findsOneWidget, reason: 'the movements list shows the return first');
      expect(find.descendant(of: returnTile, matching: find.textContaining('CUSTOMER →')), findsOneWidget);

      // a count of the beans corrects the book
      router.go('/stock/counts');
      await _frames(tester);
      await _tap(tester, find.byKey(const ValueKey('stock-count-open')));
      await _choose(tester, 'stock-move-item', 'Coffee beans');
      await _choose(tester, 'stock-move-place', 'MAIN · Main store');
      await tester.enterText(find.byKey(const ValueKey('stock-count-observed')), '10');
      await _tap(tester, find.byKey(const ValueKey('stock-count-submit')));
      expect(await _quantity(container, 'demo-item-beans', 'demo-place-main'), '12.5', reason: 'a count moves nothing until it is approved');
      final apply = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('stock-count-apply-'));
      await _tap(tester, apply.first);
      expect(await _quantity(container, 'demo-item-beans', 'demo-place-main'), '10');
      await _reconciled(container);

      final reasons = [for (final StockMovementRow m in (await container.read(stockQueriesProvider).movementsPage(demoFirstSpaceId, limit: 6)).rows) m.reason];
      expect(reasons, containsAll(['adjustment', 'return_out', 'return_in']));
      expect(reasons.where((r) => r == 'consumption' || r == 'correction' || r == 'return_in').length, greaterThanOrEqualTo(1));
    });
  }
}
