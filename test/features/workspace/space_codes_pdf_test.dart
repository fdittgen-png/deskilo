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

  test('#596 — the QR sizes on its own: every card carries a strictly '
      'larger code at each step, and every combination fits the card',
      () {
    const mm = 72 / 25.4;
    // Usable card heights (box minus the 8 pt padding on both sides).
    final usable = {
      SpaceCardSize.small: 40 * mm - 16,
      SpaceCardSize.medium: 53.98 * mm - 16,
      SpaceCardSize.large: 84 * mm - 16,
    };
    for (final card in SpaceCardSize.values) {
      final s = spaceQrEdge(card, SpaceQrSize.small);
      final m = spaceQrEdge(card, SpaceQrSize.medium);
      final l = spaceQrEdge(card, SpaceQrSize.large);
      expect(s, lessThan(m), reason: '$card small < medium');
      expect(m, lessThan(l), reason: '$card medium < large');
      expect(l, lessThanOrEqualTo(usable[card]!),
          reason: '$card large must fit inside the padding — the padding '
              'doubles as the QR quiet zone');
    }
    // The worst combination stays above the phone-camera floor: a small
    // card's small code is still ≥ 18 mm.
    expect(spaceQrEdge(SpaceCardSize.small, SpaceQrSize.small),
        greaterThanOrEqualTo(18 * mm));
    // MEDIUM reproduces the historical #584 edge on every card
    // (26/38/64 mm ± 3 mm) so existing printouts keep their look.
    expect(spaceQrEdge(SpaceCardSize.small, SpaceQrSize.medium) / mm,
        closeTo(26, 3));
    expect(spaceQrEdge(SpaceCardSize.medium, SpaceQrSize.medium) / mm,
        closeTo(38, 3));
    expect(spaceQrEdge(SpaceCardSize.large, SpaceQrSize.medium) / mm,
        closeTo(64, 3));
  });

  test('#596 — the sheet builds at every card × code combination', () async {
    for (final card in SpaceCardSize.values) {
      for (final qr in SpaceQrSize.values) {
        final bytes = await buildSpaceCodesPdf(
          workspaceName: 'Pézenas Cowork',
          entries: _entries(2),
          baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
          boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
          size: card,
          qrSize: qr,
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-',
            reason: '$card × $qr');
      }
    }
  });
}
