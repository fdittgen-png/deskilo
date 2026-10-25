// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One frozen answer behind every printed and exported copy of a report. The
// report is planned into figure requests ([biSnapshotPlan]); the server
// answers them once, under the reader's current rights and their right to
// export (`bi_export_snapshot_v1`); [biReportSnapshotOf] types that answer.
// The preview, the PDF, the CSV and the workbook all read THIS value, so the
// four cannot disagree and none of them asks the server a second time.
//
// A figure that could not be given is a failure of that figure, never a
// zero; a visual this export cannot answer is listed as left out, never
// approximated; each amount keeps its own currency.
//
// Pure Dart.
library;

import '../../../core/data/json_reader.dart';
import 'bi_batch.dart';
import 'bi_query.dart';
import 'bi_report_definition.dart';
import 'bi_report_edit.dart';
import 'bi_result.dart';
import 'kpi_contract.dart';

/// The files a snapshot may become.
enum BiExportFormat {
  pdf,
  csv,
  xlsx;

  static BiExportFormat? fromWire(Object? v) =>
      values.where((f) => f.name == v).firstOrNull;
}

/// Why a visual of the report is not in an export.
enum BiLeftOutReason {
  /// The figure is not one this export answers yet.
  notExportable,

  /// Its filters or grouping are not ones this export answers; the total
  /// is never printed in place of the narrower figure.
  unsupportedScope,
}

/// How one export failed, as the person can act on it.
enum BiExportFailure {
  /// The reader may not export these figures (exportData, a figure's
  /// rights, another workspace, a report they cannot read).
  forbidden,

  /// Exporting is switched off in this workspace, or the format is.
  off,

  /// More figures than one export may carry: narrow the report.
  tooLarge,

  /// The report changed since it was opened.
  stale,

  /// Nothing in the report can be exported.
  empty,

  /// The request was malformed or the answer did not hold together.
  invalid,

  /// The server could not be reached or did not answer.
  unavailable,
}

class BiExportRefused implements Exception {
  const BiExportRefused(this.failure);
  final BiExportFailure failure;

  @override
  String toString() => 'BiExportRefused(${failure.name})';
}

/// The figure metrics this export answers: the ones the batch answers.
const _exportable = {
  'capacity.seat_utilisation',
  'finance.invoiced',
  'finance.collected',
};

/// A visual of the report with the periods it shows.
class BiSnapshotItem {
  const BiSnapshotItem({
    required this.pageIndex,
    required this.page,
    required this.visual,
    required this.periods,
    required this.keys,
    this.levelId,
  });

  final int pageIndex;
  final BiReportPage page;
  final BiReportVisual visual;

  /// Oldest first; one for a figure card, the evolution for a chart or a
  /// table.
  final List<BiPeriod> periods;

  /// The request key of each period, in [periods] order.
  final List<String> keys;
  final String? levelId;
}

class BiLeftOut {
  const BiLeftOut(this.page, this.visual, this.reason);
  final BiReportPage page;
  final BiReportVisual visual;
  final BiLeftOutReason reason;
}

/// What an export of a report asks.
class BiSnapshotPlan {
  const BiSnapshotPlan({
    required this.report,
    required this.period,
    required this.items,
    required this.texts,
    required this.leftOut,
    required this.requests,
  });

  final BiReportDefinition report;
  final BiPeriod period;
  final List<BiSnapshotItem> items;

  /// The text visuals, printed as they are.
  final List<({int pageIndex, BiReportVisual visual})> texts;
  final List<BiLeftOut> leftOut;

  /// Every distinct figure, once.
  final List<BiBatchRequest> requests;
}

/// `[from, to)` of a period on the workspace clock.
typedef BiWindow = ({DateTime from, DateTime to}) Function(BiPeriod period);

/// The requests of [report] for [period]: a figure card asks the period, a
/// chart or a table its last [seriesLength] periods. A figure asked by two
/// visuals is asked once. Refuses ([BiExportFailure.tooLarge]) a report
/// asking more than [limit] figures, and ([BiExportFailure.empty]) one with
/// nothing to export.
BiSnapshotPlan biSnapshotPlan(
  BiReportDefinition report, {
  required BiPeriod period,
  required int seriesLength,
  required BiWindow window,
  required int limit,
}) {
  final items = <BiSnapshotItem>[];
  final texts = <({int pageIndex, BiReportVisual visual})>[];
  final leftOut = <BiLeftOut>[];
  final keyOf = <String, String>{};
  final requests = <BiBatchRequest>[];
  String ask(String metricId, BiPeriod p, String? levelId) {
    final r = _request('r${requests.length}', metricId, p, levelId, window);
    final known = keyOf[r.identity];
    if (known != null) return known;
    requests.add(r);
    return keyOf[r.identity] = r.key;
  }

  for (final (pageIndex, page) in report.pages.indexed) {
    for (final visual in biVisualsInOrder(page.visuals)) {
      switch (_classify(report, page, visual)) {
        case null:
          texts.add((pageIndex: pageIndex, visual: visual));
        case final BiLeftOutReason reason:
          leftOut.add(BiLeftOut(page, visual, reason));
        case (metricId: final String metricId, levelId: final String? levelId):
          final count = visual.type == BiVisualType.kpi ? 1 : seriesLength;
          final periods = [
            for (var i = count - 1; i >= 0; i--) period.shift(-i),
          ];
          items.add(
            BiSnapshotItem(
              pageIndex: pageIndex,
              page: page,
              visual: visual,
              periods: periods,
              keys: [for (final p in periods) ask(metricId, p, levelId)],
              levelId: levelId,
            ),
          );
      }
    }
  }
  if (items.isEmpty) throw const BiExportRefused(BiExportFailure.empty);
  if (requests.length > limit) {
    throw const BiExportRefused(BiExportFailure.tooLarge);
  }
  return BiSnapshotPlan(
    report: report,
    period: period,
    items: items,
    texts: texts,
    leftOut: leftOut,
    requests: requests,
  );
}

/// What [visual] is to an export: a text (null), a card left out and why,
/// or the figure it asks with the level it is narrowed to.
Object? _classify(
  BiReportDefinition report,
  BiReportPage page,
  BiReportVisual visual,
) {
  final metricId = visual.metricId;
  if (visual.type == BiVisualType.text || metricId == null) return null;
  if (!_exportable.contains(metricId)) return BiLeftOutReason.notExportable;
  final scope = report.scopeOf(page, visual);
  final level = scope == null || visual.dimension != null
      ? null
      : _levelOf(metricId, scope);
  if (level == null) return BiLeftOutReason.unsupportedScope;
  return (metricId: metricId, levelId: level.isEmpty ? null : level);
}

/// The level a capacity figure is narrowed to ('' for the whole space), or
/// null when [scope] is not one the figure can answer: only one level, and
/// only for the capacity figure.
String? _levelOf(String metricId, List<BiReportFilter> scope) {
  if (scope.isEmpty) return '';
  if (metricId != 'capacity.seat_utilisation') return null;
  final levels = {
    for (final f in scope)
      if (f.dimension == 'level' && f.operator == 'eq') f.value else '',
  };
  return levels.length == 1 && levels.single.isNotEmpty ? levels.single : null;
}

BiBatchRequest _request(
  String key,
  String metricId,
  BiPeriod p,
  String? levelId,
  BiWindow window,
) {
  if (metricId == 'capacity.seat_utilisation') {
    final w = window(p);
    return BiBatchRequest.capacity(
      key: key,
      from: w.from,
      to: w.to,
      levelId: levelId,
    );
  }
  final months = biPeriodMonths(p);
  return BiBatchRequest.finance(
    key: key,
    metricId: metricId,
    fromMonth: months.from,
    toMonth: months.to,
  );
}

/// The whole months of [p], `YYYY-MM` first and last (#1924).
({String from, String to}) biPeriodMonths(BiPeriod p) {
  String m(int month) => '${p.year}-${month.toString().padLeft(2, '0')}';
  return (from: m(p.startMonth), to: m(p.startMonth + p.grain.months - 1));
}

/// One figure of the snapshot, exactly as the server gave it.
class BiSnapshotFigure {
  const BiSnapshotFigure({
    required this.metric,
    required this.period,
    required this.measure,
    this.currency = '',
    this.failure,
  });

  final KpiDefinition metric;
  final BiPeriod period;

  /// Numerator, denominator, quality and reasons; [value] derives from it
  /// by the metric's own aggregation, exactly as the dashboard does.
  final BiMeasure measure;

  /// The currency of an amount ('' for a ratio).
  final String currency;

  /// The SQLSTATE (or `incompatible`) of a figure the server could not
  /// give; its value is null, never 0.
  final String? failure;

  num? get value => failure != null ? null : measure.value(metric.aggregation);

  /// Measured but qualified: part of the period not covered, or stale.
  bool get qualified =>
      measure.quality.contains(KpiQuality.partial) ||
      measure.quality.contains(KpiQuality.stale);
}

/// A visual with its figures, in its report's order.
class BiSnapshotVisual {
  const BiSnapshotVisual({required this.item, required this.figures});
  final BiSnapshotItem item;

  /// One per period of [item], oldest first.
  final List<BiSnapshotFigure> figures;
}

/// Who and what the snapshot is of: everything the printout names.
class BiSnapshotSource {
  const BiSnapshotSource({
    required this.workspaceId,
    required this.workspaceName,
    required this.reportName,
    this.reportId,
    this.reportRevision,
  });

  final String workspaceId;
  final String workspaceName;
  final String reportName;

  /// The saved report's id and revision; null for an unsaved analysis.
  final String? reportId;
  final int? reportRevision;
}

/// The frozen answer every copy of one export is made from.
class BiReportSnapshot {
  const BiReportSnapshot({
    required this.source,
    required this.plan,
    required this.format,
    required this.computedAt,
    required this.hash,
    required this.visuals,
  });

  final BiSnapshotSource source;
  final BiSnapshotPlan plan;
  final BiExportFormat format;

  /// When the server computed the figures (one statement, one snapshot).
  final DateTime computedAt;

  /// The server's digest of the figures it gave.
  final String hash;
  final List<BiSnapshotVisual> visuals;

  BiReportDefinition get report => plan.report;
  BiPeriod get period => plan.period;

  Iterable<BiSnapshotFigure> get figures => visuals.expand((v) => v.figures);

  /// Not every figure is known and whole: a failure, an unknown or a
  /// qualified figure, or a visual left out. A partial export never
  /// claims to be complete, whatever the print layout says.
  bool get partial =>
      plan.leftOut.isNotEmpty ||
      figures.any((f) => f.value == null || f.qualified);

  /// Holds an amount: a management figure, not statutory accounts.
  bool get financial =>
      figures.any((f) => f.metric.disclosure == KpiDisclosure.financial);

  /// The currencies of the amounts, each kept apart.
  Set<String> get currencies => {
    for (final f in figures)
      if (f.currency.isNotEmpty) f.currency,
  };

  /// The metrics the snapshot holds, once each, in reading order.
  List<KpiDefinition> get metrics =>
      {for (final f in figures) f.metric.id: f.metric}.values.toList();
}

/// The answer of `bi_export_snapshot_v1` for [plan], typed. An answer about
/// another workspace, or without a time or digest, is refused, never shown;
/// an answer the plan did not ask is ignored, a request it does not answer
/// is that figure's failure.
BiReportSnapshot biReportSnapshotOf(
  BiSnapshotPlan plan,
  Object? answer, {
  required BiSnapshotSource source,
  required BiExportFormat format,
}) {
  final reader = JsonReader.of(answer, context: 'bi export');
  final computedAt = DateTime.tryParse(reader.stringOr('computed_at'));
  final hash = reader.stringOr('hash');
  if (reader.stringOr('workspace_id') != source.workspaceId ||
      computedAt == null ||
      hash.isEmpty ||
      reader.stringOr('format') != format.name) {
    throw const BiExportRefused(BiExportFailure.invalid);
  }
  final byKey = <String, Map<String, Object?>>{
    for (final raw in reader.list('results'))
      JsonReader.of(raw).stringOr('request_key'): JsonReader.of(raw).json,
  };
  final requests = {for (final r in plan.requests) r.key: r};
  BiSnapshotFigure figure(String key, BiPeriod p) => _figure(
    biBatchEntryFromJson(requests[key]!, byKey[key]),
    requests[key]!,
    p,
  );
  return BiReportSnapshot(
    source: source,
    plan: plan,
    format: format,
    computedAt: computedAt,
    hash: hash,
    visuals: [
      for (final item in plan.items)
        BiSnapshotVisual(
          item: item,
          figures: [
            for (final (i, p) in item.periods.indexed) figure(item.keys[i], p),
          ],
        ),
    ],
  );
}

BiSnapshotFigure _figure(BiBatchEntry e, BiBatchRequest r, BiPeriod p) {
  final metric = kpiDefinitionOf(r.metricId)!;
  final seat = e.seatCapacity;
  final money = e.financeSummary;
  if (seat != null) {
    return BiSnapshotFigure(
      metric: metric,
      period: p,
      measure: biSeatMeasure(seat),
    );
  }
  if (money != null) {
    return BiSnapshotFigure(
      metric: metric,
      period: p,
      measure: biFinanceMeasure(money, r.metricId),
      currency: money.currency,
    );
  }
  return BiSnapshotFigure(
    metric: metric,
    period: p,
    measure: const BiMeasure(numerator: 0, quality: {KpiQuality.unavailable}),
    failure: e.code ?? 'unavailable',
  );
}

/// The export read (`bi_export_snapshot_v1`): the server checks the right
/// to export and every figure's own rights, then answers the figures of one
/// snapshot. Throws [BiExportRefused].
abstract interface class BiExportRepository {
  Future<Object?> snapshot(
    String workspaceId, {
    required List<BiBatchRequest> requests,
    required BiExportFormat format,
    String? reportId,
    int? reportRevision,
  });
}

/// No server to export from (the demonstration).
class UnavailableBiExportRepository implements BiExportRepository {
  const UnavailableBiExportRepository();

  @override
  Future<Object?> snapshot(
    String workspaceId, {
    required List<BiBatchRequest> requests,
    required BiExportFormat format,
    String? reportId,
    int? reportRevision,
  }) async => throw const BiExportRefused(BiExportFailure.unavailable);
}
