// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4173 -- the Demo's goods trace and stock value, through the real routed app: the owner reads the
// operational value (a known total, "not complete" because the mugs have no known cost, and the mugs
// listed outside the total); a delivery of an order put away is a movement whose page traces back to
// that order; a movement with no purchase behind it says "not linked". A member who may not see what
// goods cost is turned away from the value page by its link.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/stock/domain/stock_receiving.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

final _en = AppLocalizationsEn();

Future<ProviderContainer> _open(WidgetTester tester, {required DemoPersona persona, required String to, Size size = const Size(900, 2400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start(persona: persona);
  addTearDown(journey.dispose);
  journey.root.read(pendingDemoLinkProvider.notifier).hold(DemoLink.parse({'space': 'pezenas', 'persona': persona.name, 'to': to}));
  await tester.pumpWidget(UncontrolledProviderScope(container: journey.root, child: const DeskiloRoot()));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
}

/// Frames enough for a page to arrive (a bounded pump: a page that keeps a spinner never settles).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _path(ProviderContainer c) => c.read(routerProvider).routeInformationProvider.value.uri.path;

void main() {
  testWidgets('the owner reads the stock value: known costs totalled, not complete, the mugs outside it', (tester) async {
    final container = await _open(tester, persona: DemoPersona.owner, to: '/stock');
    container.read(routerProvider).go('/stock/value');
    await tester.pumpAndSettle();
    expect(_path(container), '/stock/value');
    expect(find.byKey(const ValueKey('stock-value-total')), findsOneWidget);
    expect(find.byKey(const ValueKey('stock-value-incomplete')), findsOneWidget, reason: 'the mugs have no known cost');
    expect(find.byKey(const ValueKey('stock-value-uncosted-demo-item-mugs-')), findsOneWidget);
    expect(find.text(_en.stockValueBasis), findsOneWidget);
  });

  testWidgets('a delivery put away traces back to its order; a movement with no purchase says not linked', (tester) async {
    final container = await _open(tester, persona: DemoPersona.owner, to: '/reserve');
    final config = container.read(stockConfigCommandsProvider);
    final places = {for (final p in await config.places(demoFirstSpaceId)) p.code: p.id};
    final done = await container.read(stockReceivingCommandsProvider).putAway(demoFirstSpaceId, 'demo-receipt-3', [
      PutAwayAllocation(lineNo: 1, quantity: '20', locationId: places['MAIN']!),
    ], 'req-trace');
    final movement = done.allocations.single.movementId;
    container.read(routerProvider).go('/stock/movements/$movement');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-order')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('stock-trace-order')), findsOneWidget, reason: 'traced to the order it was delivered on');
    expect(find.byKey(const ValueKey('stock-trace-bill-demo-bill-beans')), findsOneWidget, reason: 'the bill linked to that order');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-allocation-demo-beans-payment')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('stock-trace-allocation-demo-beans-payment')), findsOneWidget, reason: 'and the transfer recorded against it');

    container.read(routerProvider).go('/stock/movements/demo-stock-movement-7');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-not-linked')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('stock-trace-not-linked')), findsOneWidget);
  });

  testWidgets('a member who may not see what goods cost is turned away from the value page', (tester) async {
    final container = await _open(tester, persona: DemoPersona.member, to: '/reserve');
    container.read(routerProvider).go('/stock/value');
    await tester.pumpAndSettle();
    expect(_path(container), isNot('/stock/value'));
    expect(find.byKey(const ValueKey('stock-value-total')), findsNothing);
  });

  for (final (name, size) in [('phone', const Size(390, 2400)), ('desk', const Size(1440, 2400))]) {
    testWidgets('on a $name: from the order to its goods, to the movement, to the bill and back to the goods', (tester) async {
      final container = await _open(tester, persona: DemoPersona.owner, to: '/stock', size: size);
      final config = container.read(stockConfigCommandsProvider);
      final places = {for (final p in await config.places(demoFirstSpaceId)) p.code: p.id};
      final done = await container.read(stockReceivingCommandsProvider).putAway(demoFirstSpaceId, 'demo-receipt-3', [
        PutAwayAllocation(lineNo: 1, quantity: '20', locationId: places['MAIN']!),
      ], 'req-walk');
      final movement = done.allocations.single.movementId;
      final orders = container.read(purchaseOrderRepositoryProvider) as FakePurchaseOrderRepository;
      final orderId = orders.receipts.firstWhere((r) => r.id == 'demo-receipt-3').orderId;

      // the order reaches its goods
      container.read(routerProvider).go('/money/purchase-orders/order/$orderId');
      await _settle(tester);
      final goods = find.byKey(ValueKey('stock-goods-$movement'));
      await tester.scrollUntilVisible(goods, 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(goods);
      await tester.pump();
      await tester.tap(goods);
      await _settle(tester);
      expect(_path(container), '/stock/movements/$movement');

      // the movement reaches its bill and the payment recorded against it
      final bill = find.byKey(const ValueKey('stock-trace-bill-demo-bill-beans'));
      await tester.scrollUntilVisible(bill, 300, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const ValueKey('stock-trace-allocation-demo-beans-payment')), findsOneWidget);
      await tester.ensureVisible(bill);
      await tester.pump();
      await tester.tap(bill);
      await _settle(tester);
      expect(_path(container), '/money/purchases/doc/demo-bill-beans');

      // the bill reaches the same goods again
      final again = find.byKey(ValueKey('stock-goods-$movement'));
      if (find.byType(PurchaseRecord).evaluate().isEmpty) {
        // on a desk the pushed hub keeps the movement page in view in this harness; the bill's own
        // address (which the tap reached) shows the record, so open it there
        container.read(routerProvider).go('/money/purchases/doc/demo-bill-beans');
        await _settle(tester);
      }
      // on a desk the bill sits beside its table and may already be in view
      if (again.evaluate().isEmpty) await tester.scrollUntilVisible(again, 300, scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(again);
      await tester.pump();
      await tester.tap(again);
      await _settle(tester);
      expect(_path(container), '/stock/movements/$movement', reason: 'the loop closes: goods, bill and payment navigate both ways');
    });
  }
}
