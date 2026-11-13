// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3628 — the permissions grouped by the part of the business they open, so
// a role's page reads module by module. One place says which module each
// permission belongs to; the switch is exhaustive, so a new permission
// cannot be added without being placed.
import 'workspace_permission.dart';

/// The parts of the business the permissions open, in reading order.
enum PermissionModule {
  everyday,
  people,
  places,
  money,
  stock,
  documents,
  configuration,
  environments,
}

/// The module [permission] belongs to.
PermissionModule _moduleOf(WorkspacePermission permission) =>
    switch (permission) {
      WorkspacePermission.useMessages ||
      WorkspacePermission.makeReservations ||
      WorkspacePermission.viewCalendar ||
      WorkspacePermission.viewDirectory ||
      WorkspacePermission.viewMyMoney ||
      WorkspacePermission.viewDocuments => PermissionModule.everyday,
      WorkspacePermission.manageRoles ||
      WorkspacePermission.manageMembers ||
      WorkspacePermission.viewPersonalData ||
      WorkspacePermission.managePrivacy ||
      WorkspacePermission.viewNegotiations ||
      WorkspacePermission.manageNegotiations ||
      WorkspacePermission.paymentTermsEdit => PermissionModule.people,
      WorkspacePermission.manageReservations ||
      WorkspacePermission.manageSites ||
      WorkspacePermission.operateKiosk ||
      WorkspacePermission.manageValidation => PermissionModule.places,
      WorkspacePermission.issueInvoices ||
      WorkspacePermission.viewFinances ||
      WorkspacePermission.manageBilling ||
      WorkspacePermission.manageServices ||
      WorkspacePermission.approveExpenses ||
      WorkspacePermission.managePurchases ||
      WorkspacePermission.recordOutgoingPayments ||
      WorkspacePermission.manageLease => PermissionModule.money,
      WorkspacePermission.viewStock ||
      WorkspacePermission.manageStock ||
      WorkspacePermission.approveStockAdjustments => PermissionModule.stock,
      WorkspacePermission.manageDocuments ||
      WorkspacePermission.designDocuments ||
      WorkspacePermission.exportData ||
      WorkspacePermission.viewAnalytics => PermissionModule.documents,
      WorkspacePermission.workspaceSettings ||
      WorkspacePermission.manageConfiguration ||
      WorkspacePermission.manageIntegrations => PermissionModule.configuration,
      WorkspacePermission.deployToProd ||
      WorkspacePermission.deployToDev ||
      WorkspacePermission.accessProd => PermissionModule.environments,
    };

/// Every permission, module by module, in the catalogue's order within one.
List<(PermissionModule, List<WorkspacePermission>)> permissionsByModule() => [
  for (final module in PermissionModule.values)
    (
      module,
      [
        for (final p in WorkspacePermission.values)
          if (_moduleOf(p) == module) p,
      ],
    ),
];
