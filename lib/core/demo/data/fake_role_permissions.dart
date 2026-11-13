// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the in-memory half of RolePermissions: moved verbatim out of the part
// files; the state it reads is `FakeWorkspaceState`.
import 'dart:async';

import 'package:deskilo/features/workspace/domain/role_permission_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'fake_workspace_state.dart';

mixin FakeRolePermissions on FakeWorkspaceState
    implements RolePermissionRepository {
  @override
  Future<void> setRolePermissions(
    String workspaceId,
    String role,
    List<String> permissions,
  ) async {
    // #513 — mirrors set_role_permissions: caller must hold manageRoles.
    // #3293: in the workspace being edited — the Demo's spaces share one
    // list, whose first row is the main space.
    if (!effectivePermissions(
      myMember,
      target(workspaceId),
    ).contains(WorkspacePermission.manageRoles)) {
      throw const PostgrestException(
          message: 'only role managers may edit permissions', code: 'DKN01');
    }
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] = workspaces[i].copyWith(
      rolePermissions: {...workspaces[i].rolePermissions, role: permissions},
    );
  }

  /// #1089 — mirrors `set_role_permission`: ONE permission, merged into
  /// the list as it stands. A fake that recomputed the whole list would
  /// pass a test the server would fail, which is how the defect survived.
  @override
  Future<void> setRolePermission(
    String workspaceId,
    String role,
    String permission, {
    required bool enabled,
  }) async {
    if (!effectivePermissions(
      myMember,
      target(workspaceId),
    ).contains(WorkspacePermission.manageRoles)) {
      throw const PostgrestException(
          message: 'only role managers may edit permissions', code: 'DKN01');
    }
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    // rolePermissions is Map<String, dynamic>; strict-casts (#1060)
    // refuses to spread a dynamic, and the stored value is a JSON list.
    final stored = workspaces[i].rolePermissions[role] as List<Object?>?;
    final current = <String>[for (final p in stored ?? const <Object?>[]) '$p']
      ..remove(permission);
    if (enabled) current.add(permission);
    current.sort();
    workspaces[i] = workspaces[i].copyWith(
      rolePermissions: {...workspaces[i].rolePermissions, role: current},
    );
  }
}
