// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/features/money/domain/supplier_balance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server balances preserve supplier, minor units and currency', () {
    final eur = SupplierBalance.fromJson({
      'supplier_id': 'supplier-a',
      'currency': 'EUR',
      'remaining_cents': 1250,
      'held_cents': 300,
    });
    final gbp = SupplierBalance.fromJson({
      'supplier_id': 'supplier-a',
      'currency': 'GBP',
      'remaining_cents': 300,
      'held_cents': 0,
    });
    expect(
      (eur.supplierId, eur.currency, eur.remainingCents),
      ('supplier-a', 'EUR', 1250),
    );
    expect(eur.heldCents, 300);
    expect(
      (gbp.supplierId, gbp.currency, gbp.remainingCents),
      ('supplier-a', 'GBP', 300),
    );
  });

  test('a missing amount is an error, not a zero balance', () {
    expect(
      () => SupplierBalance.fromJson({
        'supplier_id': 'supplier-a',
        'currency': 'EUR',
      }),
      throwsA(isA<JsonShapeException>()),
    );
  });
}
