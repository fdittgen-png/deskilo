// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/calendar/calendar_item.dart';
import '../domain/calendar_repository.dart';

/// The wire for `calendar_items` and the GDPR self-service RPCs (0133).
class SupabaseCalendarRepository implements CalendarRepository {
  SupabaseCalendarRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CalendarPage> fetchItems(String workspaceId, CalendarQuery query) async {
    final result = await _client.rpc<dynamic>('calendar_items', params: {
      'p_workspace_id': workspaceId,
      'p_from': query.from.toUtc().toIso8601String(),
      'p_to': query.to.toUtc().toIso8601String(),
      'p_kinds': query.kinds?.map((k) => k.wire).toList(),
      'p_member_id': query.memberId,
    });
    return CalendarPage.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<AccessMap> whoCanAccessMe(String workspaceId) async {
    final result = await _client.rpc<dynamic>('who_can_access_me', params: {
      'p_workspace_id': workspaceId,
    });
    return AccessMap.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<List<DataAccessEntry>> fetchAccessLog(String workspaceId) async {
    // RLS decides the rows: mine as a subject, or the workspace's when
    // I may manage members.
    final rows = await _client
        .from('data_access_log')
        .select()
        .eq('workspace_id', workspaceId)
        .order('at', ascending: false)
        .limit(500);
    return [for (final row in rows) DataAccessEntry.fromRow(row)];
  }

  @override
  Future<Map<String, dynamic>> exportMyData(String workspaceId) async {
    final result = await _client.rpc<dynamic>('export_my_data', params: {
      'p_workspace_id': workspaceId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<void> eraseMyMembership(String workspaceId) =>
      _client.rpc<dynamic>('erase_my_membership', params: {
        'p_workspace_id': workspaceId,
      });
}
