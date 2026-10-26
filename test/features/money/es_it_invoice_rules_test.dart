// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Spanish and Italian invoice rules read from the tax reference store.
// An Italian exempt document above the stamp-duty line owes the duty its
// row names and says so on the PDF, a taxed, exported or credited one does
// not; the modelo 347 lists the Spanish customers above its line, by
// quarter and province; a small-business alert never reads another kind of
// threshold; the threshold's charge and the gate's outside-VAT postal codes
// survive the store's JSON and the editor's fields.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/small_business_threshold.dart';
import 'package:deskilo/features/money/domain/stamp_duty.dart';
import 'package:deskilo/features/money/domain/vat_filing_terms.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_register_es_347.dart';
import 'package:deskilo/features/money/presentation/widgets/tax_reference_gate_fields.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(
  String number,
  DateTime issued, {
  required List<InvoiceVatTotal> vat,
  String seller = 'IT',
  String buyerCountry = 'IT',
  String vatId = 'IT01234567890',
  String postalCode = '00100',
}) => Invoice(
  id: number,
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: number,
  issuedAt: issued,
  title: number,
  lines: const [],
  totalCents: vat.fold(0, (s, t) => s + t.grossCents),
  currency: 'EUR',
  memberName: 'Cliente',
  memberAddress: '',
  workspaceName: 'Demo',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
  vatTotals: vat,
  sellerParty: InvoiceParty(name: 'Spazio', country: seller),
  buyerParty: InvoiceParty(
    name: 'Cliente',
    company: 'Cliente Srl',
    country: buyerCountry,
    vatId: vatId,
    postalCode: postalCode,
  ),
);

InvoiceVatTotal _total(double percent, int net, int vat, {String c = 'S'}) =>
    InvoiceVatTotal(
      percent: percent,
      category: c,
      grossCents: net + vat,
      netCents: net,
      vatCents: vat,
    );

/// The duty of an issued document, through the decision the FatturaPA and
/// the PDF share.
int? stampDutyOf(Invoice invoice, {TaxReferenceSet? reference}) =>
    stampDutyCents((
      country: invoice.sellerParty?.country ?? '',
      currency: invoice.currency,
      day: invoice.issuedAt,
      totals: invoice.vatTotals,
      grossCents: invoice.vatTotals.fold(0, (sum, t) => sum + t.grossCents),
      buyerCountry: invoice.buyerParty?.country ?? '',
    ), reference: reference);

void main() {
  final day = DateTime(2026, 5, 4);

  group('imposta di bollo (IT)', () {
    test('an exempt document above the line owes the duty of its row', () {
      final exempt = _invoice('FT-1', day, vat: [_total(0, 7748, 0, c: 'E')]);
      expect(stampDutyOf(exempt), 200);
      expect(
        stampDutyOf(_invoice('FT-2', day, vat: [_total(0, 7747, 0, c: 'E')])),
        isNull,
        reason: 'the line itself owes nothing',
      );
      expect(
        stampDutyOf(_invoice('FT-3', day, vat: [_total(22, 10000, 2200)])),
        isNull,
        reason: 'a document that charges VAT',
      );
      expect(
        stampDutyOf(_invoice('FT-4', day, vat: [_total(0, 9000, 0, c: 'G')])),
        isNull,
        reason: 'an export (N3.1)',
      );
      expect(
        stampDutyOf(_invoice('FT-5', day, vat: [_total(0, -9000, 0, c: 'E')])),
        isNull,
        reason: 'a credit note',
      );
      expect(
        stampDutyOf(
          _invoice(
            'F-6',
            day,
            seller: 'FR',
            vat: [_total(0, 9000, 0, c: 'E')],
          ),
        ),
        isNull,
        reason: 'a country without a stamp-duty row',
      );
    });

    test('the invoice says it under the reason no VAT is charged', () {
      final data = invoiceReportData(
        const ReportStrings(),
        _invoice('FT-1', day, vat: [_total(0, 9000, 0, c: 'E')]),
        proforma: false,
        copy: false,
      );
      expect(
        data['exemption_reason'],
        endsWith(
          'Imposta di bollo assolta in modo virtuale ai sensi del D.M. 17 '
          'giugno 2014.',
        ),
      );
      final taxed = invoiceReportData(
        const ReportStrings(),
        _invoice('FT-2', day, vat: [_total(22, 10000, 2200)]),
        proforma: false,
        copy: false,
      );
      expect(taxed['exemption_reason'], isNot(contains('bollo')));
    });

    test('the duty and its line move with the row', () {
      final rows = [
        for (final r in ActiveTaxReference.current.rows)
          if (!(r.domain == TaxDomain.threshold && r.key == 'stamp_duty')) r,
        const TaxReferenceRow(
          country: 'IT',
          key: 'stamp_duty',
          validFrom: '2026-01-01',
          value: ThresholdValue(
            cents: 10000,
            effect: 'stamp_duty',
            currency: 'EUR',
            chargeCents: 250,
          ),
          source: 'test',
          confirmed: false,
        ),
      ];
      final set = TaxReferenceSet(rows);
      final doc = _invoice('FT-1', day, vat: [_total(0, 10001, 0, c: 'E')]);
      expect(stampDutyOf(doc, reference: set), 250);
      expect(
        stampDutyOf(
          _invoice('FT-2', day, vat: [_total(0, 9000, 0, c: 'E')]),
          reference: set,
        ),
        isNull,
      );
    });
  });

  group('modelo 347 (ES)', () {
    test('the Spanish customers above the line, by quarter and province', () {
      Invoice es(
        String n,
        DateTime d,
        List<InvoiceVatTotal> vat, {
        String nif = 'ESB11111111',
        String country = 'ES',
        String postal = '28001',
      }) => _invoice(
        n,
        d,
        vat: vat,
        seller: 'ES',
        buyerCountry: country,
        vatId: nif,
        postalCode: postal,
      );
      final list = modelo347Lines(
        [
          es('F-1', DateTime(2026, 2), [_total(21, 200000, 42000)]),
          es('F-2', DateTime(2026, 8), [_total(21, 100000, 21000)]),
          es(
            'F-3',
            DateTime(2026, 3),
            [_total(21, 100000, 21000)],
            nif: 'ESB22222222',
            postal: '08001',
          ),
          es(
            'F-4',
            DateTime(2026, 5),
            [_total(0, 900000, 0, c: 'AE')],
            nif: 'FR12123456789',
            country: 'FR',
          ),
          es('F-5', DateTime(2025, 12), [_total(21, 900000, 189000)]),
          // another currency is not summed with the euro line
          es('F-6', DateTime(2026, 4), [
            _total(21, 900000, 189000),
          ], nif: 'ESB22222222').copyWith(currency: 'USD'),
        ],
        year: 2026,
        reference: ActiveTaxReference.current,
        immediateSupply: false,
      )!;
      expect(list.currency, 'EUR');
      final lines = list.lines;
      expect(lines, hasLength(1), reason: 'B22222222 stays under 3,005.06');
      expect(lines.single.nif, 'B11111111');
      expect(lines.single.province, '28');
      expect(lines.single.quarters, [242000, 0, 121000, 0]);
      expect(
        modelo347Csv(lines, currency: 'EUR').split('\r\n')[1],
        '"B11111111";"Cliente Srl";"28";B;3630.00;2420.00;0.00;1210.00;0.00',
      );
    });

    test('a space in SII files no modelo 347', () {
      expect(
        () => modelo347Lines(
          const [],
          year: 2026,
          reference: ActiveTaxReference.current,
          immediateSupply: true,
        ),
        throwsA(
          isA<VatFilingFileException>().having(
            (e) => e.problem,
            'problem',
            VatFilingFileProblem.exoneratedBySii,
          ),
        ),
      );
    });
  });

  test('a small-business alert reads only small-business thresholds', () {
    const set = TaxReferenceSet([
      TaxReferenceRow(
        country: 'ES',
        key: 'modelo347',
        validFrom: '1900-01-01',
        value: ThresholdValue(
          cents: 300506,
          effect: 'annual_operations',
          currency: 'EUR',
        ),
        source: 'test',
        confirmed: false,
      ),
    ]);
    expect(
      smallBusinessAlerts(
        country: 'ES',
        currency: 'EUR',
        turnoverCents: 900000,
        reference: set,
      ),
      isEmpty,
      reason: 'the modelo 347 line is not an exemption that ends',
    );
  });

  test('the charge and the postal codes survive the JSON and the editor', () {
    const threshold = ThresholdValue(
      cents: 7747,
      effect: 'stamp_duty',
      currency: 'EUR',
      chargeCents: 200,
    );
    expect(threshold.toJson()['charge_cents'], 200);
    expect(
      (TaxValue.parse(
        TaxDomain.threshold,
        JsonReader.of(threshold.toJson()),
      ) as ThresholdValue).chargeCents,
      200,
    );
    const gate = IssuingGateValue(
      supported: true,
      outsideVatPostalCodes: ['35', '38'],
    );
    expect(
      (TaxValue.parse(
        TaxDomain.issuingGate,
        JsonReader.of(gate.toJson()),
      ) as IssuingGateValue).outsideVatPostalCodes,
      ['35', '38'],
    );
    expect(
      const IssuingGateValue(supported: true).toJson(),
      isNot(contains('outside_vat_postal_codes')),
      reason: 'a gate without territories keeps its JSON',
    );
    expect(taxReferenceExtraTexts(gate)['outside_vat_postal_codes'], '35, 38');
    expect(taxReferenceExtraTexts(threshold)['charge_cents'], '200');
    expect(postalPrefixesOf(' 35, 38 ,, 51'), ['35', '38', '51']);
  });
}
