// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3981 — the window convention for US Letter, proved on the PDF, on both
// engines. The recipient's ink is inside the #10 envelope's field
// (25.4 to 108.4 mm across, 56 to 77 mm down), nothing else has ink
// between 50 and 93 mm, the flow starts at 93 mm; `left` and `right` both
// land in the same field; a sixth address line is reported, not printed
// outside. A4 keeps its millimetres.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/report_conformance.dart';
import 'package:deskilo/features/money/domain/report_letter_layouts.dart';
import 'package:deskilo/features/money/presentation/report_layout_actions.dart';
import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/pdf_geometry.dart';

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

const _name = 'Zephyrine Quarterbridge-Okonkwo';
const _fiveLines = '1 Main Street\nSuite 4\nSpringfield, IL 62701\nUSA';

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

Invoice _invoice(String address) => Invoice(
  id: 'i1',
  workspaceId: 'w1',
  memberId: 'm1',
  number: 'INV-2026-0050',
  issuedAt: DateTime.utc(2026, 9, 4),
  title: '2026-08',
  currency: 'USD',
  memberName: _name,
  memberAddress: address,
  workspaceName: 'COWORKONTI',
  workspaceAddress: '4 avenue de Castelnau, 34120 Pézenas',
  issuerName: 'Flo',
  signature: 'a' * 64,
  totalCents: 10000,
  paper: 'Letter',
  lines: [
    const InvoiceLine(kind: 'adjustment', label: 'Desk, half day', amountCents: 10000),
  ],
);

Future<Uint8List> _banded(AddressWindow window, String address) =>
    buildInvoicePdf(
      InvoicePdfRequest(
        invoice: _invoice(address),
        strings: _strings,
        addressWindow: window,
        paper: Paper.letter,
        money: (cents) => '\$${(cents / 100).toStringAsFixed(2)}',
        lineText: (line) => invoiceLineText(const ReportStrings(), line),
        activityText: (entry) => annexEntryText(const ReportStrings(), entry),
        dateLabel: 'Sep 4, 2026',
        periodLabel: 'August 2026',
        baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
        boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
      ),
    );

Future<Uint8List> _positioned(AddressWindow window, String address) async =>
    (await tryLayoutPdf(
      layoutXml: defaultLetterLayoutXml(
        'invoice',
        const LetterStrings(),
        window: window,
      ),
      data: {
        'workspace': 'COWORKONTI',
        'workspace_address': '4 avenue de Castelnau, 34120 Pézenas',
        'number': 'INV-2026-0050',
        'client_name': _name,
        'client_address': address,
        'vat': <Object?>[],
        'status_members': <Object?>[],
        'usage_records': <Object?>[],
        'lines': [
          {'label': 'Desk', 'qty': '1', 'unit_price': '100.00', 'amount': '100.00'},
        ],
      },
      what: 'invoice',
      print: const LayoutPrint(
        documentTitle: 'invoice',
        pageLabel: 'Page',
        paper: Paper.letter,
      ),
      font: (asset) async => _ttf(asset),
    ))!;

List<InkAt> _page1(Uint8List bytes) => [
  for (final i in textPositions(bytes, paper: Paper.letter))
    if (i.page == 1) i,
];

bool _inField(InkAt i, AddressField f) =>
    i.yMm >= f.topMm - 0.5 &&
    i.yMm <= f.bottomMm &&
    i.xMm >= f.leftMm - 0.5 &&
    i.xMm <= f.rightMm;

/// What the convention asks of a Letter sheet's first page.
void _conforms(Uint8List bytes, {required String reason}) {
  final f = AddressWindow.left.fieldOn(Paper.letter);
  final page1 = _page1(bytes);
  final inField = page1.where((i) => _inField(i, f)).toList();
  expect(inField, isNotEmpty, reason: '$reason: a recipient in the field');
  final band = page1
      .where((i) => i.yMm > f.senderLimitMm && i.yMm < f.flowResumeMm)
      .toList();
  expect(
    band.where((i) => !_inField(i, f)),
    isEmpty,
    reason: '$reason: nothing but the recipient between 50 and 93 mm',
  );
  final flow = page1.where((i) => i.yMm >= f.bottomMm && !_inField(i, f));
  expect(flow, isNotEmpty, reason: '$reason: the flow is there');
  expect(
    flow.map((i) => i.yMm).reduce((a, b) => a < b ? a : b),
    greaterThanOrEqualTo(f.flowResumeMm - 0.5),
    reason: '$reason: the flow starts at 93 mm',
  );
}

void main() {
  test('the Letter field is the #10 envelope\'s, A4 keeps its own', () {
    for (final window in [AddressWindow.left, AddressWindow.right]) {
      final f = window.fieldOn(Paper.letter);
      expect(
        [f.leftMm, f.topMm, f.widthMm, f.heightMm, f.senderLimitMm, f.flowResumeMm],
        [25.4, 56, 83, 21, 50, 93],
        reason: '$window',
      );
    }
    final a4 = AddressWindow.right.fieldOn(Paper.a4);
    expect(
      [a4.leftMm, a4.topMm, a4.widthMm, a4.heightMm, a4.senderLimitMm, a4.flowResumeMm],
      [110, 45, 85, 40, 45, 90],
    );
    expect(AddressWindow.left.fieldOn(Paper.a4).leftMm, 20);
    final zones = reportZones(AddressWindow.left, paper: Paper.letter);
    expect(zones.map((z) => z.name), ['sender', 'address field', 'body']);
    expect([zones[1].topMm, zones[1].bottomMm], [56, 77]);
    expect(zones[1].leftMm, 25.4);
    expect(zones[1].widthMm, 83);
    expect(zones[0].bottomMm, 50);
    expect(zones[2].topMm, 93);
  });

  for (final window in [AddressWindow.left, AddressWindow.right]) {
    test('banded, a ${window.name} window on Letter prints in the field', () async {
      _conforms(await _banded(window, _fiveLines), reason: 'banded ${window.name}');
    });
    test('positioned, a ${window.name} window on Letter prints in the field', () async {
      _conforms(await _positioned(window, _fiveLines), reason: 'positioned ${window.name}');
    });
  }

  test('left and right land in the same field', () async {
    final left = _page1(await _banded(AddressWindow.left, _fiveLines));
    final right = _page1(await _banded(AddressWindow.right, _fiveLines));
    final f = AddressWindow.left.fieldOn(Paper.letter);
    expect(
      right.where((i) => _inField(i, f)).map((i) => (i.xMm, i.yMm)).toList(),
      left.where((i) => _inField(i, f)).map((i) => (i.xMm, i.yMm)).toList(),
    );
  });

  test('five lines fit the field; a sixth is not printed outside it', () async {
    final f = AddressWindow.left.fieldOn(Paper.letter);
    int lines(Iterable<InkAt> ink) =>
        ink.where((i) => _inField(i, f)).map((i) => i.yMm.round()).toSet().length;
    final five = _page1(await _banded(AddressWindow.left, _fiveLines));
    expect(lines(five), 5, reason: 'the name and four lines of address');
    final six = _page1(
      await _banded(AddressWindow.left, '$_fiveLines\nPlanet Earth'),
    );
    expect(lines(six), lessThan(6), reason: 'the sixth does not fit');
    expect(
      six.where((i) => i.yMm > f.bottomMm && i.yMm < f.flowResumeMm),
      isEmpty,
      reason: 'and nothing is printed below the field',
    );
  });
}
