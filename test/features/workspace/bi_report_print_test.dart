// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2581 — the printout of a snapshot. The provenance (workspace, report and
// revision, period, date basis, currencies, filters, computation time,
// digest) and the qualification are printed whatever the layout says; a
// financial copy says it is management information. The layout's paper,
// orientation, margins, header and footer reach the PDF; each report page
// starts a sheet when asked; a long table runs over sheets with its
// headings repeated and every row kept; long German labels, accents,
// negative values and unknowns survive. The PDF is read back as text: what
// a reader sees is asserted, not the widget tree.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_report_pdf.dart';
import 'package:deskilo/features/workspace/domain/bi_report_print.dart';
import 'package:deskilo/features/workspace/domain/bi_report_snapshot.dart';
import 'package:deskilo/features/workspace/presentation/bi_print_strings_l10n.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/bi_report_fixture.dart';
import '../../helpers/pdf_text.dart';

final _en = AppLocalizationsEn();
final _words = biPrintStringsOf(_en, 'en', wall: (at) => at);

pw.Font _font(String name) => pw.Font.ttf(
  ByteData.sublistView(File('assets/fonts/Roboto-$name.ttf').readAsBytesSync()),
);

Future<Uint8List> _pdf(BiPrintDocument doc) => buildBiPrintPdf(
  doc,
  fonts: (base: _font('Regular'), bold: _font('Bold')),
  pageLabel: 'Page',
);

void main() {
  setUpAll(initializeDateFormatting);

  group('the document', () {
    test('carries its provenance and qualification', () {
      final doc = biPrintDocument(fixtureSnapshot(), _words);
      final lines = {for (final l in doc.provenance) l.label: l.value};
      expect(lines[_en.biPrintWorkspace], 'Pézenas Coworking');
      expect(lines[_en.biPrintReport], 'Board pack · revision 4');
      expect(lines[_en.biPrintPeriod], 'September 2026');
      expect(lines[_en.biPrintDateBasis], contains('booked time'));
      expect(lines[_en.biPrintDateBasis], contains('month of the invoice'));
      expect(lines[_en.biPrintCurrency], 'CHF, EUR');
      expect(lines[_en.biPrintFilters], 'none');
      expect(lines[_en.biPrintSnapshot], fixtureHash.substring(0, 12));
      expect(doc.qualification, _en.biPrintPartial);
      expect(doc.management, _en.biPrintManagement);
      expect(doc.sourceLine, contains('Pézenas Coworking · Board pack'));
    });

    test(
      'hiding the sources never hides the provenance or the qualification',
      () {
        final doc = biPrintDocument(
          fixtureSnapshot(
            report: fixtureReport(
              style: const BiPrintStyle(showSources: false),
            ),
          ),
          _words,
        );
        expect(doc.sources, isEmpty);
        expect(doc.provenance, hasLength(9));
        expect(
          doc.provenance
              .firstWhere((l) => l.label == _en.biPrintFigures)
              .value,
          contains('capacity.seat_utilisation v1'),
          reason: 'the figure\'s version is provenance, never hidden',
        );
        expect(doc.qualification, _en.biPrintPartial);
        expect(doc.management, isNotNull);
        final shown = biPrintDocument(fixtureSnapshot(), _words).sources;
        expect(shown.first, contains('capacity.seat_utilisation v1'));
      },
    );

    test(
      'lays the visuals out in the report\'s order, with what is left out said',
      () {
        final doc = biPrintDocument(fixtureSnapshot(), _words);
        final occupancy = doc.sections.first;
        expect(occupancy.newSheet, isFalse);
        expect((occupancy.blocks[0] as BiPrintFigure).value, '16.7%');
        final line = occupancy.blocks[1] as BiPrintTable;
        expect(line.rows.map((r) => r.first), [
          'July 2026',
          'August 2026',
          'September 2026',
        ]);
        expect(line.rows[2].sublist(1, 3), [
          '16.7%',
          '20 / 120',
        ], reason: 'the value and what it is made of, as the server gave it');
        expect(line.rows[1].last, _en.biPrintQualified);
        expect(
          (occupancy.blocks[2] as BiPrintText).text,
          'Seats are counted within opening hours.',
        );
        final money = doc.sections[1];
        expect(money.newSheet, isTrue);
        expect((money.blocks[0] as BiPrintFigure).value, '€1,234.56');
        final collected = money.blocks[1] as BiPrintTable;
        expect(collected.rows.map((r) => r[1]), [
          _en.biPrintUnknown,
          'CHF25.00',
          '-€10.00',
        ]);
        expect(collected.rows.first.last, _en.biPrintFailed);
        expect((money.blocks[2] as BiPrintFigure).note, _en.biPrintLeftOut);
        expect((money.blocks[3] as BiPrintFigure).value, '—');
      },
    );

    test('without page breaks every page flows on', () {
      final doc = biPrintDocument(
        fixtureSnapshot(
          report: fixtureReport(style: const BiPrintStyle(pageBreaks: false)),
        ),
        _words,
      );
      expect(doc.sections.every((s) => !s.newSheet), isTrue);
    });
  });

  group('the PDF', () {
    test(
      'prints the values the preview shows, on the layout\'s paper',
      () async {
        const style = BiPrintStyle(
          paper: 'Letter',
          orientation: 'landscape',
          margin: 'narrow',
          header: 'Board pack — confidential',
          footer: 'Prepared for the owners',
        );
        final snapshot = fixtureSnapshot(report: fixtureReport(style: style));
        final doc = biPrintDocument(snapshot, _words);
        final bytes = await _pdf(doc);
        final sizes = pdfPageSizes(bytes);
        expect(
          sizes,
          hasLength(2),
          reason: 'the money page starts its own sheet',
        );
        expect(sizes.first.width, closeTo(792, 0.5));
        expect(sizes.first.height, closeTo(612, 0.5));
        final pages = pdfPageLines(bytes);
        for (final page in pages) {
          expect(page, contains('Board pack — confidential'));
          expect(page, contains('Prepared for the owners'));
          expect(
            page,
            contains(fixtureHash.substring(0, 12)),
            reason: 'the source line on every sheet',
          );
        }
        final text = pages.join(' ');
        for (final figure in snapshot.figures.where((f) => f.value != null)) {
          expect(text, contains(biSnapshotValueText(figure, 'en')));
        }
        expect(text, contains('20 / 120'));
        expect(text, contains(_en.biPrintManagement));
        expect(text, contains('Page 1/2'));
      },
    );

    test('a long table runs over sheets with its headings, and keeps every row', () async {
      final rows = [
        for (var i = 0; i < 90; i++)
          [
            'Überbuchungsquote der Arbeitsplätze im Erdgeschoss, Monat ${i + 1}',
            '-1.234,${i.toString().padLeft(2, '0')} €',
            '',
            '',
          ],
      ];
      final doc = BiPrintDocument(
        style: const BiPrintStyle(),
        title: 'Langer Bericht',
        provenance: const [BiPrintLine('Arbeitsbereich', 'Café Zürich')],
        qualification: 'Teilweise Kopie',
        sources: const [],
        sections: [
          BiPrintSection(
            title: 'Seite 1',
            newSheet: false,
            blocks: [
              BiPrintTable(
                title: 'Tabelle',
                headings: const ['Zeitraum', 'Wert', 'Basis', 'Status'],
                rows: rows,
              ),
            ],
          ),
        ],
        sourceLine: 'Café Zürich · Langer Bericht',
      );
      final pages = pdfPageLines(await _pdf(doc));
      expect(pages.length, greaterThan(1));
      for (final page in pages) {
        expect(
          page,
          contains('Zeitraum Wert Basis Status'),
          reason: 'headings repeat on every sheet',
        );
        expect(
          page,
          contains('Café Zürich · Langer Bericht'),
          reason: 'the footer is never pushed off',
        );
      }
      final text = pages.join(' ');
      for (var i = 0; i < 90; i++) {
        expect(
          text,
          contains('-1.234,${i.toString().padLeft(2, '0')} €'),
          reason: 'row $i is printed whole',
        );
      }
      expect(text, contains('Überbuchungsquote'));
    });
  });

  test('print words come from the catalogue in every value', () {
    final fr = biPrintStringsOf(_en, 'fr', wall: (at) => at);
    final figure = fixtureSnapshot().figures.first;
    expect(
      fr.formats.value(figure),
      isNot(_words.formats.value(figure)),
      reason: 'the locale formats the number',
    );
    expect(_words.columns, [
      _en.biPrintColPeriod,
      _en.biPrintColValue,
      _en.biPrintColBasis,
      _en.biPrintColStatus,
    ]);
    expect(BiExportFormat.values.map((f) => f.name), ['pdf', 'csv', 'xlsx']);
  });
}
