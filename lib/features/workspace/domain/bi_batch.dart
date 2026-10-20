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

  /// What is asked, without the caller's handle: two requests with the same
  /// identity are the same figure (#2578 coordinator).
  String get identity => [
    metricId,
    from?.toUtc().toIso8601String(),
    to?.toUtc().toIso8601String(),
    levelId,
    fromMonth,
    toMonth,
  ].join('|');

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

  const BiBatchEntry._(
    this.key,
    this.seatCapacity,
    this.financeSummary,
    this.code,
    this.message,
  );

  final String key;
  final SeatCapacityKpi? seatCapacity;
  final FinanceSummaryKpi? financeSummary;

  /// The SQLSTATE of the failure (`22023` bad request, `0A000` unsupported).
  final String? code;
  final String? message;

  bool get ok => seatCapacity != null || financeSummary != null;

  /// The same answer under another caller's handle.
  BiBatchEntry withKey(String other) => BiBatchEntry._(
    other,
    seatCapacity,
    financeSummary,
    code,
    message,
  );

  /// The failure the single-figure read would have thrown.
  KpiUnavailable toError() => KpiUnavailable(message ?? code ?? 'unavailable');
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
