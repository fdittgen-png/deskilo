// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 4 — the item figures over Supabase (`kpi_item_margins`, 0675).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/kpi_contract.dart';
import '../domain/kpi_items.dart';

class SupabaseItemKpiRepository implements ItemKpiRepository {
  SupabaseItemKpiRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ItemMarginsKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final Object? row;
    try {
      row = await _client.rpc<Object?>(
        'kpi_item_margins',
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
    return itemMarginsFromJson(Map<String, Object?>.from(row! as Map));
  }
}
