// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the Spanish registers of issued invoices, pinned BEFORE
// the writers move into the Spanish add-on: the libro registro de facturas
// expedidas (the AEAT's XLSX layout, as the cells of its sheet), the SII
// message (SuministroLRFacturasEmitidas), the modelo 347 list and the
// Verifactu record chain, for domestic, EU and non-EU buyers, a reverse
// charge, an exempt and an exported supply, a credit note, a replacement with
// its reason, a buyer without an id, a voided document, and a second year.
// The goldens are written by the code as it stands and compared byte for byte:
// the move must change none of them. Rewrite only with
// `UPDATE_PARITY_GOLDENS=1`, never under CI. Dates are UTC, so the files do
// not depend on the machine's zone.
import 'package:deskilo/core/files/xlsx.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/vat_register_es.dart';
import 'package:deskilo/features/money/domain/vat_register_es_347.dart';
import 'package:deskilo/features/money/domain/vat_register_es_sii.dart';
import 'package:deskilo/features/money/domain/verifactu.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

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
      correctionReason: 'R4', replacesNumber: 'F-2026-0008'),
  _invoice('F-2026-0011', _d(2026, 12, 31),
      vat: [_total(21, 40000, 8400)], total: 48400),
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
