// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2583 — the overview's own figures over Supabase (0536).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/kpi_contract.dart';
import '../domain/kpi_overview.dart';

class SupabaseOverviewKpiRepository implements OverviewKpiRepository {
  SupabaseOverviewKpiRepository(this._client);

  final SupabaseClient _client;

  static const _functions = {
    'people.active_memberships_current': 'kpi_memberships_current',
    'sales.overdue_receivables': 'kpi_overdue_receivables',
  };

  @override
  Future<OverviewFigure> figure(
    String workspaceId,
    String kpiId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final fn = _functions[kpiId];
    if (fn == null) throw KpiUnavailable('no reader for $kpiId');
    final Object? row;
    try {
      row = await _client.rpc<Object?>(
        fn,
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
    return overviewFigureFromJson(Map<String, Object?>.from(row! as Map));
  }
}
