// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4393 -- a quantity stays exact from the field to the ledger. In the Demo, one
// unit of a third of a litre is put away as the server records it,
// round(1 * 1 / 3, 6) = 0.333333 l: a value, never an exception. On a scan,
// one third has no six-decimal value: no `1/3` reaches a quantity field.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_receiving_commands.dart';
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/stock/domain/stock_receiving.dart';
import 'package:deskilo/features/stock/domain/stock_scan_session.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart' show SupplierDraft;
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one third of a litre is put away as the ledger rounds it, without an exception', () async {
    final today = DateTime(2026, 11, 23);
    final suppliers = FakeSupplierRepository();
    final alpha = await suppliers.save('ws-1', const SupplierDraft(name: 'Alpha'));
    final repo = FakePurchaseOrderRepository(suppliers: () => suppliers.suppliers, services: () => const [], now: () => today);
    final order = await repo.save(
      'ws-1',
      'seed',
      PurchaseOrderDraft(
        supplierId: alpha,
        lines: const [
          PurchaseOrderLineDraft(serviceId: 'demo-item-syrup', description: 'Syrup', quantity: 1, unit: 'third', unitPriceCents: 300),
        ],
      ),
    );
    final sent = await repo.markSent('ws-1', order.id, order.revision, 'sent');
    final config = DemoStockConfigCommands('ws-1');
    final receiving = DemoStockReceivingCommands('ws-1', repo, config, DemoStockLedger('ws-1', config));
    final done = await receiving.recordAndPutAway(
      'ws-1',
      DeliveryDraft(
        orderId: order.id,
        orderRevision: sent.revision,
        receivedOn: '2026-11-23',
        lines: const [(lineNo: 1, quantity: '1')],
      ),
      const [PutAwayAllocation(lineNo: 1, quantity: '1', locationId: 'demo-place-main')],
      'req-third',
    );
    expect(done.allocations.single.enteredQuantity.text, '1');
    expect(done.allocations.single.inventoryQuantity.text, '0.333333');
  });

  test('a scan of one third has no six-decimal value: a problem, never the text n/d', () {
    final line = ScanLine(itemId: 'demo-item-syrup', itemName: 'Syrup', unit: 'l')..add(1, 3);
    expect(line.quantity.problem, ExactQuantityProblem.notRepresentable);
    expect(line.quantityText, isNull);
    expect(line.shownQuantity, '≈ 0.333333');
    line
      ..add(1, 3)
      ..add(1, 3);
    expect(line.quantityText, '1', reason: 'three thirds are one, exactly');
  });
}
