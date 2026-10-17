// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #982 — the nine permissions: in the catalog, with defaults that keep
// what admins could always do and withhold what only owners could.
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/screens/roles_screen_labels.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 24→25 (2026-10-02): #1921 viewAnalytics — read aggregated operational
  // KPIs without holding a write right.
  // 25→31 (2026-10-04): the everyday features are permissions — useMessages,
  // makeReservations, viewCalendar, viewDirectory, viewMyMoney, viewDocuments.
  // 31→32 (2026-10-16): #2573 managePurchases — capture the supplier bills.
  // 32→33 (2026-10-17): #2574 recordOutgoingPayments — record cash paid out.
  test('the catalog carries 33 permissions, wire names equal to Dart names',
      () {
    expect(WorkspacePermission.values, hasLength(33));
    for (final p in WorkspacePermission.values) {
      expect(p.wireName, p.name);
    }
  });

  test('every permission has a human label, never its wire name', () {
    final l10n = AppLocalizationsEn();
    for (final p in WorkspacePermission.values) {
      expect(permissionLabel(l10n, p), isNot(p.name), reason: '$p');
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
      // #989 — pushing to production stays with the owner; refreshing
      // the dev and entering the prod are an admin's.
      WorkspacePermission.deployToProd,
      // #2573 — supplier bills are captured by who is given the right.
      WorkspacePermission.managePurchases,
      // #2574 — cash paid out is recorded by who is given the right.
      WorkspacePermission.recordOutgoingPayments,
    ]) {
      expect(admin, isNot(contains(p)), reason: '$p stays with the owner');
    }
    expect(defaultPermissionsFor(PermissionRole.coOwner),
        WorkspacePermission.values.toSet());
    expect(defaultPermissionsFor(PermissionRole.member), isEmpty);
  });
}
