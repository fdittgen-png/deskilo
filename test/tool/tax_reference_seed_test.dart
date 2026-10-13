// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 -- the seed reproduces today's Dart constants EXACTLY, and the two
// places it lands (the migration's seed block and the app's bundled copy)
// are what the generator writes. Pinned against the constants themselves,
// not against the generated files alone: a pin that validates generated
// output against itself proves nothing.
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/tax_reference/seed.dart';

TaxReferenceSet _seedSet() => TaxReferenceSet.parse(
      [
        for (final r in buildTaxReferenceSeed())
          {
            'domain': r.domain,
            'country': r.country,
            'key': r.key,
            'valid_from': r.validFrom,
            'valid_to': null,
            'value': r.value,
            'source': r.source,
            'confirmed': r.confirmed,
          },
      ],
    );

File _migration() => Directory('supabase/migrations')
    .listSync()
    .whereType<File>()
    .singleWhere((f) => f.path.endsWith('_tax_reference.sql'));

void main() {
  final set = _seedSet().on('2026-10-13');

  test('every country\'s rates are the catalogue\'s, in order, with the same dates', () {
    for (final country in vatCatalogueCountries) {
      final stored = [
        for (final r in set.where(TaxDomain.rate, country: country))
          if (r.country == country) r,
      ]..sort((a, b) =>
          (a.value as RateValue).position.compareTo((b.value as RateValue).position));
      final code = vatCatalogueFor(country);
      expect(stored, hasLength(code.length), reason: country);
      for (final (i, r) in code.indexed) {
        final v = stored[i].value as RateValue;
        expect(v.label, r.label, reason: country);
        expect(v.percent, r.percent, reason: country);
        expect(v.group, r.groupKey, reason: country);
        expect(v.category, r.category, reason: country);
        expect(v.exemptionReason, r.exemptionReason, reason: country);
        expect(stored[i].validFrom, r.validFrom, reason: country);
      }
    }
  });

  test('the EU member set is the code\'s', () {
    expect(
      {for (final r in set.where(TaxDomain.euMember)) r.country},
      euMemberStates,
    );
  });

  test('the VAT id patterns are the code\'s', () {
    expect(
      {for (final r in set.where(TaxDomain.vatIdPattern)) r.country: (r.value as VatIdPatternValue).pattern},
      vatIdBodiesForSeed,
    );
  });

  test('a statutory mention resolves to what the function prints, country by country', () {
    String text(String regime, String country) =>
        (set.lookup(TaxDomain.mention, country, regime)!.value as ExemptionTextValue).text;
    for (final c in {...vatCatalogueCountries, ...euMemberStates, 'ZZ'}) {
      expect(text('exempt', c), defaultExemptionMention(c, VatRegime.exempt), reason: c);
      expect(text('not_subject', c), defaultExemptionMention(c, VatRegime.notSubject), reason: c);
      expect(text('reverse_charge', c), reverseChargeMention(c), reason: c);
      expect(text('export', c), exportMention(c), reason: c);
      expect(
        text('exigibility_receipts', c),
        exigibilityMention(regime: VatRegime.vatRegistered, sellerCountry: c, onPaymentBasis: true),
        reason: c,
      );
    }
  });

  test('an unverified value is not marked confirmed', () {
    for (final r in set.rows) {
      if (r.domain == TaxDomain.mention || r.domain == TaxDomain.vatIdPattern) {
        expect(r.confirmed, isFalse, reason: '${r.country} ${r.key}');
      }
      expect(r.source.trim(), isNotEmpty);
    }
  });

  test('the migration\'s seed block is what the generator writes', () {
    expect(
      seedBlockOf(_migration().readAsStringSync()),
      taxReferenceSeedSql(buildTaxReferenceSeed()),
      reason: 'dart run tool/build_tax_reference_seed.dart --migration ${_migration().path}',
    );
  });

  test('the bundled copy is what the generator writes', () {
    expect(
      File('assets/instance/tax_reference.json').readAsStringSync(),
      taxReferenceBundleJson(buildTaxReferenceSeed()),
      reason: 'dart run tool/build_tax_reference_seed.dart',
    );
  });
}
