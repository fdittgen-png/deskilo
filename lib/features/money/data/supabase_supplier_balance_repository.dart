// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/supplier_balance.dart';
import '../domain/supplier_payables_page.dart';

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

  @override
  Future<SupplierPayablesPage> fetchPayables(
    String workspaceId,
    String supplierId, {
    SupplierPayablesCursor? after,
  }) async => SupplierPayablesPage.fromJson(await _client.rpc<Object?>(
    'supplier_payables_page_v1',
    params: {
      'p_workspace_id': workspaceId,
      'p_supplier_id': supplierId,
      'p_after_created': ?after?.created,
      'p_after_id': ?after?.id,
    },
  ));
}
