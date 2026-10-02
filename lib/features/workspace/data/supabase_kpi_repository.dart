// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1918 — the KPI reads, one definer RPC each. The server checks the
// permission and the flag; this class only asks.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/kpi_contract.dart';

class SupabaseKpiRepository implements KpiRepository {
  SupabaseKpiRepository(this._client);

  final SupabaseClient _client;

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
