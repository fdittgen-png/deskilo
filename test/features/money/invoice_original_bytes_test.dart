// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — an issued invoice's PDF depends only on the invoice: rendered at
// two moments it is the same bytes, in the banded engine, as a Factur-X
// with its embedded XML, and in the positioned engine. Its dates are the
// invoice's issue and its file identifier is taken from its content.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/pinned_pdf.dart';
import 'package:deskilo/features/money/domain/report_letter_layouts.dart';
import 'package:deskilo/features/money/presentation/report_layout_actions.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

const _strings = InvoicePdfStrings(
  invoiceTitle: 'Invoice',
  issuedOn: 'Issued on',
  issuedBy: 'Issued by',
  billedTo: 'Billed to',
  total: 'Total',
  signature: 'Digital signature (SHA-256)',
  voided: '',
  voidedWatermark: 'Voided',
  proforma: 'Proforma',
  replaces: 'Replaces',
  description: 'Description',
  charges: 'Charges',
  payments: 'Payments',
  annex: 'Annex — details',
  attendance: 'Attendance',
  activity: 'Bookings',
  reserved: 'reserved',
  page: 'Page',
);

final _issuedAt = DateTime.utc(2026, 9, 4, 8, 30, 15);

final _invoice = Invoice(
  id: 'i1',
  workspaceId: 'w1',
  memberId: 'm1',
  number: 'INV-2026-0050',
  issuedAt: _issuedAt,
  title: '2026-08',
  currency: 'EUR',
  memberName: 'Zephyrine Quarterbridge',
  memberAddress: '1 rue Haute\n34120 Pézenas',
  workspaceName: 'COWORKONTI',
  workspaceAddress: '4 avenue de Castelnau, 34120 Pézenas',
  issuerName: 'Flo',
  signature: 'a' * 64,
  totalCents: 10000,
  lines: const [
    InvoiceLine(
      kind: 'adjustment',
      label: 'Desk, half day',
      amountCents: 10000,
    ),
  ],
);

Future<Uint8List> _banded({String facturXml = ''}) => buildInvoicePdf(
  InvoicePdfRequest(
    invoice: _invoice,
    strings: _strings,
    addressWindow: AddressWindow.left,
    money: (cents) => '€${(cents / 100).toStringAsFixed(2)}',
    lineText: (line) => invoiceLineText(const ReportStrings(), line),
    activityText: (entry) => annexEntryText(const ReportStrings(), entry),
    dateLabel: 'Sep 4, 2026',
    periodLabel: 'August 2026',
    facturXml: facturXml,
    colorProfile: facturXml.isEmpty
        ? null
        : Uint8List.fromList(File('assets/pdf/sRGB2014.icc').readAsBytesSync()),
    baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
    boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
  ),
);

Future<Uint8List> _positioned() async => (await tryLayoutPdf(
  layoutXml: defaultLetterLayoutXml('invoice', const LetterStrings()),
  data: const {
    'number': 'INV-2026-0050',
    'client_name': 'Zephyrine Quarterbridge',
    'vat': <Object?>[],
  },
  what: 'invoice',
  print: LayoutPrint(
    documentTitle: 'Invoice',
    pageLabel: 'Page',
    datedAt: _issuedAt,
  ),
  font: (asset) async => _ttf(asset),
))!;

/// Renders [make] twice, a second apart, so the clock has moved between.
Future<(Uint8List, Uint8List)> _twice(Future<Uint8List> Function() make) async {
  final first = await make();
  await Future<void>.delayed(const Duration(milliseconds: 1100));
  return (first, await make());
}

void main() {
  test(
    'the banded invoice is the same bytes whenever it is rendered',
    () async {
      final (a, b) = await _twice(_banded);
      expect(b, a);
      expect(
        latin1.decode(a),
        contains('/CreationDate(D:20260904083015'),
        reason: 'dated by its issue',
      );
    },
  );

  test('so is the Factur-X with its embedded XML', () async {
    final (a, b) = await _twice(
      () => _banded(facturXml: '<rsm:CrossIndustryInvoice/>'),
    );
    expect(b, a);
    expect(latin1.decode(a), contains('factur-x.xml'));
    expect(
      latin1.decode(a),
      contains('2026-09-04T08:30:15'),
      reason: 'the PDF/A metadata names the issue',
    );
  });

  test('and the positioned invoice', () async {
    final (a, b) = await _twice(_positioned);
    expect(b, a);
  });

  test('the identifier is taken from the content; every length stays', () {
    Uint8List pdf(String text) => Uint8List.fromList(
      latin1.encode(
        '%PDF-1.5\n1 0 obj<</CreationDate(D:20991231235959Z)>>endobj\n$text\n'
        'trailer<</ID[<${'1' * 64}><${'1' * 64}>]>>',
      ),
    );
    final one = pinnedPdf(pdf('one'), _issuedAt);
    final two = pinnedPdf(pdf('two'), _issuedAt);
    expect(one.length, pdf('one').length);
    expect(latin1.decode(one), contains('(D:20260904083015Z)'));
    final id = RegExp(r'/ID\[<([0-9a-f]+)>');
    expect(
      id.firstMatch(latin1.decode(one))!.group(1),
      isNot(id.firstMatch(latin1.decode(two))!.group(1)),
    );
    expect(pinnedPdf(pdf('one'), _issuedAt), one);
  });
}
