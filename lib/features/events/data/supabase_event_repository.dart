// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../money/domain/payment_terms.dart';
import '../domain/event_decision.dart';
import '../domain/event_repository.dart';
import '../domain/validation_policy.dart';
import '../domain/workspace_event.dart';

class SupabaseEventRepository implements EventRepository {
  SupabaseEventRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<WorkspaceEvent>> fetchEvents(
    String workspaceId, {
    int limit = 100,
  }) async {
    // Lazy timeout sweep before reading (spec §8.2).
    await _client.rpc<dynamic>('sweep_pending_events', params: {
      'p_workspace_id': workspaceId,
    });
    final rows = await _client
        .from('events')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> respond(String eventId, {required bool accept}) async {
    await _client.rpc<dynamic>('respond_to_event', params: {
      'p_event_id': eventId,
      'p_accept': accept,
    });
  }

  @override
  Future<String> requestInvoiceWriteoff(
    String invoiceId, {
    String reason = '',
  }) async {
    final result =
        await _client.rpc<dynamic>('request_invoice_writeoff', params: {
      'p_invoice_id': invoiceId,
      'p_reason': reason,
    });
    return result as String;
  }

  @override
  Future<String> requestReservationDeletion(
    String reservationId, {
    String reason = '',
  }) async {
    final result = await _client
        .rpc<dynamic>('request_reservation_deletion', params: {
      'p_reservation_id': reservationId,
      'p_reason': reason,
    });
    return result as String;
  }

  @override
  Future<String> requestPaymentTermsChange(
    String memberId, {
    required PaymentTerms terms,
    String reason = '',
  }) async {
    final result =
        await _client.rpc<dynamic>('request_payment_terms_change', params: {
      'p_member_id': memberId,
      'p_terms': terms.toJson(),
      'p_reason': reason,
    });
    return result as String;
  }

  @override
  Future<String> requestQuotaExtension(
    String workspaceId, {
    required String period,
    required int halfDays,
  }) async {
    final result =
        await _client.rpc<dynamic>('request_quota_extension', params: {
      'p_workspace_id': workspaceId,
      'p_period': period,
      'p_half_days': halfDays,
    });
    return result as String;
  }

  @override
  Future<Map<String, List<EventDecision>>> fetchDecisions(
    String workspaceId,
    List<String> eventIds,
  ) async {
    if (eventIds.isEmpty) return const {};
    // RLS already scopes rows to events of workspaces I belong to.
    final rows = await _client
        .from('event_decisions')
        .select()
        .inFilter('event_id', eventIds)
        .order('decided_at', ascending: true);
    final grouped = <String, List<EventDecision>>{};
    for (final row in rows) {
      final decision = _decisionFromRow(row);
      grouped.putIfAbsent(decision.eventId, () => []).add(decision);
    }
    return grouped;
  }

  @override
  Future<WorkspaceEvent?> fetchEvent(String eventId) async {
    final rows = await _client
        .from('events')
        .select()
        .eq('id', eventId)
        .limit(1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<ValidationPolicy>> fetchValidationPolicies(
    String workspaceId,
  ) async {
    final rows = await _client
        .from('validation_policies')
        .select()
        .eq('workspace_id', workspaceId);
    return rows.map(_policyFromRow).toList();
  }

  @override
  Future<void> upsertValidationPolicy(ValidationPolicy policy) async {
    await _client.from('validation_policies').upsert(
      {
        if (policy.id != null) 'id': policy.id,
        'workspace_id': policy.workspaceId,
        'event_type': policy.eventType,
        'required_count': policy.requiredCount,
        'admins_may_validate': policy.adminsMayValidate,
        'eligible_admin_ids': policy.eligibleAdminIds,
        'owner_required': policy.ownerRequired,
        // #629 — reservation_delete only; false everywhere else.
        'auto_validate_admin': policy.autoValidateAdmin,
        'auto_validate_owner': policy.autoValidateOwner,
        'validator_scope': policy.validatorScope,
        // #840 — the owner's own-act exception, and one-at-a-time asking.
        'owner_may_self_validate': policy.ownerMaySelfValidate,
        'sequential': policy.sequential,
      },
      onConflict: 'workspace_id,event_type',
    );
  }

  WorkspaceEvent _fromRow(Map<String, dynamic> row) => WorkspaceEvent(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        type: EventType.fromDb(row['type'] as String),
        action: EventAction.values.byName(row['action'] as String),
        actorMemberId: row['actor_member_id'] as String,
        subjectMemberId: row['subject_member_id'] as String,
        reservationId: row['reservation_id'] as String?,
        payload: (row['payload'] as Map).cast<String, dynamic>(),
        status: EventStatus.values.byName(row['status'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        decidedAt: row['decided_at'] == null
            ? null
            : DateTime.parse(row['decided_at'] as String),
      );

  EventDecision _decisionFromRow(Map<String, dynamic> row) => EventDecision(
        id: row['id'] as String,
        eventId: row['event_id'] as String,
        memberId: row['member_id'] as String?,
        accept: row['decision'] as String == 'accept',
        decidedBySystem: row['decided_by_system'] as bool,
        decidedAt: DateTime.parse(row['decided_at'] as String),
      );

  ValidationPolicy _policyFromRow(Map<String, dynamic> row) =>
      ValidationPolicy(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        eventType: row['event_type'] as String?,
        requiredCount: row['required_count'] as int,
        adminsMayValidate: row['admins_may_validate'] as bool,
        eligibleAdminIds:
            (row['eligible_admin_ids'] as List).cast<String>(),
        ownerRequired: row['owner_required'] as bool,
        autoValidateAdmin: row['auto_validate_admin'] as bool? ?? false,
        autoValidateOwner: row['auto_validate_owner'] as bool? ?? false,
        validatorScope: row['validator_scope'] as String? ?? 'admins',
        ownerMaySelfValidate:
            row['owner_may_self_validate'] as bool? ?? false,
        sequential: row['sequential'] as bool? ?? false,
      );
}
