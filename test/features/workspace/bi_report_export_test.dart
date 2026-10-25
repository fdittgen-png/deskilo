// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2581 — the data files of a snapshot. The CSV and the workbook carry the
// same exact numbers (a ratio's full value with its numerator and
// denominator, an amount in minor units with its own currency, an unknown
// as an empty cell and a failed status, never 0), the metric ids and
// versions, units, date basis and coverage, and what the export is of
// (workspace, report and revision, period, computation time, digest,
// qualification, what was left out). A title that starts like a formula
// stays text. The PDF prints the same figures: one snapshot, four copies.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/features/workspace/domain/bi_report_export.dart';
import 'package:deskilo/features/workspace/domain/bi_report_pdf.dart';
import 'package:deskilo/features/workspace/domain/bi_report_print.dart';
import 'package:deskilo/features/workspace/domain/bi_report_snapshot.dart';
import 'package:deskilo/features/workspace/presentation/bi_print_strings_l10n.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_print_preview.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/bi_report_fixture.dart';
import '../../helpers/pdf_text.dart';

String _title(String id) => 'T:$id';

String _csv(BiReportSnapshot s) {
  final bytes = biExportCsv(s, _title);
  expect(bytes.take(3), [
    0xEF,
    0xBB,
    0xBF,
  ], reason: 'UTF-8 with a byte order mark');
  return utf8.decode(bytes.sublist(3));
}

/// The cells of the workbook's sheet [n] (1-based), row by row: a number as
/// its literal, text as its text.
List<List<String>> _sheet(Uint8List xlsx, int n) {
  final archive = ZipDecoder().decodeBytes(xlsx);
  final xml = utf8.decode(
    archive.findFile('xl/worksheets/sheet$n.xml')!.content as List<int>,
  );
  expect(xml, isNot(contains('<f>')), reason: 'no cell is a formula');
  int column(String ref) =>
      ref.codeUnits.fold(0, (n, c) => n * 26 + c - 64) - 1;
  return [
    for (final row in RegExp(r'<row[^>]*>(.*?)</row>').allMatches(xml))
      () {
        final cells = <String>[];
        for (final c in RegExp(
          r'<c r="([A-Z]+)\d+"[^>]*>(.*?)</c>',
        ).allMatches(row.group(1)!)) {
          final at = column(c.group(1)!);
          while (cells.length < at) {
            cells.add('');
          }
          cells.add(
            RegExp(r'<(?:v|t[^>]*)>(.*?)</(?:v|t)>')
                    .firstMatch(c.group(2)!)
                    ?.group(1) ??
                '',
          );
        }
        return cells;
      }(),
  ];
}

void main() {
  setUpAll(initializeDateFormatting);

  test('the CSV says what it is of, then every figure exactly', () {
    final s = fixtureSnapshot(format: BiExportFormat.csv);
    final csv = _csv(s);
    final about = csv.split('\r\n\r\n').first;
    expect(about, contains('"snapshot_hash","$fixtureHash"'));
    expect(about, contains('"computed_at","2026-10-02T08:30:00.000Z"'));
    expect(about, contains('"report_revision",4'));
    expect(about, contains('"qualification","partial"'));
    expect(
      about,
      contains('"scope","management_information_not_statutory_accounts"'),
    );
    expect(about, contains('"currencies","CHF EUR"'));
    expect(
      about,
      contains('"left_out","v6:notExportable v7:unsupportedScope"'),
    );
    expect(about, contains('capacity.seat_utilisation@1'));
    final rows = csv.split('\r\n\r\n').last.trim().split('\r\n');
    expect(rows.first, biExportColumns.map((c) => '"$c"').join(','));
    final card = rows[1];
    expect(
      card,
      contains(
        ',${20 / 120},"percent",,20.0,120.0,"reservation_time","recorded_history"',
      ),
    );
    expect(
      rows.where((r) => r.contains('"finance.invoiced"')).single,
      contains(',123456,"currency_minor","EUR",123456,,'),
    );
    expect(
      rows.where((r) => r.contains('"CHF"')).single,
      contains(',2500,"currency_minor","CHF",'),
    );
    final failed = rows.where((r) => r.contains('"failed:22023"')).single;
    expect(
      failed,
      contains(',,"currency_minor",,,,'),
      reason: 'unknown is empty, never 0',
    );
  });

  test('a title that starts like a formula stays text', () {
    final s = fixtureSnapshot(
      format: BiExportFormat.csv,
      report: fixtureReport(moneyTitle: '=HYPERLINK("http://x","y")'),
    );
    final csv = _csv(s);
    expect(csv, contains('"\'=HYPERLINK(""http://x"",""y"")"'));
    expect(csv, isNot(contains(',=HYPERLINK')));
    expect(csv, isNot(contains(',"=HYPERLINK')));
  });

  test('the workbook holds the same numbers as number cells', () {
    final s = fixtureSnapshot(format: BiExportFormat.xlsx);
    final xlsx = biExportWorkbook(s, _title);
    final figures = _sheet(xlsx, 1);
    final about = _sheet(xlsx, 2);
    expect(figures.first, biExportColumns);
    final valueAt = biExportColumns.indexOf('value');
    final csvRows = _csv(s)
        .split('\r\n\r\n')
        .last
        .trim()
        .split('\r\n')
        .skip(1)
        .toList();
    expect(figures.length - 1, csvRows.length);
    for (final (i, row) in figures.skip(1).indexed) {
      final f = s.figures.elementAt(i);
      expect(
        row.length > valueAt ? row[valueAt] : '',
        f.value == null ? '' : '${f.value}',
        reason: 'row $i',
      );
    }
    expect(
      {
        for (final r in about.skip(1)) r.first: r.length > 1 ? r[1] : '',
      }['snapshot_hash'],
      fixtureHash,
    );
  });

  testWidgets('preview, PDF, CSV and workbook show the same figures', (
    tester,
  ) async {
    final s = fixtureSnapshot();
    final words = biPrintStringsOf(AppLocalizationsEn(), 'en', wall: (at) => at);
    final doc = biPrintDocument(s, words);
    pw.Font font(String n) => pw.Font.ttf(
      ByteData.sublistView(
        File('assets/fonts/Roboto-$n.ttf').readAsBytesSync(),
      ),
    );
    final bytes = await tester.runAsync(
      () => buildBiPrintPdf(
        doc,
        fonts: (base: font('Regular'), bold: font('Bold')),
        pageLabel: 'Page',
      ),
    );
    final pdf = pdfPageLines(bytes!).join(' ');
    // The preview as it is drawn: every run of text on the sheet.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: BiPrintPreview(document: doc)),
        ),
      ),
    );
    final preview = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((t) => t.text.toPlainText())
        .join(' ');
    final csv = _csv(s);
    for (final f in s.figures.where((f) => f.value != null)) {
      final shown = biSnapshotValueText(f, 'en');
      expect(preview, contains(shown));
      expect(pdf, contains(shown));
      expect(csv, contains(',${f.value},'));
    }
  });

  test('the file is named by workspace, period and digest only', () {
    final s = fixtureSnapshot(format: BiExportFormat.xlsx);
    expect(
      biExportFileName(s, 'pezenas'),
      'pezenas-analytics-2026-09-${fixtureHash.substring(0, 12)}.xlsx',
    );
  });
}
