// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A fixed analytical report and the server's answer to its export, for the
// snapshot, print, export and export-sheet tests: seat utilisation 20 of
// 120 seat hours, an invoiced amount in euros, collected amounts in two
// currencies with one month the server could not answer, a qualified
// (partial) month, a text card, a card this export does not answer and a
// card whose filter it cannot answer.
import 'package:deskilo/features/workspace/domain/bi_batch.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_report_snapshot.dart';

const fixtureWorkspace = 'ws-1';
const fixturePeriod = BiPeriod(BiGrain.month, 2026, 9);
final fixtureHash = 'ab12' * 16;

BiReportVisual _kpi(
  String id,
  String metric,
  int order, {
  List<BiReportFilter> filters = const [],
}) => BiReportVisual(
  id: id,
  type: BiVisualType.kpi,
  metricId: metric,
  filters: filters,
  layout: BiVisualLayout(order: order),
);

BiReportDefinition fixtureReport({
  BiPrintStyle style = const BiPrintStyle(),
  String moneyTitle = 'Money',
}) => BiReportDefinition(
  period: const BiReportPeriod.fixed(BiGrain.month, '2026-09'),
  printStyle: style,
  pages: [
    BiReportPage(
      id: 'p1',
      title: 'Occupancy',
      visuals: [
        _kpi('v1', 'capacity.seat_utilisation', 0),
        const BiReportVisual(
          id: 'v2',
          type: BiVisualType.line,
          metricId: 'capacity.seat_utilisation',
          layout: BiVisualLayout(order: 1),
        ),
        const BiReportVisual(
          id: 'v3',
          type: BiVisualType.text,
          text: 'Seats are counted within opening hours.',
          layout: BiVisualLayout(order: 2),
        ),
      ],
    ),
    BiReportPage(
      id: 'p2',
      title: moneyTitle,
      visuals: [
        _kpi('v4', 'finance.invoiced', 0),
        const BiReportVisual(
          id: 'v5',
          type: BiVisualType.table,
          metricId: 'finance.collected',
          layout: BiVisualLayout(order: 1),
        ),
        _kpi('v6', 'purchases.ap_outstanding', 2),
        _kpi(
          'v7',
          'capacity.seat_utilisation',
          3,
          filters: const [BiReportFilter('level', 'neq', 'l2')],
        ),
      ],
    ),
  ],
);

({DateTime from, DateTime to}) fixtureWindow(BiPeriod p) => (
  from: DateTime.utc(p.year, p.startMonth),
  to: DateTime.utc(p.year, p.startMonth + p.grain.months),
);

BiSnapshotPlan fixturePlan({BiReportDefinition? report, int limit = 60}) =>
    biSnapshotPlan(
      report ?? fixtureReport(),
      period: fixturePeriod,
      seriesLength: 3,
      window: fixtureWindow,
      limit: limit,
    );

const fixtureSource = BiSnapshotSource(
  workspaceId: fixtureWorkspace,
  workspaceName: 'Pézenas Coworking',
  reportName: 'Board pack',
  reportId: 'view-1',
  reportRevision: 4,
);

Map<String, Object?> _seat(
  num reserved,
  num offered, {
  List<String> quality = const [],
}) => {
  'seats': 5,
  'physical_seat_hours': offered,
  'offered_seat_hours': offered,
  'reserved_seat_hours': reserved,
  'reserved_outside_offered_seat_hours': 0,
  'overlapping_seat_hours': 0,
  'rooms_without_seats': 0,
  'offered_room_hours': 0,
  'reserved_room_hours': 0,
  'from': '2026-09-01T00:00:00Z',
  'to': '2026-10-01T00:00:00Z',
  'quality': quality,
  'reasons': <String>[],
  'computed_at': '2026-10-02T08:30:00Z',
};

Map<String, Object?> _money(
  String month, {
  int invoiced = 0,
  int collected = 0,
  String currency = 'EUR',
}) => {
  'from': month,
  'to': month,
  'currency': currency,
  'invoiced_minor': invoiced,
  'credit_notes_minor': 0,
  'collected_minor': collected,
  'invoices': 3,
  'matches': 2,
  'quality': <String>[],
  'reasons': <String>[],
  'computed_at': '2026-10-02T08:30:00Z',
};

/// The figure the server gives for [r], by metric and month; [shift] adds
/// to every amount (the data changed).
Map<String, Object?> _result(BiBatchRequestLike r, int shift) {
  final month = r.fromMonth ?? r.from!.toIso8601String().substring(0, 7);
  final meta = <String, Object?>{
    'request_key': r.key,
    'metric_id': r.metricId,
    'metric_version': 1,
    'unit': r.metricId == 'capacity.seat_utilisation'
        ? 'percent'
        : 'currency_minor',
    'date_basis': switch (r.metricId) {
      'capacity.seat_utilisation' => 'reservation_time',
      'finance.invoiced' => 'invoice_month',
      _ => 'payment_matched_at',
    },
    'coverage': r.metricId == 'capacity.seat_utilisation'
        ? 'recorded_history'
        : 'current_records',
  };
  if (r.metricId == 'capacity.seat_utilisation') {
    return {
      ...meta,
      'ok': true,
      'result': switch (month) {
        '2026-09' => _seat(20 + shift, 120),
        '2026-08' => _seat(30, 120, quality: ['partial']),
        _ => _seat(60, 120),
      },
    };
  }
  if (r.metricId == 'finance.collected' && month == '2026-07') {
    return {...meta, 'ok': false, 'code': '22023', 'message': 'not answered'};
  }
  return {
    ...meta,
    'ok': true,
    'result': r.metricId == 'finance.invoiced'
        ? _money(month, invoiced: 123456 + shift)
        : month == '2026-08'
        ? _money(month, collected: 2500, currency: 'CHF')
        : _money(month, collected: -1000 + shift),
  };
}

typedef BiBatchRequestLike = ({
  String key,
  String metricId,
  DateTime? from,
  String? fromMonth,
});

/// The answer of `bi_export_snapshot_v1` to [plan].
Map<String, Object?> fixtureAnswer(
  BiSnapshotPlan plan, {
  String workspaceId = fixtureWorkspace,
  BiExportFormat format = BiExportFormat.pdf,
  String? hash,
}) => fixtureAnswerOf(
  plan.requests,
  workspaceId: workspaceId,
  format: format,
  hash: hash,
);

/// The answer to [requests]; [shift] adds to every amount and to the
/// reserved seat hours of September (the data changed).
Map<String, Object?> fixtureAnswerOf(
  List<BiBatchRequest> requests, {
  String workspaceId = fixtureWorkspace,
  BiExportFormat format = BiExportFormat.pdf,
  String? hash,
  int shift = 0,
  String computedAt = '2026-10-02T08:30:00Z',
}) => {
  'computed_at': computedAt,
  'workspace_id': workspaceId,
  'format': format.name,
  'hash': hash ?? fixtureHash,
  'report_id': 'view-1',
  'report_revision': 4,
  'results': [
    for (final r in requests)
      _result((
        key: r.key,
        metricId: r.metricId,
        from: r.from,
        fromMonth: r.fromMonth,
      ), shift),
  ],
};

BiReportSnapshot fixtureSnapshot({
  BiReportDefinition? report,
  BiExportFormat format = BiExportFormat.pdf,
  int shift = 0,
}) {
  final plan = fixturePlan(report: report);
  return biReportSnapshotOf(
    plan,
    fixtureAnswerOf(plan.requests, format: format, shift: shift),
    source: fixtureSource,
    format: format,
  );
}
