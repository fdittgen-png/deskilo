// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the Spanish registers of issued invoices, pinned BEFORE
// the writers move into the Spanish add-on: the libro registro de facturas
// expedidas (the AEAT's XLSX layout, as the cells of its sheet), the SII
// message (SuministroLRFacturasEmitidas), the modelo 347 list and the
// Verifactu record chain, for domestic, EU and non-EU buyers, a reverse
// charge (US buyer, category G: N2), an exempt supply, a real export (Z: E2,
// clave 02), a domestic reverse charge (AE: S2) and a mixed S3 invoice, a
// credit note (R1), a credit without a frozen reason (R4) and one to a buyer
// without an id (R5), a positive replacement, the 347 line at, one cent
// below and one cent above, a supplied and a missing threshold, a voided
// document, and a second year.
// The goldens are written by the code as it stands and compared byte for byte:
// the move must change none of them. Rewrite only with
// `UPDATE_PARITY_GOLDENS=1`, never under CI. Dates are UTC, so the files do
// not depend on the machine's zone.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:deskilo_xlsx/deskilo_xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/money/es_register_support.dart';

import 'parity_golden.dart';

const _seller = InvoiceParty(
  name: 'Espacio Coworking, S.L.',
  vatId: 'ESB12345678',
  country: 'ES',
  vatRegime: 'vat_registered',
);

Invoice _invoice(
  String number,
  DateTime issued, {
  required List<InvoiceVatTotal> vat,
  String vatId = 'ESB98765432',
  String country = 'ES',
  String company = 'Cliente SL',
  int total = 0,
  bool voided = false,
  String correctionReason = '',
  String replacesNumber = '',
}) => Invoice(
  id: number,
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: number,
  issuedAt: issued,
  title: 'Puesto fijo',
  lines: const [],
  totalCents: total,
  currency: 'EUR',
  memberName: 'Cliente',
  memberAddress: '',
  workspaceName: 'Demo',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
  vatTotals: vat,
  voidedAt: voided ? issued : null,
  correctionReason: correctionReason,
  replacesNumber: replacesNumber,
  sellerParty: _seller,
  buyerParty: InvoiceParty(
    name: 'Ana',
    company: company,
    country: country,
    vatId: vatId,
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

DateTime _d(int y, int m, int d) => DateTime.utc(y, m, d, 9);

/// A year of documents covering every branch the writers decide on.
List<Invoice> _documents() => [
  _invoice('F-2026-0001', _d(2026, 1, 15), vat: [
    _total(21, 100000, 21000),
    _total(10, 40000, 4000),
    _total(4, 20000, 800),
  ], total: 185800),
  _invoice('F-2026-0002', _d(2026, 2, 3),
      vat: [_total(0, 30000, 0, c: 'AE')],
      vatId: 'FR12123456789', country: 'FR', total: 30000),
  _invoice('F-2026-0003', _d(2026, 2, 20),
      vat: [_total(0, 50000, 0, c: 'G')],
      vatId: '123456789', country: 'US', total: 50000),
  _invoice('F-2026-0004', _d(2026, 3, 9),
      vat: [_total(0, 8000, 0, c: 'E')], total: 8000),
  _invoice('F-2026-0005', _d(2026, 3, 30),
      vat: [_total(21, 1000, 210)], vatId: '', total: 1210),
  _invoice('F-2026-0006', _d(2026, 4, 2),
      vat: [_total(21, 999, 210)], voided: true),
  _invoice('F-2026-0007', _d(2026, 4, 10),
      vat: [_total(21, -10000, -2100)],
      total: -12100, correctionReason: 'R1', replacesNumber: 'F-2026-0001'),
  _invoice('F-2026-0008', _d(2026, 7, 1),
      vat: [_total(21, 250000, 52500)], total: 302500),
  _invoice('F-2026-0009', _d(2026, 7, 22),
      vat: [_total(21, 300000, 63000)],
      vatId: 'ESA11111111', company: 'Otro Cliente SA', total: 363000),
  _invoice('F-2026-0010', _d(2026, 10, 5),
      vat: [_total(21, 90000, 18900)], total: 108900,
      // a POSITIVE replacement: F1 in the libro and SII, R1 in Verifactu
      // (it is not a credit, so it pins no R4)
      correctionReason: 'R4', replacesNumber: 'F-2026-0008'),
  _invoice('F-2026-0011', _d(2026, 12, 31),
      vat: [_total(21, 40000, 8400)], total: 48400),
  // export of goods, category Z to a US buyer: E2 / clave 02
  _invoice('F-2026-0012', _d(2026, 5, 6),
      vat: [_total(0, 60000, 0, c: 'Z')],
      vatId: '987654321', country: 'US', total: 60000),
  // domestic reverse charge, category AE to a Spanish buyer: S2
  _invoice('F-2026-0013', _d(2026, 5, 20),
      vat: [_total(0, 45000, 0, c: 'AE')],
      vatId: 'ESB55555555', company: 'Obras SL', total: 45000),
  // both on one invoice: S1 taxed + S2 reverse-charged = S3 on the SII
  _invoice('F-2026-0014', _d(2026, 6, 4),
      vat: [_total(21, 10000, 2100), _total(0, 20000, 0, c: 'AE')],
      vatId: 'ESB66666666', company: 'Mixta SL', total: 32100),
  // a credit with no frozen reason and an identified buyer: R4
  _invoice('F-2026-0015', _d(2026, 11, 3),
      vat: [_total(21, -5000, -1050)],
      total: -6050, replacesNumber: 'F-2026-0011'),
  // a credit to a buyer without an id: R5
  _invoice('F-2026-0016', _d(2026, 11, 10),
      vat: [_total(21, -2000, -420)],
      vatId: '', total: -2420, replacesNumber: 'F-2026-0005'),
  // the 347 line is 3005.06 EUR, VAT included: one below, AT it (excluded),
  // one cent above (included)
  _invoice('F-2026-0017', _d(2026, 8, 3),
      vat: [_total(21, 248351, 52154)],
      vatId: 'ESB00000001', company: 'Bajo SL', total: 300505),
  _invoice('F-2026-0018', _d(2026, 8, 4),
      vat: [_total(21, 248352, 52154)],
      vatId: 'ESB00000002', company: 'Igual SL', total: 300506),
  _invoice('F-2026-0019', _d(2026, 8, 5),
      vat: [_total(21, 248353, 52154)],
      vatId: 'ESB00000003', company: 'Encima SL', total: 300507),
  _invoice('F-2027-0001', _d(2027, 1, 2),
      vat: [_total(21, 700000, 147000)], total: 847000),
];

String _cell(Object? c) => switch (c) {
  null => '',
  XlsxAmount(:final value) => value.toStringAsFixed(2),
  _ => '$c',
};

String _sheetText(XlsxSheet sheet) => [
  'sheet=${sheet.name}',
  for (final row in sheet.rows) row.map(_cell).join('|'),
].join('\n');

void main() {
  final reference = ActiveTaxReference.current;
  final docs2026 = registerDocuments(
    _documents(),
    from: DateTime.utc(2026),
    to: DateTime.utc(2027),
  );

  test('the Spanish registers are what they were before the move', () {
    const dir = 'test/parity/golden/es_register';
    final text = <String, String>{};

    text['libro_year.txt'] = _sheetText(
      esLibroExpedidas(docs2026, activity: 'A038612', reference: reference),
    );
    text['libro_monthly.txt'] = _sheetText(
      esLibroExpedidas(
        docs2026,
        activity: 'A038612',
        monthly: true,
        reference: reference,
      ),
    );
    text['libro_q3.txt'] = _sheetText(
      esLibroExpedidas(
        registerDocuments(
          _documents(),
          from: DateTime.utc(2026, 7),
          to: DateTime.utc(2026, 10),
        ),
        activity: 'A038612',
        reference: reference,
      ),
    );
    text['sii_year.xml'] = siiFacturasEmitidasXml(
      docs2026,
      vatId: 'ESB12345678',
      name: 'Espacio Coworking, S.L.',
      reference: reference,
    );
    text['sii_q1.xml'] = siiFacturasEmitidasXml(
      registerDocuments(
        _documents(),
        from: DateTime.utc(2026),
        to: DateTime.utc(2026, 4),
      ),
      vatId: 'ES B1234 5678',
      name: 'Espacio Coworking, S.L.',
      reference: reference,
    );
    final list2026 = modelo347Lines(
      docs2026,
      year: 2026,
      reference: reference,
      immediateSupply: false,
    );
    text['modelo347_2026.csv'] = list2026 == null
        ? 'none'
        : modelo347Csv(list2026.lines, currency: list2026.currency);
    final list2027 = modelo347Lines(
      registerDocuments(
        _documents(),
        from: DateTime.utc(2027),
        to: DateTime.utc(2028),
      ),
      year: 2027,
      reference: reference,
      immediateSupply: false,
    );
    text['modelo347_2027.csv'] = list2027 == null
        ? 'none'
        : modelo347Csv(list2027.lines, currency: list2027.currency);

    // The Verifactu chain, record by record, as the AEAT's RegistroAlta.
    final chain = StringBuffer();
    var previous = '';
    var previousNumber = '';
    var previousDate = '';
    for (final invoice in docs2026) {
      final record = verifactuRecordFor(
        invoice: invoice,
        seller: _seller,
        buyer: invoice.buyerParty!,
        previousHuella: previous,
        previousNumber: previousNumber,
        previousIssueDate: previousDate,
        generatedAt: DateTime.utc(2026, 11, 2, 10, 30),
      );
      chain
        ..writeln(
          verifactuRecordXml(record, issuerName: 'Espacio Coworking, S.L.'),
        )
        ..writeln('huella=${record.huella}');
      previous = record.huella;
      previousNumber = record.number;
      previousDate = record.issueDate;
    }
    text['verifactu_chain.xml'] = chain.toString();

    expectParity(dir: dir, text: text);
  });

  test('the 347 line comes from the reference: supplied, other, missing', () {
    const dir = 'test/parity/golden/es_register_threshold';
    String csv(TaxReferenceSet set) {
      final list = modelo347Lines(
        docs2026,
        year: 2026,
        reference: set,
        immediateSupply: false,
      );
      return list == null
          ? 'none'
          : modelo347Csv(list.lines, currency: list.currency);
    }

    const row = TaxReferenceRow(
      country: 'ES',
      key: 'modelo347',
      validFrom: '1900-01-01',
      value: ThresholdValue(
        cents: 100000,
        effect: 'annual_operations',
        currency: 'EUR',
      ),
      source: 'test',
      confirmed: false,
    );
    expectParity(
      dir: dir,
      text: {
        'modelo347_supplied_1000.csv': csv(const TaxReferenceSet([row])),
        'modelo347_missing.csv': csv(const TaxReferenceSet([])),
      },
    );
  });

  test('a space on the SII is refused a modelo 347, as before', () {
    expect(
      () => modelo347Lines(
        docs2026,
        year: 2026,
        reference: reference,
        immediateSupply: true,
      ),
      throwsA(isA<Object>()),
    );
  });
}
