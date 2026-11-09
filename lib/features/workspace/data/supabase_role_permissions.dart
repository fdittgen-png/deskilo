// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the permission a role holds, as one mixin composed into
// `SupabaseWorkspaceRepository` (the part-file bodies and their `_xxxImpl`
// forwarders are gone).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/validation/pending_validation.dart';
import '../domain/role_permission_repository.dart';

mixin SupabaseRolePermissions implements RolePermissionRepository {
  /// The client of the class this is mixed into.
  SupabaseClient get client;

  @override
  Future<void> setRolePermission(
    String workspaceId,
    String role,
    String permission, {
    required bool enabled,
  }) async {
    // #1089 — the DELTA, never a recomputed list. The server merges it
    // into the row as it stands, and a held change carries the same
    // delta so confirming it cannot undo whatever happened while it
    // waited.
    final answer = await client.rpc<dynamic>(
      'request_matrix_permission',
      params: {
        'p_workspace_id': workspaceId,
        'p_role': role,
        'p_permission': permission,
        'p_enabled': enabled,
      },
    );
    applyOrPendingVoid(answer);
  }

  @override
  Future<void> setRolePermissions(
    String workspaceId,
    String role,
    List<String> permissions,
  ) async {
    // #982 — through the matrix_change policy: held or applied at once.
    final answer = await client.rpc<dynamic>(
      'request_matrix_change',
      params: {
        'p_workspace_id': workspaceId,
        'p_role': role,
        'p_permissions': permissions,
      },
    );
    applyOrPendingVoid(answer);
  }
}
