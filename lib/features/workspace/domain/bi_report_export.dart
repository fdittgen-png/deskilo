// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A report snapshot as data: one row per figure with its metric id and
// version, its period, its exact value and unit, its currency, the
// numerator and denominator it is made of, its date basis, coverage and
// quality — and, apart, what the export is of (workspace, report and
// revision, period, filters, computation time, digest, qualification).
// The CSV writes the second above the first; the workbook gives each its
// own sheet. Values are the snapshot's own numbers, never formatted
// strings; every text cell goes through the one CSV cell writer, so a
// title that starts like a formula stays text.
//
// Column and key names are the file's stable contract (machine-readable),
// not prose. Pure Dart.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../core/files/xlsx.dart';
import '../../../core/text/csv.dart';
import 'bi_report_snapshot.dart';
import 'bi_result.dart';

/// The columns of the figures table.
@visibleForTesting
const biExportColumns = [
  'page',
  'page_title',
  'visual_id',
  'visual_type',
  'metric_id',
  'metric_title',
  'metric_version',
  'period',
  'from',
  'to',
  'value',
  'unit',
  'currency',
  'numerator',
  'denominator',
  'date_basis',
  'coverage',
  'quality',
  'status',
];

/// One row per figure, in the report's order; [metricTitle] names a metric
/// in the reader's language.
List<List<Object?>> _rows(
  BiReportSnapshot s,
  String Function(String metricId) metricTitle,
) => [
  biExportColumns,
  for (final v in s.visuals)
    for (final f in v.figures)
      [
        v.item.pageIndex + 1,
        v.item.page.title,
        v.item.visual.id,
        v.item.visual.type.name,
        f.metric.id,
        metricTitle(f.metric.id),
        f.metric.version,
        f.period.wire,
        biPeriodMonths(f.period).from,
        biPeriodMonths(f.period).to,
        f.value,
        f.metric.unit,
        _currency(f),
        _known(f)?.numerator,
        _known(f)?.denominator,
        f.metric.dateBasis.wire,
        f.metric.coverage.wire,
        (f.measure.quality.map((q) => q.name).toList()..sort()).join(' '),
        _status(f),
      ],
];

String? _currency(BiSnapshotFigure f) => f.currency.isEmpty ? null : f.currency;

/// The measure of a figure the server gave; null for a failed one.
BiMeasure? _known(BiSnapshotFigure f) => f.failure == null ? f.measure : null;

String _status(BiSnapshotFigure f) => switch (f) {
  BiSnapshotFigure(failure: final code?) => 'failed:$code',
  BiSnapshotFigure(qualified: true) => 'qualified',
  _ => 'ok',
};

String _qualification(BiReportSnapshot s) => s.partial ? 'partial' : 'complete';

String _scope(BiReportSnapshot s) => s.financial
    ? 'management_information_not_statutory_accounts'
    : 'operational';

/// What the export is of, as key/value rows.
List<List<Object?>> _about(BiReportSnapshot s) => [
  ['key', 'value'],
  ['source', 'bi_export_snapshot_v1'],
  ['workspace_id', s.source.workspaceId],
  ['workspace', s.source.workspaceName],
  ['report_id', s.source.reportId],
  ['report', s.source.reportName],
  ['report_revision', s.source.reportRevision],
  ['period', s.period.wire],
  ['grain', s.period.grain.name],
  [
    'filters',
    s.report.filters
        .map((f) => '${f.dimension} ${f.operator} ${f.value}')
        .join('; '),
  ],
  ['computed_at', s.computedAt.toUtc().toIso8601String()],
  ['snapshot_hash', s.hash],
  ['format', s.format.name],
  ['qualification', _qualification(s)],
  ['scope', _scope(s)],
  ['currencies', (s.currencies.toList()..sort()).join(' ')],
  ['metrics', s.metrics.map((m) => '${m.id}@${m.version}').join(' ')],
  [
    'left_out',
    s.plan.leftOut.map((l) => '${l.visual.id}:${l.reason.name}').join(' '),
  ],
];

/// The CSV: what it is of, a blank line, the figures. UTF-8 with a byte
/// order mark, so a spreadsheet reads accents as they are.
Uint8List biExportCsv(
  BiReportSnapshot s,
  String Function(String metricId) metricTitle,
) {
  String cell(Object? v) => switch (v) {
    null => '',
    num() => '$v',
    _ => csvCell('$v'),
  };
  String rows(List<List<Object?>> rows) =>
      rows.map((r) => r.map(cell).join(',')).join('\r\n');
  final text =
      '${rows(_about(s))}\r\n\r\n${rows(_rows(s, metricTitle))}\r\n';
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
}

/// The workbook: the figures and what they are of, each on its sheet, on
/// the existing XLSX writer (numbers stay number cells).
Uint8List biExportWorkbook(
  BiReportSnapshot s,
  String Function(String metricId) metricTitle,
) => buildXlsx([
  XlsxSheet(name: 'figures', rows: _rows(s, metricTitle)),
  XlsxSheet(name: 'about', rows: _about(s)),
]);

/// The file name: the workspace, the period and the digest, nothing else.
String biExportFileName(BiReportSnapshot s, String slug) {
  final ext = s.format.name;
  return '$slug-analytics-${s.period.wire}-${s.digest}.$ext';
}
