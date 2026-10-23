// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The workspace data report as a PDF: a cover, the contents, then one
// section per part, each starting on its own page. The registers (invoices,
// payments and balances, purchases) are printed across the sheet; every
// table repeats its header on each page and ends on a bold totals row;
// every page carries "Page n/m". Pure Dart: the words and formats arrive in
// [WorkspaceDataReportStrings], the plan pictures as PNG bytes.
import 'dart:typed_data';

import 'package:deskilo_document_pdf/report_page_footer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../money/domain/invoice_pdf.dart' show watermarkForeground;
import 'workspace_data_report.dart';

/// The words and formats the report is printed in.
class WorkspaceDataReportStrings {
  const WorkspaceDataReportStrings({
    required this.title,
    required this.contents,
    required this.workspace,
    required this.period,
    required this.generatedOn,
    required this.timeZone,
    required this.currency,
    required this.total,
    required this.none,
    required this.yes,
    required this.no,
    required this.pageLabel,
    required this.part,
    required this.table,
    required this.column,
    required this.word,
    required this.role,
    required this.wholeLevel,
    required this.money,
    required this.day,
    required this.month,
    required this.number,
  });

  final String title;
  final String contents;

  /// The cover's labels.
  final String workspace;
  final String period;
  final String generatedOn;
  final String timeZone;
  final String currency;

  /// The first cell of a totals row; the line of an empty table.
  final String total;
  final String none;
  final String yes;
  final String no;
  final String pageLabel;

  /// A section's title, a table's title and a column's header by key.
  final String Function(DataReportPart part) part;
  final String Function(String key) table;
  final String Function(String key) column;

  /// A stored word (a status, a kind) and a role key, in the reader's words.
  final String Function(String key) word;
  final String Function(String key) role;

  /// The line under a level bookable as a whole, its price formatted.
  final String Function(String price) wholeLevel;

  final String Function(int cents) money;
  final String Function(DateTime day) day;
  final String Function(DateTime month) month;

  /// A count or a number of hours.
  final String Function(num value) number;
}

/// Everything the PDF is drawn from.
class WorkspaceDataReportPdfRequest {
  const WorkspaceDataReportPdfRequest({
    required this.report,
    required this.strings,
    required this.generatedAt,
    required this.baseFont,
    required this.boldFont,
    this.planImages = const {},
    this.watermark = '',
  });

  final WorkspaceDataReport report;
  final WorkspaceDataReportStrings strings;
  final DateTime generatedAt;
  final pw.Font baseFont;
  final pw.Font boldFont;

  /// Level id → the plan drawn as a PNG.
  final Map<String, Uint8List> planImages;
  final String watermark;
}

const _margin = pw.EdgeInsets.fromLTRB(40, 40, 40, 36);
const _muted = PdfColors.grey700;
const _headerFill = PdfColors.grey200;
const _cellPadding = pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3);

Future<Uint8List> buildWorkspaceDataReportPdf(
  WorkspaceDataReportPdfRequest request,
) async {
  final s = request.strings;
  final document = pw.Document(title: s.title);
  pw.PageTheme theme(PdfPageFormat format) => pw.PageTheme(
    pageFormat: format,
    margin: _margin,
    theme: pw.ThemeData.withFont(
      base: request.baseFont,
      bold: request.boldFont,
    ).copyWith(defaultTextStyle: const pw.TextStyle(fontSize: 9)),
    buildForeground: watermarkForeground(request.watermark),
  );
  pw.Widget footer(pw.Context context) => reportPageFooter(
    context,
    content: const [],
    pageLabel: s.pageLabel,
    numberFirstPage: true,
  );

  document.addPage(
    pw.Page(
      pageTheme: theme(PdfPageFormat.a4),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [..._cover(request), pw.Spacer(), footer(context)],
      ),
    ),
  );
  for (final section in request.report.sections) {
    document.addPage(
      pw.MultiPage(
        pageTheme: theme(
          section.part.landscape
              ? PdfPageFormat.a4.landscape
              : PdfPageFormat.a4,
        ),
        footer: footer,
        build: (context) => [
          pw.Header(text: s.part(section.part)),
          for (final table in section.tables)
            ..._titledTable(s, table, titled: section.tables.length > 1),
          for (final level in section.levels) ..._level(request, level),
        ],
      ),
    );
  }
  // The contents are drawn last, once every heading has its page, and
  // placed right after the cover.
  document.addPage(
    pw.Page(
      pageTheme: theme(PdfPageFormat.a4),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Header(level: 0, child: pw.Text(s.contents)),
          pw.TableOfContent(),
          pw.Spacer(),
          footer(context),
        ],
      ),
    ),
    index: 1,
  );
  return document.save();
}

List<pw.Widget> _cover(WorkspaceDataReportPdfRequest request) {
  final s = request.strings;
  final r = request.report;
  final period = switch ((r.from, r.to)) {
    (final from?, final to?) => '${s.day(from)} – ${s.day(to)}',
    _ => s.none,
  };
  pw.Widget line(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 140,
          child: pw.Text(label, style: const pw.TextStyle(color: _muted)),
        ),
        pw.Expanded(child: pw.Text(value)),
      ],
    ),
  );
  return [
    pw.SizedBox(height: 120),
    pw.Text(
      s.title,
      style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 8),
    pw.Text(r.workspaceName, style: const pw.TextStyle(fontSize: 16)),
    pw.SizedBox(height: 32),
    line(s.workspace, r.workspaceName),
    line(s.period, period),
    line(s.generatedOn, s.day(request.generatedAt)),
    line(s.timeZone, r.timeZone),
    line(s.currency, r.currency),
  ];
}

/// A table under its own title when its section holds more than one.
List<pw.Widget> _titledTable(
  WorkspaceDataReportStrings s,
  DataReportTable table, {
  required bool titled,
}) => [
  if (titled) pw.Header(level: 2, text: s.table(table.key)),
  _table(s, table),
  pw.SizedBox(height: 12),
];

List<pw.Widget> _level(
  WorkspaceDataReportPdfRequest request,
  DataReportLevel level,
) {
  final s = request.strings;
  final image = request.planImages[level.levelId];
  return [
    pw.Header(level: 2, text: level.name),
    if (level.wholePriceCents case final cents?)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(s.wholeLevel(cents == 0 ? '' : s.money(cents))),
      ),
    if (image != null)
      pw.Container(
        height: 300,
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Image(pw.MemoryImage(image)),
      ),
    _table(s, level.table),
    pw.SizedBox(height: 12),
  ];
}

bool _numeric(DataReportCell kind) => switch (kind) {
  DataReportCell.money ||
  DataReportCell.count ||
  DataReportCell.hours ||
  DataReportCell.percent => true,
  _ => false,
};

String _cell(WorkspaceDataReportStrings s, DataReportCell kind, Object? v) =>
    switch (v) {
      null => '',
      final int cents when kind == DataReportCell.money => s.money(cents),
      final int pct when kind == DataReportCell.percent => '${s.number(pct)} %',
      final num n => s.number(n),
      final bool b => b ? s.yes : s.no,
      final DateTime m when kind == DataReportCell.month => s.month(m),
      final DateTime d => s.day(d),
      final String w when kind == DataReportCell.word && w.isNotEmpty => s.word(
        w,
      ),
      final String r when kind == DataReportCell.role => s.role(r),
      _ => '$v',
    };

/// A table whose header row repeats on every page it runs onto, and whose
/// totals row is bold under a rule.
pw.Widget _table(WorkspaceDataReportStrings s, DataReportTable table) {
  if (table.rows.isEmpty) {
    return pw.Text(s.none, style: const pw.TextStyle(color: _muted));
  }
  final align = [
    for (final c in table.columns)
      if (_numeric(c.kind))
        pw.Alignment.centerRight
      else
        pw.Alignment.centerLeft,
  ];
  pw.Widget text(String value, int i, {bool bold = false}) => pw.Container(
    padding: _cellPadding,
    alignment: align[i],
    child: pw.Text(
      value,
      style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
    ),
  );
  final totals = table.totals;
  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
    ),
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _headerFill),
        children: [
          for (final (i, c) in table.columns.indexed)
            text(s.column(c.key), i, bold: true),
        ],
      ),
      for (final row in table.rows)
        pw.TableRow(
          children: [
            for (final (i, c) in table.columns.indexed)
              text(_cell(s, c.kind, row[i]), i),
          ],
        ),
      if (totals != null)
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide()),
          ),
          children: [
            for (final (i, c) in table.columns.indexed)
              text(
                i == 0 && totals[i] == null
                    ? s.total
                    : _cell(s, c.kind, totals[i]),
                i,
                bold: true,
              ),
          ],
        ),
    ],
  );
}
