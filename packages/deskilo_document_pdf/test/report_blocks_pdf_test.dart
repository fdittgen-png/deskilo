// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4160 -- the generic block renderer and the diagonal watermark, in the PDF
// package and with no application around them: the same widgets the invoice
// and the workspace reports have always drawn, with a missing image drawing
// nothing, a sized image capped by a hard band, and the watermark scaled by the
// length of its word.
import 'dart:typed_data';

import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:deskilo_document_pdf/deskilo_document_pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

/// A 1x1 PNG, enough for the PDF library to place.
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

pw.Image _imageOf(pw.Widget widget) =>
    (widget as pw.Padding).child! as pw.Image;

Future<Uint8List> _save(List<pw.Widget> body, {String watermark = ''}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        buildForeground: reportWatermarkForeground(watermark),
      ),
      build: (_) => body,
    ),
  );
  return doc.save();
}

void main() {
  group('the blocks as widgets', () {
    test('every block kind draws one widget, in order, with its own words', () {
      final blocks = parseReportMarkup(
        '# Title\n## Section\nBody\n> small\n---\nItem | 3\n= Total | 9\n\n'
        ':::\nLeft\n|||\nRight\n:::',
      );
      final widgets = reportBlockWidgets(blocks);
      expect(widgets, hasLength(blocks.length));
      String textOf(pw.Widget w) =>
          ((w as pw.Padding).child! as pw.Text).text.toPlainText();
      expect(textOf(widgets[0]), 'Title');
      expect(textOf(widgets[1]), 'SECTION', reason: 'sections are small caps');
      expect(widgets[2], isA<pw.Text>());
      expect((widgets[2] as pw.Text).text.toPlainText(), 'Body');
      expect((widgets[3] as pw.Text).text.toPlainText(), 'small');
      expect(widgets[4], isA<pw.Container>());
      expect(widgets[5], isA<pw.Padding>(), reason: 'a table row');
      expect(widgets[6], isA<pw.Padding>());
      expect(widgets[7], isA<pw.SizedBox>(), reason: 'the blank line');
      expect(widgets[8], isA<pw.Row>(), reason: 'the columns');
    });

    test('an image the host did not resolve draws nothing', () {
      final widgets = reportBlockWidgets(
        parseReportMarkup('![missing]'),
        images: {'other': _png},
      );
      expect(widgets.single, isA<pw.SizedBox>());
      expect((widgets.single as pw.SizedBox).child, isNull);
    });

    test('an image keeps its printed height, and a hard band caps it', () {
      final blocks = parseReportMarkup('![logo|l]\n![plan|xl]');
      final free = reportBlockWidgets(
        blocks,
        images: {'logo': _png, 'plan': _png},
      );
      expect(_imageOf(free[0]).height, 96);
      expect(_imageOf(free[1]).height, 300);
      final capped = reportBlockWidgets(
        blocks,
        images: {'logo': _png, 'plan': _png},
        maxImageHeight: 70,
      );
      expect(_imageOf(capped[0]).height, 70, reason: 'larger than the band');
      expect(_imageOf(capped[1]).height, 70);
      final small = reportBlockWidgets(
        parseReportMarkup('![logo|s]'),
        images: {'logo': _png},
        maxImageHeight: 70,
      );
      expect(
        _imageOf(small.single).height,
        40,
        reason: 'smaller keeps its own',
      );
    });

    test('a page of every block kind and an image is a PDF', () async {
      final bytes = await _save(
        reportBlockWidgets(
          parseReportMarkup(
            '# T\nText\n![logo|right]\n:::\n![logo|s]\n|||\nA | 1\n:::',
          ),
          images: {'logo': _png},
        ),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('the watermark', () {
    test('an empty word paints nothing', () {
      expect(reportWatermarkForeground(''), isNull);
    });

    test('the size follows the length of the word, capped at 120 points', () {
      expect(reportWatermarkSize('A'), 120);
      expect(reportWatermarkSize('ERRATA'), 120);
      expect(reportWatermarkSize('DEVELOPMENT'), closeTo(820 / 11, 0.001));
      expect(reportWatermarkSize('DÉVELOPPEMENT'), closeTo(820 / 13, 0.001));
      expect(
        reportWatermarkSize('X' * 40),
        lessThan(reportWatermarkSize('X' * 10)),
      );
    });

    test('a short and a very long word both render a page', () async {
      for (final word in ['COPY', 'DEVELOPPEMENT-FEHLERHAFT-ERRATA-PROFORMA']) {
        final bytes = await _save([pw.Text('body')], watermark: word);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: word);
      }
    });

    test('its ink is the shared light grey at half opacity', () {
      expect(reportWatermark, PdfColors.grey400);
      expect(reportWatermarkOpacity, 0.5);
    });
  });
}
