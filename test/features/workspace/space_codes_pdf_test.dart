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

List<SpaceCodeEntry> _entries(int count) => [
      for (var i = 1; i <= count; i++)
        (
          name: 'Table $i',
          kindLabel: 'Desk',
          payload: 'deskilo://space?ws=ws-1&kind=desk&id=desk-$i',
          contextLines: const ['Pézenas Cowork', 'Ground floor'],
        ),
    ];

void main() {
  test('twelve spaces produce a two-page A4 sheet at medium', () async {
    final bytes = await buildSpaceCodesPdf(
      workspaceName: 'Pézenas Cowork',
      entries: _entries(12),
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // Two A4 pages (595.28 pt MediaBox width) carry 10 + 2 cards.
    final raw = String.fromCharCodes(bytes);
    expect(RegExp(r'/MediaBox[^\]]*595').allMatches(raw).length, 2);
  });

  test('#584 — the size drives the grid: 12 cards fill 1 page small '
      '(18/page), 2 pages medium (10/page), 4 pages large (3/page)',
      () async {
    Future<int> pages(SpaceCardSize size) async {
      final bytes = await buildSpaceCodesPdf(
        workspaceName: 'Pézenas Cowork',
        entries: _entries(12),
        baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
        boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
        size: size,
      );
      return RegExp(r'/MediaBox[^\]]*595')
          .allMatches(String.fromCharCodes(bytes))
          .length;
    }

    expect(await pages(SpaceCardSize.small), 1);
    expect(await pages(SpaceCardSize.medium), 2);
    expect(await pages(SpaceCardSize.large), 4);
  });
}
