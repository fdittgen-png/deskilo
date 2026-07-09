// SPDX-License-Identifier: MIT
import 'package:supabase_flutter/supabase_flutter.dart';

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
      );
}
