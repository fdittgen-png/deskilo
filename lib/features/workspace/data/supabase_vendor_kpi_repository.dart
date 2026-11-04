// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 2 — the vendor figures over Supabase (`kpi_vendor_quality`, 0673).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/kpi_contract.dart';
import '../domain/kpi_vendors.dart';

class SupabaseVendorKpiRepository implements VendorKpiRepository {
  SupabaseVendorKpiRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<VendorQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final Object? row;
    try {
      row = await _client.rpc<Object?>(
        'kpi_vendor_quality',
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
    return vendorQualityFromJson(Map<String, Object?>.from(row! as Map));
  }
}
