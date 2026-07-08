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

  @override
  Future<Map<String, String>> fetchMemberNames(String workspaceId) async {
    // members ↔ profiles share auth.users ids but carry no direct FK, so
    // PostgREST cannot embed — two queries, joined client-side.
    final memberRows = await _client
        .from('members')
        .select('id, user_id')
        .eq('workspace_id', workspaceId);
    final userIds =
        memberRows.map((r) => r['user_id'] as String).toSet().toList();
    if (userIds.isEmpty) return const {};
    final profileRows = await _client
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', userIds);
    final nameByUser = {
      for (final r in profileRows)
        r['id'] as String: r['display_name'] as String,
    };
    return {
      for (final r in memberRows)
        r['id'] as String: nameByUser[r['user_id'] as String] ?? '',
    };
  }

  Workspace _workspaceFromRow(Map<String, dynamic> row) => Workspace(
        id: row['id'] as String,
        name: row['name'] as String,
        countryCode: row['country_code'] as String,
        currencyCode: row['currency_code'] as String,
        timezone: row['timezone'] as String,
        inviteCode: row['invite_code'] as String,
      );

  @override
  Future<List<Member>> fetchMembers(String workspaceId) async {
    final rows = await _client
        .from('members')
        .select()
        .eq('workspace_id', workspaceId)
        .order('joined_at', ascending: true);
    return rows.map(_memberFromRow).toList();
  }

  @override
  Future<void> updateMemberPlan(String memberId, String? planId) async {
    await _client
        .from('members')
        .update({'plan_id': planId}).eq('id', memberId);
  }

  @override
  Future<void> updateMemberStatus(String memberId, MemberStatus status) async {
    await _client
        .from('members')
        .update({'status': status.name}).eq('id', memberId);
  }

  @override
  Future<String> setWorkspaceCode(String workspaceId, String code) async {
    final result = await _client.rpc<dynamic>('set_workspace_code', params: {
      'p_workspace_id': workspaceId,
      'p_code': code,
    });
    return result as String;
  }

  Member _memberFromRow(Map<String, dynamic> row) => Member(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        userId: row['user_id'] as String,
        isAdmin: row['is_admin'] as bool,
        isOwner: row['is_owner'] as bool,
        status: MemberStatus.values.byName(row['status'] as String),
        planId: row['plan_id'] as String?,
      );
}
