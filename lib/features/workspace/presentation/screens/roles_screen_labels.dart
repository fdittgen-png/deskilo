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
        WorkspacePermission.manageLease =>
          l10n.permManageLease,
        WorkspacePermission.managePrivacy =>
          l10n.permManagePrivacy,
        WorkspacePermission.viewStock =>
          l10n.permViewStock,
        WorkspacePermission.manageStock =>
          l10n.permManageStock,
        WorkspacePermission.approveStockAdjustments =>
          l10n.permApproveStockAdjustments,
        _ => permission.name,
      };

/// #3628 — one line of what [permission] allows, beside its name.
String permissionAllows(AppLocalizations l10n, WorkspacePermission permission) =>
    switch (permission) {
      WorkspacePermission.manageRoles => l10n.permAllowsManageRoles,
      WorkspacePermission.manageMembers => l10n.permAllowsManageMembers,
      WorkspacePermission.manageValidation => l10n.permAllowsManageValidation,
      WorkspacePermission.workspaceSettings => l10n.permAllowsWorkspaceSettings,
      WorkspacePermission.issueInvoices => l10n.permAllowsIssueInvoices,
      WorkspacePermission.viewFinances => l10n.permAllowsViewFinances,
      WorkspacePermission.manageDocuments => l10n.permAllowsManageDocuments,
      WorkspacePermission.manageServices => l10n.permAllowsManageServices,
      WorkspacePermission.approveExpenses => l10n.permAllowsApproveExpenses,
      WorkspacePermission.viewNegotiations => l10n.permAllowsViewNegotiations,
      WorkspacePermission.manageNegotiations => l10n.permAllowsManageNegotiations,
      WorkspacePermission.paymentTermsEdit => l10n.permAllowsPaymentTermsEdit,
      WorkspacePermission.manageSites => l10n.permAllowsManageSites,
      WorkspacePermission.manageBilling => l10n.permAllowsManageBilling,
      WorkspacePermission.manageReservations => l10n.permAllowsManageReservations,
      WorkspacePermission.operateKiosk => l10n.permAllowsOperateKiosk,
      WorkspacePermission.exportData => l10n.permAllowsExportData,
      WorkspacePermission.designDocuments => l10n.permAllowsDesignDocuments,
      WorkspacePermission.viewPersonalData => l10n.permAllowsViewPersonalData,
      WorkspacePermission.manageIntegrations => l10n.permAllowsManageIntegrations,
      WorkspacePermission.manageConfiguration => l10n.permAllowsManageConfiguration,
      WorkspacePermission.deployToProd => l10n.permAllowsDeployToProd,
      WorkspacePermission.deployToDev => l10n.permAllowsDeployToDev,
      WorkspacePermission.accessProd => l10n.permAllowsAccessProd,
      WorkspacePermission.viewAnalytics => l10n.permAllowsViewAnalytics,
      WorkspacePermission.useMessages => l10n.permAllowsUseMessages,
      WorkspacePermission.makeReservations => l10n.permAllowsMakeReservations,
      WorkspacePermission.viewCalendar => l10n.permAllowsViewCalendar,
      WorkspacePermission.viewDirectory => l10n.permAllowsViewDirectory,
      WorkspacePermission.viewMyMoney => l10n.permAllowsViewMyMoney,
      WorkspacePermission.viewDocuments => l10n.permAllowsViewDocuments,
      WorkspacePermission.managePurchases => l10n.permAllowsManagePurchases,
      WorkspacePermission.recordOutgoingPayments => l10n.permAllowsRecordOutgoingPayments,
      WorkspacePermission.manageLease => l10n.permAllowsManageLease,
      WorkspacePermission.managePrivacy => l10n.permAllowsManagePrivacy,
      WorkspacePermission.viewStock => l10n.permAllowsViewStock,
      WorkspacePermission.manageStock => l10n.permAllowsManageStock,
      WorkspacePermission.approveStockAdjustments => l10n.permAllowsApproveStockAdjustments,
    };
