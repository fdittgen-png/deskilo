// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2385 — the one plain money formatter of the exports: the currency's
// grain, integer arithmetic, a chosen separator.
import 'package:deskilo/core/money/money_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the currency decides the grain', () {
    expect(minorToText(1250, 'EUR'), '12.50');
    expect(minorToText(1250, 'JPY'), '1250');
    expect(minorToText(1250, 'KWD'), '1.250');
  });

  test('the sign survives below one unit, or goes when asked', () {
    expect(minorToText(-5, 'EUR'), '-0.05');
    expect(minorToText(-1250, 'EUR', absolute: true), '12.50');
    expect(minorToText(0, 'EUR'), '0.00');
  });

  test('a comma for the French and German files', () {
    expect(minorToText(13055, 'EUR', decimalSeparator: ','), '130,55');
  });

  test('agrees with the double formatting it replaced, cent by cent', () {
    for (var cents = -100100; cents <= 100100; cents += 7) {
      expect(minorToText(cents, 'EUR'), (cents / 100).toStringAsFixed(2));
    }
  });
}
