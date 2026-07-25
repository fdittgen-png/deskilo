// SPDX-License-Identifier: 0BSD
//
// The space QR sheet: badge-grid A4 pages, one card per desk, office
// and level — chunked at ten cards per page.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/workspace/domain/space_codes_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Font _ttf(String path) => pw.Font.ttf(
      ByteData.sublistView(File(path).readAsBytesSync()),
    );

void main() {
  test('twelve spaces produce a two-page A4 sheet', () async {
    final bytes = await buildSpaceCodesPdf(
      workspaceName: 'Pézenas Cowork',
      entries: [
        for (var i = 1; i <= 12; i++)
          (
            name: 'Table $i',
            kindLabel: 'Desk',
            payload: 'deskilo://space?ws=ws-1&kind=desk&id=desk-$i',
          ),
      ],
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // Two A4 pages (595.28 pt MediaBox width) carry 10 + 2 cards.
    final raw = String.fromCharCodes(bytes);
    expect(RegExp(r'/MediaBox[^\]]*595').allMatches(raw).length, 2);
  });
}
