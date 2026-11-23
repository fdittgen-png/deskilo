// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- the factor of a purchase unit is read exactly: whole numbers, decimals with a point or a comma, and
// fractions, in lowest terms; zero, signs and text are refused.
import 'package:deskilo/features/stock/domain/item_groups.dart';
import 'package:deskilo/features/stock/domain/purchase_factor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a whole number, a decimal and a fraction are read exactly, in lowest terms', () {
    expect(parsePurchaseFactor('12'), (num: 12, den: 1));
    expect(parsePurchaseFactor('0.5'), (num: 1, den: 2));
    expect(parsePurchaseFactor('0,25'), (num: 1, den: 4));
    expect(parsePurchaseFactor('1/3'), (num: 1, den: 3));
    expect(parsePurchaseFactor('6 / 4'), (num: 3, den: 2));
  });

  test('zero, a zero denominator, a sign and text are refused', () {
    for (final bad in ['0', '1/0', '0/3', '-2', 'abc', '', '1.1234567', '1/2/3']) {
      expect(parsePurchaseFactor(bad), isNull, reason: bad);
    }
  });

  test('a factor is shown as a whole number when it is one, else as a fraction', () {
    expect(purchaseFactorText(12, 1), '12');
    expect(purchaseFactorText(1, 3), '1/3');
  });

  test('a margin in percent is basis points, exactly: two decimals at most, up to a thousand percent', () {
    expect(marginBpsOfPercent('35'), 3500);
    expect(marginBpsOfPercent('12.5'), 1250);
    expect(marginBpsOfPercent('0.05'), 5);
    expect(marginBpsOfPercent('1000'), 100000);
    for (final bad in ['', 'abc', '12.345', '1000.01', '-1', '1,5']) {
      expect(marginBpsOfPercent(bad), isNull, reason: bad);
    }
    expect(percentOfMarginBps(3500), '35');
    expect(percentOfMarginBps(1250), '12.5');
    expect(percentOfMarginBps(5), '0.05');
  });
}
