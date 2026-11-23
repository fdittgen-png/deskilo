// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/pg_code.dart';
import '../domain/business_receivables.dart';

/// Reads the complete per-currency aggregate on the server rather than summing
/// the invoices a screen happened to load.
class SupabaseBusinessReceivablesRepository
    implements BusinessReceivablesRepository {
  const SupabaseBusinessReceivablesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<BusinessReceivables> summary(String workspaceId) async {
    try {
      return BusinessReceivables.fromJson(
        await _client.rpc<Object?>(
          'business_receivables_summary_v1',
          params: {'p_workspace_id': workspaceId},
        ),
      );
    } on PostgrestException catch (e, st) {
      // 42501: not the finance right of that business, or no invoicing there.
      if (e.code == PgCode.insufficientPrivilege) {
        Error.throwWithStackTrace(const BusinessReceivablesRefusal(), st);
      }
      rethrow;
    }
  }

  @override
  Future<ReceivablesPage> page(
    String workspaceId,
    String currency, {
    ReceivableState? state,
    ReceivablesCursor? after,
  }) async {
    try {
      return ReceivablesPage.fromJson(
        await _client.rpc<Object?>(
          'business_receivables_page_v1',
          params: {
            'p_workspace_id': workspaceId,
            'p_currency': currency,
            'p_bucket': ?state?.wire,
            'p_after_issued': ?after?.issuedAt,
            'p_after_id': ?after?.id,
          },
        ),
      );
    } on PostgrestException catch (e, st) {
      if (e.code == PgCode.insufficientPrivilege) {
        Error.throwWithStackTrace(const BusinessReceivablesRefusal(), st);
      }
      rethrow;
    }
  }
}
