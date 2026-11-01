// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2488 -- the `country` rows of a tax reference snapshot as the catalogue's
// countries: the rows in force (newest open version of each), in their
// `position` order. A row whose banking scheme the app has no payment form
// for is left out, never read as SEPA: a workspace is not created with
// payment instructions of the wrong shape.
import '../vat/tax_reference.dart';
import '../vat/tax_reference_active.dart';
import 'country_catalog.dart';

List<Country> countriesOfReference(TaxReferenceSet set) {
  final rows = [
    for (final row in set.resolved(null).where(TaxDomain.country))
      if (row.value case final CountryValue v)
        if (BankingScheme.values.asNameMap()[v.bankingScheme] case final scheme?)
          if (v.currency.length == 3 && v.timeZone.isNotEmpty)
            (position: v.position, country: Country(row.country, v.currency, v.timeZone, scheme: scheme)),
  ]..sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0 ? byPosition : a.country.code.compareTo(b.country.code);
    });
  return [for (final r in rows) r.country];
}
