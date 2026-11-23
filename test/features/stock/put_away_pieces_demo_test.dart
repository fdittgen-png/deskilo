// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4379 (G13b), #4363 (G14) -- the Demo's journey: five gift baskets arrive, each is put away with the tag its
// NFC chip answers when the phone reads it, and the Demo makes five pieces with their tags, as 0889 does; a chip
// already bound elsewhere is refused by the Demo and named in the sheet, and nothing is made then.
import 'package:deskilo/core/demo/data/demo_item_groups.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_stock_receiving_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_tags.dart';
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/nfc/nfc_uid_reader.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/presentation/purchase_order_stock_seam.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/stock/domain/stock_tags.dart';
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

import '../../helpers/mock_providers.dart';
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

const _basket = TagOwner.item('demo-item-basket');

typedef _Demo = ({FakeNfcUidReader nfc, DemoStockTags tags, FakePurchaseOrderRepository orders});

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
}

/// The Demo's own stock kit for one business, an order of 5 gift baskets sent, 5 received; the put-away is open.
Future<_Demo> _receiveFive(WidgetTester tester, Size size) async {
  final suppliers = FakeSupplierRepository();
  final alpha = await suppliers.save('ws-1', const SupplierDraft(name: 'Alpha'));
  final orders = FakePurchaseOrderRepository(suppliers: () => suppliers.suppliers, services: () => const [], now: () => _today);
  final o = await orders.save(
    'ws-1',
    'seed',
    PurchaseOrderDraft(
      supplierId: alpha,
      lines: const [PurchaseOrderLineDraft(serviceId: 'demo-item-basket', description: 'Gift basket', quantity: 5, unit: 'piece', unitPriceCents: 2400)],
    ),
  );
  await orders.markSent('ws-1', o.id, o.revision, 'sent');
  final config = DemoStockConfigCommands('ws-1');
  final ledger = DemoStockLedger('ws-1', config);
  final groups = DemoItemGroups('ws-1', config, () => _today);
  final tags = DemoStockTags(tagModeOf: (item) async => (await groups.effective('ws-1', item)).params['tag_mode']?.value as String?);
  final nfc = FakeNfcUidReader(available: true);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(purchaseOrdersApp([
    currentWorkspaceProvider.overrideWith((ref) async => _workspace),
    myMemberProvider.overrideWith((ref) async => null),
    myPermissionsProvider.overrideWithValue({WorkspacePermission.managePurchases, WorkspacePermission.manageStock}),
    enabledFeaturesSyncProvider.overrideWithValue({
      WorkspaceFeature.purchases,
      WorkspaceFeature.purchaseOrders,
      WorkspaceFeature.stockManagement,
      WorkspaceFeature.stockReceiving,
      WorkspaceFeature.stockTags,
    }),
    supplierRepositoryProvider.overrideWithValue(suppliers),
    purchaseOrderRepositoryProvider.overrideWithValue(orders),
    purchaseOrderStockSeamProvider.overrideWithValue(const StockPurchaseOrderSeam()),
    stockQueriesProvider.overrideWithValue(DemoStockQueries(ledger)),
    stockConfigCommandsProvider.overrideWithValue(config),
    stockReceivingCommandsProvider.overrideWithValue(DemoStockReceivingCommands('ws-1', orders, config, ledger, tags: tags)),
    itemGroupsProvider.overrideWithValue(groups),
    nfcUidReaderProvider.overrideWithValue(nfc),
    servicesProvider.overrideWith((ref) async => const <ServiceItem>[]),
    clockProvider.overrideWithValue(FixedClock(_today)),
  ]));
  await _settle(tester);
  await openOrder(tester, '2026-0001');
  await _settle(tester);
  await _tap(tester, 'purchase-order-receive-2026-0001');
  await tester.enterText(find.byKey(const ValueKey('purchase-order-receive-line-1')), '5');
  await _tap(tester, 'purchase-order-receive-confirm');
  await _tap(tester, 'purchase-order-putaway-2026-0001-${orders.receipts.single.id}');
  return (nfc: nfc, tags: tags, orders: orders);
}

/// The phone reads one chip: the NFC button, then the chip answers.
Future<void> _readChip(WidgetTester tester, FakeNfcUidReader nfc, String uid) async {
  await _tap(tester, 'stock-scan-nfc');
  nfc.tap(uid);
  await _settle(tester);
}

Future<int> _pieces(DemoStockTags tags) async => (await tags.tags('ws-1', _basket)).where((t) => t.isPiece).length;

void main() {
  for (final (name, size) in [('phone', const Size(390, 2400)), ('desk', const Size(1440, 2400))]) {
    group('on a $name', () {
      testWidgets('five gift baskets are put away with the chips the phone reads: five pieces, each with its tag', (tester) async {
        final demo = await _receiveFive(tester, size);
        expect(await _pieces(demo.tags), 5, reason: 'the Demo starts with five baskets in stock');
        for (var i = 1; i <= 5; i++) {
          await _readChip(tester, demo.nfc, '04bb00${i}0');
        }
        expect(find.text(_en.stockPutAwayTagsCount(5, 5)), findsOneWidget);
        await _tap(tester, 'putaway-confirm');
        expect(await _pieces(demo.tags), 10, reason: 'five new pieces, one per chip');
        expect(demo.tags.ownerOf('04BB0010')?.itemId, 'demo-item-basket');
      });

      testWidgets("a chip already on a shelf is refused, named by its place among the tags, and nothing is made", (tester) async {
        final demo = await _receiveFive(tester, size);
        await _readChip(tester, demo.nfc, '04bb0010');
        await _readChip(tester, demo.nfc, 'a1b2c3d4'); // the shelf's chip in the Demo
        for (var i = 3; i <= 5; i++) {
          await _readChip(tester, demo.nfc, '04bb00${i}0');
        }
        await _tap(tester, 'putaway-confirm');
        expect(find.text(_en.stockPutAwayPieceProblem(2, _en.stockTagBoundElsewhere('demo-place-shelf'))), findsOneWidget);
        expect(await _pieces(demo.tags), 5, reason: 'nothing was put away, so no piece was made');
        expect(demo.orders.receipts, hasLength(1));
      });
    });
  }
}
