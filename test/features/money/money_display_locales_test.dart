// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1870 — every UI locale shows the stored value: the digits on screen,
// read back, are the minor units in storage, for zero-, two- and three-
// decimal currencies and up to the largest exact amount.
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

void main() {
  setUpAll(() => initializeDateFormatting());
  const locales = ['en', 'fr', 'de', 'es', 'it'];
  const cases = [
    ('CAD', 114975),
    ('EUR', -1005),
    ('JPY', 5000),
    ('KWD', 1250),
    ('EUR', 9007199254740991),
  ];
  for (final locale in locales) {
    for (final (code, minor) in cases) {
      test('$locale shows $minor $code as stored', () {
        final shown = moneyFormat(code, locale: locale).formatMinor(minor);
        expect(_digits(shown), '${minor.abs()}', reason: shown);
        expect(shown.contains('-') || shown.contains('−'), minor < 0,
            reason: shown);
      });
    }
  }
}
