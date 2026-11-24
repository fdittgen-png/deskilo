// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4424 -- an exact quantity reads in the member's format locale with every
// digit it holds: the decimal separator and the grouping are the locale's, no
// digit is rounded away or added, a negative keeps its sign and a unit follows.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spaces of every width read as one plain space, so the table states the digits.
String _plain(String s) => s.replaceAll(RegExp('[  ]'), ' ');

void main() {
  String q(String locale, String value, {String? unit}) => _plain(
    AppFormat(
      locale: locale,
      currencyCode: 'EUR',
    ).quantity(ExactQuantity.parse(value), unit: unit),
  );

  const table = <String, List<String>>{
    //        1.5     1234.5        0.333333     -2      12
    'en_US': ['1.5', '1,234.5', '0.333333', '-2', '12'],
    'fr_FR': ['1,5', '1 234,5', '0,333333', '-2', '12'],
    'de_DE': ['1,5', '1.234,5', '0,333333', '-2', '12'],
    'es_ES': ['1,5', '1.234,5', '0,333333', '-2', '12'],
    'it_IT': ['1,5', '1.234,5', '0,333333', '-2', '12'],
  };
  for (final MapEntry(key: locale, value: want) in table.entries) {
    test('$locale reads every digit in its own format', () {
      expect([
        for (final v in ['1.5', '1234.5', '0.333333', '-2', '12']) q(locale, v),
      ], want);
    });
  }

  test('a unit follows the number', () {
    expect(q('fr_FR', '1.5', unit: 'kg'), '1,5 kg');
    expect(q('en_US', '1.5', unit: ''), '1.5');
  });
}
