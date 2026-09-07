// SPDX-License-Identifier: 0BSD
//
// #985 — VAT like an ERP: dated rate versions, one tax point, the
// counterparty dimension. The Dart twins of migration 0182, the
// catalogue's explicit groups, and the e-invoice categories G and E.
import 'dart:io';

import 'package:deskilo/core/vat/vat_treatment.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart'
    show buildInvoiceUbl;
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const old = VatRate(
      id: 'r-20', label: 'Standard 20 %', percent: 20, validTo: '2026-09-01');
  const next = VatRate(
      id: 'r-21',
      label: 'Standard 21 %',
      percent: 21,
      validFrom: '2026-09-01',
      supersedesId: 'r-20');
  const reduced = VatRate(id: 'r-5', label: 'Réduit 5,5 %', percent: 5.5);
  final rates = [old, next, reduced];

  group('vatPercentAt — the family walk (0182 vat_rate_percent_at)', () {
    test('the old row read after the change gives the new value', () {
      expect(vatPercentAt(rates, 'r-20', DateTime(2026, 9, 15)), 21);
      expect(vatPercentAt(rates, 'r-20', DateTime(2026, 8, 15)), 20);
    });

    test('the successor read backwards gives the old value', () {
      expect(vatPercentAt(rates, 'r-21', DateTime(2026, 8, 15)), 20);
      expect(vatPercentAt(rates, 'r-21', DateTime(2026, 9, 1)), 21);
    });

    test('a rate outside the family is untouched by the change', () {
      expect(vatPercentAt(rates, 'r-5', DateTime(2026, 12, 31)), 5.5);
    });

    test('an inactive family answers null — the default takes over', () {
      final off = [old.copyWith(active: false), next.copyWith(active: false)];
      expect(vatPercentAt(off, 'r-20', DateTime(2026, 9, 15)), isNull);
    });

    test('the pointed row wins a tie on the start date', () {
      const twinA = VatRate(id: 'a', label: 'A', percent: 10);
      const twinB = VatRate(id: 'b', label: 'B', percent: 12, supersedesId: 'a');
      expect(vatPercentAt([twinA, twinB], 'a', DateTime(2026, 1, 1)), 10);
      expect(vatPercentAt([twinA, twinB], 'b', DateTime(2026, 1, 1)), 12);
    });
  });

  test('vatTaxPoint — the month\'s last day, or today when billed ahead', () {
    final today = DateTime(2026, 9, 6);
    expect(vatTaxPoint('2026-08', today), DateTime(2026, 8, 31));
    expect(vatTaxPoint('2026-09', today), today);
    expect(vatTaxPoint('2026-11', today), today);
  });

  test('VatRate carries its window and its family on the wire', () {
    final json = next.toJson();
    expect(json['valid_from'], '2026-09-01');
    expect(json['valid_to'], isNull);
    expect(json['supersedes_id'], 'r-20');
    final back = VatRate.fromRow({
      'id': 'x',
      'label': 'L',
      'percent': 21,
      'valid_from': '2026-09-01',
      'valid_to': '2027-01-01',
      'supersedes_id': 'r-20',
    });
    expect(back.validFrom, '2026-09-01');
    expect(back.validTo, '2027-01-01');
    expect(back.supersedesId, 'r-20');
    expect(back.isDated, isTrue);
    expect(reduced.isDated, isFalse);
    expect(back.copyWith(clearValidTo: true).validTo, isNull);
  });

  test('the catalogue names the group of every rate, in every country', () {
    for (final country in vatCatalogueCountries) {
      final seeded = vatCatalogueFor(country);
      expect(seeded, isNotEmpty, reason: country);
      expect(seeded.first.groupKey, 'standard', reason: country);
      for (final r in seeded) {
        expect(r.groupKey, isNotEmpty, reason: '$country ${r.label}');
      }
    }
    final fr = vatCatalogueFor('FR');
    expect(fr.map((r) => r.groupKey).toList(),
        ['standard', 'intermediate', 'reduced', 'super_reduced']);
    final de = vatCatalogueFor('DE');
    expect(de.map((r) => r.groupKey).toList(), ['standard', 'reduced']);
  });

  test('VatTreatment round-trips its wire and defaults to auto', () {
    for (final t in VatTreatment.values) {
      expect(VatTreatment.fromWire(t.wire), t);
    }
    expect(VatTreatment.fromWire('nonsense'), VatTreatment.auto);
    expect(VatTreatment.fromWire(null), VatTreatment.auto);
  });

  group('the counterparty category on the document', () {
    Invoice doc(String category, {int percent = 0}) => Invoice(
          id: 'i',
          workspaceId: 'w',
          memberId: 'm',
          number: 'INV-1',
          period: '2026-11',
          currency: 'EUR',
          issuedAt: DateTime.utc(2026, 9, 6),
          issuerName: 'Flo',
          memberAddress: '',
          memberName: 'Zoé',
          signature: '',
          title: '',
          workspaceAddress: '',
          workspaceName: 'Cowork',
          lines: [
            InvoiceLine(
                kind: 'subscription',
                label: '100',
                amountCents: 10000,
                vatPercent: percent.toDouble()),
          ],
          totalCents: 10000,
          vatTotals: [
            InvoiceVatTotal(
                percent: percent.toDouble(),
                category: category,
                grossCents: 10000,
                netCents: 10000,
                vatCents: 0),
          ],
        );
    const seller = InvoiceParty(
        name: 'Cowork', country: 'FR', vatId: 'FR12345678901',
        vatRegime: 'vat_registered');

    test('G: the CII and the UBL carry the category and VATEX-EU-G', () {
      final invoice = doc('G');
      expect(invoice.counterpartyCategory, 'G');
      expect(exemptionCodeForCategory('G', 'FR', VatRegime.vatRegistered),
          'VATEX-EU-G');
      final cii = buildInvoiceCii(
          invoice: invoice,
          seller: seller,
          buyer: const InvoiceParty(name: 'Zoé', country: 'US'),
          lineText: (l) => l.label);
      expect(cii, contains('<ram:CategoryCode>G</ram:CategoryCode>'));
      expect(cii, contains('VATEX-EU-G'));
      expect(cii, contains(exportMention('FR')));
      final ubl = buildInvoiceUbl(
          invoice: invoice,
          seller: seller,
          buyer: const InvoiceParty(name: 'Zoé', country: 'US'),
          lineText: (l) => l.label);
      expect(ubl, contains('<cbc:ID>G</cbc:ID>'));
      expect(ubl, contains('VATEX-EU-G'));
    });

    test('E from an exempt buyer prints the BUYER\'s reason', () {
      final invoice = doc('E');
      expect(invoice.counterpartyCategory, 'E');
      final cii = buildInvoiceCii(
          invoice: invoice,
          seller: seller,
          buyer: const InvoiceParty(
              name: 'Ambassade',
              country: 'FR',
              taxExemptionReason: 'Exonération art. 261 CGI'),
          lineText: (l) => l.label);
      expect(cii, contains('<ram:CategoryCode>E</ram:CategoryCode>'));
      expect(cii, contains('Exonération art. 261 CGI'));
    });

    test('a plain domestic document has no counterparty category', () {
      expect(doc('S', percent: 20).counterpartyCategory, '');
      expect(
          exemptionMentionFor(
              category: 'S',
              sellerCountry: 'FR',
              sellerReason: 'x',
              buyerReason: 'y',
              regime: VatRegime.vatRegistered),
          'x');
    });
  });

  test('migration 0182 — the server carries every function the client relies on',
      () {
    final sql =
        File('supabase/migrations/0182_vat_rate_versions.sql').readAsStringSync();
    for (final fn in [
      'vat_rate_family',
      'vat_rate_percent_at',
      'workspace_default_vat_percent(p_workspace_id uuid, p_date date)',
      'workspace_tariff_vat_percent(p_workspace_id uuid, p_date date)',
      'vat_tax_point',
      'set_member_vat_treatment',
    ]) {
      expect(sql, contains(fn));
    }
    for (final t in VatTreatment.values) {
      expect(sql, contains("'${t.wire}'"));
    }
  });
}
