// SPDX-License-Identifier: AGPL-3.0-or-later
// Real PDFs prove that body length cannot move the footer, that footer
// growth goes upward, and that continuation pages omit letter addresses.
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/pdf_geometry.dart';

pw.Font font(String name) => pw.Font.ttf(
  File('assets/fonts/$name.ttf').readAsBytesSync().buffer.asByteData(),
);

void main() {
  test(
    'banded footer stays at the same bottom position on every sheet',
    () async {
      Future<List<InkAt>> render(int rows) async {
        final bytes = await buildBandedLetterPdf(
          report: InvoiceReport(
            header: const [ReportHeading('FIRST_PAGE_ADDRESS')],
            continuation: const [ReportText('DOCUMENT_REFERENCE')],
            body: List.generate(rows, (i) => ReportText('Body row $i')),
            footer: const [ReportText('FIXED FOOTER')],
          ),
          pageLabel: 'Page',
          documentTitle: 'Reference 123',
          baseFont: pw.Font.helvetica(),
          boldFont: pw.Font.helveticaBold(),
        );
        if (rows > 100) {
          final streams = pageStreams(bytes);
          expect(streams.first, contains('FIRST_PAGE_ADDRESS'));
          for (final stream in streams.skip(1)) {
            expect(stream, isNot(contains('FIRST_PAGE_ADDRESS')));
            expect(stream, contains('DOCUMENT_REFERENCE'));
          }
          final output = Directory('build/report-sections')
            ..createSync(recursive: true);
          File('${output.path}/multipage.pdf').writeAsBytesSync(bytes);
        }
        return textPositions(bytes);
      }

      final short = await render(2);
      final long = await render(110);
      expect(long.map((i) => i.page).toSet().length, greaterThan(1));
      final shortFooter = short
          .where((p) => p.xMm < 150)
          .map((p) => p.yMm)
          .reduce((a, b) => a > b ? a : b);
      expect(shortFooter, greaterThan(260));
      for (final page in long.map((i) => i.page).toSet()) {
        final footer = long
            .where((p) => p.page == page && p.xMm < 150)
            .map((p) => p.yMm)
            .reduce((a, b) => a > b ? a : b);
        expect(footer, closeTo(shortFooter, .2), reason: 'page $page');
      }
    },
  );

  test(
    'positioned footer grows upward and keeps its last line anchored',
    () async {
      Future<double> lastLine(int lines) async {
        final xml =
            '<report-layout margin="20mm">'
            '<header><text>HEADER</text></header>'
            '<body><text>BODY</text></body><footer height="30mm">'
            '${List.generate(lines, (i) => '<text>Footer $i</text>').join()}'
            '</footer></report-layout>';
        final bytes = await buildLayoutPdf(
          document: renderLayoutDocument(xml, const {}),
          data: const {},
          documentTitle: 'Reference',
          pageLabel: 'Page',
          baseFont: font('Roboto-Regular'),
          boldFont: font('Roboto-Bold'),
        );
        return textPositions(bytes)
            .map((p) => p.yMm)
            .reduce((a, b) => a > b ? a : b);
      }

      expect(await lastLine(1), closeTo(await lastLine(5), .2));
    },
  );
}
