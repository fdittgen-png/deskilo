// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the Canadian numbers and the way the two taxes print
//
// #2361 — the business number with its RT account and Revenu Québec's TQ
// number (server twin: migration 0424, pgTAP 181), the bilingual mentions,
// the small supplier's wording, the quick-method flag, and an invoice whose
// total carries GST and QST printing them on two rows.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:deskilo/features/money/domain/vat_components.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _quebec() => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'm1',
  number: 'F-2026-0001',
  issuedAt: DateTime(2026, 9, 30),
  title: '2026-09',
  lines: const [InvoiceLine(label: 'Desk', amountCents: 114975, vatPercent: 14.975)],
  totalCents: 114975,
  currency: 'CAD',
  memberName: 'Ana Martin',
  memberAddress: '',
  workspaceName: 'Espace',
  workspaceAddress: '',
  issuerName: 'Espace',
  signature: 'sig',
  vatTotals: [
    InvoiceVatTotal(
      percent: 14.975,
      category: 'S',
      grossCents: 114975,
      netCents: 100000,
      vatCents: 14975,
      components: vatComponentsOf('CA', 14.975, 100000, 14975),
    ),
  ],
  sellerParty: InvoiceParty.fromSnapshot(const {
    'country': 'CA',
    'vat_regime': 'vat_registered',
    'vat_id': '123456789rt0001',
    'legal_id': '1234567890 TQ0001',
  }),
);

void main() {
  test('the business number carries the RT account', () {
    for (final ok in ['123456789 RT0001', '123456789RT0002', '123456789 rt0001']) {
      expect(isValidCanadianBn(ok), isTrue, reason: ok);
    }
    for (final bad in ['123456789', '12345678 RT0001', '123456789 RC0001', '', 'GB123456789']) {
      expect(isValidCanadianBn(bad), isFalse, reason: bad);
    }
  });

  test('the QST number is ten digits and TQ', () {
    expect(isValidQstNumber('1234567890 TQ0001'), isTrue);
    expect(isValidQstNumber('1234567890TQ0001'), isTrue);
    expect(isValidQstNumber('1234567890 TQ'), isFalse);
    expect(isValidQstNumber('123456789 RT0001'), isFalse);
    expect(formatCanadianRegistration('123456789rt0001'), '123456789 RT0001');
    expect(formatCanadianRegistration('1234567890TQ0001'), '1234567890 TQ0001');
    expect(formatCanadianRegistration('not a number'), 'not a number');
  });

  test('a registered seller prints its numbers, the QST one only when charged', () {
    List<String> mentions({bool qst = false, VatRegime regime = VatRegime.vatRegistered}) =>
        nationalInvoiceMentions(
          sellerCountry: 'CA',
          regime: regime,
          currency: 'CAD',
          untaxedCents: 0,
          correction: false,
          sellerVatId: '123456789rt0001',
          sellerLegalId: '1234567890TQ0001',
          qstCharged: qst,
        );
    expect(mentions(), ['GST/HST No. · N° de TPS/TVH : 123456789 RT0001']);
    expect(mentions(qst: true), [
      'GST/HST No. · N° de TPS/TVH : 123456789 RT0001',
      'QST No. · N° de TVQ : 1234567890 TQ0001',
    ]);
    expect(mentions(regime: VatRegime.exempt), isEmpty);
    expect(
      nationalInvoiceMentions(
        sellerCountry: 'CH', regime: VatRegime.vatRegistered, currency: 'CHF',
        untaxedCents: 0, correction: false, sellerVatId: '123456789rt0001'),
      isEmpty,
    );
  });

  test('a small supplier says so, in both languages', () {
    final text = defaultExemptionMention('CA', VatRegime.exempt);
    expect(text, contains('Small supplier'));
    expect(text, contains('Petit fournisseur'));
    expect(defaultExemptionMention('CA', VatRegime.vatRegistered), isEmpty);
  });

  test('a Quebec invoice prints GST and QST on two rows, on the same base', () {
    final data = invoiceReportData(
      const ReportStrings(),
      _quebec(),
      proforma: false,
      copy: false,
    );
    final rows = (data['vat']! as List).cast<Map<String, Object?>>();
    expect(rows.length, 2);
    expect(rows[0]['rate'].toString(), startsWith('GST '));
    expect(rows[1]['rate'].toString(), startsWith('QST '));
    expect(rows[0]['net'], rows[1]['net']);
    expect(rows.map((r) => r['amount']).join(' '), contains('50'));
    expect(rows.map((r) => r['amount']).join(' '), contains('99'));
    expect('${data['special_mentions']}', contains('1234567890 TQ0001'));
    expect('${data['special_mentions']}', contains('123456789 RT0001'));
    final french = invoiceReportData(
      const ReportStrings(localeName: 'fr'),
      _quebec(),
      proforma: false,
      copy: false,
    );
    final frRows = (french['vat']! as List).cast<Map<String, Object?>>();
    expect(frRows[0]['rate'].toString(), startsWith('TPS '));
    expect(frRows[1]['rate'].toString(), startsWith('TVQ '));
  });

  test('the quick-method flag round-trips and leaves other identities alone', () {
    final legal = InvoiceLegal.fromJson(const {'quick_method': true});
    expect(legal.quickMethod, isTrue);
    expect(legal.toJson()['quick_method'], isTrue);
    expect(InvoiceLegal.fromJson(legal.toJson()), legal);
    expect(const InvoiceLegal().toJson().containsKey('quick_method'), isFalse);
    expect(
      legal.withLandTaxation(
        optionToTax: false, optionToTaxDate: '', optionToTaxReference: '',
        facilitiesPackage: false).quickMethod,
      isFalse,
    );
  });
}
