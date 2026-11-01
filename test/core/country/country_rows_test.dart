// SPDX-License-Identifier: AGPL-3.0-or-later
// #2488 -- the catalogue is the reference store's `country` rows: read in
// their position order, a row the app cannot honour is left out, an empty
// answer never empties the forms, and a country added in the store is one
// a workspace can be created in, with its currency and zone.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/core/country/country_rows.dart';
import 'package:deskilo/core/country/country_seed.g.dart';
import 'package:deskilo/core/locale/device_locale.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/tax_reference/seed.dart';

Map<String, Object?> _row(String country, Map<String, Object?> value, {String key = 'catalogue'}) => {
      'domain': 'country',
      'country': country,
      'key': key,
      'valid_from': '1900-01-01',
      'valid_to': null,
      'value': value,
      'source': 'test',
      'confirmed': false,
    };

TaxReferenceSet _set(List<Map<String, Object?>> rows) => TaxReferenceSet.parse(rows);

void main() {
  tearDown(CountryCatalog.reset);

  test('rows become countries in position order, then code', () {
    final countries = countriesOfReference(_set([
      _row('ZZ', {'currency': 'EUR', 'time_zone': 'Europe/Paris', 'banking_scheme': 'sepa', 'position': 2}),
      _row('AA', {'currency': 'CHF', 'time_zone': 'Europe/Zurich', 'banking_scheme': 'ch', 'position': 2}),
      _row('MM', {'currency': 'GBP', 'time_zone': 'Europe/London', 'banking_scheme': 'uk', 'position': 1}),
    ]));
    expect([for (final c in countries) c.code], ['MM', 'AA', 'ZZ']);
    expect(countries.first.scheme, BankingScheme.uk);
    expect(countries[1].scheme, BankingScheme.ch);
  });

  test('a row with a scheme the app has no payment form for is left out, not read as SEPA', () {
    final countries = countriesOfReference(_set([
      _row('AA', {'currency': 'EUR', 'time_zone': 'Europe/Paris', 'banking_scheme': 'swift'}),
      _row('BB', {'currency': 'EUR', 'time_zone': 'Europe/Paris', 'banking_scheme': 'sepa'}),
    ]));
    expect([for (final c in countries) c.code], ['BB']);
  });

  test('the seed asset read as a snapshot is the golden catalogue, value for value', () {
    final rows = File('assets/instance/tax_reference.json').readAsStringSync();
    final set = TaxReferenceSet.parse(jsonDecode(rows));
    expect(
      [for (final c in countriesOfReference(set)) (c.code, c.currencyCode, c.defaultTimezone, c.scheme)],
      [for (final c in bundledCountries) (c.code, c.currencyCode, c.defaultTimezone, c.scheme)],
    );
  });

  test('an installed catalogue replaces the bundled copy; an empty one does not', () {
    CountryCatalog.install(const []);
    expect(CountryCatalog.countries.length, 32, reason: 'empty answer ignored');
    CountryCatalog.install(const [Country('AU', 'AUD', 'Australia/Sydney')]);
    expect(CountryCatalog.countries.map((c) => c.code), ['AU']);
    CountryCatalog.reset();
    expect(CountryCatalog.countries.length, 32);
  });

  test('a country added in the store is one a workspace is created in, with its currency and zone', () {
    expect(CountryCatalog.isKnown('AU'), isFalse);
    CountryCatalog.install([
      ...bundledCountries,
      const Country('AU', 'AUD', 'Australia/Sydney'),
    ]);
    expect(CountryCatalog.isKnown('au'), isTrue);
    final c = initialCountryFor(const Locale('en', 'AU'));
    expect((c.code, c.currencyCode, c.defaultTimezone), ('AU', 'AUD', 'Australia/Sydney'));
  });

  test('the generated Dart copy is what the asset produces (no drift)', () {
    final rows = buildTaxReferenceSeed();
    expect(File('lib/core/country/country_seed.g.dart').readAsStringSync(), countrySeedDart(rows),
        reason: 'dart run tool/build_tax_reference_seed.dart');
  });
}
