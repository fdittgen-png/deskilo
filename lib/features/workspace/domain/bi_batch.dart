// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 (C1) — many KPI figures in one read. A card asked the server one
// figure per period and per group; the batch asks them together, on one
// snapshot, and answers each on its own: one that fails does not blank the
// others, and a refusal of the reader refuses the lot (KpiForbidden).
//
// Pure Dart.
library;

import 'kpi_contract.dart';

/// One figure asked for. A capacity figure has a window `[from, to)` and an
/// optional level; a finance figure has whole months, both inclusive.
class BiBatchRequest {
  const BiBatchRequest.capacity({
    required this.key,
    required DateTime this.from,
    required DateTime this.to,
    this.levelId,
  }) : metricId = 'capacity.seat_utilisation',
       fromMonth = null,
       toMonth = null;

  const BiBatchRequest.finance({
    required this.key,
    required this.metricId,
    required String this.fromMonth,
    required String this.toMonth,
  }) : from = null,
       to = null,
       levelId = null;

  /// The caller's own handle, echoed in the answer.
  final String key;
  final String metricId;
  final DateTime? from;
  final DateTime? to;
  final String? levelId;
  final String? fromMonth;
  final String? toMonth;

  Map<String, Object?> toJson() => {
    'request_key': key,
    'metric_id': metricId,
    if (from != null) 'from': from!.toUtc().toIso8601String(),
    if (to != null) 'to': to!.toUtc().toIso8601String(),
    if (levelId != null) 'level_id': levelId,
    if (fromMonth != null) 'from_month': fromMonth,
    if (toMonth != null) 'to_month': toMonth,
  };
}

/// The answer to one request: the figure, or why it could not be given.
class BiBatchEntry {
  const BiBatchEntry.seat(this.key, SeatCapacityKpi this.seatCapacity)
    : financeSummary = null,
      code = null,
      message = null;

  const BiBatchEntry.finance(this.key, FinanceSummaryKpi this.financeSummary)
    : seatCapacity = null,
      code = null,
      message = null;

  const BiBatchEntry.failed(this.key, {this.code, this.message})
    : seatCapacity = null,
      financeSummary = null;

  final String key;
  final SeatCapacityKpi? seatCapacity;
  final FinanceSummaryKpi? financeSummary;

  /// The SQLSTATE of the failure (`22023` bad request, `0A000` unsupported).
  final String? code;
  final String? message;

  bool get ok => seatCapacity != null || financeSummary != null;

  /// The exception the single-figure read would have thrown.
  Exception toException() => KpiUnavailable(message ?? code ?? 'unavailable');
}

/// Reads a batch. The server answers it in one call; a fan-out stands in
/// where the single-figure repositories are all there is (tests, the demo).
abstract class KpiBatchReader {
  /// One entry per request, in order. Throws [KpiForbidden] when the reader
  /// may not see these figures here.
  Future<List<BiBatchEntry>> read(
    String workspaceId,
    List<BiBatchRequest> requests,
  );
}

/// The batch for readers that only know one figure at a time: each request
/// is asked on its own, a failure is that request's alone, a refusal refuses
/// the batch. No snapshot guarantee — only the server's batch has one.
class FanOutBatchReader implements KpiBatchReader {
  const FanOutBatchReader(this._seat, [this._finance]);

  final KpiRepository _seat;
  final FinanceKpiRepository? _finance;

  @override
  Future<List<BiBatchEntry>> read(
    String workspaceId,
    List<BiBatchRequest> requests,
  ) => Future.wait([
    for (final r in requests) _one(workspaceId, r),
  ]);

  Future<BiBatchEntry> _one(String workspaceId, BiBatchRequest r) async {
    try {
      if (r.metricId == 'capacity.seat_utilisation') {
        final k = await _seat.seatCapacity(
          workspaceId,
          from: r.from!,
          to: r.to!,
          levelId: r.levelId,
        );
        return BiBatchEntry.seat(r.key, k);
      }
      final finance = _finance;
      if (finance == null) {
        return BiBatchEntry.failed(r.key, code: '0A000', message: 'no finance reader');
      }
      final k = await finance.summary(
        workspaceId,
        fromMonth: r.fromMonth!,
        toMonth: r.toMonth!,
      );
      return BiBatchEntry.finance(r.key, k);
    } on KpiForbidden {
      rethrow;
    } on KpiUnavailable catch (e) {
      return BiBatchEntry.failed(r.key, message: e.reason);
    }
  }
}
