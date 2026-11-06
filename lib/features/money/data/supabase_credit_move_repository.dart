// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
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
}
