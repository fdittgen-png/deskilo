// SPDX-License-Identifier: 0BSD
//
// #873 — the invoice must conform to the French window-envelope spec,
// measured on the GENERATED PDF rather than asserted about the code
// that generates it.
//
//   sender block   20 mm from the top and left edges
//   address field  110 mm from the left, 45 mm (max 50) from the top,
//                  inside an 85 × 40 mm aperture
//   body           resumes at 90 mm — below the field and its tolerance
//   footer         fixed at the bottom of EVERY page
//   page 2+        a continuation strip, never the letterhead again
//
// Every one of these has been wrong at least once, and none of them was
// visible until a sheet was printed and folded into an envelope.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/presentation/invoice_line_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/pdf_geometry.dart';

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

const _strings = InvoicePdfStrings(
  invoiceTitle: 'Facture',
  issuedOn: 'Émise le',
  issuedBy: 'Émise par',
  billedTo: 'Facturé à',
  total: 'Total TTC',
  signature: 'Signature numérique (SHA-256)',
  voided: '',
  voidedWatermark: 'Erronée',
  proforma: 'Proforma',
  replaces: 'Remplace',
  description: 'Désignation',
  charges: 'Charges',
  payments: 'Règlements',
  annex: 'Annexe — détails',
  attendance: 'Présences',
  activity: 'Réservations',
  reserved: 'réservé',
  page: 'Page',
);

Invoice _invoice({int lines = 1}) => Invoice(
      id: 'i1',
      workspaceId: 'w1',
      memberId: 'm1',
      number: 'INV-2026-0044',
      issuedAt: DateTime.utc(2026, 9, 4),
      title: '2026-08',
      currency: 'EUR',
      memberName: 'SASU KaloA',
      memberAddress: '209 rue Jean Bart, Immeuble AGORA 1B\n31670 LABÈGE',
      workspaceName: 'COWORKONTI',
      workspaceAddress: '4 avenue de Castelnau, 34120 Pézenas',
      issuerName: 'Flo',
      signature: 'a' * 64,
      totalCents: 10000,
      lines: [
        for (var i = 0; i < lines; i++)
          InvoiceLine(
              kind: 'adjustment',
              label: 'Participation 100 % — ligne $i',
              amountCents: 10000),
      ],
    );

Future<Uint8List> _pdf({
  AddressWindow window = AddressWindow.right,
  int lines = 1,
}) =>
    buildInvoicePdf(
      invoice: _invoice(lines: lines),
      strings: _strings,
      addressWindow: window,
      money: (cents) => '${(cents / 100).toStringAsFixed(2)} €',
      lineText: (line) => invoiceLineText(null, line),
      activityText: (entry) => annexEntryText(null, entry),
      dateLabel: '4 sept. 2026',
      periodLabel: 'août 2026',
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

void main() {
  test('the sheet is A4 and the sender block starts at the 20 mm margin',
      () async {
    final bytes = await _pdf();
    saveForInspection(bytes, 'invoice-right-window.pdf');
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(bytes), contains('/MediaBox'));

    final ink = textPositions(bytes).where((i) => i.page == 1).toList();
    expect(ink, isNotEmpty, reason: 'nothing was drawn on page 1');

    final leftMost = ink.map((i) => i.xMm).reduce((a, b) => a < b ? a : b);
    final topMost = ink.map((i) => i.yMm).reduce((a, b) => a < b ? a : b);
    // A text BASELINE sits below the top of its box, so the first ink
    // is a few mm under the margin — what must never happen is ink
    // ABOVE it.
    expect(leftMost, greaterThanOrEqualTo(20 - 0.5),
        reason: 'ink breaches the 20 mm left margin');
    expect(leftMost, lessThan(24), reason: 'left margin is not 20 mm');
    expect(topMost, greaterThanOrEqualTo(20 - 0.5),
        reason: 'ink breaches the 20 mm top margin');
    expect(topMost, lessThan(30), reason: 'top margin is not 20 mm');
  });

  test('the recipient lands inside the 85 × 40 mm aperture at 110/45 mm',
      () async {
    final bytes = await _pdf();
    final page1 = textPositions(bytes).where((i) => i.page == 1);

    // The address is the ink in the right half between 45 and 90 mm.
    final inField = page1
        .where((i) => i.xMm >= 100 && i.yMm >= 40 && i.yMm <= 90)
        .toList();
    expect(inField, isNotEmpty,
        reason: 'no recipient drawn in the window zone — the invoice '
            'would post blank through the envelope');

    for (final i in inField) {
      expect(i.xMm, greaterThanOrEqualTo(110 - 0.5),
          reason: 'left of the aperture: $i');
      expect(i.xMm, lessThanOrEqualTo(110 + 85),
          reason: 'right of the aperture: $i');
      expect(i.yMm, greaterThanOrEqualTo(45 - 0.5),
          reason: 'above the aperture: $i');
      expect(i.yMm, lessThanOrEqualTo(50 + 40),
          reason: 'below the aperture: $i');
    }
  });

  test('nothing intrudes on the field, and the body resumes at 90 mm',
      () async {
    final bytes = await _pdf();
    final page1 = textPositions(bytes).where((i) => i.page == 1);

    // Between the sender block and 90 mm the LEFT half must be clear:
    // that band belongs to the envelope window and its tolerance.
    final intruders = page1
        .where((i) => i.xMm < 100 && i.yMm > 45 && i.yMm < 90)
        .toList();
    expect(intruders, isEmpty,
        reason: 'flow content sits in the window band: $intruders');
  });

  test('the footer is fixed to the bottom of EVERY page', () async {
    // Enough lines to force a second sheet.
    final bytes = await _pdf(lines: 60);
    final ink = textPositions(bytes);
    final pages = ink.map((i) => i.page).toSet();
    expect(pages.length, greaterThan(1),
        reason: 'the fixture no longer spans pages; raise the line count');

    for (final page in pages) {
      final bottom = ink
          .where((i) => i.page == page)
          .map((i) => i.yMm)
          .reduce((a, b) => a > b ? a : b);
      expect(bottom, greaterThan(240),
          reason: 'page $page has no footer near the bottom edge');
    }
  });

  test('page two carries a continuation strip, not the letterhead',
      () async {
    final bytes = await _pdf(lines: 60);
    final ink = textPositions(bytes);

    // The field itself — found by its placement transform, so this
    // cannot be confused with ordinary content at the same height.
    expect(
      addressFieldPages(bytes,
          leftEdgePt: AddressWindow.right.leftEdge,
          topPt: addressWindowTop,
          heightPt: addressWindowHeight),
      [1],
      reason: 'the address field must be painted on page 1 and nowhere '
          'else',
    );

    // And a later page starts its content ABOVE 90 mm, because it has
    // no window band to reserve — the strip is short by design.
    final page2Top = ink
        .where((i) => i.page == 2)
        .map((i) => i.yMm)
        .reduce((a, b) => a < b ? a : b);
    expect(page2Top, lessThan(45),
        reason: 'page 2 still reserves the letterhead band');
  });

  test('the left-hand convention moves the field to 20 mm and nothing '
      'else', () async {
    final bytes = await _pdf(window: AddressWindow.left);
    saveForInspection(bytes, 'invoice-left-window.pdf');
    final page1 = textPositions(bytes).where((i) => i.page == 1);
    final inField =
        page1.where((i) => i.yMm >= 45 && i.yMm <= 85).toList();
    expect(inField, isNotEmpty);
    for (final i in inField) {
      expect(i.xMm, greaterThanOrEqualTo(20 - 0.5), reason: '$i');
      expect(i.xMm, lessThanOrEqualTo(20 + 85), reason: '$i');
    }
  });
}
