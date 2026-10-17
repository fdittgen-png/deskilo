// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2478 (C2 of #2476) -- the rate catalogue, the EU member set, the
// statutory texts and the VAT id patterns come from the tax reference store.
// `golden/vat_reference_golden.json` was captured from the Dart constants
// BEFORE they were deleted: every answer the functions gave, country by
// country. The store reproduces it exactly, and the golden stays.
//
// The second group is the history rule: change the data, regenerate
// nothing, compare -- a document keeps the values of the day it was issued.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final golden = jsonDecode(
    File('test/features/money/golden/vat_reference_golden.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final countries = (golden['countries'] as List).cast<String>();

  test('vatCatalogueFor equals the old catalogue for every country', () {
    final expected = golden['catalogue'] as Map<String, dynamic>;
    for (final c in countries) {
      final got = [
        for (final r in vatCatalogueFor(c))
          {
            'label': r.label,
            'percent': r.percent,
            'isDefault': r.isDefault,
            'category': r.category,
            'groupKey': r.groupKey,
            'outsideBase': r.outsideBase,
            'validFrom': r.validFrom,
            'exemptionReason': r.exemptionReason,
          },
      ];
      expect(got, expected[c], reason: c);
    }
  });

  test('the catalogue notes and the group examples are the old ones', () {
    for (final c in countries) {
      expect(vatCatalogueNote(c), (golden['note'] as Map)[c], reason: c);
      expect(
        [
          for (final e in vatGroupExamples(c)) {'group': e.group.wire, 'example': e.example},
        ],
        (golden['examples'] as Map)[c],
        reason: c,
      );
    }
    final decided = TaxReferenceSet([
      for (final r in ActiveTaxReference.current.rows)
        if (r.domain == TaxDomain.rate && r.validFrom == '2028-01-01')
          r.confirmedWith('vote')
        else
          r,
    ]);
    expect(vatCatalogueNote('CH', asOf: '2026-12-01', reference: decided),
        contains('The vote passed'));
  });

  test('every statutory mention is the old string, for every country', () {
    final expected = golden['mentions'] as Map<String, dynamic>;
    for (final c in countries) {
      expect({
        'exempt': defaultExemptionMention(c, VatRegime.exempt),
        'exempt_ex': defaultExemptionMention(c, VatRegime.exempt, vatId: 'FR12345678901EX'),
        'not_subject': defaultExemptionMention(c, VatRegime.notSubject),
        'registered': defaultExemptionMention(c, VatRegime.vatRegistered),
        'reverse_charge': reverseChargeMention(c),
        'export': exportMention(c),
        'receipts': exigibilityMention(
            regime: VatRegime.vatRegistered, sellerCountry: c, onPaymentBasis: true),
        'invoices': exigibilityMention(
            regime: VatRegime.vatRegistered, sellerCountry: c, onPaymentBasis: false),
        'exigibility_exempt': exigibilityMention(
            regime: VatRegime.exempt, sellerCountry: c, onPaymentBasis: true),
      }, expected[c], reason: c);
    }
  });

  test('the EU set, its aliases and the VAT id patterns are the old ones', () {
    expect(euMemberStates.toList()..sort(), golden['eu']);
    for (final MapEntry(key: code, value: eu) in (golden['isEu'] as Map<String, dynamic>).entries) {
      expect(isEuCountry(code), eu, reason: "isEuCountry('$code')");
    }
    for (final MapEntry(key: code, value: want) in (golden['euCode'] as Map<String, dynamic>).entries) {
      expect(euCountryCode(code), want, reason: "euCountryCode('$code')");
    }
    for (final MapEntry(key: prefix, value: body) in (golden['idBodies'] as Map<String, dynamic>).entries) {
      expect(ActiveTaxReference.current.vatIdBody(prefix), body as String, reason: prefix);
    }
    for (final MapEntry(key: id, value: ok) in (golden['idChecks'] as Map<String, dynamic>).entries) {
      expect(looksLikeEuVatId(id), ok, reason: "looksLikeEuVatId('$id')");
    }
  });

  group('history is frozen: change the data, regenerate nothing, compare', () {
    TaxReferenceRow row(String domain, String country, String key, String from,
            Map<String, Object?> value) =>
        TaxReferenceRow.fromJson({
          'domain': domain,
          'country': country,
          'key': key,
          'valid_from': from,
          'valid_to': null,
          'value': value,
          'source': 'a test',
          'confirmed': true,
        });

    /// The bundled copy with the version in force on [from] closed and a
    /// successor added -- what `set_tax_reference` does.
    TaxReferenceSet changed(String domain, String country, String key, String from,
        Map<String, Object?> value) {
      final all = ActiveTaxReference.current.rows;
      return TaxReferenceSet([
        for (final r in all)
          if (r.domain.wire == domain && r.country == country && r.key == key && r.validTo == null)
            r.closedOn(from)
          else
            r,
        row(domain, country, key, from, value),
      ]);
    }

    test('a rate changed from a day: the catalogue shows the version in force on a day', () {
      final set = changed('rate', 'DE', 'standard', '2027-01-01', {
        'label': 'Regelsatz 20 %', 'percent': 20, 'group': 'standard',
        'category': 'S', 'position': 0,
      });
      expect(vatCatalogueFor('DE', asOf: '2026-12-31', reference: set).first.percent, 19);
      expect(vatCatalogueFor('DE', asOf: '2027-01-01', reference: set).first.percent, 20);
      expect(vatCatalogueFor('DE', reference: set).first.validFrom, '2027-01-01');
      // The installed snapshot is untouched.
      expect(vatCatalogueFor('DE').first.percent, 19);
    });

    test('a statutory text changed later never reaches an invoice issued before', () {
      final set = changed('exemption_text', 'DE', 'exempt', '2027-01-01',
          {'regime': 'exempt', 'text': 'A new wording.'});
      final before = defaultExemptionMention('DE', VatRegime.exempt);
      expect(defaultExemptionMention('DE', VatRegime.exempt, asOf: '2026-12-31', reference: set), before);
      expect(defaultExemptionMention('DE', VatRegime.exempt, asOf: '2027-01-01', reference: set),
          'A new wording.');

      // The printed document: an invoice dated before the change keeps its
      // text through the report data, whatever the installation holds now.
      const workspace = Workspace(
        id: 'w', name: 'N', countryCode: 'DE', currencyCode: 'EUR',
        timezone: 'Europe/Berlin', inviteCode: 'CODE123456', vatRegime: 'exempt',
      );
      final previous = ActiveTaxReference.current;
      addTearDown(() => ActiveTaxReference.install(previous));
      ActiveTaxReference.install(set);
      StatutoryMentionInput input() => (
            workspace: workspace,
            seller: null,
            buyer: null,
            reverseCharged: false,
            counterpartyCategory: '',
            rateExemptionReasons: const <String>[],
            frozen: null,
          );
      expect(statutoryMentionData(input(), asOf: '2026-12-31')['exemption_reason'], before);
      expect(statutoryMentionData(input(), asOf: '2027-02-01')['exemption_reason'],
          'A new wording.');
    });

    test('a member state joining from a day: earlier documents keep their answer', () {
      final set = changed('eu_member', 'GB', 'member', '2030-01-01', {});
      // GB had no row: the changed() helper only added one from the day.
      expect(isEuCountry('GB', reference: set.on('2029-12-31')), isFalse);
      expect(isEuCountry('GB', reference: set.on('2030-01-01')), isTrue);
      expect(isEuCountry('GB'), isFalse);
    });
  });
}
