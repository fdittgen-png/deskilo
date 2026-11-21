// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4160 -- the report blocks and the markup parser, in the neutral model: the
// same markup the invoice engine and the workspace reports have always used,
// parsed with no template language, tracing or application type around it.
import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:test/test.dart';

void main() {
  group('the markup', () {
    test('a heading, a section, text, a muted line, a rule and a table', () {
      final blocks = parseReportMarkup(
        '# Title\n## Section\nBody text\n> small print\n---\n'
        'Item | Qty\n= Total | 3',
      );
      expect(blocks.map((b) => b.runtimeType.toString()), [
        'ReportHeading',
        'ReportSubheading',
        'ReportText',
        'ReportMuted',
        'ReportDivider',
        'ReportTableRow',
        'ReportTableRow',
      ]);
      expect((blocks[0] as ReportHeading).text, 'Title');
      expect((blocks[1] as ReportSubheading).text, 'Section');
      final row = blocks[5] as ReportTableRow;
      expect(row.cells, ['Item', 'Qty']);
      expect(row.bold, isFalse);
      final total = blocks[6] as ReportTableRow;
      expect(total.cells, ['Total', '3']);
      expect(total.bold, isTrue);
    });

    test('blank lines collapse to one spacer and never lead', () {
      final blocks = parseReportMarkup('\n\nA\n\n\n\nB\n');
      expect(blocks.map((b) => b.runtimeType.toString()), [
        'ReportText',
        'ReportSpacer',
        'ReportText',
      ]);
    });

    test('an image names its size and alignment, defaults left out, unknown '
        'words ignored', () {
      final plain = parseReportMarkup('![logo]').single as ReportImage;
      expect(plain.size, ReportImageSize.medium);
      expect(plain.align, ReportImageAlign.left);
      expect(plain.markup, 'logo', reason: 'a plain image round-trips');
      final sized =
          parseReportMarkup('![plan|xl|center]').single as ReportImage;
      expect(sized.size, ReportImageSize.extraLarge);
      expect(sized.align, ReportImageAlign.center);
      expect(sized.markup, 'plan|xl|center');
      final order = parseReportMarkup('![stamp|right|s]').single as ReportImage;
      expect(order.size, ReportImageSize.small);
      expect(order.align, ReportImageAlign.right);
      final unknown = parseReportMarkup('![x|huge|up]').single as ReportImage;
      expect(unknown.size, ReportImageSize.medium);
      expect(unknown.align, ReportImageAlign.left);
      expect(
        [for (final s in ReportImageSize.values) s.height],
        [40, 64, 96, 300],
        reason: 'the heights are the printed sizes',
      );
    });

    test('columns split at ||| and an empty first column pushes the second '
        'right; each column is parsed with the same rules', () {
      final cols =
          parseReportMarkup(':::\n|||\nTotal | 10\n:::').single
              as ReportColumns;
      expect(cols.columns, hasLength(2));
      expect(cols.columns.first, isEmpty);
      expect((cols.columns.last.single as ReportTableRow).cells, [
        'Total',
        '10',
      ]);
    });

    test('every image a report references is found, inside columns too', () {
      final report = RenderedReport(
        header: parseReportMarkup('![logo]'),
        body: parseReportMarkup(':::\n![a|l]\n|||\n![b]\n:::'),
        footer: parseReportMarkup('![stamp]'),
        continuation: parseReportMarkup('![never-counted]'),
      );
      expect(reportImageRefs(report), {'logo', 'a', 'b', 'stamp'});
    });
  });

  group('the rendered bands', () {
    test(
      'a report keeps its paper and numbering until a host says otherwise',
      () {
        const report = RenderedReport(header: [], body: [], footer: []);
        expect(report.numberFirstPage, isFalse);
        expect(report.paper, Paper.a4);
        expect(identical(report.withNumberFirstPage(false), report), isTrue);
        expect(identical(report.onPaper(null), report), isTrue);
        expect(identical(report.onPaper(Paper.a4), report), isTrue);
        final numbered = report.withNumberFirstPage(true);
        expect(numbered.numberFirstPage, isTrue);
        expect(numbered.paper, Paper.a4);
        final letter = numbered.onPaper(
          Paper.values.firstWhere((p) => p != Paper.a4),
        );
        expect(letter.numberFirstPage, isTrue, reason: 'paper keeps numbering');
        expect(letter.paper, isNot(Paper.a4));
      },
    );
  });
}
