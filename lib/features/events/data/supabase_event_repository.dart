// SPDX-License-Identifier: MIT
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/event_repository.dart';
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
}
