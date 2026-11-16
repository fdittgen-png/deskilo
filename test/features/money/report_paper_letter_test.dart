// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3852 — an invoice on the paper it was issued on. On Letter both engines
// print it on the Letter sheet, with no ink off the sheet and the
// recipient's name on page 1; on A4 nothing changes. On Letter a window
// is the #3981 field of the #10 envelope (address_window_letter_test).
// Every report kind declares the papers it is printed on.
//
// A letter or report made now is printed on the business's paper when its
// kind declares it, in both engines. One invoice's ink positions on A4 and
// on Letter, banded and positioned, are goldens; regenerate them with
// --dart-define=WRITE_GOLDEN=true only when a document is meant to change.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/domain/report_letter_layouts.dart';
import 'package:deskilo/features/money/presentation/letter_doc_pdf.dart';
import 'package:deskilo/features/money/presentation/report_layout_actions.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/pdf_geometry.dart';

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

const _recipient = 'Zephyrine Quarterbridge-Okonkwo';

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

Invoice _invoice(String recipient, {int lines = 60}) => Invoice(
  id: 'i1',
  workspaceId: 'w1',
  memberId: 'm1',
  number: 'INV-2026-0050',
  issuedAt: DateTime.utc(2026, 9, 4),
  title: '2026-08',
  currency: 'USD',
  memberName: recipient,
  memberAddress: '1 Main Street\nSpringfield, IL 62701',
  workspaceName: 'COWORKONTI',
  workspaceAddress: '4 avenue de Castelnau, 34120 Pézenas',
  issuerName: 'Flo',
  signature: 'a' * 64,
  totalCents: 10000 * lines,
  paper: 'Letter',
  lines: [
    for (var i = 0; i < lines; i++)
      InvoiceLine(
        kind: 'adjustment',
        label: 'Desk, half day $i',
        amountCents: 10000,
      ),
  ],
);

Future<Uint8List> _banded(String recipient, Paper paper) => buildInvoicePdf(
  InvoicePdfRequest(
    invoice: _invoice(recipient),
    strings: _strings,
    addressWindow: AddressWindow.left,
    paper: paper,
    money: (cents) => '\$${(cents / 100).toStringAsFixed(2)}',
    lineText: (line) => invoiceLineText(const ReportStrings(), line),
    activityText: (entry) => annexEntryText(const ReportStrings(), entry),
    dateLabel: 'Sep 4, 2026',
    periodLabel: 'August 2026',
    baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
    boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
  ),
);

Map<String, Object?> _data(String recipient) => {
  'workspace': 'COWORKONTI',
  'workspace_address': '4 avenue de Castelnau, 34120 Pézenas',
  'number': 'INV-2026-0050',
  'client_name': recipient,
  'client_address': '1 Main Street, Springfield, IL 62701',
  // the lists the letter standard's bodies loop over
  'vat': <Object?>[],
  'status_members': <Object?>[],
  'usage_records': <Object?>[],
  'lines': [
    for (var i = 0; i < 60; i++)
      {
        'label': 'Desk, half day $i',
        'qty': '1',
        'unit_price': '100.00',
        'amount': '100.00',
      },
  ],
};

Future<Uint8List> _positioned(
  String recipient,
  Paper? paper, {
  String kind = 'invoice',
}) async => (await tryLayoutPdf(
  layoutXml: defaultLetterLayoutXml(kind, const LetterStrings()),
  data: _data(recipient),
  what: kind,
  print: LayoutPrint(documentTitle: kind, pageLabel: 'Page', paper: paper),
  font: (asset) async => _ttf(asset),
))!;

/// The sizes of the pages, in points.
List<(double, double)> _sheets(Uint8List bytes) => [
  for (final m in RegExp(
    r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]',
  ).allMatches(latin1.decode(bytes)))
    (double.parse(m.group(1)!), double.parse(m.group(2)!)),
];

/// The bytes without what changes on every run: the id and the dates.
String _stable(Uint8List bytes) => latin1
    .decode(bytes)
    .replaceAll(RegExp(r'/ID\s*\[[^\]]*\]'), '')
    .replaceAll(RegExp(r'/(CreationDate|ModDate)\s*\([^)]*\)'), '');

Set<(int, int, int)> _ink(Uint8List bytes, Paper paper) => {
  for (final i in textPositions(bytes, paper: paper))
    (i.page, i.xMm.round(), i.yMm.round()),
};

/// On Letter: every sheet is Letter, no ink is off it, and the ink only
/// the recipient's name adds is on page 1, inside the sheet.
void _onLetter(Uint8List named, Uint8List unnamed) {
  final sheets = _sheets(named);
  expect(sheets.length, greaterThan(1), reason: 'a long invoice flows');
  for (final sheet in sheets) {
    expect(sheet, (612.0, 792.0));
  }
  for (final i in textPositions(named, paper: Paper.letter)) {
    expect(i.xMm, inInclusiveRange(0, Paper.letter.widthMm), reason: '$i');
    expect(i.yMm, inInclusiveRange(0, Paper.letter.heightMm), reason: '$i');
  }
  final name = _ink(
    named,
    Paper.letter,
  ).difference(_ink(unnamed, Paper.letter));
  expect(name, isNotEmpty, reason: 'the recipient is printed');
  expect(name.map((i) => i.$1).toSet(), {1}, reason: 'on page 1');
}

const _write = bool.fromEnvironment('WRITE_GOLDEN');

/// The sheets and every ink position, in tenths of a millimetre.
String _inkGolden(Uint8List bytes, Paper paper) => [
  for (final (w, h) in _sheets(bytes)) 'sheet ${w.toStringAsFixed(2)} x ${h.toStringAsFixed(2)}',
  for (final i in textPositions(bytes, paper: paper))
    'p${i.page} ${i.xMm.toStringAsFixed(1)} ${i.yMm.toStringAsFixed(1)}',
].join('\n');

void _golden(String name, String actual) {
  final file = File('test/features/money/goldens/$name.txt');
  if (_write) file.writeAsStringSync('$actual\n');
  expect('$actual\n', file.readAsStringSync(),
      reason: '$name: regenerate with --dart-define=WRITE_GOLDEN=true');
}

Workspace _business(String country) => Workspace(
  id: 'ws-$country',
  name: 'Space',
  countryCode: country,
  currencyCode: 'USD',
  timezone: 'UTC',
  inviteCode: '',
);

/// A letter made now, through the app's letter path, for a business of
/// [country]: its bands, or the positioned [layoutXml].
Future<Uint8List> _letter(WidgetTester tester, String country, String kind,
    {String? layoutXml}) async {
  WidgetRef? captured;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentWorkspaceProvider.overrideWith((ref) async => _business(country)),
    ],
    child: MaterialApp(home: Consumer(builder: (context, ref, _) {
      captured = ref;
      ref.watch(currentWorkspaceProvider);
      return const SizedBox();
    })),
  ));
  await tester.pump();
  final made = await tester.runAsync(() => letterPdfOf(
    captured!,
    (
      report: const InvoiceReport(header: [], body: [ReportText(_recipient)], footer: []),
      title: kind,
      layoutXml: layoutXml,
      data: _data(_recipient),
      images: const {},
    ),
    kind: kind,
    pageLabel: 'Page',
  ));
  expect(_sheets(made!.bytes), isNotEmpty, reason: 'a PDF with its pages');
  return made.bytes;
}

void main() {
  test('on Letter a named window takes the Letter field; A4 keeps its own', () {
    final made = parseLayoutXml(
      '<report-layout><recipient window="fr"/></report-layout>',
    );
    expect(made.onPaper(Paper.a4).recipient!.window, AddressWindow.right);
    final placed = made.onPaper(Paper.letter).recipient!;
    expect(placed.window, AddressWindow.right, reason: 'the kind is kept');
    expect(placed.frame, isNull);
    final off = parseLayoutXml(
      '<report-layout><recipient window="off"/></report-layout>',
    );
    expect(off.onPaper(Paper.letter).recipient!.isOff, isTrue);
  });

  test('the banded invoice on Letter', () async {
    _onLetter(
      await _banded(_recipient, Paper.letter),
      await _banded('', Paper.letter),
    );
  });

  test('the positioned invoice on Letter', () async {
    _onLetter(
      await _positioned(_recipient, Paper.letter),
      await _positioned('', Paper.letter),
    );
  });

  test('on A4 the positioned invoice is the design as it was', () async {
    expect(
      _stable(await _positioned(_recipient, Paper.a4)),
      _stable(await _positioned(_recipient, null)),
    );
    final (w, h) = _sheets(await _positioned(_recipient, Paper.a4)).first;
    expect(w, closeTo(595.28, 0.01));
    expect(h, closeTo(841.89, 0.01));
  });

  test('every kind is printed on A4; a kind the letter standard draws on '
      'Letter too, and its default layout stays on the Letter sheet', () async {
    for (final kind in reportKinds(reminderLevels: 1)) {
      expect(kind.papers, contains(Paper.a4), reason: kind.id);
      if (!isPersonFacingKind(kind.id)) continue;
      expect(kind.papers, contains(Paper.letter), reason: kind.id);
      final bytes = await _positioned(_recipient, Paper.letter, kind: kind.id);
      for (final sheet in _sheets(bytes)) {
        expect(sheet, (612.0, 792.0), reason: kind.id);
      }
      for (final i in textPositions(bytes, paper: Paper.letter)) {
        expect(
          i.xMm,
          inInclusiveRange(0, Paper.letter.widthMm),
          reason: '${kind.id} $i',
        );
        expect(
          i.yMm,
          inInclusiveRange(0, Paper.letter.heightMm),
          reason: '${kind.id} $i',
        );
      }
    }
  });

  test('a kind prints on the paper it declares, else on its design\'s own', () {
    const a4Only = ReportKind(id: 'x', slot: ReportDocSlot('x'), papers: [Paper.a4]);
    expect(a4Only.printedOn(Paper.letter), isNull);
    expect(a4Only.printedOn(Paper.a4), Paper.a4);
    const report = InvoiceReport(header: [], body: [], footer: []);
    expect(report.onPaper(null), same(report));
    final letter = report.onPaper(Paper.letter);
    expect(letter.paper, Paper.letter);
    expect(letter.numberedFor('general_ledger').paper, Paper.letter,
        reason: 'a report numbered from page 1 keeps its paper');
  });

  for (final kind in ['customer_statement', 'vat']) {
    testWidgets('a US business\'s $kind made now is on Letter, banded', (tester) async {
      for (final sheet in _sheets(await _letter(tester, 'US', kind))) {
        expect(sheet, (612.0, 792.0));
      }
    });
    testWidgets('a US business\'s $kind made now is on Letter, positioned', (tester) async {
      const layout = '<report-layout page="A4"><body><text>{{ client_name }}</text></body></report-layout>';
      final made = await _letter(tester, 'US', kind, layoutXml: layout);
      final direct = await tester.runAsync(() => tryLayoutPdf(
        layoutXml: layout,
        data: _data(_recipient),
        what: kind,
        print: LayoutPrint(documentTitle: kind, pageLabel: 'Page', paper: Paper.letter),
        font: (asset) async => _ttf(asset),
      ));
      expect(_stable(made), _stable(direct!), reason: 'the positioned engine drew it');
      for (final sheet in _sheets(made)) {
        expect(sheet, (612.0, 792.0));
      }
    });
  }

  testWidgets('a French business\'s statement made now stays on A4', (tester) async {
    final (w, h) = _sheets(await _letter(tester, 'FR', 'customer_statement')).first;
    expect(w, closeTo(595.28, 0.01));
    expect(h, closeTo(841.89, 0.01));
  });

  test('golden: one invoice on A4 and on Letter, banded and positioned', () async {
    for (final paper in Paper.values) {
      final name = paper.wire.toLowerCase();
      _golden('invoice_ink_banded_$name', _inkGolden(await _banded(_recipient, paper), paper));
      _golden('invoice_ink_positioned_$name', _inkGolden(await _positioned(_recipient, paper), paper));
    }
  });
}
