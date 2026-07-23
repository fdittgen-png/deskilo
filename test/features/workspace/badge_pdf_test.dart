// SPDX-License-Identifier: 0BSD
//
// Badge sheet (A4 revision): the one-time badge QR repeated at
// credit-card size, 2×5 per A4 page — print once, cut, keep spares.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/workspace/domain/badge_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Font _ttf(String path) => pw.Font.ttf(
      ByteData.sublistView(File(path).readAsBytesSync()),
    );

void main() {
  test('the badge card is ISO ID-1 credit-card size, ten per A4 sheet',
      () {
    // 85.60 × 53.98 mm in PDF points.
    expect(badgeCardWidth, closeTo(85.6 * PdfPageFormat.mm, 0.01));
    expect(badgeCardHeight, closeTo(53.98 * PdfPageFormat.mm, 0.01));
    expect(badgeSheetCount, 10);
    // The grid must fit A4 inside the 10 mm margins.
    const printable = 190 * PdfPageFormat.mm;
    expect(badgeSheetColumns * badgeCardWidth, lessThan(printable));
    const printableH = 277 * PdfPageFormat.mm;
    expect(badgeSheetRows * badgeCardHeight, lessThan(printableH));
  });

  test('builds a single-page A4 PDF with the member card grid', () async {
    final bytes = await buildBadgePdf(
      workspaceName: 'Pézenas Cowork',
      memberName: 'Aurélie Dupré-Œstergaard',
      token: 'a' * 64,
      hint: 'Present your badge at the kiosk',
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // Exactly one A4 page (595.28 × 841.89 pt MediaBox) carries the grid.
    final raw = String.fromCharCodes(bytes);
    expect(RegExp(r'/MediaBox[^\]]*595').allMatches(raw).length, 1);
  });
}
