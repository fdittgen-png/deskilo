// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- how a sales-tax invoice reads and prints. The server freezes net
// prices, the tax per jurisdiction and the customer's certificate (pgTAP 190);
// here the document: the frozen JSON decodes into typed totals, the lines
// quote their net, the totals block names each jurisdiction and cites the
// certificate, and the PDF prints no VAT caption (changing the VAT caption
// changes nothing on the sheet; changing the subtotal caption does).
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_sales_tax.dart';
import 'package:deskilo/features/money/domain/invoice_sales_tax.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

const _frozen = <String, Object?>{
  'percent': 8.875,
  'category': 'S',
  'gross_cents': 10888,
  'net_cents': 10000,
  'vat_cents': 888,
  'state': 'NY',
  'jurisdiction': '10001',
  'components': [
    {
      'scheme': 'SALES_TAX',
      'authority': 'US-NY',
      'level': 'state',
      'name': 'New York State',
      'percent': 4,
      'base_cents': 10000,
      'tax_cents': 400,
    },
    {
      'scheme': 'SALES_TAX',
      'authority': 'US-NY',
      'level': 'city',
      'name': 'New York City',
      'percent': 4.5,
      'base_cents': 10000,
      'tax_cents': 450,
    },
    {
      'scheme': 'SALES_TAX',
      'authority': 'US-NY',
      'level': 'district',
      'name': 'MCTD',
      'percent': 0.375,
      'base_cents': 10000,
      'tax_cents': 38,
    },
  ],
};

const _certified = <String, Object?>{
  'percent': 0,
  'category': 'E',
  'gross_cents': 5000,
  'net_cents': 5000,
  'vat_cents': 0,
  'state': 'NY',
  'jurisdiction': '10001',
  'exemption_basis': 'certificate',
  'certificate': {'kind': 'nonprofit', 'state': 'NY', 'number': 'ST-119.1'},
};

Invoice _invoice(List<Map<String, Object?>> totals) => Invoice(
  id: 'i1',
  workspaceId: 'w1',
  memberId: 'm1',
  number: 'INV-1',
  issuedAt: DateTime.utc(2026, 9, 30),
  title: '2026-09',
  currency: 'USD',
  memberName: 'Customer LLC',
  memberAddress: '200 Main St\nAlbany',
  workspaceName: 'Space',
  workspaceAddress: '1 Broadway, New York',
  issuerName: 'Owner',
  signature: 'a' * 64,
  totalCents: totals.fold(0, (s, t) => s + (t['gross_cents']! as int)),
  lines: [
    const InvoiceLine(
      kind: 'service',
      label: 'Printing',
      amountCents: 10888,
      netCents: 10000,
      taxCents: 888,
    ),
    const InvoiceLine(
      kind: 'service',
      label: 'Event',
      amountCents: 5000,
      netCents: 5000,
    ),
  ],
  vatTotals: [for (final t in totals) InvoiceVatTotal.fromJson(t)],
);

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

InvoicePdfStrings _strings({
  String vat = 'VAT',
  String subtotal = 'Subtotal',
}) => InvoicePdfStrings(
  invoiceTitle: 'Invoice',
  issuedOn: 'Issued',
  issuedBy: 'By',
  billedTo: 'Billed to',
  total: 'Total',
  signature: 'Signature',
  voided: '',
  replaces: 'Replaces',
  description: 'Description',
  charges: 'Charges',
  payments: 'Payments',
  net: 'Net',
  vat: vat,
  subtotal: subtotal,
  exemptCertificate: 'Exemption certificate',
  annex: 'Annex',
  attendance: 'Attendance',
  activity: 'Activity',
  reserved: 'reserved',
  page: 'Page',
);

Future<Uint8List> _pdf(Invoice invoice, InvoicePdfStrings strings) =>
    buildInvoicePdf(
      InvoicePdfRequest(
        invoice: invoice,
        strings: strings,
        addressWindow: AddressWindow.right,
        money: (cents) => '${(cents / 100).toStringAsFixed(2)} \$',
        lineText: (line) => invoiceLineText(const ReportStrings(), line),
        activityText: (entry) => annexEntryText(const ReportStrings(), entry),
        dateLabel: 'Sep 30, 2026',
        periodLabel: 'September 2026',
        baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
        boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
      ),
    );

/// The page content streams, inflated: what is DRAWN, without the document
/// id and dates that differ between two renderings of the same sheet.
String _drawn(Uint8List bytes) {
  final raw = String.fromCharCodes(bytes);
  final out = StringBuffer();
  for (final match in RegExp(r'stream\r?\n').allMatches(raw)) {
    final end = raw.indexOf('endstream', match.end);
    if (end < 0) continue;
    try {
      out.writeln(
        String.fromCharCodes(zlib.decode(bytes.sublist(match.end, end))),
      );
    } on Object catch (_) {
      // Not a deflated stream (fonts, metadata).
    }
  }
  return out.toString();
}

void main() {
  reportDataTests();
  test('the frozen totals decode with their jurisdictions and certificate', () {
    final invoice = _invoice([_frozen, _certified]);
    expect(invoice.isSalesTax, isTrue);
    final taxed = invoice.vatTotals.first;
    expect(taxed.state, 'NY');
    expect(taxed.components.map((c) => '${c.name}:${c.taxCents}'), [
      'New York State:400',
      'New York City:450',
      'MCTD:38',
    ]);
    expect(taxed.components.first.level, 'state');
    expect(invoice.vatTotals.last.exemptionBasis, 'certificate');
    expect(invoice.vatTotals.last.certificate['number'], 'ST-119.1');
    // a VAT invoice is none of this
    expect(
      _invoice([
        {
          'percent': 20,
          'category': 'S',
          'gross_cents': 120,
          'net_cents': 100,
          'vat_cents': 20,
        },
      ]).isSalesTax,
      isFalse,
    );
  });

  test('a line quotes its net price; a VAT line quotes its amount', () {
    final invoice = _invoice([_frozen, _certified]);
    expect(invoice.quotedCents(invoice.lines.first), 10000);
    expect(invoice.lines.first.taxCents, 888);
    final vat = invoice.copyWith(
      vatTotals: const [
        InvoiceVatTotal(
          percent: 20,
          category: 'S',
          grossCents: 120,
          netCents: 100,
          vatCents: 20,
        ),
      ],
    );
    expect(vat.quotedCents(vat.lines.first), 10888);
  });

  test('the totals block: one row per jurisdiction, the certificate once', () {
    final invoice = _invoice([_frozen, _certified]);
    final rows = salesTaxByJurisdiction(invoice.vatTotals);
    expect(rows.map((r) => '${r.name} ${r.percent} ${r.taxCents}'), [
      'New York State 4.0 400',
      'New York City 4.5 450',
      'MCTD 0.375 38',
    ]);
    expect(
      exemptionCertificateLines(invoice.vatTotals, 'Exemption certificate'),
      ['Exemption certificate ST-119.1 (NY)'],
    );
    // two entries citing the same certificate cite it once
    expect(
      exemptionCertificateLines([
        ...invoice.vatTotals,
        ...invoice.vatTotals,
      ], 'Cert'),
      ['Cert ST-119.1 (NY)'],
    );
  });

  test(
    'the sheet prints no VAT caption and does print the subtotal one',
    () async {
      final invoice = _invoice([_frozen, _certified]);
      final base = await _pdf(invoice, _strings());
      final drawn = _drawn(base);
      expect(drawn, contains(']TJ'));
      expect(
        _drawn(await _pdf(invoice, _strings())),
        drawn,
        reason: 'what is drawn is deterministic',
      );
      expect(String.fromCharCodes(base.take(5)), '%PDF-');
      expect(
        _drawn(await _pdf(invoice, _strings(vat: 'TVA'))),
        drawn,
        reason: 'a sales-tax sheet must not print the VAT caption',
      );
      expect(
        _drawn(await _pdf(invoice, _strings(subtotal: 'Sous-total'))),
        isNot(drawn),
        reason: 'the subtotal caption is on the sheet',
      );
    },
  );

  test('a VAT sheet still prints its VAT caption (control)', () async {
    final vat =
        _invoice([
          {
            'percent': 20,
            'category': 'S',
            'gross_cents': 15888,
            'net_cents': 13240,
            'vat_cents': 2648,
          },
        ]).copyWith(
          vatTotals: const [
            InvoiceVatTotal(
              percent: 20,
              category: 'S',
              grossCents: 15888,
              netCents: 13240,
              vatCents: 2648,
            ),
          ],
        );
    expect(
      _drawn(await _pdf(vat, _strings(vat: 'TVA'))),
      isNot(_drawn(await _pdf(vat, _strings()))),
    );
  });
}

// The designed layouts read the same data: #2362 -- a sales-tax invoice's
// placeholders carry its net prices and one row per jurisdiction.
void reportDataTests() {
  test('the report data: net lines, one tax row per jurisdiction', () {
    final invoice = _invoice([_frozen, _certified]);
    final data = invoiceReportData(
      const ReportStrings(),
      invoice,
      proforma: false,
      copy: false,
    );
    final lines = data['lines']! as List<Object?>;
    expect((lines.first! as Map)['amount'], '\$100.00');
    expect((lines.first! as Map)['vat_rate'], '');
    expect(
      [for (final v in data['vat']! as List<Object?>) (v! as Map)['rate']],
      ['New York State 4 %', 'New York City 4.5 %', 'MCTD 0.375 %'],
    );
    expect(data['net_total'], '\$150.00');
    expect(data['vat_total'], '\$8.88');
    expect(data['total'], '\$158.88');
  });
}
