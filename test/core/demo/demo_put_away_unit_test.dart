// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 (0972) -- the Demo puts a delivery away in any unit the item converts from, as the server does (pgTAP 579): mugs are ordered by the
// carton of 12; 24 pieces against a line of 2 cartons are the 2 cartons, entered in pieces; a piece more than the 2 cartons is over-allocated;
// 12 pieces and then a carton make the 2 cartons; a kilo of mugs has no conversion and is refused naming the unit.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_receiving_commands.dart';
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_receiving.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart' show SupplierDraft;
import 'package:flutter_test/flutter_test.dart';

Future<({DemoStockReceivingCommands receiving, PurchaseOrder order})> _sentOrder() async {
  final today = DateTime(2026, 11, 23);
  final suppliers = FakeSupplierRepository();
  final alpha = await suppliers.save('ws-1', const SupplierDraft(name: 'Alpha'));
  final repo = FakePurchaseOrderRepository(suppliers: () => suppliers.suppliers, services: () => const [], now: () => today);
  final order = await repo.save(
    'ws-1',
    'seed',
    PurchaseOrderDraft(
      supplierId: alpha,
      lines: const [PurchaseOrderLineDraft(serviceId: 'demo-item-mugs', description: 'Mugs', quantity: 2, unit: 'carton', unitPriceCents: 1200)],
    ),
  );
  final sent = await repo.markSent('ws-1', order.id, order.revision, 'sent');
  final config = DemoStockConfigCommands('ws-1');
  return (receiving: DemoStockReceivingCommands('ws-1', repo, config, DemoStockLedger('ws-1', config)), order: sent);
}

PutAwayAllocation _part(String quantity, String unit) =>
    PutAwayAllocation(lineNo: 1, quantity: quantity, unit: unit, locationId: 'demo-place-main');

Future<List<ReceiptAllocation>> _receive(DemoStockReceivingCommands r, PurchaseOrder o, List<PutAwayAllocation> parts) async => (await r.recordAndPutAway(
  'ws-1',
  DeliveryDraft(orderId: o.id, orderRevision: o.revision, receivedOn: '2026-11-23', lines: const [(lineNo: 1, quantity: '2')]),
  parts,
  'req-${parts.length}-${parts.first.unit}',
)).allocations;

void main() {
  test('24 pieces against 2 cartons: entered in pieces, 24 on hand', () async {
    final (:receiving, :order) = await _sentOrder();
    final done = await _receive(receiving, order, [_part('24', 'piece')]);
    expect((done.single.enteredUnit, done.single.enteredQuantity.text, done.single.inventoryQuantity.text), ('piece', '24', '24'));
  });

  test('a piece more than the 2 cartons is over-allocated', () async {
    final (:receiving, :order) = await _sentOrder();
    await expectLater(
      _receive(receiving, order, [_part('24', 'piece'), _part('1', 'piece')]),
      throwsA(isA<StockConfigRefused>().having((e) => e.reason, 'reason', StockRefusal.overAllocated)),
    );
  });

  test('12 pieces and a carton make the 2 cartons; a piece more is refused', () async {
    final (:receiving, :order) = await _sentOrder();
    final done = await _receive(receiving, order, [_part('12', 'piece'), _part('1', 'carton')]);
    expect(done.map((a) => a.inventoryQuantity.text), ['12', '12']);
    await expectLater(
      receiving.putAway('ws-1', done.first.receiptLineId.split(':').first, [_part('1', 'piece')], 'req-more'),
      throwsA(isA<StockConfigRefused>().having((e) => e.reason, 'reason', StockRefusal.overAllocated)),
    );
  });

  test('a kilo of mugs has no conversion', () async {
    final (:receiving, :order) = await _sentOrder();
    await expectLater(
      _receive(receiving, order, [_part('1', 'kg')]),
      throwsA(isA<StockConfigRefused>().having((e) => e.reason, 'reason', StockRefusal.unitUnmapped)),
    );
  });
}
