// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4171 (B) -- putting a delivery away into stock on the order's own pane, as a
// buyer who also manages the stock uses it: a partial delivery recorded and put
// away in one go, what remains put away later in parts, never more than arrived
// (said under the field), a line that is not stock named and not dropped, and
// nothing offered to a buyer who does not manage the stock. The Demo's receiving
// answers by the server's rules (pgTAP 490).
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_stock_receiving_commands.dart';
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/presentation/purchase_order_stock_seam.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/stock/presentation/purchase_order_stock_seam_impl.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/purchase_orders_app.dart';

final _en = AppLocalizationsEn();
final _today = DateTime(2026, 11, 4);

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

/// A sent order to Alpha: 40 kg of the shop's coffee beans (a stock item) and a
/// line of paper towels (free text, not stock).
Future<(FakePurchaseOrderRepository, FakeSupplierRepository)> _orders() async {
  final suppliers = FakeSupplierRepository();
  final alpha = await suppliers.save('ws-1', const SupplierDraft(name: 'Alpha'));
  final repo = FakePurchaseOrderRepository(suppliers: () => suppliers.suppliers, services: () => const [], now: () => _today);
  final o = await repo.save(
    'ws-1',
    'seed',
    PurchaseOrderDraft(
      supplierId: alpha,
      lines: const [
        PurchaseOrderLineDraft(serviceId: 'demo-item-beans', description: 'Coffee beans', quantity: 40, unit: 'kg', unitPriceCents: 900),
        PurchaseOrderLineDraft(description: 'Paper towels', quantity: 12, unit: 'roll', unitPriceCents: 150),
      ],
    ),
  );
  await repo.markSent('ws-1', o.id, o.revision, 'sent');
  return (repo, suppliers);
}

class _World {
  _World(this.repo, this.suppliers, this.config, this.receiving);

  final FakePurchaseOrderRepository repo;
  final FakeSupplierRepository suppliers;
  final DemoStockConfigCommands config;
  final DemoStockReceivingCommands receiving;
}

Future<_World> _world() async {
  final (repo, suppliers) = await _orders();
  final config = DemoStockConfigCommands('ws-1');
  return _World(repo, suppliers, config, DemoStockReceivingCommands('ws-1', repo, config));
}

Widget _app(_World w, Set<WorkspacePermission> rights) => purchaseOrdersApp([
  currentWorkspaceProvider.overrideWith((ref) async => _workspace),
  myMemberProvider.overrideWith((ref) async => null),
  myPermissionsProvider.overrideWithValue(rights),
  enabledFeaturesSyncProvider.overrideWithValue({
    WorkspaceFeature.purchases,
    WorkspaceFeature.purchaseOrders,
    WorkspaceFeature.stockManagement,
    WorkspaceFeature.stockReceiving,
  }),
  supplierRepositoryProvider.overrideWithValue(w.suppliers),
  purchaseOrderRepositoryProvider.overrideWithValue(w.repo),
  // what the composition root wires: the stock's own part of the order pane
  purchaseOrderStockSeamProvider.overrideWithValue(const StockPurchaseOrderSeam()),
  stockQueriesProvider.overrideWithValue(const DemoStockQueries('ws-1')),
  stockConfigCommandsProvider.overrideWithValue(w.config),
  stockReceivingCommandsProvider.overrideWithValue(w.receiving),
  servicesProvider.overrideWith((ref) async => const <ServiceItem>[]),
  clockProvider.overrideWithValue(FixedClock(_today)),
]);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

const _buyer = {WorkspacePermission.managePurchases, WorkspacePermission.manageStock};

Future<void> _open(WidgetTester tester, _World w, Size size, Set<WorkspacePermission> rights) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(w, rights));
  await _settle(tester);
  await openOrder(tester, '2026-0001');
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 2400)), ('desk', const Size(1440, 2400))]) {
    group('on a $name', () {
      testWidgets('a partial delivery is recorded and put away in one go; the free-text line is named, not dropped', (tester) async {
        final w = await _world();
        await _open(tester, w, size, _buyer);
        await _tap(tester, 'purchase-order-receive-2026-0001');
        await tester.enterText(find.byKey(const ValueKey('purchase-order-receive-line-1')), '20');
        await tester.enterText(find.byKey(const ValueKey('purchase-order-receive-line-2')), '');
        await _tap(tester, 'purchase-order-receive-also');
        expect(find.byKey(const ValueKey('putaway-2-not-stock')), findsOneWidget, reason: 'paper towels are not stock: named');
        await _tap(tester, 'purchase-order-receive-confirm');
        final receipt = w.repo.receipts.single;
        expect(receipt.lines, {1: 20.0}, reason: 'the delivery was recorded');
        final rows = await w.receiving.allocationsOfOrder('ws-1', w.repo.orders.single.id);
        expect(rows.map((a) => (a.lineNo, a.enteredQuantity.text, a.enteredUnit)), [(1, '20', 'kg')]);
        expect(find.text(_en.stockPutAwayProgress('Coffee beans', '20', '0')), findsOneWidget);
        expect(find.textContaining('Coffee beans: 20 of 40 received'), findsOneWidget, reason: 'received and put away read side by side');
      });

      testWidgets('what remains is put away later, in parts, and never more than arrived', (tester) async {
        final w = await _world();
        await _open(tester, w, size, _buyer);
        // the delivery alone: 20 kg, nothing put away
        await _tap(tester, 'purchase-order-receive-2026-0001');
        await tester.enterText(find.byKey(const ValueKey('purchase-order-receive-line-1')), '20');
        await tester.enterText(find.byKey(const ValueKey('purchase-order-receive-line-2')), '');
        await _tap(tester, 'purchase-order-receive-confirm');
        final id = w.repo.receipts.single.id;
        expect(find.text(_en.stockPutAwayProgress('Coffee beans', '0', '20')), findsOneWidget);
        // 30 is more than arrived
        await _tap(tester, 'purchase-order-putaway-2026-0001-$id');
        await tester.enterText(find.byKey(const ValueKey('putaway-1-qty')), '30');
        await _tap(tester, 'putaway-confirm');
        expect(find.text(_en.stockReasonOverAllocated), findsOneWidget, reason: 'said under the field; nothing is put away');
        expect(await w.receiving.allocationsOfOrder('ws-1', w.repo.orders.single.id), isEmpty);
        // 12, then the 8 that remain
        await tester.enterText(find.byKey(const ValueKey('putaway-1-qty')), '12');
        await _tap(tester, 'putaway-confirm');
        expect(find.text(_en.stockPutAwayProgress('Coffee beans', '12', '8')), findsOneWidget);
        await _tap(tester, 'purchase-order-putaway-2026-0001-$id');
        expect(tester.widget<TextField>(find.descendant(of: find.byKey(const ValueKey('putaway-1-qty')), matching: find.byType(TextField))).controller!.text, '8',
            reason: 'what is left is the default');
        await _tap(tester, 'putaway-confirm');
        expect(find.text(_en.stockPutAwayProgress('Coffee beans', '20', '0')), findsOneWidget);
        expect(find.byKey(ValueKey('purchase-order-putaway-2026-0001-$id')), findsNothing, reason: 'nothing is left to put away');
        final rows = await w.receiving.allocationsOfOrder('ws-1', w.repo.orders.single.id);
        expect(rows.length, 2, reason: 'each part is its own allocation');
      });

      testWidgets('a buyer who does not manage the stock is offered no put-away', (tester) async {
        final w = await _world();
        await _open(tester, w, size, {WorkspacePermission.managePurchases});
        await _tap(tester, 'purchase-order-receive-2026-0001');
        expect(find.byKey(const ValueKey('purchase-order-receive-also')), findsNothing);
      });
    });
  }
}
