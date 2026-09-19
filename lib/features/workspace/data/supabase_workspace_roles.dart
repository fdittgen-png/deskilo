// SPDX-License-Identifier: 0BSD
//
// #1528 — the roles of 0247, read through its select policies and
// written through its two definers.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_permission.dart';
import '../domain/workspace_role.dart';
import '../domain/workspace_roles_repository.dart';

class SupabaseWorkspaceRoles implements WorkspaceRolesRepository {
  const SupabaseWorkspaceRoles(this._client);

  final SupabaseClient _client;

  @override
  Future<List<WorkspaceRole>> fetchRoles(String workspaceId) async {
    final rows = await _client
        .from('workspace_roles')
        .select('id, key, permissions, names, sort_order, active')
        .eq('workspace_id', workspaceId);
    return [
      for (final row in rows as List)
        () {
          final map = Map<String, dynamic>.from(row as Map);
          return WorkspaceRole(
            id: '${map['id']}',
            key: '${map['key']}',
            names: {
              for (final e in (map['names'] as Map? ?? const {}).entries)
                '${e.key}': '${e.value}',
            },
            permissions: {
              for (final name in (map['permissions'] as List? ?? const []))
                for (final p in WorkspacePermission.values)
                  // A permission this app does not know is a server newer
                  // than the app; the role renders with the rest.
                  if (p.wireName == '$name') p,
            },
            sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
            active: map['active'] as bool? ?? true,
          );
        }(),
    ];
  }

  @override
  Future<List<String>> fetchRoleMembers(String roleId) async {
    final rows = await _client
        .from('workspace_role_members')
        .select('member_id')
        .eq('role_id', roleId);
    return [
      for (final row in rows as List)
        '${Map<String, dynamic>.from(row as Map)['member_id']}',
    ];
  }

  @override
  Future<String> setRole(String workspaceId, WorkspaceRole role) async {
    final id = await _client.rpc<dynamic>('set_workspace_role', params: {
      'p_workspace_id': workspaceId,
      'p_key': role.key,
      'p_permissions': [for (final p in role.permissions) p.wireName],
      'p_names': role.names,
      'p_sort_order': role.sortOrder,
      'p_active': role.active,
    });
    return '$id';
  }

  @override
  Future<void> assignRole({
    required String memberId,
    required String roleId,
    required bool assign,
  }) =>
      _client.rpc<void>('assign_workspace_role', params: {
        'p_member_id': memberId,
        'p_role_id': roleId,
        'p_assign': assign,
      });
}
