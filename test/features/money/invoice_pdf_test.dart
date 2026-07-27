// SPDX-License-Identifier: 0BSD
//
// The invoice PDF (0060): one A4 page carrying only SNAPSHOT fields —
// both addresses, issuer, date, lines, total and the SHA-256 digital
// signature. Nothing live leaks in; re-rendering an archive row must
// reproduce the same document.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/presentation/invoice_line_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

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
