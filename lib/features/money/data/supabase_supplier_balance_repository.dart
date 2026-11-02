// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../domain/supplier_balance.dart';

/// Reads the complete server aggregate rather than summing a capped page.
class SupabaseSupplierBalanceRepository implements SupplierBalanceRepository {
  const SupabaseSupplierBalanceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SupplierBalance>> fetchBalances(String workspaceId) async {
    final json = await _client.rpc<Object?>(
      'supplier_balances_v1',
      params: {'p_workspace_id': workspaceId},
    );
    final result = JsonReader.of(json, context: 'supplier_balances_v1');
    return [for (final row in result.list('rows')) SupplierBalance.fromJson(row)];
  }
}
