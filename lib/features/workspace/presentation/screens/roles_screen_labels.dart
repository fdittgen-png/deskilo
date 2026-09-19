// SPDX-License-Identifier: 0BSD
//
// #1528 — one name per permission, for every screen that shows them.
//
// The built-in role matrix (#513) and the editor for a workspace's own
// roles are looking at the same catalogue, so they say the same words.
// Two copies of this switch would drift the day somebody adds a
// permission and updates one of them.
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_permission.dart';

String permissionLabel(AppLocalizations? l10n, WorkspacePermission permission) =>
    switch (permission) {
        WorkspacePermission.manageRoles =>
          l10n?.permManageRoles ?? 'Manage roles & permissions',
        WorkspacePermission.manageMembers =>
          l10n?.permManageMembers ?? 'Manage members',
        WorkspacePermission.manageValidation =>
          l10n?.permManageValidation ?? 'Configure validation policies',
        WorkspacePermission.workspaceSettings =>
          l10n?.permWorkspaceSettings ?? 'Edit workspace settings',
        WorkspacePermission.issueInvoices =>
          l10n?.permIssueInvoices ?? 'Issue invoices & match payments',
        WorkspacePermission.viewFinances =>
          l10n?.permViewFinances ?? 'View workspace finances',
        WorkspacePermission.manageDocuments =>
          l10n?.permManageDocuments ?? 'Manage the document library',
        WorkspacePermission.manageServices =>
          l10n?.permManageServices ?? 'Manage services & packages',
        WorkspacePermission.approveExpenses =>
          l10n?.permApproveExpenses ?? 'Approve expenses',
        WorkspacePermission.viewNegotiations =>
          l10n?.permViewNegotiations ?? 'View commercial agreements',
        WorkspacePermission.manageNegotiations =>
          l10n?.permManageNegotiations ?? 'Manage commercial agreements',
        WorkspacePermission.paymentTermsEdit =>
          l10n?.permPaymentTermsEdit ?? 'Request payment-condition changes',
        WorkspacePermission.manageSites =>
          l10n?.permManageSites ?? 'Manage sites and levels',
        WorkspacePermission.manageBilling =>
          l10n?.permManageBilling ?? 'Manage tariffs and billing rules',
        WorkspacePermission.manageReservations =>
          l10n?.permManageReservations ?? 'Manage reservations of others',
        WorkspacePermission.operateKiosk =>
          l10n?.permOperateKiosk ?? 'Operate the kiosk and badges',
        WorkspacePermission.exportData =>
          l10n?.permExportData ?? 'Export accounting and data',
        WorkspacePermission.designDocuments =>
          l10n?.permDesignDocuments ?? 'Design the documents',
        WorkspacePermission.viewPersonalData =>
          l10n?.permViewPersonalData ?? 'Read members\' personal data',
        WorkspacePermission.manageIntegrations =>
          l10n?.permManageIntegrations ?? 'Manage integrations',
        WorkspacePermission.manageConfiguration =>
          l10n?.permManageConfiguration ?? 'Manage the configuration',
        WorkspacePermission.deployToProd =>
          l10n?.permDeployToProd ?? 'Deploy to production',
        WorkspacePermission.deployToDev =>
          l10n?.permDeployToDev ?? 'Deploy to development',
        WorkspacePermission.accessProd =>
          l10n?.permAccessProd ?? 'Enter the production workspace',
      };
