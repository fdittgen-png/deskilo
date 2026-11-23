// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/codes/pg_code.dart';
import '../domain/business_payables.dart';
import '../domain/supplier_balance.dart';
import '../domain/supplier_payables_page.dart';
import 'supabase_supplier_balance_repository.dart';

/// What a business has to pay, read as the server's complete aggregates: the
/// supplier balances (0653) and what it owes its members back (0831).
class SupabaseBusinessPayablesRepository implements BusinessPayablesRepository {
  SupabaseBusinessPayablesRepository(this._client)
    : _suppliers = SupabaseSupplierBalanceRepository(_client);

  final SupabaseClient _client;
  final SupabaseSupplierBalanceRepository _suppliers;

  @override
  Future<List<SupplierBalance>> supplierBalances(String workspaceId) =>
      _refused(() => _suppliers.fetchBalances(workspaceId));

  @override
  Future<MemberReimbursements> memberReimbursements(String workspaceId) =>
      _refused(
        () async => MemberReimbursements.fromJson(
          await _client.rpc<Object?>(
            'member_reimbursements_summary_v1',
            params: {'p_workspace_id': workspaceId},
          ),
        ),
      );

  @override
  Future<SupplierPayablesPage> payablesPage(
    String workspaceId,
    String currency, {
    String? creditorKind,
    SupplierPayablesCursor? after,
  }) => _refused(
    () async => SupplierPayablesPage.fromJson(
      await _client.rpc<Object?>(
        'business_payables_page_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_currency': currency,
          'p_creditor_kind': ?creditorKind,
          'p_after_created': ?after?.created,
          'p_after_id': ?after?.id,
        },
      ),
    ),
  );

  /// 42501: not the right of that business, or purchasing is off there.
  Future<T> _refused<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on PostgrestException catch (e, st) {
      if (e.code == PgCode.insufficientPrivilege) {
        Error.throwWithStackTrace(const BusinessPayablesRefusal(), st);
      }
      rethrow;
    }
  }
}
