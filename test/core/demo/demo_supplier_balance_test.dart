// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/demo/data/supplier_balance_repository.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:flutter_test/flutter_test.dart';

PayableRow _row(
  String id,
  String supplier,
  String currency,
  int remaining, {
  ObligationState state = ObligationState.open,
}) => PayableRow(
  obligation: PurchaseObligation(
    id: id,
    purchaseId: 'purchase-$id',
    creditorKind: CreditorKind.supplier,
    creditorId: supplier,
    amountCents: 1000,
    currency: currency,
    state: state,
    appliedCents: 0,
    remainingCents: remaining,
  ),
  purchase: PurchaseSummary(
    id: 'purchase-$id',
    kind: PurchaseKind.bill,
    state: PurchaseState.approved,
    category: '',
    reference: id,
    currency: currency,
    grossCents: 1000,
  ),
);

void main() {
  test('continuation reaches every Demo payable beyond 2000 rows', () async {
    final purchases = FakePurchaseRepository();
    for (var i = 0; i < 2101; i++) {
      purchases.payables.add(_row(i.toString().padLeft(4, '0'), 's', 'EUR', 1));
    }
    final repo = FakeSupplierBalanceRepository(
      workspaceId: 'ws',
      purchases: purchases,
    );
    var page = await repo.fetchPayables('ws', 's');
    var count = page.rows.length;
    while (page.next != null) {
      page = await repo.fetchPayables('ws', 's', after: page.next);
      count += page.rows.length;
    }
    expect(count, 2101);
    expect((await repo.fetchBalances('ws')).single.remainingCents, 2101);
  });

  test(
    'Demo reads partial and settled obligations by supplier and currency',
    () async {
      final purchases = FakePurchaseRepository()
        ..payables.addAll([
          _row('partial', 's', 'EUR', 400),
          _row('settled', 's', 'EUR', 0),
          _row('held', 's', 'EUR', 100, state: ObligationState.held),
          _row('cancelled', 's', 'EUR', 300, state: ObligationState.cancelled),
          _row('other-currency', 's', 'GBP', 200),
          _row('other-supplier', 'other', 'EUR', 900),
        ]);
      final repo = FakeSupplierBalanceRepository(
        workspaceId: 'ws',
        purchases: purchases,
      );
      final balances = await repo.fetchBalances('ws');
      expect(
        {
          for (final b in balances)
            (b.supplierId, b.currency): b.remainingCents,
        },
        {('s', 'EUR'): 500, ('s', 'GBP'): 200, ('other', 'EUR'): 900},
      );
      expect(
        balances
            .singleWhere((b) => b.supplierId == 's' && b.currency == 'EUR')
            .heldCents,
        100,
      );
      final page = await repo.fetchPayables('ws', 's');
      expect(page.rows.map((r) => r.obligation.id).toSet(), {
        'partial',
        'settled',
        'held',
        'cancelled',
        'other-currency',
      });
      expect(page.next, isNull);
      await expectLater(
        repo.fetchBalances('another-workspace'),
        throwsStateError,
      );
    },
  );
}
