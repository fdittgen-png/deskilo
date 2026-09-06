// SPDX-License-Identifier: 0BSD
//
// The invoice PDF (0060): one A4 page carrying only SNAPSHOT fields —
// both addresses, issuer, date, lines, total and the SHA-256 digital
// signature. Nothing live leaks in; re-rendering an archive row must
// reproduce the same document.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/presentation/invoice_line_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

/// A REAL engine-encoded PNG: the image codec refuses hand-rolled bytes,
/// so the picture is painted and read back rather than invented.
Future<Uint8List> _pngBytes() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 120, 48),
      ui.Paint()..color = const ui.Color(0xFFB2432F));
  final image = await recorder.endRecording().toImage(120, 48);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

pw.Font _ttf(String path) => pw.Font.ttf(
      ByteData.sublistView(File(path).readAsBytesSync()),
    );

/// The page content streams, inflated — PDF drawing operators are Flate
/// compressed, and the watermark is only observable as operators (its
/// text is glyph-encoded by the embedded font).
String _operators(Uint8List bytes) {
  final raw = String.fromCharCodes(bytes);
  final out = StringBuffer();
  for (final match in RegExp(r'stream\r?\n').allMatches(raw)) {
    final end = raw.indexOf('endstream', match.end);
    if (end < 0) continue;
    try {
      out.writeln(String.fromCharCodes(zlib.decode(bytes.sublist(match.end, end))));
    } catch (_) {
      // Not a deflated stream (fonts, metadata) — nothing to read here.
    }
  }
  return out.toString();
}

/// Text-showing operators — one per rendered Text run.
int _textRuns(Uint8List bytes) =>
    RegExp(r'\]TJ').allMatches(_operators(bytes)).length;

/// The 45° rotation the diagonal watermark paints (cos/sin of π/4).
final _diagonal = RegExp(
    r'0\.707\d* 0\.707\d* -0\.707\d* 0\.707\d* [\d.]+ [\d.]+ cm');

/// Its light grey (grey400, 0xBD → 189/255), painted at half opacity so
/// the figures underneath stay readable.
final _lightGrey = RegExp(r'0\.741\d* 0\.741\d* 0\.741\d* rg');

const _strings = InvoicePdfStrings(
  invoiceTitle: 'Invoice',
  issuedOn: 'Issued on',
  issuedBy: 'Issued by',
  billedTo: 'Billed to',
  total: 'Balance due',
  signature: 'Digital signature (SHA-256)',
  voided: 'ERRONEOUS — voided on Jul 20, 2026',
  voidedWatermark: 'Erronée',
  proforma: 'Proforma',
  replaces: 'Replaces',
  description: 'Description',
  charges: 'Charges',
  payments: 'Payments',
  annex: 'Annex — details',
  attendance: 'Check-ins',
  activity: 'Bookings & payments',
  reserved: 'reserved',
  page: 'Page',
);

void main() {
  test('builds a single-page A4 PDF from the invoice snapshot', () async {
    final invoice = Invoice(
      id: 'inv-1',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0001',
      issuedAt: DateTime(2026, 7, 13),
      title: '2026-07',
      lines: const [
        InvoiceLine(
            kind: 'subscription', label: '50', amountCents: 15000),
        InvoiceLine(kind: 'service', label: 'Coffee ×3', amountCents: 450),
      ],
      totalCents: 15450,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test, 34120 Pezenas',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marche, 34120 Pezenas',
      issuerName: 'Flo',
      signature: 'f' * 64,
    );

    final bytes = await buildInvoicePdf(
      invoice: invoice,
      strings: _strings,
      money: (cents) => '${(cents / 100).toStringAsFixed(2)} EUR',
      lineText: (line) => invoiceLineText(null, line),
      activityText: (entry) => annexEntryText(null, entry),
      dateLabel: 'Jul 13, 2026',
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // A4 pages (595.28 × 841.89 pt MediaBox); the compact invoice fits
    // one.
    final raw = String.fromCharCodes(bytes);
    expect(RegExp(r'/MediaBox[^\]]*595').allMatches(raw).length, 1);
    expect(_diagonal.hasMatch(_operators(bytes)), isFalse,
        reason: 'a valid invoice carries no erroneous watermark');
  });

  test(
      'a DETAILED invoice (0064) renders the annex — long months '
      'paginate', () async {
    final invoice = Invoice(
      id: 'inv-9',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0009',
      issuedAt: DateTime(2026, 7, 31),
      title: '2026-07',
      lines: const [
        InvoiceLine(kind: 'subscription', label: '50', amountCents: 15000),
        InvoiceLine(kind: 'payment', label: 'PayPal', amountCents: -5000),
      ],
      totalCents: 10000,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test, 34120 Pezenas',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marche, 34120 Pezenas',
      issuerName: 'Flo',
      signature: 'd' * 64,
      detailed: true,
      detailLedger: [
        for (var i = 1; i <= 30; i++)
          InvoiceDetailEntry(
            on: '2026-07-${i.toString().padLeft(2, '0')}',
            category: i.isEven ? 'service' : 'payment',
            label: 'Entry $i',
            amountCents: i.isEven ? 150 : -150,
          ),
      ],
      attendance: [
        for (var i = 1; i <= 26; i++)
          InvoiceAttendance(
            startsAt: '2026-07-${i.toString().padLeft(2, '0')}T09:00',
            endsAt: '2026-07-${i.toString().padLeft(2, '0')}T13:00',
            space: 'A1 · Window desk',
            status: i.isEven ? 'checked_in' : 'reserved',
          ),
      ],
    );

    final bytes = await buildInvoicePdf(
      invoice: invoice,
      strings: _strings,
      money: (cents) => '${(cents / 100).toStringAsFixed(2)} EUR',
      lineText: (line) => invoiceLineText(null, line),
      activityText: (entry) => annexEntryText(null, entry),
      dateLabel: 'Jul 31, 2026',
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final raw = String.fromCharCodes(bytes);
    expect(RegExp(r'/MediaBox[^\]]*595').allMatches(raw).length,
        greaterThanOrEqualTo(2),
        reason: '56 annex rows cannot fit one A4 page — MultiPage must '
            'paginate');
  });

  test(
      'a VOIDED replacement renders the erroneous banner and the '
      'replaced number on one A4 page (0061)', () async {
    final invoice = Invoice(
      id: 'inv-2',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0002',
      issuedAt: DateTime(2026, 7, 14),
      title: '2026-07',
      lines: const [
        InvoiceLine(
            kind: 'subscription', label: '50', amountCents: 15000),
      ],
      totalCents: 15000,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test, 34120 Pezenas',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marche, 34120 Pezenas',
      issuerName: 'Flo',
      signature: 'e' * 64,
      voidedAt: DateTime(2026, 7, 20),
      voidedByName: 'Flo',
      replacesInvoiceId: 'inv-1',
      replacesNumber: 'INV-2026-0001',
    );

    final bytes = await buildInvoicePdf(
      invoice: invoice,
      strings: _strings,
      money: (cents) => '${(cents / 100).toStringAsFixed(2)} EUR',
      lineText: (line) => invoiceLineText(null, line),
      activityText: (entry) => annexEntryText(null, entry),
      dateLabel: 'Jul 14, 2026',
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final raw = String.fromCharCodes(bytes);
    expect(RegExp(r'/MediaBox[^\]]*595').allMatches(raw).length, 1);

    // 0071 — and the whole sheet says so: the word runs diagonally in
    // light grey BEHIND the content, so an erroneous invoice cannot be
    // mistaken for a valid one at a glance or on a photocopy.
    final operators = _operators(bytes);
    expect(_diagonal.hasMatch(operators), isTrue,
        reason: 'the watermark is drawn at 45°');
    expect(_lightGrey.hasMatch(operators), isTrue,
        reason: 'in light grey — it must never fight the figures on top');
  });

  test(
      'FACTUR-X (0073): the PDF becomes PDF/A-3 and carries the CII invoice '
      'as factur-x.xml — one file for both readers', () async {
    final invoice = Invoice(
      id: 'inv-4',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0006',
      issuedAt: DateTime(2026, 7, 27),
      period: '2026-06',
      title: '2026-06',
      lines: const [
        InvoiceLine(kind: 'subscription', label: '100', amountCents: 25000),
      ],
      totalCents: 25000,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test, 34120 Pezenas',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marche, 34120 Pezenas',
      issuerName: 'Flo',
      signature: 'b' * 64,
    );
    const xml = '<rsm:CrossIndustryInvoice>probe</rsm:CrossIndustryInvoice>';

    final bytes = await buildInvoicePdf(
      invoice: invoice,
      strings: _strings,
      money: (cents) => '\${(cents / 100).toStringAsFixed(2)} EUR',
      lineText: (line) => invoiceLineText(null, line),
      activityText: (entry) => annexEntryText(null, entry),
      dateLabel: 'Jul 27, 2026',
      facturXml: xml,
      colorProfile: Uint8List.fromList(
        File('assets/pdf/sRGB2014.icc').readAsBytesSync(),
      ),
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

    final raw = String.fromCharCodes(bytes);
    expect(raw, contains('/EmbeddedFile'));
    expect(raw, contains('factur-x.xml'),
        reason: 'the format mandates that exact file name');
    expect(raw, contains('AFRelationship'));
    expect(raw, contains('/Alternative'));
    expect(raw, contains(xml),
        reason: 'the attachment is stored uncompressed and IS the invoice');
    expect(raw, contains('<pdfaid:part>3</pdfaid:part>'),
        reason: 'PDF/A-3 — Factur-X exists nowhere else');
    expect(raw, contains('<fx:DocumentType>INVOICE</fx:DocumentType>'));
    expect(raw, contains('EN 16931'),
        reason: 'the declared conformance level, not a downgraded BASIC');
    // The output intent PDF/A demands.
    expect(raw, contains('/OutputIntent'));

    // Without a colour profile it stays an ordinary PDF: no half-Factur-X.
    final plain = await buildInvoicePdf(
      invoice: invoice,
      strings: _strings,
      money: (cents) => '\${(cents / 100).toStringAsFixed(2)} EUR',
      lineText: (line) => invoiceLineText(null, line),
      activityText: (entry) => annexEntryText(null, entry),
      dateLabel: 'Jul 27, 2026',
      facturXml: xml,
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );
    expect(String.fromCharCodes(plain), isNot(contains('factur-x.xml')));
  });

  testWidgets('#923 — the letterhead LOGO survives the envelope window: the '
      'sender band is fixed at 25 mm and a letterhead with a logo is '
      'taller, so it scales instead of being clipped away',
      (tester) async {
    // The engine encodes the PNG and the pdf package decodes it: both
    // need the real async zone, not the fake one a widget test pumps.
    await tester.runAsync(() async {
    final invoice = Invoice(
      id: 'inv-logo',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0004',
      issuedAt: DateTime(2026, 9, 6),
      period: '2026-09',
      title: 'INV-2026-0004',
      lines: const [
        InvoiceLine(kind: 'service', label: 'Participation', amountCents: 10000),
      ],
      totalCents: 10000,
      currency: 'EUR',
      memberName: 'SASU KaloA',
      memberAddress: '209 rue Jean Bart\n31670 LABÈGE',
      workspaceName: 'COWORKONTI',
      workspaceAddress: '4 avenue de Castelnau, 34120 Pézenas',
      issuerName: 'Flo',
      signature: 'c' * 64,
    );
    // A real engine-encoded PNG: the codec refuses hand-rolled bytes.
    final logo = await _pngBytes();
    final report = renderReportBands(
      bands: const ReportBands(
        header: '![logo]\nAssociation loi 1901\n4 avenue de Castelnau',
        body: '{% for line in lines %}{{ line.label }} | {{ line.amount }}\n'
            '{% endfor %}',
        footer: '> {{ workspace }}',
      ),
      data: const {
        'workspace': 'COWORKONTI',
        'lines': [
          {'label': 'Participation', 'amount': '100,00 €'},
        ],
      },
    );
    expect(report, isNotNull);
    expect(reportImageRefs(report!), contains('logo'));

    final bytes = await buildInvoicePdf(
      invoice: invoice,
      strings: _strings,
      money: (cents) => '\${(cents / 100).toStringAsFixed(2)} EUR',
      lineText: (line) => invoiceLineText(null, line),
      activityText: (entry) => annexEntryText(null, entry),
      dateLabel: 'Sep 6, 2026',
      report: report,
      reportImages: {'logo': logo},
      // The window ON is the case that used to lose it.
      addressWindow: AddressWindow.left,
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );
    final raw = String.fromCharCodes(bytes);
    expect(raw, contains('/Subtype/Image'),
        reason: 'the logo must reach the page, not be clipped out of it');

    // And with the window OFF it was always there — the guard must not
    // have traded one case for the other.
    final plain = await buildInvoicePdf(
      invoice: invoice,
      strings: _strings,
      money: (cents) => '\${(cents / 100).toStringAsFixed(2)} EUR',
      lineText: (line) => invoiceLineText(null, line),
      activityText: (entry) => annexEntryText(null, entry),
      dateLabel: 'Sep 6, 2026',
      report: report,
      reportImages: {'logo': logo},
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );
    expect(String.fromCharCodes(plain), contains('/Subtype/Image'));
    });
  });

  test(
      'a PROFORMA carries the same figures with NO signature and its own '
      'diagonal stamp — a quote, not a document of record (0072)', () async {
    final invoice = Invoice(
      id: '',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: '',
      issuedAt: DateTime(2026, 7, 27),
      period: '2026-06',
      title: '2026-06',
      lines: const [
        InvoiceLine(kind: 'subscription', label: '100', amountCents: 25000),
      ],
      totalCents: 25000,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test, 34120 Pezenas',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marche, 34120 Pezenas',
      issuerName: 'Flo',
      // Nothing was issued: no number, no fingerprint.
      signature: '',
    );

    Future<Uint8List> render({required bool proforma}) => buildInvoicePdf(
          invoice: proforma
              ? invoice
              : invoice.copyWith(
                  number: 'INV-2026-0005', signature: 'f' * 64),
          strings: _strings,
          money: (cents) => '\${(cents / 100).toStringAsFixed(2)} EUR',
          lineText: (line) => invoiceLineText(null, line),
          activityText: (entry) => annexEntryText(null, entry),
          dateLabel: 'Jul 27, 2026',
          proforma: proforma,
          baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
          boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
        );

    final proforma = await render(proforma: true);
    final issued = await render(proforma: false);

    expect(_diagonal.hasMatch(_operators(proforma)), isTrue,
        reason: 'stamped, so it can never pass for the invoice');
    expect(_diagonal.hasMatch(_operators(issued)), isFalse);
    // Fewer runs even though the proforma ADDS the watermark: the
    // signature caption and its (wrapping) digest are gone.
    expect(_textRuns(proforma), lessThan(_textRuns(issued)),
        reason: 'a proforma certifies nothing, so it prints no signature');
  });

  test(
      'the erroneous watermark repeats on EVERY page — the annex is part '
      'of the same voided document (0071)', () async {
    final invoice = Invoice(
      id: 'inv-3',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0003',
      issuedAt: DateTime(2026, 7, 31),
      title: '2026-07',
      lines: const [
        InvoiceLine(kind: 'subscription', label: '50', amountCents: 15000),
      ],
      totalCents: 15000,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test, 34120 Pezenas',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marche, 34120 Pezenas',
      issuerName: 'Flo',
      signature: 'c' * 64,
      voidedAt: DateTime(2026, 8, 2),
      voidedByName: 'Flo',
      detailed: true,
      detailLedger: [
        for (var i = 1; i <= 30; i++)
          InvoiceDetailEntry(
            on: '2026-07-${i.toString().padLeft(2, '0')}',
            category: 'service',
            label: 'Entry $i',
            amountCents: 150,
          ),
      ],
      attendance: [
        for (var i = 1; i <= 26; i++)
          InvoiceAttendance(
            startsAt: '2026-07-${i.toString().padLeft(2, '0')}T09:00',
            endsAt: '2026-07-${i.toString().padLeft(2, '0')}T13:00',
            space: 'A1 · Window desk',
            status: 'checked_in',
          ),
      ],
    );

    final bytes = await buildInvoicePdf(
      invoice: invoice,
      strings: _strings,
      money: (cents) => '${(cents / 100).toStringAsFixed(2)} EUR',
      lineText: (line) => invoiceLineText(null, line),
      activityText: (entry) => annexEntryText(null, entry),
      dateLabel: 'Jul 31, 2026',
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

    final pages = RegExp(r'/MediaBox[^\]]*595')
        .allMatches(String.fromCharCodes(bytes))
        .length;
    expect(pages, greaterThanOrEqualTo(2));
    expect(_diagonal.allMatches(_operators(bytes)).length, pages,
        reason: 'one watermark per page, annex included');
  });
}
