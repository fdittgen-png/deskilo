// SPDX-License-Identifier: AGPL-3.0-or-later
// #2488 -- the golden of the country catalogue, captured BEFORE it moves
// into the reference store: `CountryCatalog` must keep answering exactly
// these values for these codes, in this order, whatever feeds it.
import 'package:deskilo/core/country/country_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

const _golden = <(String, String, String, BankingScheme)>[
  ('AT', 'EUR', 'Europe/Vienna', BankingScheme.sepa),
  ('BE', 'EUR', 'Europe/Brussels', BankingScheme.sepa),
  ('CY', 'EUR', 'Asia/Nicosia', BankingScheme.sepa),
  ('DE', 'EUR', 'Europe/Berlin', BankingScheme.sepa),
  ('EE', 'EUR', 'Europe/Tallinn', BankingScheme.sepa),
  ('ES', 'EUR', 'Europe/Madrid', BankingScheme.sepa),
  ('FI', 'EUR', 'Europe/Helsinki', BankingScheme.sepa),
  ('FR', 'EUR', 'Europe/Paris', BankingScheme.sepa),
  ('GR', 'EUR', 'Europe/Athens', BankingScheme.sepa),
  ('HR', 'EUR', 'Europe/Zagreb', BankingScheme.sepa),
  ('IE', 'EUR', 'Europe/Dublin', BankingScheme.sepa),
  ('IT', 'EUR', 'Europe/Rome', BankingScheme.sepa),
  ('LT', 'EUR', 'Europe/Vilnius', BankingScheme.sepa),
  ('LU', 'EUR', 'Europe/Luxembourg', BankingScheme.sepa),
  ('LV', 'EUR', 'Europe/Riga', BankingScheme.sepa),
  ('MT', 'EUR', 'Europe/Malta', BankingScheme.sepa),
  ('NL', 'EUR', 'Europe/Amsterdam', BankingScheme.sepa),
  ('PT', 'EUR', 'Europe/Lisbon', BankingScheme.sepa),
  ('SI', 'EUR', 'Europe/Ljubljana', BankingScheme.sepa),
  ('SK', 'EUR', 'Europe/Bratislava', BankingScheme.sepa),
  ('BG', 'BGN', 'Europe/Sofia', BankingScheme.sepa),
  ('CZ', 'CZK', 'Europe/Prague', BankingScheme.sepa),
  ('DK', 'DKK', 'Europe/Copenhagen', BankingScheme.sepa),
  ('HU', 'HUF', 'Europe/Budapest', BankingScheme.sepa),
  ('PL', 'PLN', 'Europe/Warsaw', BankingScheme.sepa),
  ('RO', 'RON', 'Europe/Bucharest', BankingScheme.sepa),
  ('SE', 'SEK', 'Europe/Stockholm', BankingScheme.sepa),
  ('CH', 'CHF', 'Europe/Zurich', BankingScheme.ch),
  ('NO', 'NOK', 'Europe/Oslo', BankingScheme.sepa),
  ('GB', 'GBP', 'Europe/London', BankingScheme.uk),
  ('US', 'USD', 'America/New_York', BankingScheme.us),
  ('CA', 'CAD', 'America/Toronto', BankingScheme.ca),
];

void main() {
  test('the catalogue lists exactly today\'s countries, in order, with their values', () {
    expect(
      [
        for (final c in CountryCatalog.countries)
          (c.code, c.currencyCode, c.defaultTimezone, c.scheme),
      ],
      _golden,
    );
  });

  test('byCode answers every code, in either case', () {
    for (final (code, currency, zone, scheme) in _golden) {
      for (final spelled in [code, code.toLowerCase()]) {
        final c = CountryCatalog.byCode(spelled);
        expect((c.code, c.currencyCode, c.defaultTimezone, c.scheme), (code, currency, zone, scheme));
        expect(CountryCatalog.isKnown(spelled), isTrue);
      }
    }
  });

  test('an unknown code reads as the fallback country, and is not known', () {
    expect(CountryCatalog.byCode('ZZ').code, 'FR');
    expect(CountryCatalog.isKnown('ZZ'), isFalse);
    expect(CountryCatalog.isKnown(''), isFalse);
  });
}
