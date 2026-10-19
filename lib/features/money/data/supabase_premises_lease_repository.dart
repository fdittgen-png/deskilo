// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';
import '../../../core/validation/pending_validation.dart';
import '../domain/premises_lease.dart';

/// The premises lease and its RPCs (0474). Reading is one RPC that checks the
/// right; every write derives actor, status and schedules on the server.
/// The lease an RPC answered, or [PendingValidationException] when the
/// space's policy held the change for a second person (0506): nothing is
/// applied until they confirm.
PremisesLease _leaseOrPending(Object? answer) {
  if (answer is Map && answer['pending'] == true) {
    throw PendingValidationException('${answer['event_id']}');
  }
  return PremisesLease.fromJson(answer);
}

class SupabasePremisesLeaseRepository implements PremisesLeaseRepository {
  const SupabasePremisesLeaseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PremisesLease>> fetchLeases(String workspaceId) async {
    final json = await _client.rpc<Object?>(
      'premises_leases_v1',
      params: {'p_workspace_id': workspaceId},
    );
    return [
      for (final l in JsonReader.of(
        json,
        context: 'premises leases',
      ).list('leases'))
        PremisesLease.fromJson(l),
    ];
  }

  @override
  Future<PremisesLease> saveLease(String workspaceId, LeaseDraft draft) async =>
      PremisesLease.fromJson(
        await _client.rpc<Object?>(
          'save_premises_lease_v1',
          params: {
            'p_workspace_id': workspaceId,
            'p_lease_id': draft.leaseId,
            'p_revision': draft.revision,
            'p_payload': draft.toPayload(),
            'p_request_id': draft.requestId,
          },
        ),
      );

  @override
  Future<PremisesLease> addTerm(
    String workspaceId,
    LeaseTermCommand command,
  ) async => _leaseOrPending(
    await _client.rpc<Object?>(
      'add_lease_term_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_lease_id': command.leaseId,
        'p_revision': command.revision,
        'p_kind': command.kind.wire,
        'p_label': command.label,
        'p_amount_cents': command.amountCents,
        'p_every_months': command.everyMonths,
        'p_effective_from': isoDay(command.effectiveFrom),
        'p_request_id': command.requestId,
      },
    ),
  );

  @override
  Future<PremisesLease> giveNotice(
    String workspaceId,
    LeaseNoticeCommand command,
  ) async => _leaseOrPending(
    await _client.rpc<Object?>(
      'give_lease_notice_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_lease_id': command.leaseId,
        'p_revision': command.revision,
        'p_notice_given_on': isoDay(command.givenOn),
        'p_effective_end': isoDay(command.effectiveEnd),
        'p_reason': command.reason,
        'p_request_id': command.requestId,
      },
    ),
  );

  @override
  Future<PremisesLease> settleCharges(
    String workspaceId,
    LeaseSettlementCommand command,
  ) async => PremisesLease.fromJson(
    await _client.rpc<Object?>(
      'settle_lease_charges_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_lease_id': command.leaseId,
        'p_revision': command.revision,
        'p_period_start': isoDay(command.periodStart),
        'p_period_end': isoDay(command.periodEnd),
        'p_actual_cents': command.actualCents,
        'p_due_on': isoDay(command.dueOn),
        'p_request_id': command.requestId,
      },
    ),
  );
}
