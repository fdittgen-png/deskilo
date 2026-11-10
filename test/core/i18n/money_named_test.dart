// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A personal surface lists the documents of businesses in different
// countries: an amount there names its currency without doubt. A symbol
// that several selectable currencies share ($, kr, ¥) is spelled as the ISO
// code; a symbol one currency carries alone stays; a code that is missing is
// never read as another currency.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

const _nbsp = ' ';

String _named(String locale, String code, int minor) => AppFormat(
  locale: locale,
  currencyCode: 'EUR',
).moneyNamed(code).formatMinor(minor);

/// The symbol a personal surface spells [code] with, to a reader of [locale].
String _symbol(String code, {required String locale}) => AppFormat(
  locale: locale,
  currencyCode: 'EUR',
).moneyNamed(code).currencySymbol;

void main() {
  test('no two selectable currencies are spelled with the same symbol', () {
    for (final locale in kFormatLocales) {
      final seen = <String, String>{};
      for (final code in Currencies.selectable) {
        final symbol = _symbol(code, locale: locale);
        expect(
          seen[symbol],
          isNull,
          reason: '$locale: $code and ${seen[symbol]} both read "$symbol"',
        );
        seen[symbol] = code;
      }
    }
  });

  test('the dollars, the crowns and the yen and yuan are named by code', () {
    for (final code in [
      'USD',
      'CAD',
      'AUD',
      'MXN',
      'SEK',
      'NOK',
      'DKK',
      'JPY',
      'CNY',
    ]) {
      for (final locale in ['en_US', 'en_CA', 'fr_CA', 'sv_SE', 'ja_JP']) {
        expect(_symbol(code, locale: locale), code, reason: '$locale $code');
      }
    }
  });

  test('a symbol only one currency carries stays', () {
    expect(_symbol('EUR', locale: 'en_GB'), '€');
    expect(_symbol('GBP', locale: 'fr_FR'), '£');
    expect(_symbol('PLN', locale: 'de_DE'), 'zł');
    expect(_symbol('CHF', locale: 'de_CH'), 'CHF');
  });

  test('a code the kernel does not list is spelled as itself', () {
    expect(_symbol('ARS', locale: 'en_US'), 'ARS');
    expect(_named('en_US', 'ARS', 120000), 'ARS${_nbsp}1,200.00');
  });

  test('the amount is set off from a code, on the side the locale puts it', () {
    expect(_named('en_US', 'USD', 12000), 'USD${_nbsp}120.00');
    expect(_named('en_US', 'CAD', 12000), 'CAD${_nbsp}120.00');
    expect(_named('fr_FR', 'USD', 12000), '120,00${_nbsp}USD');
    expect(_named('en_GB', 'EUR', 12000), '€120.00');
    expect(_named('de_DE', 'EUR', 12000), '120,00$_nbsp€');
  });

  test('the minor unit follows the currency, not the euro', () {
    expect(_named('en_US', 'JPY', 1250), 'JPY${_nbsp}1,250');
    expect(_named('en_GB', 'EUR', 1250), '€12.50');
  });

  test(
    'a record without a currency shows the number alone, never a default',
    () {
      for (final locale in ['en_US', 'de_DE', 'fr_FR', 'de_CH']) {
        final shown = _named(locale, '', 123456);
        expect(shown, isNot(contains('€')), reason: locale);
        expect(shown, isNot(contains('EUR')), reason: locale);
        expect(
          shown.trim(),
          shown,
          reason: '$locale: no gap left for a symbol',
        );
        expect(
          RegExp(r'[A-Za-z€£¥\$]').hasMatch(shown),
          isFalse,
          reason: '$locale: "$shown"',
        );
      }
    },
  );

  test('a workspace screen is spelled as before: its one currency keeps its symbol', () {
    const format = AppFormat(locale: 'en_US', currencyCode: 'USD');
    expect(format.money(12000), r'$120.00');
    expect(format.moneyIn('CAD').formatMinor(12000), r'$120.00');
  });
}
