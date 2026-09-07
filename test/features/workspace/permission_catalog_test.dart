// SPDX-License-Identifier: 0BSD
//
// #982 — the nine permissions: in the catalog, with defaults that keep
// what admins could always do and withhold what only owners could.
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the catalog carries 21 permissions, wire names equal to Dart names',
      () {
    expect(WorkspacePermission.values, hasLength(21));
    for (final p in WorkspacePermission.values) {
      expect(p.wireName, p.name);
    }
  });

  test('admin defaults: the five that admins always had, not the four '
      'that were owner-only', () {
    final admin = defaultPermissionsFor(PermissionRole.admin);
    expect(admin, containsAll([
      WorkspacePermission.manageSites,
      WorkspacePermission.manageReservations,
      WorkspacePermission.operateKiosk,
      WorkspacePermission.exportData,
      WorkspacePermission.viewPersonalData,
    ]));
    for (final p in [
      WorkspacePermission.manageBilling,
      WorkspacePermission.designDocuments,
      WorkspacePermission.manageIntegrations,
      WorkspacePermission.manageConfiguration,
    ]) {
      expect(admin, isNot(contains(p)), reason: '$p stays with the owner');
    }
    expect(defaultPermissionsFor(PermissionRole.coOwner),
        WorkspacePermission.values.toSet());
    expect(defaultPermissionsFor(PermissionRole.member), isEmpty);
  });
}
