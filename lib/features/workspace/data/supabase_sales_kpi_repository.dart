// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 3 — the sales figures over Supabase (`kpi_sales_quality`, 0674).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/kpi_contract.dart';
import '../domain/kpi_sales.dart';

class SupabaseSalesKpiRepository implements SalesKpiRepository {
  SupabaseSalesKpiRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SalesQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final Object? row;
    try {
      row = await _client.rpc<Object?>(
        'kpi_sales_quality',
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
    return salesQualityFromJson(Map<String, Object?>.from(row! as Map));
  }
}
