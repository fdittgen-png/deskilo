// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3484, #3653 — a rate reads in the member's format locale through the
// locale's own percent pattern: a whole rate without decimals, a fractional
// one with its own precision, and the two units are two named entry points
// (a rate already in percent, a fraction), never a hundredfold mistake.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/rate_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Any no-break or narrow space the locale puts before the sign is one
/// space here: the pattern is the locale's, the test pins the digits.
String _plain(String s) => s.replaceAll(RegExp(r'[   ]'), ' ');

void main() {
  setUpAll(() async {
    for (final l in ['en_GB', 'de_DE', 'de_CH', 'fr_FR', 'fr_CA']) {
      await initializeDateFormatting(l);
    }
  });

  AppFormat at(String locale) => AppFormat(locale: locale, currencyCode: 'EUR');

  const table = <String, List<String>>{
    // rate:   20      8.1      2.6      9.975
    'en_GB': ['20%', '8.1%', '2.6%', '9.975%'],
    'de_DE': ['20 %', '8,1 %', '2,6 %', '9,975 %'],
    'de_CH': ['20%', '8.1%', '2.6%', '9.975%'],
    'fr_FR': ['20 %', '8,1 %', '2,6 %', '9,975 %'],
  };

  for (final MapEntry(key: locale, value: expected) in table.entries) {
    test('the rate table in $locale', () {
      final format = at(locale);
      final rates = [20, 8.1, 2.6, 9.975];
      for (var i = 0; i < rates.length; i++) {
        expect(
          _plain(format.ratePercent(rates[i])),
          expected[i],
          reason: '${rates[i]} in $locale',
        );
      }
    });

    test('a fraction is the same text as its rate in $locale', () {
      final format = at(locale);
      expect(format.fractionPercent(0.2), format.ratePercent(20));
      expect(format.fractionPercent(0.081), format.ratePercent(8.1));
      expect(format.fractionPercent(0.026), format.ratePercent(2.6));
      expect(format.fractionPercent(0.09975), format.ratePercent(9.975));
    });
  }

  test('no hundredfold: 8.1 as a rate is not 810 %', () {
    expect(_plain(at('en_GB').ratePercent(8.1)), isNot(contains('810')));
    expect(_plain(at('en_GB').fractionPercent(0.081)), '8.1%');
  });

  test('zero and the precision cap', () {
    expect(_plain(at('fr_FR').ratePercent(0)), '0 %');
    expect(ratePercentText(14.975, locale: 'fr_CA'), contains('14,975'));
    expect(ratePercentText(1 / 3, locale: 'en_GB'), '0.3333%');
  });
}
