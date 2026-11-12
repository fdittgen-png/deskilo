// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3658 — an amount without its currency is incomplete, not smaller. The
// same 1 250 stored units are 1 250 JPY, 12.50 EUR or 1.250 KWD; with no
// currency the scale itself is unknown, so the amount reads "Currency
// unavailable" and never a number. The rule is not an assertion: it holds
// in a release build exactly as in a test. Documents, files and payments
// refuse a missing currency with CurrencyUnavailable.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('valid currencies keep their own scale', () {
    expect(
      moneyFormat('JPY', locale: 'en_US').formatMinor(1250),
      contains('1,250'),
    );
    expect(
      moneyFormat('JPY', locale: 'en_US').formatMinor(1250),
      isNot(contains('.')),
    );
    expect(
      moneyFormat('EUR', locale: 'en_US').formatMinor(1250),
      contains('12.50'),
    );
    expect(
      moneyFormat('KWD', locale: 'en_US').formatMinor(1250),
      contains('1.250'),
    );
  });

  test('a missing, blank or malformed currency reads "Currency unavailable", '
      'never a number', () {
    for (final code in [null, '', 'eur', 'EURO', '€']) {
      final format = moneyFormat(code, locale: 'en_US');
      expect(format.unavailable, isTrue, reason: '$code');
      expect(format.formatMinor(1250), 'Currency unavailable', reason: '$code');
      expect(format.format(12.5), 'Currency unavailable', reason: '$code');
      expect(format.formatMinor(1250), isNot(contains(RegExp('[0-9]'))));
    }
  });

  test('in the reader\'s language, English where the app has none', () {
    expect(
      moneyFormat(null, locale: 'fr_FR').formatMinor(1),
      'Devise indisponible',
    );
    expect(
      moneyFormat(null, locale: 'de_CH').formatMinor(1),
      'Währung nicht verfügbar',
    );
    expect(
      moneyFormat(null, locale: 'ja_JP').formatMinor(1),
      'Currency unavailable',
    );
  });

  test('the app format of no business shows no amount', () {
    const format = AppFormat(locale: 'en_US', currencyCode: '');
    expect(format.money(1250), 'Currency unavailable');
    expect(format.moneyCompact(1250), 'Currency unavailable');
    expect(format.moneyIn(null).formatMinor(1250), 'Currency unavailable');
    expect(format.moneyNamed('').formatMinor(1250), 'Currency unavailable');
    expect(format.money(1250, currency: 'EUR'), contains('12.50'));
    expect(AppFormat.fallback.money(1250), 'Currency unavailable');
  });

  test('a document, a file or a payment refuses a missing currency', () {
    expect(requireCurrency('JPY'), 'JPY');
    for (final code in [null, '', 'eur']) {
      expect(
        () => requireCurrency(code, where: 'letter'),
        throwsA(isA<CurrencyUnavailable>()),
        reason: '$code',
      );
    }
  });
}
