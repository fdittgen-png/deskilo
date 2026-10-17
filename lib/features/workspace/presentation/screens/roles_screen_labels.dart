// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1528 — one name per permission, for every screen that shows them.
//
// The built-in role matrix (#513) and the editor for a workspace's own
// roles are looking at the same catalogue, so they say the same words.
// Two copies of this switch would drift the day somebody adds a
// permission and updates one of them.
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_permission.dart';

String permissionLabel(AppLocalizations l10n, WorkspacePermission permission) =>
    switch (permission) {
        WorkspacePermission.manageRoles =>
          l10n.permManageRoles,
        WorkspacePermission.manageMembers =>
          l10n.permManageMembers,
        WorkspacePermission.manageValidation =>
          l10n.permManageValidation,
        WorkspacePermission.workspaceSettings =>
          l10n.permWorkspaceSettings,
        WorkspacePermission.issueInvoices =>
          l10n.permIssueInvoices,
        WorkspacePermission.viewFinances =>
          l10n.permViewFinances,
        WorkspacePermission.manageDocuments =>
          l10n.permManageDocuments,
        WorkspacePermission.manageServices =>
          l10n.permManageServices,
        WorkspacePermission.approveExpenses =>
          l10n.permApproveExpenses,
        WorkspacePermission.viewNegotiations =>
          l10n.permViewNegotiations,
        WorkspacePermission.manageNegotiations =>
          l10n.permManageNegotiations,
        WorkspacePermission.paymentTermsEdit =>
          l10n.permPaymentTermsEdit,
        WorkspacePermission.manageSites =>
          l10n.permManageSites,
        WorkspacePermission.manageBilling =>
          l10n.permManageBilling,
        WorkspacePermission.manageReservations =>
          l10n.permManageReservations,
        WorkspacePermission.operateKiosk =>
          l10n.permOperateKiosk,
        WorkspacePermission.exportData =>
          l10n.permExportData,
        WorkspacePermission.designDocuments =>
          l10n.permDesignDocuments,
        WorkspacePermission.viewPersonalData =>
          l10n.permViewPersonalData,
        WorkspacePermission.manageIntegrations =>
          l10n.permManageIntegrations,
        WorkspacePermission.manageConfiguration =>
          l10n.permManageConfiguration,
        WorkspacePermission.deployToProd =>
          l10n.permDeployToProd,
        WorkspacePermission.deployToDev =>
          l10n.permDeployToDev,
        WorkspacePermission.accessProd =>
          l10n.permAccessProd,
        WorkspacePermission.viewAnalytics =>
          l10n.permViewAnalytics,
        _ => _laterLabel(l10n, permission),
      };

/// The permissions added after the administration ones; kept apart so the
/// main switch does not grow with the catalogue.
String _laterLabel(AppLocalizations l10n, WorkspacePermission permission) =>
    switch (permission) {
        WorkspacePermission.useMessages =>
          l10n.permUseMessages,
        WorkspacePermission.makeReservations =>
          l10n.permMakeReservations,
        WorkspacePermission.viewCalendar =>
          l10n.permViewCalendar,
        WorkspacePermission.viewDirectory =>
          l10n.permViewDirectory,
        WorkspacePermission.viewMyMoney =>
          l10n.permViewMyMoney,
        WorkspacePermission.viewDocuments =>
          l10n.permViewDocuments,
        WorkspacePermission.managePurchases =>
          l10n.permManagePurchases,
        WorkspacePermission.recordOutgoingPayments =>
          l10n.permRecordOutgoingPayments,
        _ => permission.name,
      };
