// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the quantity a till accepts: an exact decimal above zero, a comma read as a point, at most six decimals and
// twelve integer digits; the sum of two is exact.
import 'package:deskilo/features/money/domain/till_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a comma is read as a point, and the trailing zeros are dropped', () => expect(tillQuantityOf('0,350'), '0.35'));
  test('six decimals are kept', () => expect(tillQuantityOf('1.123456'), '1.123456'));
  test('seven decimals are refused', () => expect(tillQuantityOf('1.1234567'), isNull));
  test('zero and nothing are refused', () {
    expect(tillQuantityOf('0'), isNull);
    expect(tillQuantityOf('0.000'), isNull);
    expect(tillQuantityOf(''), isNull);
    expect(tillQuantityOf('-1'), isNull);
    expect(tillQuantityOf('abc'), isNull);
  });
  test('twelve integer digits are kept, thirteen are refused', () {
    expect(tillQuantityOf('999999999999'), '999999999999');
    expect(tillQuantityOf('1000000000000'), isNull);
  });
  test('the sum of two quantities is exact', () => expect(tillQuantitySum('0.1', '0.2'), '0.3'));
  test('the suggested cash is the amount and the next whole 1-2-5 steps of the currency, from its decimals', () {
    expect(tillCashSuggestions(1340, minorDigits: 2), [1340, 1400, 1500, 2000]);
    expect(tillCashSuggestions(210, minorDigits: 2), [210, 300, 400, 500]);
    // a currency without decimals steps in its own whole units
    expect(tillCashSuggestions(1340, minorDigits: 0), [1340, 1350, 1400, 1500]);
    // #4511 -- with the currency's notes, the total rounded up to each note
    expect(tillCashSuggestions(1340, minorDigits: 2, notes: const [500, 1000, 2000, 5000]), [1340, 1500, 2000, 5000]);
    expect(tillCashSuggestions(0, minorDigits: 2), isEmpty);
  });
}
