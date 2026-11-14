// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2488 -- the `country` rows of a tax reference snapshot as the catalogue's
// countries: the rows in force (newest open version of each), in their
// `position` order. A row whose banking scheme the app has no payment form
// for is left out, never read as SEPA: a workspace is not created with
// payment instructions of the wrong shape.
import 'package:deskilo_document_model/paper.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'country_catalog.dart';

/// #3852 — the papers a row names; none, or one the app does not print on:
/// both.
List<Paper> _papers(List<String>? wire) {
  final papers = [for (final w in wire ?? const <String>[]) ?Paper.fromWire(w)];
  return papers.isEmpty ? Paper.values : papers;
}

List<Country> countriesOfReference(TaxReferenceSet set) {
  // #3852 — the papers of a country's documents, from its own rows.
  final papers = {
    for (final row in set.resolved(null).where(TaxDomain.documentPaper))
      if (row.value case final DocumentPaperValue v) row.country: v,
  };
  final rows = [
    for (final row in set.resolved(null).where(TaxDomain.country))
      if (row.value case final CountryValue v)
        if (BankingScheme.values.asNameMap()[v.bankingScheme] case final scheme?)
          if (v.currency.length == 3 && v.timeZone.isNotEmpty)
            (position: v.position, country: Country(row.country, v.currency, v.timeZone, scheme: scheme,
                paper: Paper.fromWire(papers[row.country]?.paper) ?? Paper.a4,
                papers: _papers(papers[row.country]?.papers))),
  ]..sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0 ? byPosition : a.country.code.compareTo(b.country.code);
    });
  return [for (final r in rows) r.country];
}
