// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3591 -- on a screen an alphabetic currency symbol is set off from the
// number by a no-break space, on whichever side the locale puts it; a glyph
// symbol keeps the locale's own spacing; documents (which name their own
// locale through `moneyFormat`) are spelled exactly as before.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

const _locales = [
  'en',
  'en_GB',
  'de_DE',
  'de_CH',
  'fr_FR',
  'fr_CH',
  'it_IT',
  'es_ES',
];
const _codes = ['EUR', 'CHF', 'GBP', 'USD', 'PLN'];
const _nbsp = ' ';

String _symbolOf(String locale, String code) =>
    NumberFormat.simpleCurrency(locale: locale, name: code).currencySymbol;

void main() {
  group('a screen', () {
    for (final locale in _locales) {
      for (final code in _codes) {
        final symbol = _symbolOf(locale, code);
        final alphabetic = RegExp(r'^[A-Za-z]{3}$').hasMatch(symbol);
        test('$locale $code ($symbol)', () {
          final format = AppFormat(locale: locale, currencyCode: code);
          for (final minor in [9500, 123456, -9500]) {
            final screen = format.moneyIn(code).formatMinor(minor);
            final viaMoney = format.money(minor);
            final document = moneyFormat(
              code,
              locale: locale,
            ).formatMinor(minor);
            expect(viaMoney, screen, reason: 'money() and moneyIn() agree');
            if (alphabetic) {
              final sym = RegExp.escape(symbol);
              expect(
                RegExp('^[-−]?$sym$_nbsp[\\d-]|\\d$_nbsp$sym\$')
                    .hasMatch(screen),
                isTrue,
                reason: '$screen: the symbol is set off by a no-break space',
              );
              expect(
                screen.replaceAll(RegExp(r'\s'), ''),
                document.replaceAll(RegExp(r'\s'), ''),
                reason: 'only the space moved, never a digit or a sign',
              );
            } else {
              expect(
                screen,
                document,
                reason: 'a glyph keeps the locale spacing',
              );
            }
          }
        });
      }
    }

    test('the compact form is spaced the same way', () {
      const format = AppFormat(locale: 'en', currencyCode: 'CHF');
      expect(format.moneyCompact(9500), 'CHF${_nbsp}95');
    });
  });

  test('a document is spelled as before: no space is added', () {
    expect(moneyFormat('CHF', locale: 'en').formatMinor(9500), 'CHF95.00');
    expect(moneyFormat('EUR', locale: 'en').formatMinor(12000), '€120.00');
    expect(moneyFormat('CHF', locale: 'en').spaceAlphabetic, isFalse);
  });
}
