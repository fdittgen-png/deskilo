// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4379 (G13b), #4363 (G14) -- a delivery of an item tagged piece by piece is put away with one tag per piece:
// the sheet counts what was read of what is needed, a tag read twice or one more than the line still has is
// refused under the field, the quantity follows the tags, and the put-away carries the tags to the server
// (0889 `units`). A piece the server refuses is named by its place among the tags, the tags read stay in the
// sheet, and the retry goes under the same request id. At phone and desk width.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_stock_receiving_commands.dart';
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
import 'package:deskilo/features/stock/domain/item_groups.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_receiving.dart';
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

/// The coffee beans are tagged piece by piece here (their effective tag mode).
class _Groups implements ItemGroups {
  @override
  Future<ItemEffective> effective(String workspaceId, String itemId) async => ItemEffective(
    itemId: itemId,
    groupId: null,
    params: {'tag_mode': const EffectiveParam(value: 'per_unit', source: 'item')},
    problems: const [],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The Demo's receiving, recording what each put-away sent; [refuseNext] is thrown once, as the server would.
class _Receiving implements StockReceivingCommands {
  _Receiving(this._inner);

  final DemoStockReceivingCommands _inner;
  final sent = <(String, List<PutAwayAllocation>)>[];
  Exception? refuseNext;

  @override
  Future<PutAwayResult> putAway(String workspaceId, String receiptId, List<PutAwayAllocation> allocations, String requestId) async {
    sent.add((requestId, allocations));
    final refusal = refuseNext;
    refuseNext = null;
    if (refusal != null) throw refusal;
    return _inner.putAway(workspaceId, receiptId, allocations, requestId);
  }

  @override
  Future<List<ReceiptAllocation>> allocations(String workspaceId, String receiptId) => _inner.allocations(workspaceId, receiptId);

  @override
  Future<List<ReceiptAllocation>> allocationsOfOrder(String workspaceId, String orderId) => _inner.allocationsOfOrder(workspaceId, orderId);

  @override
  Future<PutAwayResult> recordAndPutAway(String workspaceId, DeliveryDraft delivery, List<PutAwayAllocation> allocations, String requestId) =>
      _inner.recordAndPutAway(workspaceId, delivery, allocations, requestId);
}

Future<(FakePurchaseOrderRepository, FakeSupplierRepository, _Receiving)> _world() async {
  final suppliers = FakeSupplierRepository();
  final alpha = await suppliers.save('ws-1', const SupplierDraft(name: 'Alpha'));
  final repo = FakePurchaseOrderRepository(suppliers: () => suppliers.suppliers, services: () => const [], now: () => _today);
  final o = await repo.save(
    'ws-1',
    'seed',
    PurchaseOrderDraft(
      supplierId: alpha,
      lines: const [PurchaseOrderLineDraft(serviceId: 'demo-item-beans', description: 'Coffee beans', quantity: 12, unit: 'kg', unitPriceCents: 900)],
    ),
  );
  await repo.markSent('ws-1', o.id, o.revision, 'sent');
  final config = DemoStockConfigCommands('ws-1');
  final ledger = DemoStockLedger('ws-1', config);
  return (repo, suppliers, _Receiving(DemoStockReceivingCommands('ws-1', repo, config, ledger)));
}

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

/// Records a delivery of [delivered] kg alone, then opens the put-away of what remains.
Future<_Receiving> _openPutAway(WidgetTester tester, Size size, String delivered) async {
  final (repo, suppliers, receiving) = await _world();
  final config = DemoStockConfigCommands('ws-1');
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
    purchaseOrderRepositoryProvider.overrideWithValue(repo),
    purchaseOrderStockSeamProvider.overrideWithValue(const StockPurchaseOrderSeam()),
    stockQueriesProvider.overrideWithValue(DemoStockQueries(DemoStockLedger('ws-1', config))),
    stockConfigCommandsProvider.overrideWithValue(config),
    stockReceivingCommandsProvider.overrideWithValue(receiving),
    itemGroupsProvider.overrideWithValue(_Groups()),
    nfcUidReaderProvider.overrideWithValue(FakeNfcUidReader()),
    servicesProvider.overrideWith((ref) async => const <ServiceItem>[]),
    clockProvider.overrideWithValue(FixedClock(_today)),
  ]));
  await _settle(tester);
  await openOrder(tester, '2026-0001');
  await _settle(tester);
  await _tap(tester, 'purchase-order-receive-2026-0001');
  await tester.enterText(find.byKey(const ValueKey('purchase-order-receive-line-1')), delivered);
  await _tap(tester, 'purchase-order-receive-confirm');
  await _tap(tester, 'purchase-order-putaway-2026-0001-${repo.receipts.single.id}');
  return receiving;
}

Future<void> _read(WidgetTester tester, String tag) async {
  await tester.ensureVisible(find.byKey(const ValueKey('putaway-1-tag')));
  await tester.enterText(find.byKey(const ValueKey('putaway-1-tag')), tag);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _settle(tester);
}

String _quantity(WidgetTester tester) => tester
    .widget<TextField>(find.descendant(of: find.byKey(const ValueKey('putaway-1-qty')), matching: find.byType(TextField)))
    .controller!
    .text;

void main() {
  for (final (name, size) in [('phone', const Size(390, 2400)), ('desk', const Size(1440, 2400))]) {
    group('on a $name', () {
      testWidgets('3 of 12 pieces are put away with their 3 tags; a tag read twice is refused', (tester) async {
        final receiving = await _openPutAway(tester, size, '12');
        expect(find.text(_en.stockPutAwayTagsCount(0, 12)), findsOneWidget, reason: 'nothing read of 12');
        await _read(tester, '04:aa:11:bb');
        await _read(tester, '04aa11cc');
        await _read(tester, '04AA11BB');
        expect(find.text(_en.stockScanAlreadyRead('04AA11BB')), findsOneWidget, reason: 'the same tag, written otherwise');
        await _read(tester, '04aa11dd');
        expect(_quantity(tester), '3', reason: 'the quantity follows the tags');
        expect(find.text(_en.stockPutAwayTagsCount(3, 12)), findsOneWidget);
        await _tap(tester, 'putaway-confirm');
        final (_, allocations) = receiving.sent.single;
        expect(allocations.single.quantity, '3');
        expect(allocations.single.tags, ['04AA11BB', '04AA11CC', '04AA11DD']);
        expect(allocations.single.toJson()['units'], [
          {'tag': '04AA11BB'},
          {'tag': '04AA11CC'},
          {'tag': '04AA11DD'},
        ]);
      });

      testWidgets('one tag more than the line still has is refused: 2 received, 2 tagged', (tester) async {
        await _openPutAway(tester, size, '2');
        await _read(tester, '04aa0001');
        await _read(tester, '04aa0002');
        await _read(tester, '04aa0003');
        expect(find.text(_en.stockPutAwayTagAllRead(2)), findsOneWidget);
        expect(find.byKey(const ValueKey('putaway-1-tag-04AA0003')), findsNothing);
        expect(_quantity(tester), '2');
      });

      testWidgets('a quantity that is not the number of tags read is said under the tag field, nothing is sent', (tester) async {
        final receiving = await _openPutAway(tester, size, '12');
        await _read(tester, '04aa0001');
        await tester.enterText(find.byKey(const ValueKey('putaway-1-qty')), '5');
        await _tap(tester, 'putaway-confirm');
        expect(find.text(_en.stockPutAwayTagsMissing(5, 1)), findsOneWidget);
        expect(receiving.sent, isEmpty);
      });

      testWidgets('a refused piece is named, the tags stay, and the retry goes under the same request id', (tester) async {
        final receiving = await _openPutAway(tester, size, '12');
        await _read(tester, '04aa0001');
        await _read(tester, '04aa0002');
        receiving.refuseNext = const StockTagRefused('DKG22', {'allocation': 0, 'unit': 2, 'owner': 'Shelf A'});
        await _tap(tester, 'putaway-confirm');
        expect(find.text(_en.stockPutAwayPieceProblem(2, _en.stockTagBoundElsewhere('Shelf A'))), findsOneWidget);
        expect(find.byKey(const ValueKey('putaway-1-tag-04AA0002')), findsOneWidget, reason: 'the tags read are kept');
        await tester.tap(find.byTooltip(_en.stockPutAwayTagRemove('04AA0002')));
        await _settle(tester);
        await _read(tester, '04aa0003');
        await _tap(tester, 'putaway-confirm');
        expect(receiving.sent.length, 2);
        expect(receiving.sent.first.$1, receiving.sent.last.$1, reason: 'one form, one request id');
        expect(receiving.sent.last.$2.single.tags, ['04AA0001', '04AA0003']);
      });
    });
  }
}
