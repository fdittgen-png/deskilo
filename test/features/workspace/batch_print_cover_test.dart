// SPDX-License-Identifier: 0BSD
//
// #671 — batch prints carry the workspace's own wording.
//
// The badge sheet and the space QR cards were hard-coded PDFs. They are
// documents an owner prints repeatedly, so the text around the cards is
// now edited in report management like every other printable.
//
// The one design decision worth pinning is WHERE that text goes. These
// sheets are laid out to the millimetre — ISO/IEC 7810 cards that get
// cut out and stuck on things — so a header above the grid would have to
// come out of the card budget: two fewer badges per sheet, on every
// sheet, forever. A cover page costs one leaf of paper once and takes
// nothing away from what the print is actually for.
import 'dart:typed_data';

import 'package:deskilo/features/workspace/domain/badge_pdf.dart';
import 'package:deskilo/features/workspace/domain/space_codes_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

/// The bundled font is not loadable in a plain test, and Helvetica is
/// enough: nothing here asserts on glyphs.
pw.Font get _font => pw.Font.helvetica();

/// Pages in a PDF, counted from the `/Type /Page` objects. Crude, but it
/// is the one property these tests care about and it needs no parser.
int pageCount(Uint8List bytes) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;

Future<Uint8List> badges({List<pw.Widget> body = const []}) => buildBadgePdf(
      workspaceName: 'Pézenas',
      memberName: 'Alex Sample',
      token: 'tok-1',
      hint: 'Present your badge',
      baseFont: _font,
      boldFont: _font,
      coverBody: body,
    );

Future<Uint8List> codes({List<pw.Widget> body = const []}) =>
    buildSpaceCodesPdf(
      workspaceName: 'Pézenas',
      entries: [
        for (var i = 0; i < 3; i++)
          (
            name: 'Seat $i',
            kindLabel: 'Seat',
            payload: 'deskilo://space/$i',
            contextLines: const ['Level 1'],
          ),
      ],
      baseFont: _font,
      boldFont: _font,
      coverBody: body,
    );

void main() {
  group('the cover page never costs a card', () {
    test('the badge sheet gains a PAGE, not a header', () async {
      final without = pageCount(await badges());
      final with_ = pageCount(await badges(body: [pw.Text('House rules')]));
      expect(without, 1, reason: 'the sheet is one full A4 of 2x5 cards');
      expect(with_, without + 1,
          reason: 'the wording goes on its own leaf; squeezing it above '
              'the grid would cost two badges on every sheet printed');
    });

    test('the space-code sheet likewise', () async {
      final without = pageCount(await codes());
      final with_ = pageCount(await codes(body: [pw.Text('Stick these on')]));
      expect(with_, without + 1);
    });
  });

  group('an owner who cleared the text meant to print cards', () {
    test('empty bands produce NO cover page, not a blank leaf', () async {
      // Reset-to-empty is a real thing to do in the report editor, and
      // it must not start emitting a blank sheet with every print run.
      expect(pageCount(await badges(body: const [])), 1);
      expect(pageCount(await badges()), 1);
    });
  });

  group('the cards themselves are untouched', () {
    test('adding a cover does not change the card geometry', () async {
      // The dimensions are ISO/IEC 7810 ID-1 and the borders are cut
      // lines. A cover page that shifted them would make every printed
      // sheet unusable in the guillotine.
      expect(badgeCardWidth, closeTo(85.6 * 72 / 25.4, 0.01));
      expect(badgeCardHeight, closeTo(53.98 * 72 / 25.4, 0.01));
      expect(badgeSheetColumns * badgeSheetRows, badgeSheetCount);
    });
  });
}
