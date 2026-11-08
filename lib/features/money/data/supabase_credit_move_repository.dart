// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../domain/credit_move.dart';

/// #2380 — `move_payment_credit_v1` (0688).
class SupabaseCreditMoveRepository implements CreditMoveRepository {
  SupabaseCreditMoveRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CreditMove> moveCredit({
    required String creditId,
    required String toMemberId,
    required String reason,
    required String requestId,
  }) async {
    final result = await _client.rpc<Object?>(
      'move_payment_credit_v1',
      params: {
        'p_credit_id': creditId,
        'p_to_member_id': toMemberId,
        'p_reason': reason,
        'p_request_id': requestId,
      },
    );
    return CreditMove.fromJson(
      JsonReader.of(result, context: 'move_payment_credit_v1').json,
    );
  }

  @override
  Future<Set<String>> fetchMovedCreditIds(String workspaceId) async {
    final rows = await fetchAllPages(
      table: 'ledger_credit_moves',
      build: () => _client
          .from('ledger_credit_moves')
          .select('from_credit_id, reversal_ledger_id')
          .eq('workspace_id', workspaceId)
          .order('id', ascending: true),
    );
    return {
      for (final row in rows) ...[
        row['from_credit_id'] as String,
        row['reversal_ledger_id'] as String,
      ],
    };
  }
}
