// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1918 — the KPI reads, one definer RPC each. The server checks the
// permission and the flag; this class only asks.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../domain/bi_batch.dart';
import '../domain/kpi_contract.dart';
import '../domain/kpi_purchases.dart';

class SupabaseKpiRepository implements KpiRepository {
  SupabaseKpiRepository(this._client);

  final SupabaseClient _client;

  /// The same client, for the batch read beside the single-figure ones.
  SupabaseClient get client => _client;

  @override
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  }) async {
    final Object? row;
    try {
      row = await _client.rpc<dynamic>(
        'kpi_seat_capacity',
        params: {
          'p_workspace_id': workspaceId,
          'p_from': from.toUtc().toIso8601String(),
          'p_to': to.toUtc().toIso8601String(),
          'p_level_id': levelId,
        },
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the tile shows it.
      if (e.code == '42501') {
        Error.throwWithStackTrace(const KpiForbidden(), st);
      }
      rethrow;
    }
    return seatCapacityFromJson(Map<String, dynamic>.from(row as Map));
  }
}

/// #1924 — the finance KPIs, one definer RPC for both figures.
class SupabaseFinanceKpiRepository implements FinanceKpiRepository {
  SupabaseFinanceKpiRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<FinanceSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final Object? row;
    try {
      row = await _client.rpc<dynamic>(
        'kpi_finance_summary',
        params: {
          'p_workspace_id': workspaceId,
          'p_from': fromMonth,
          'p_to': toMonth,
        },
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the card shows it.
      if (e.code == '42501') {
        Error.throwWithStackTrace(const KpiForbidden(), st);
      }
      rethrow;
    }
    return financeSummaryFromJson(Map<String, dynamic>.from(row as Map));
  }
}

/// How a KPI read retries. A refusal, a missing source, a malformed
/// answer or any answer of the server itself is final: asking again
/// returns the same, and Riverpod's default (ten tries, up to 6.4 s
/// apart, again in every provider that watches this one) kept a BI card
/// loading for 76 s before it could say so. Only a transport failure is
/// tried again, twice and quickly.
Duration? kpiRetry(int retryCount, Object error) {
  if (retryCount >= 2) return null;
  return switch (error) {
    KpiUnavailable() || KpiForbidden() || FormatException() => null,
    PostgrestException() => null,
    _ => Duration(milliseconds: 200 << retryCount),
  };
}

/// #2578 — many figures in one call (`bi_query_batch_v1`, 0505): one
/// snapshot, each request answered on its own.
class SupabaseBiBatchReader implements KpiBatchReader {
  SupabaseBiBatchReader(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BiBatchEntry>> read(
    String workspaceId,
    List<BiBatchRequest> requests,
  ) async {
    if (requests.isEmpty) return const [];
    final Object? body;
    try {
      body = await _client.rpc<Object?>(
        'bi_query_batch_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_requests': [for (final r in requests) r.toJson()],
        },
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the card shows it.
      if (e.code == '42501') {
        Error.throwWithStackTrace(const KpiForbidden(), st);
      }
      rethrow;
    }
    final byKey = {
      for (final raw in JsonReader.of(body, context: 'bi batch').list('results'))
        JsonReader.of(raw).stringOr('request_key'): JsonReader.of(raw),
    };
    return [for (final r in requests) _entry(r, byKey[r.key])];
  }

  BiBatchEntry _entry(BiBatchRequest r, JsonReader? raw) {
    if (raw == null) return BiBatchEntry.failed(r.key, message: 'no answer');
    final result = raw.objectOrNull('result');
    if (!raw.boolOr('ok', fallback: false) || result == null) {
      return BiBatchEntry.failed(
        r.key,
        code: raw.stringOrNull('code'),
        message: raw.stringOrNull('message'),
      );
    }
    return r.metricId == 'capacity.seat_utilisation'
        ? BiBatchEntry.seat(r.key, seatCapacityFromJson(result.json))
        : BiBatchEntry.finance(r.key, financeSummaryFromJson(result.json));
  }
}

/// #2582 — the purchase figures (`kpi_purchases_summary`, 0527).
class SupabasePurchaseKpiRepository implements PurchaseKpiRepository {
  SupabasePurchaseKpiRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PurchaseSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final Object? row;
    try {
      row = await _client.rpc<Object?>(
        'kpi_purchases_summary',
        params: {
          'p_workspace_id': workspaceId,
          'p_from': fromMonth,
          'p_to': toMonth,
        },
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the card shows it.
      if (e.code == '42501') {
        Error.throwWithStackTrace(const KpiForbidden(), st);
      }
      rethrow;
    }
    return purchaseSummaryFromJson(Map<String, Object?>.from(row as Map));
  }
}
