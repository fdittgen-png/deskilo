// SPDX-License-Identifier: MIT
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/member.dart';
import '../domain/workspace.dart';
import '../domain/workspace_repository.dart';

class SupabaseWorkspaceRepository implements WorkspaceRepository {
  SupabaseWorkspaceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Workspace>> fetchMyWorkspaces() async {
    final rows = await _client.from('workspaces').select();
    return rows.map(_workspaceFromRow).toList();
  }

  @override
  Future<String> createWorkspace({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
  }) async {
    final result = await _client.rpc<dynamic>('create_workspace', params: {
      'p_name': name,
      'p_country_code': countryCode,
      'p_currency_code': currencyCode,
      'p_timezone': timezone,
    });
    return result as String;
  }

  @override
  Future<String> joinWorkspace(String inviteCode) async {
    final result = await _client.rpc<dynamic>('join_workspace', params: {
      'p_invite_code': inviteCode,
    });
    return result as String;
  }

  @override
  Future<Member?> fetchMyMember(String workspaceId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('members')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return _memberFromRow(row);
  }

  Workspace _workspaceFromRow(Map<String, dynamic> row) => Workspace(
        id: row['id'] as String,
        name: row['name'] as String,
        countryCode: row['country_code'] as String,
        currencyCode: row['currency_code'] as String,
        timezone: row['timezone'] as String,
        inviteCode: row['invite_code'] as String,
      );

  Member _memberFromRow(Map<String, dynamic> row) => Member(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        userId: row['user_id'] as String,
        isAdmin: row['is_admin'] as bool,
        isOwner: row['is_owner'] as bool,
        status: MemberStatus.values.byName(row['status'] as String),
      );
}
