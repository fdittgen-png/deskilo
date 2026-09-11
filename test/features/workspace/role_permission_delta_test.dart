// SPDX-License-Identifier: 0BSD
//
// #1089 — the role matrix is written one permission at a time.
//
// The roles screen computed a role's WHOLE permission list from the
// snapshot it was built with and sent that. Two people with the screen
// open, or one person whose screen predates somebody else's change, and
// the second write silently reverts the first — on the surface that
// governs who may do what, with nobody told, because from each side
// their own save succeeded.
//
// Worse on the held path: a validation policy stores the stale list in
// the event and applies it when a validator confirms, so the window is
// however long the decision takes rather than milliseconds.
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  test('a grant does not erase a concurrent grant', () async {
    final repo = FakeWorkspaceRepository.withWorkspace();
    final ws = repo.workspaces.first.id;
    repo.myMember = repo.myMember.copyWith(isOwner: true, isAdmin: true);

    // Someone grants exportData.
    await repo.setRolePermission(ws, 'admin',
        WorkspacePermission.exportData.wireName, enabled: true);
    // Someone else, from a screen built BEFORE that, grants operateKiosk.
    await repo.setRolePermission(ws, 'admin',
        WorkspacePermission.operateKiosk.wireName, enabled: true);

    final admin = (repo.workspaces.first.rolePermissions['admin'] as List)
        .cast<String>();
    expect(admin, contains(WorkspacePermission.exportData.wireName),
        reason: 'the first grant must survive the second');
    expect(admin, contains(WorkspacePermission.operateKiosk.wireName));
  });

  test('a revoke removes exactly one permission', () async {
    final repo = FakeWorkspaceRepository.withWorkspace();
    final ws = repo.workspaces.first.id;
    repo.myMember = repo.myMember.copyWith(isOwner: true, isAdmin: true);

    await repo.setRolePermission(ws, 'admin',
        WorkspacePermission.exportData.wireName, enabled: true);
    await repo.setRolePermission(ws, 'admin',
        WorkspacePermission.operateKiosk.wireName, enabled: true);
    await repo.setRolePermission(ws, 'admin',
        WorkspacePermission.exportData.wireName, enabled: false);

    final admin = (repo.workspaces.first.rolePermissions['admin'] as List)
        .cast<String>();
    expect(admin, isNot(contains(WorkspacePermission.exportData.wireName)));
    expect(admin, contains(WorkspacePermission.operateKiosk.wireName),
        reason: 'a revoke touches one permission, not the role');
  });
}
