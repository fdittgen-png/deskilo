// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/date_text.dart';
import '../domain/lease_commitment.dart';

/// The lease's expected obligations and their matches (0479).
class SupabaseLeaseCommitmentRepository implements LeaseCommitmentRepository {
  const SupabaseLeaseCommitmentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CommitmentPage> fetchCommitments(
    String workspaceId,
    String leaseId, {
    DateTime? before,
  }) async => CommitmentPage.fromJson(
    await _client.rpc<Object?>(
      'purchase_commitment_page_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_lease_id': leaseId,
        'p_before': before == null ? null : isoDay(before),
      },
    ),
  );

  @override
  Future<void> matchCommitments(
    String workspaceId,
    CommitmentMatchCommand command,
  ) async {
    await _client.rpc<Object?>(
      'match_purchase_commitments_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_purchase_id': command.purchaseId,
        'p_revision': command.revision,
        'p_matches': [
          for (final a in command.allocations)
            {
              'occurrence_id': a.occurrenceId,
              'line_no': a.lineNo,
              'allocated_cents': a.cents,
            },
        ],
        'p_request_id': command.requestId,
      },
    );
  }

  @override
  Future<void> reverseMatch(
    String workspaceId, {
    required String matchId,
    required String reason,
    required String requestId,
  }) async {
    await _client.rpc<Object?>(
      'reverse_commitment_match_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_match_id': matchId,
        'p_reason': reason,
        'p_request_id': requestId,
      },
    );
  }
}
