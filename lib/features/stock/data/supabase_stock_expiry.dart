// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_expiry.dart';
import 'stock_rpc.dart';

/// #4431 -- `stock_expiry_report_v1` behind the port: pages of 200 until the report is complete or [maxRows] is reached.
class SupabaseStockExpiry implements StockExpiry {
  SupabaseStockExpiry(this._client);

  final SupabaseClient _client;

  @override
  Future<ExpiryReport> report(String workspaceId, ExpiryQuery query, {int maxRows = 2000}) async {
    final rows = <ExpiryRow>[];
    Map<String, Object?>? after;
    DateTime? asOf;
    var cut = false;
    while (true) {
      final answer = await StockRpc(_client).object('stock_expiry_report_v1', {
        'p_workspace_id': workspaceId,
        'p_on': query.on == null ? null : isoDay(query.on!),
        'p_scope': query.scope.wire,
        'p_horizon_days': query.horizonDays,
        'p_location_id': query.locationId,
        'p_group_id': query.groupId,
        'p_limit': 200,
        'p_after': after,
      });
      final r = JsonReader.of(answer, context: 'stock_expiry_report_v1');
      final as = r.stringOrNull('as_of');
      if (as != null) asOf = DateTime.parse(as);
      rows.addAll([for (final row in r.requiredList('rows')) ExpiryRow.fromJson(row)]);
      final next = r.objectOrNull('next')?.json;
      if (r.boolOr('complete', fallback: false)) break;
      // a page that neither ends nor continues would silently truncate
      if (next == null) throw const FormatException('stock_expiry_report_v1: no continuation');
      if (rows.length >= maxRows) {
        cut = true;
        break;
      }
      after = Map<String, Object?>.from(next);
    }
    return ExpiryReport(rows: rows, asOf: asOf, cut: cut);
  }
}
