// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/trace/trace_logger.dart';
import '../domain/bi_batch.dart';
import '../domain/kpi_contract.dart';

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
  ) => Future.wait([for (final r in requests) _one(workspaceId, r)]);

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
        return BiBatchEntry.failed(
          r.key,
          code: '0A000',
          message: 'no finance reader',
        );
      }
      final k = await finance.summary(
        workspaceId,
        fromMonth: r.fromMonth!,
        toMonth: r.toMonth!,
      );
      return BiBatchEntry.finance(r.key, k);
    } on KpiForbidden {
      rethrow;
    } on KpiUnavailable catch (e, st) {
      TraceLogger.instance.error(
        'workspace',
        'a KPI request of a batch failed',
        error: e,
        stackTrace: st,
      );
      return BiBatchEntry.failed(r.key, message: e.reason);
    }
  }
}
