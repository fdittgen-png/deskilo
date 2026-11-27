// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The countries a postal address may choose are the catalogue's, with a
// country already stored kept among them when the catalogue does not offer it.
import 'package:deskilo/core/country/country_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogue = [for (final c in CountryCatalog.countries) c.code];

  test('without a stored country, the catalogue as it is', () {
    expect(CountryCatalog.addressCodes(), catalogue);
    expect(CountryCatalog.addressCodes(stored: ''), catalogue);
  });

  test('a stored country of the catalogue is not listed twice', () {
    expect(CountryCatalog.addressCodes(stored: catalogue.first), catalogue);
  });

  test('a stored country the catalogue does not offer leads the list, as it was stored', () {
    expect(CountryCatalog.addressCodes(stored: 'BR'), ['BR', ...catalogue]);
  });
}
