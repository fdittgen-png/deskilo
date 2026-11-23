// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4393 -- the reads that left the binary float: the registry's unit cost (numeric division text of any length),
// a delivered quantity the purchase order computed in floats, a reorder level, and a quantity typed without
// grouping. Each keeps what the float version answered for real inputs, and refuses what the server refuses.
import 'package:deskilo/core/format/decimal_input.dart';
import 'package:deskilo/features/stock/domain/put_away_progress.dart';
import 'package:deskilo/features/stock/domain/stock_registry.dart';
import 'package:deskilo/features/stock/domain/stock_reorder.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

StockRegistryRow _row(String? cost) => StockRegistryRow(
  itemId: 'i', itemName: 'Beans', unit: 'kg', onHand: ExactQuantity.zero, cost: cost, costVisible: true,
);

void main() {
  test('the unit cost is read at its own scale and rounded half away from zero', () {
    for (final (cost, want) in [
      ('333.33333333333333', 333),
      ('12.5', 13),
      ('12.4999995', 12),
      ('-3.5', -4),
      ('7', 7),
      ('0.5', 1),
      ('not a number', null),
    ]) {
      expect(_row(cost).costMinor, want, reason: cost);
    }
    expect(_row(null).costMinor, isNull);
  });

  test('a delivered quantity with float noise reads as the column would hold it, and never throws', () {
    expect(exactOfReceived(0.3 - 0.1).text, '0.2');
    expect(exactOfReceived(1 - 0.9).text, '0.1');
    expect(exactOfReceived(40).text, '40');
    expect(exactOfReceived(123456.789012).text, '123456.789012');
    expect(exactOfReceived(1e21), ExactQuantity.zero, reason: 'outside the column: no order line holds it');
  });

  test('a reorder level is a quantity the server reads: never signed, at most six decimals, twelve digits', () {
    String? level(String point) => checkReorderPoint(point: point, value: '', upTo: false)['reorder_point'];
    for (final ok in ['0', '20', '12.5', '00012', '999999999999.999999']) {
      expect(level(ok), isNull, reason: ok);
    }
    for (final bad in ['-0', '-1', '1.', '.5', '1e3', '1.1234567', '1234567890123', '']) {
      expect(level(bad), 'quantity_invalid', reason: bad);
    }
  });

  test('a quantity typed without grouping reads a comma or a dot as the decimal separator', () {
    expect(exactQuantityFromInput('1,5', grouping: false).value?.text, '1.5');
    expect(exactQuantityFromInput('1.5', grouping: false).value?.text, '1.5');
    expect(exactQuantityFromInput('1.234,5', grouping: false).value, isNull);
  });
}
