// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3510 -- the settlement reports kept for review, read through the table's
// row-level security (whoever may see the finances) and ended through
// `mark_settlement_review_handled_v1` (billing managers of the review's own
// business).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/settlement_fetch.dart';

/// The reviews one read lists, newest report first.
const int _shown = 100;

class SupabaseSettlementReviews implements SettlementReviews {
  SupabaseSettlementReviews(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SettlementReview>> fetchSettlementReviews(
    String workspaceId,
  ) async {
    final rows = await _client
        .from('provider_settlement_reviews')
        .select('id, settlement_id, reason, handled_at, handled_note')
        .eq('workspace_id', workspaceId)
        .order('last_reported_at', ascending: false)
        .limit(_shown);
    return [for (final row in rows) ?SettlementReview.fromRow(row)];
  }

  @override
  Future<bool> markSettlementReviewHandled(String reviewId, String note) async {
    final answer = await _client.rpc<Object?>(
      'mark_settlement_review_handled_v1',
      params: {'p_review_id': reviewId, 'p_note': note},
    );
    return answer is Map && answer['handled'] == true;
  }
}
