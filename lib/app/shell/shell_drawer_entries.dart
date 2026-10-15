// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — what the drawer offers, as data: every destination of the
// navigation, administration, reporting and account groups with the
// permission and feature that earn it. It was 120 lines of
// ShellDrawer.build; the entries, keys and conditions are unchanged.

import 'package:flutter/material.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/l10n/lexicon.dart';
import '../../features/task_recorder/presentation/route_classification.dart'
    show taskWizardRoute;
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../l10n/app_localizations.dart';
import 'shell_destinations.dart';

/// One destination of the drawer.
class DrawerEntry {
  const DrawerEntry(
    this.key,
    this.icon,
    this.label,
    this.onTap, {
    this.selected = false,
    this.route,
  });
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? route;
}

/// The drawer's entries for one person in one workspace.
class DrawerEntries {
  DrawerEntries({
    required this.context,
    required this.features,
    required this.permissions,
    required this.accountMenu,
    required this.permanent,
    required this.visibleBranches,
    required this.tabTitles,
    required this.currentIndex,
    required this.onBranch,
    required this.go,
  });

  final BuildContext context;
  final Set<WorkspaceFeature> features;
  final Set<WorkspacePermission> permissions;
  final bool accountMenu;
  final bool permanent;
  final List<int> visibleBranches;
  final List<String> tabTitles;
  final int currentIndex;
  final ValueChanged<int> onBranch;

  /// Leaves the drawer and goes (or pushes) to [route].
  final void Function(String route, {bool push}) go;

  AppLocalizations get l10n => context.l10n;
  AppLocalizations get labels => l10n;

  // #2137 — each entry asks the permission its route asks, so a member
  // given it through a role finds the way there.
  bool may(WorkspacePermission p) => permissions.contains(p);

  List<DrawerEntry> navigation() {
    return <DrawerEntry>[
      if (may(WorkspacePermission.makeReservations))
        DrawerEntry(
          'drawer-reserve',
          shellBranchIcon(ShellBranch.reserve),
          lexiconText(
            context,
            key: 'shellReserveButton',
            fallback: l10n.shellReserveButton,
          ),
          () {
            if (!permanent) Navigator.of(context).pop();
            onBranch(ShellBranch.reserve);
          },
          selected: currentIndex == ShellBranch.reserve,
        ),
      for (final branch in visibleBranches)
        DrawerEntry(
          'drawer-tab-$branch',
          shellBranchIcon(branch),
          tabTitles[branch],
          () {
            if (!permanent) Navigator.of(context).pop();
            onBranch(branch);
          },
          selected: currentIndex == branch,
        ),
      // Events live in the calendar when it holds the alerts: no entry then.
      if (features.contains(WorkspaceFeature.eventsTab) &&
          !calendarHoldsAlerts(features) &&
          may(WorkspacePermission.useMessages))
        DrawerEntry(
          'drawer-events',
          Icons.notifications_outlined,
          lexiconText(context, key: 'tabEvents', fallback: l10n.tabEvents),
          () => go('/events', push: false),
        ),
      // The task wizard — recordings, guides and tools — after Finance and
      // Events (it used to hide behind Help's icons).
      if (features.contains(WorkspaceFeature.taskRecorder))
        DrawerEntry(
          'drawer-task-wizard',
          Icons.assistant_navigation,
          l10n.taskWizardTitle,
          () => go(taskWizardRoute),
        ),
    ];
  }

  List<DrawerEntry> administration() {
    return <DrawerEntry>[
      if (may(WorkspacePermission.workspaceSettings))
        DrawerEntry(
          'drawer-workspace-settings',
          Icons.business_outlined,
          l10n.workspaceSettingsTitle,
          () => go('/workspace-settings'),
          route: '/workspace-settings',
        ),
      if (may(WorkspacePermission.manageMembers))
        DrawerEntry(
          'drawer-members',
          Icons.group_outlined,
          l10n.membersTitle,
          () => go('/members'),
          route: '/members',
        ),
      if (may(WorkspacePermission.workspaceSettings))
        DrawerEntry(
          'drawer-availability',
          Icons.event_busy_outlined,
          l10n.availabilityTitle,
          () => go('/availability'),
          route: '/availability',
        ),
      if (may(WorkspacePermission.manageRoles) &&
          features.contains(WorkspaceFeature.roleManagement))
        DrawerEntry(
          'drawer-roles',
          Icons.admin_panel_settings_outlined,
          l10n.rolesTitle,
          () => go('/roles'),
          route: '/roles',
        ),
      if ((may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.issueInvoices)) &&
          features.contains(WorkspaceFeature.invoicing))
        DrawerEntry(
          'drawer-invoices',
          Icons.receipt_long_outlined,
          l10n.invoicesManage,
          () => go('/invoices'),
          route: '/invoices',
        ),
      if (may(WorkspacePermission.manageIntegrations))
        DrawerEntry(
          'drawer-payment-methods',
          Icons.account_balance_wallet_outlined,
          l10n.paymentInstructionsTitle,
          () => go('/payment-methods'),
          route: '/payment-methods',
        ),
      if (may(WorkspacePermission.manageIntegrations) &&
          features.contains(WorkspaceFeature.onlinePayments))
        DrawerEntry(
          'drawer-payment-config',
          Icons.credit_card_outlined,
          l10n.payConfigTitle,
          () => go('/payment-config'),
          route: '/payment-config',
        ),
      if (may(WorkspacePermission.operateKiosk) &&
          features.contains(WorkspaceFeature.nfcBadges))
        DrawerEntry(
          'drawer-nfc-config',
          Icons.nfc_outlined,
          l10n.nfcConfigTitle,
          () => go('/nfc-config'),
          route: '/nfc-config',
        ),
      if (may(WorkspacePermission.manageServices) &&
          features.contains(WorkspaceFeature.services))
        DrawerEntry(
          'drawer-services',
          Icons.room_service_outlined,
          l10n.servicesTitle,
          () => go('/services'),
          route: '/services',
        ),
      if (may(WorkspacePermission.manageServices) &&
          features.contains(WorkspaceFeature.accessorySupplements))
        DrawerEntry(
          'drawer-accessories',
          Icons.chair_outlined,
          l10n.accessoriesTitle,
          () => go('/accessories'),
          route: '/accessories',
        ),
      if (may(WorkspacePermission.manageBilling))
        DrawerEntry(
          'drawer-billing',
          Icons.tune,
          l10n.billingTitle,
          () => go('/billing'),
          route: '/billing',
        ),
      if (may(WorkspacePermission.manageConfiguration))
        DrawerEntry(
          'drawer-features',
          Icons.toggle_on_outlined,
          l10n.featuresTitle,
          () => go('/features'),
          route: '/features',
        ),
      // #2137 — editing the plan is delegable through manageSites.
      if (may(WorkspacePermission.manageSites))
        DrawerEntry(
          'drawer-editor',
          Icons.design_services_outlined,
          l10n.editorOpenTooltip,
          () => go('/editor'),
          route: '/editor',
        ),
    ];
  }

  /// #2313 — Reporting: every report and the BI in one group, one
  /// sub-item per section the Reports page would show this reader.
  List<DrawerEntry> reporting({
    required List<String> sections,
    required bool Function(String id) onSection,
  }) {
    return <DrawerEntry>[
      if (sections.contains('finance'))
        DrawerEntry(
          'drawer-reports-finance',
          Icons.account_balance_outlined,
          labels.uxReportsFinance,
          () => go('/reports?section=finance'),
          selected: onSection('finance'),
        ),
      if (sections.contains('documents'))
        DrawerEntry(
          'drawer-reports-documents',
          Icons.summarize_outlined,
          labels.uxReportsWorkspace,
          () => go('/reports?section=documents'),
          selected: onSection('documents'),
        ),
      // #1923 — the BI area, on every platform.
      if (sections.contains('analytics'))
        DrawerEntry(
          'drawer-bi',
          Icons.insights_outlined,
          labels.biTitle,
          () => go('/bi'),
          route: '/bi',
        ),
      if (sections.contains('templates'))
        DrawerEntry(
          'drawer-reports-templates',
          Icons.edit_note_outlined,
          labels.uxReportsTemplates,
          () => go('/reports?section=templates'),
          selected: onSection('templates'),
        ),
    ];
  }

  List<DrawerEntry> account() {
    return <DrawerEntry>[
      if (features.contains(WorkspaceFeature.documents) &&
          (may(WorkspacePermission.viewDocuments) ||
              may(WorkspacePermission.manageDocuments)))
        DrawerEntry(
          'drawer-documents',
          Icons.folder_open_outlined,
          l10n.documentsTitle,
          () => go('/documents'),
        ),
      DrawerEntry(
        'drawer-privacy',
        Icons.shield_outlined,
        l10n.privacyTitle,
        () => go('/privacy'),
      ),
      // #1598 — the wide shell says the same word as the narrow one: the
      // entry keeps its key and its destination and changes only its
      // name and icon, so a member who administers nothing reads
      // My account here too.
      DrawerEntry(
        'drawer-settings',
        accountMenu ? Icons.account_circle_outlined : Icons.settings_outlined,
        accountMenu ? (l10n.memberAccountTitle) : (l10n.settingsTitle),
        () => go('/settings'),
      ),
    ];
  }
}
