// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/presentation/widgets/environment_tile.dart';
import 'settings_section_header.dart';

/// #1307 S3 — what used to be one Administration block, split by the
/// decision a reader came to make (`docs/ux/SETTINGS_OWNERSHIP.md`):
///
///   * **This workspace** — how the space works: identity, hours, prices,
///     documents, validation, features;
///   * **Administration** — running its people and devices;
///   * **Governance** — what the space *is*: roles, deployment, environment.
///
/// Every tile asks the permission matrix — the question its route and the
/// server ask — never `isOwner || canAdminister`. A section whose tiles are
/// all hidden shows no header either, so a plain member meets none of them.
List<Widget> workspaceSettingsTiles(
  BuildContext context,
  WidgetRef ref, {
  required AppLocalizations? l10n,
  required bool canAdminister,
  required Set<WorkspacePermission> perms,
  required Set<WorkspaceFeature> features,
  required bool isOwner,
  required bool hasTwin,
}) {
  final workspace = <Widget>[
    if (perms.contains(WorkspacePermission.workspaceSettings))
      ListTile(
        leading: const Icon(Icons.business_outlined),
        title: Text(l10n?.workspaceSettingsTitle ?? 'Workspace'),
        onTap: () => context.push('/workspace-settings'),
      ),
    if (perms.contains(WorkspacePermission.workspaceSettings))
      ListTile(
        leading: const Icon(Icons.event_busy_outlined),
        title: Text(l10n?.availabilityTitle ?? 'Availability'),
        onTap: () => context.push('/availability'),
      ),
    if (perms.contains(WorkspacePermission.manageBilling))
      ListTile(
        leading: const Icon(Icons.payments_outlined),
        title: Text(l10n?.billingTitle ?? 'Billing'),
        onTap: () => context.push('/billing'),
      ),
    if (perms.contains(WorkspacePermission.manageServices) &&
        features.contains(WorkspaceFeature.services))
      ListTile(
        leading: const Icon(Icons.local_cafe_outlined),
        title: Text(l10n?.servicesTitle ?? 'Services'),
        onTap: () => context.push('/services'),
      ),
    // Accessory catalog (#167): owner AND admins, per the epic #163
    // decision. The screen still gates its actions on canAdminister, so
    // the tile asks the same until the screen adopts the matrix.
    if (canAdminister &&
        features.contains(WorkspaceFeature.accessorySupplements))
      ListTile(
        leading: const Icon(Icons.devices_other_outlined),
        title: Text(l10n?.accessoriesTitle ?? 'Accessories'),
        onTap: () => context.push('/accessories'),
      ),
    // #478: billing & reports as ONE entry — the invoicing hub with the
    // report editor and the reminder rules in its header. #1307 — reading
    // the workspace's invoices is viewFinances.
    if (perms.contains(WorkspacePermission.viewFinances) &&
        features.contains(WorkspaceFeature.invoicing))
      ListTile(
        key: const ValueKey('settings-billing-reports'),
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(l10n?.settingsBillingReports ?? 'Billing & reports'),
        onTap: () => context.push('/invoices'),
      ),
    // #925 — one screen for every number series.
    if (perms.contains(WorkspacePermission.manageBilling) &&
        features.contains(WorkspaceFeature.numberSequences))
      ListTile(
        key: const ValueKey('settings-number-sequences'),
        leading: const Icon(Icons.format_list_numbered_outlined),
        title: Text(l10n?.numberSequencesTitle ?? 'Number sequences'),
        subtitle: Text(
          l10n?.numberSequencesSubtitle ??
              'How invoices and credit notes are numbered.',
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.push('/settings/number-sequences'),
      ),
    // #486 — the manual payment methods members see on an unpaid statement.
    if (perms.contains(WorkspacePermission.manageIntegrations))
      ListTile(
        key: const ValueKey('settings-payment-methods'),
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: Text(l10n?.paymentInstructionsTitle ?? 'Payment instructions'),
        onTap: () => context.push('/payment-methods'),
      ),
    if (perms.contains(WorkspacePermission.manageValidation))
      ListTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: Text(l10n?.validationTitle ?? 'Validation rules'),
        onTap: () => context.push('/validation'),
      ),
    // The Features entry is always reachable to whoever configures the
    // space, so a module switched off can be switched back on (#146).
    if (perms.contains(WorkspacePermission.manageConfiguration))
      ListTile(
        leading: const Icon(Icons.toggle_on_outlined),
        title: Text(l10n?.featuresTitle ?? 'Features'),
        onTap: () => context.push('/features'),
      ),
  ];

  final administration = <Widget>[
    // Admins reach member management too (0044); owner-only controls gate
    // inside the screen, which still decides on canAdminister.
    if (canAdminister)
      ListTile(
        leading: const Icon(Icons.group_outlined),
        title: Text(l10n?.membersTitle ?? 'Members & plans'),
        onTap: () => context.push('/members'),
      ),
    if (perms.contains(WorkspacePermission.manageIntegrations) &&
        features.contains(WorkspaceFeature.onlinePayments))
      ListTile(
        leading: const Icon(Icons.credit_card_outlined),
        title: Text(l10n?.payConfigTitle ?? 'Online payments'),
        onTap: () => context.push('/payment-config'),
      ),
    if (perms.contains(WorkspacePermission.operateKiosk) &&
        features.contains(WorkspaceFeature.nfcBadges))
      ListTile(
        leading: const Icon(Icons.contactless_outlined),
        title: Text(l10n?.nfcConfigTitle ?? 'RFID / NFC badges'),
        onTap: () => context.push('/nfc-config'),
      ),
    // #945 — the workspace's sites, for those who manage them.
    if (perms.contains(WorkspacePermission.manageSites) &&
        features.contains(WorkspaceFeature.multiSite))
      ListTile(
        key: const ValueKey('settings-sites'),
        leading: const Icon(Icons.location_city_outlined),
        title: Text(l10n?.sitesTitle ?? 'Sites'),
        subtitle: Text(l10n?.sitesSubtitle ??
            'Addresses, the levels at each, and who calls which home'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.push('/settings/sites'),
      ),
    if (perms.contains(WorkspacePermission.manageConfiguration))
      ListTile(
        leading: const Icon(Icons.qr_code_2),
        title: Text(l10n?.workspaceCodeTitle ?? 'Workspace ID & QR'),
        onTap: () => context.push('/workspace-code'),
      ),
  ];

  final governance = <Widget>[
    // #513 — the role→permission matrix: whoever holds ANY permission may
    // read it, manageRoles edits it. The route asks only the feature.
    if (perms.isNotEmpty && features.contains(WorkspaceFeature.roleManagement))
      ListTile(
        key: const ValueKey('settings-roles'),
        leading: const Icon(Icons.admin_panel_settings_outlined),
        title: Text(l10n?.rolesTitle ?? 'Role management'),
        onTap: () => context.push('/roles'),
      ),
    // #990 — deploying between the two sides of the pair: the question the
    // /deployment route asks, word for word.
    if (features.contains(WorkspaceFeature.deployments) &&
        perms.contains(WorkspacePermission.deployToDev) &&
        hasTwin)
      ListTile(
        key: const ValueKey('settings-deployment'),
        leading: const Icon(Icons.rocket_launch_outlined),
        title: Text(l10n?.deploymentTitle ?? 'Deployment'),
        onTap: () => context.push('/deployment'),
      ),
    // #917 — is this space real? Owner-only, as
    // `set_workspace_environment` is.
    if (isOwner) const WorkspaceEnvironmentTile(),
  ];

  List<Widget> section(String title, List<Widget> tiles) => tiles.isEmpty
      ? const []
      : [const Divider(), SettingsSectionHeader(title), ...tiles];

  return [
    ...section(l10n?.settingsSectionWorkspace ?? 'This workspace', workspace),
    ...section(
        l10n?.settingsSectionAdministration ?? 'Administration', administration),
    ...section(l10n?.settingsSectionGovernance ?? 'Governance', governance),
  ];
}
