// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 — a Demo purchase that names a supplier carries that supplier's id:
// the purchases table resolves the name by the id, and without it every bill
// of a known supplier read "No supplier" beside a suppliers list that showed
// the same bills as open.
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a purchase is listed under the supplier its document names', () async {
    final demo = seedDemoPurchasing(DateTime(2026, 5, 13), workspaceId: 'ws-1');
    final suppliers = {for (final s in demo.suppliers.suppliers) s.id: s.name};
    final listed = await demo.purchases.fetchPurchases('ws-1');
    var named = 0;
    for (final purchase in listed) {
      final detail = await demo.purchases.fetchDetail('ws-1', purchase.id);
      final name = detail.supplierName;
      if (name == null || !suppliers.containsValue(name)) continue;
      named++;
      expect(
        suppliers[purchase.supplierId],
        name,
        reason: '${purchase.reference} names $name on its document',
      );
    }
    expect(named, greaterThan(3), reason: 'the seed links bills to suppliers');
  });
}
