// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- the issued documents of the Spanish register pins (the matrix of
// `es_register_parity_test`), shared with the host tests that read the same
// goldens through `VatRegisterFiles`.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_xlsx/deskilo_xlsx.dart';

const seller = InvoiceParty(
  name: 'Espacio Coworking, S.L.',
  vatId: 'ESB12345678',
  country: 'ES',
  vatRegime: 'vat_registered',
);

Invoice invoice(
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
  sellerParty: seller,
  buyerParty: InvoiceParty(
    name: 'Ana',
    company: company,
    country: country,
    vatId: vatId,
  ),
);

InvoiceVatTotal total(double percent, int net, int vat, {String c = 'S'}) =>
    InvoiceVatTotal(
      percent: percent,
      category: c,
      grossCents: net + vat,
      netCents: net,
      vatCents: vat,
    );

DateTime day(int y, int m, int d) => DateTime.utc(y, m, d, 9);

/// A year of documents covering every branch the writers decide on.
List<Invoice> documents() => [
  invoice('F-2026-0001', day(2026, 1, 15), vat: [
    total(21, 100000, 21000),
    total(10, 40000, 4000),
    total(4, 20000, 800),
  ], total: 185800),
  invoice('F-2026-0002', day(2026, 2, 3),
      vat: [total(0, 30000, 0, c: 'AE')],
      vatId: 'FR12123456789', country: 'FR', total: 30000),
  invoice('F-2026-0003', day(2026, 2, 20),
      vat: [total(0, 50000, 0, c: 'G')],
      vatId: '123456789', country: 'US', total: 50000),
  invoice('F-2026-0004', day(2026, 3, 9),
      vat: [total(0, 8000, 0, c: 'E')], total: 8000),
  invoice('F-2026-0005', day(2026, 3, 30),
      vat: [total(21, 1000, 210)], vatId: '', total: 1210),
  invoice('F-2026-0006', day(2026, 4, 2),
      vat: [total(21, 999, 210)], voided: true),
  invoice('F-2026-0007', day(2026, 4, 10),
      vat: [total(21, -10000, -2100)],
      total: -12100, correctionReason: 'R1', replacesNumber: 'F-2026-0001'),
  invoice('F-2026-0008', day(2026, 7, 1),
      vat: [total(21, 250000, 52500)], total: 302500),
  invoice('F-2026-0009', day(2026, 7, 22),
      vat: [total(21, 300000, 63000)],
      vatId: 'ESA11111111', company: 'Otro Cliente SA', total: 363000),
  invoice('F-2026-0010', day(2026, 10, 5),
      vat: [total(21, 90000, 18900)], total: 108900,
      // a POSITIVE replacement: F1 in the libro and SII, R1 in Verifactu
      // (it is not a credit, so it pins no R4)
      correctionReason: 'R4', replacesNumber: 'F-2026-0008'),
  invoice('F-2026-0011', day(2026, 12, 31),
      vat: [total(21, 40000, 8400)], total: 48400),
  // export of goods, category Z to a US buyer: E2 / clave 02
  invoice('F-2026-0012', day(2026, 5, 6),
      vat: [total(0, 60000, 0, c: 'Z')],
      vatId: '987654321', country: 'US', total: 60000),
  // domestic reverse charge, category AE to a Spanish buyer: S2
  invoice('F-2026-0013', day(2026, 5, 20),
      vat: [total(0, 45000, 0, c: 'AE')],
      vatId: 'ESB55555555', company: 'Obras SL', total: 45000),
  // both on one invoice: S1 taxed + S2 reverse-charged = S3 on the SII
  invoice('F-2026-0014', day(2026, 6, 4),
      vat: [total(21, 10000, 2100), total(0, 20000, 0, c: 'AE')],
      vatId: 'ESB66666666', company: 'Mixta SL', total: 32100),
  // a credit with no frozen reason and an identified buyer: R4
  invoice('F-2026-0015', day(2026, 11, 3),
      vat: [total(21, -5000, -1050)],
      total: -6050, replacesNumber: 'F-2026-0011'),
  // a credit to a buyer without an id: R5
  invoice('F-2026-0016', day(2026, 11, 10),
      vat: [total(21, -2000, -420)],
      vatId: '', total: -2420, replacesNumber: 'F-2026-0005'),
  // the 347 line is 3005.06 EUR, VAT included: one below, AT it (excluded),
  // one cent above (included)
  invoice('F-2026-0017', day(2026, 8, 3),
      vat: [total(21, 248351, 52154)],
      vatId: 'ESB00000001', company: 'Bajo SL', total: 300505),
  invoice('F-2026-0018', day(2026, 8, 4),
      vat: [total(21, 248352, 52154)],
      vatId: 'ESB00000002', company: 'Igual SL', total: 300506),
  invoice('F-2026-0019', day(2026, 8, 5),
      vat: [total(21, 248353, 52154)],
      vatId: 'ESB00000003', company: 'Encima SL', total: 300507),
  invoice('F-2027-0001', day(2027, 1, 2),
      vat: [total(21, 700000, 147000)], total: 847000),
];

String cell(Object? c) => switch (c) {
  null => '',
  XlsxAmount(:final value) => value.toStringAsFixed(2),
  _ => '$c',
};

String sheetText(XlsxSheet sheet) => [
  'sheet=${sheet.name}',
  for (final row in sheet.rows) row.map(cell).join('|'),
].join('\n');
