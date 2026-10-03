// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The WEB shell's navigation: a hamburger drawer instead of the bottom
// bar and its raised Reserve button. A browser window has the width a
// phone lacks and none of the thumb-reach the bar was built for; the
// drawer keeps the whole height for content and puts EVERY destination
// — the tabs, the Reserve hub, the administration screens, the account
// — one tap away. Native platforms keep the bar untouched.
import 'package:flutter/material.dart';
import '../../core/l10n/lexicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/navigation_style.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/workspace/presentation/widgets/workspace_emblem.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../features/workspace/domain/bi_modules.dart';
import 'shell_destinations.dart';
import '../../features/profile/presentation/widgets/personal_avatar.dart';
import '../../features/task_recorder/presentation/route_classification.dart'
    show taskRecorderRoute;

part 'shell_drawer.g.dart';

/// Whether the shell navigates through the drawer — the web build
/// always, native when the user chose the menu (#969), and tests that
/// ask for it.
@Riverpod(keepAlive: true)
bool webShell(Ref ref) => shellUsesMenu(
      platformIsWeb: ref.watch(platformIsWebProvider),
      override: ref.watch(navigationStyleControllerProvider).value,
    );

/// One destination of the drawer.
class _Entry {
  const _Entry(this.key, this.icon, this.label, this.onTap, {this.selected = false});
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
}

class ShellDrawer extends ConsumerWidget {
  const ShellDrawer({
    super.key,
    required this.tabTitles,
    required this.visibleBranches,
    required this.currentIndex,
    required this.onBranch,
    required this.pendingEvents,
  });

  final List<String> tabTitles;
  final List<int> visibleBranches;
  final int currentIndex;
  final ValueChanged<int> onBranch;
  final int pendingEvents;

  // #1306 — the bar's own icon table; one list, one set of icons.
  static IconData _branchIcon(int branch) => shellBranchIcon(branch);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final features = ref.watch(enabledFeaturesSyncProvider);
    final me = ref.watch(myMemberProvider).value;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final isOwner = me?.actsAsOwner ?? false;
    final canAdminister = me?.canAdminister ?? false;
    final showAdminSection = isOwner || canAdminister;
    // #2137 — each entry asks the permission its route asks, so a member
    // given it through a role finds the way there.
    final perms = ref.watch(myPermissionsProvider);
    bool may(WorkspacePermission p) => perms.contains(p);
    // #1598 — the effective permission set, watched, decides the account
    // entry's name in the drawer exactly as it does in the app bar.
    final accountMenu = showsMemberAccountMenu(
      features: features,
      permissions: ref.watch(myPermissionsProvider),
    );

    void go(String route, {bool push = true}) {
      Navigator.of(context).pop();
      if (push) {
        context.push(route);
      } else {
        context.go(route);
      }
    }

    final navigation = <_Entry>[
      _Entry('drawer-reserve', _branchIcon(ShellBranch.reserve),
          lexiconText(context, key: 'shellReserveButton', fallback: l10n?.shellReserveButton ?? 'Reserve'), () {
        Navigator.of(context).pop();
        onBranch(ShellBranch.reserve);
      }, selected: currentIndex == ShellBranch.reserve),
      for (final branch in visibleBranches)
        _Entry('drawer-tab-$branch', _branchIcon(branch), tabTitles[branch], () {
          Navigator.of(context).pop();
          onBranch(branch);
        }, selected: currentIndex == branch),
      if (features.contains(WorkspaceFeature.eventsTab))
        _Entry('drawer-events', Icons.notifications_outlined,
            lexiconText(context, key: 'tabEvents', fallback: l10n?.tabEvents ?? 'Events'), () => go('/events', push: false)),
    ];
    final administration = <_Entry>[
      if (may(WorkspacePermission.workspaceSettings))
        _Entry('drawer-workspace-settings', Icons.business_outlined,
            l10n?.workspaceSettingsTitle ?? 'Workspace',
            () => go('/workspace-settings')),
      if (canAdminister || may(WorkspacePermission.manageMembers))
        _Entry('drawer-members', Icons.group_outlined,
            l10n?.membersTitle ?? 'Members & plans', () => go('/members')),
      if (may(WorkspacePermission.workspaceSettings))
        _Entry('drawer-availability', Icons.event_busy_outlined,
            l10n?.availabilityTitle ?? 'Availability',
            () => go('/availability')),
      // #1923 — the BI area: the web build only, never a native menu.
      if (biAvailable(
          platformIsWeb: ref.watch(platformIsWebProvider),
          features: features,
          permissions: ref.watch(myPermissionsProvider)))
        _Entry('drawer-bi', Icons.insights_outlined,
            l10n?.biTitle ?? 'Business analytics', () => go('/bi')),
      if ((showAdminSection || perms.isNotEmpty) &&
          features.contains(WorkspaceFeature.roleManagement))
        _Entry('drawer-roles', Icons.admin_panel_settings_outlined,
            l10n?.rolesTitle ?? 'Roles', () => go('/roles')),
      if ((showAdminSection ||
              may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.issueInvoices)) &&
          features.contains(WorkspaceFeature.invoicing))
        _Entry('drawer-invoices', Icons.receipt_long_outlined,
            l10n?.settingsBillingReports ?? 'Billing & reports',
            () => go('/invoices')),
      if (may(WorkspacePermission.manageIntegrations))
        _Entry('drawer-payment-methods', Icons.account_balance_wallet_outlined,
            l10n?.paymentInstructionsTitle ?? 'Payment instructions',
            () => go('/payment-methods')),
      if (may(WorkspacePermission.manageIntegrations) &&
          features.contains(WorkspaceFeature.onlinePayments))
        _Entry('drawer-payment-config', Icons.credit_card_outlined,
            l10n?.payConfigTitle ?? 'Online payments',
            () => go('/payment-config')),
      if (may(WorkspacePermission.operateKiosk) &&
          features.contains(WorkspaceFeature.nfcBadges))
        _Entry('drawer-nfc-config', Icons.nfc_outlined,
            l10n?.nfcConfigTitle ?? 'RFID / NFC badges', () => go('/nfc-config')),
      if (may(WorkspacePermission.manageServices) &&
          features.contains(WorkspaceFeature.services))
        _Entry('drawer-services', Icons.room_service_outlined,
            l10n?.servicesTitle ?? 'Services', () => go('/services')),
      if ((canAdminister || may(WorkspacePermission.manageServices)) &&
          features.contains(WorkspaceFeature.accessorySupplements))
        _Entry('drawer-accessories', Icons.chair_outlined,
            l10n?.accessoriesTitle ?? 'Accessories', () => go('/accessories')),
      if (may(WorkspacePermission.manageBilling))
        _Entry('drawer-billing', Icons.tune, l10n?.billingTitle ?? 'Billing',
            () => go('/billing')),
      if (may(WorkspacePermission.manageConfiguration))
        _Entry('drawer-features', Icons.toggle_on_outlined,
            l10n?.featuresTitle ?? 'Features', () => go('/features')),
      if (isOwner)
        _Entry('drawer-editor', Icons.design_services_outlined,
            l10n?.editorOpenTooltip ?? 'Edit workspace', () => go('/editor')),
    ];
    final account = <_Entry>[
      if (features.contains(WorkspaceFeature.documents))
        _Entry('drawer-documents', Icons.folder_open_outlined,
            l10n?.documentsTitle ?? 'Documents', () => go('/documents')),
      _Entry('drawer-privacy', Icons.shield_outlined,
          l10n?.privacyTitle ?? 'Privacy & data', () => go('/privacy')),
      // #2142 — a labelled way to record a task, beside Help's icon.
      if (features.contains(WorkspaceFeature.taskRecorder))
        _Entry('drawer-record-task', Icons.fiber_manual_record_outlined,
            l10n?.taskRecorderRecordATask ?? 'Record a task',
            () => go(taskRecorderRoute)),
      // #1598 — the wide shell says the same word as the narrow one: the
      // entry keeps its key and its destination and changes only its
      // name and icon, so a member who administers nothing reads
      // My account here too.
      _Entry(
          'drawer-settings',
          accountMenu ? Icons.account_circle_outlined : Icons.settings_outlined,
          accountMenu
              ? (l10n?.memberAccountTitle ?? 'My account')
              : (l10n?.settingsTitle ?? 'Settings'),
          () => go('/settings')),
    ];

    Widget tile(_Entry e) => ListTile(
          key: ValueKey(e.key),
          leading: Icon(e.icon),
          title: Text(e.label),
          selected: e.selected,
          // Every badge opens the content it counts (#1306 S3): the events
          // entry while the bell is on, the Calendar entry when the
          // calendar carries the decisions instead.
          trailing: pendingEvents > 0 &&
                  (e.key == 'drawer-events' ||
                      (e.key == 'drawer-tab-${ShellBranch.calendar}' &&
                          decisionSignalOnCalendar(features)))
              ? Badge.count(count: pendingEvents)
              : null,
          onTap: e.onTap,
        );

    return Drawer(
      key: const ValueKey('shell-drawer'),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: AppSpacing.lgAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    workspace?.name ?? 'DesKilo',
                    key: const ValueKey('drawer-workspace-name'),
                    style: theme.textTheme.titleLarge,
                  ),
                  // #1289 — the space's own mark, beneath the product's
                  // name, and nothing at all when it has none.
                  const WorkspaceEmblem(key: ValueKey('drawer-emblem')),
                ],
              ),
            ),
            ListTile(
              key: const ValueKey('drawer-back-to-me'),
              leading: const PersonalAvatar(),
              title: Text(l10n?.spaceBackToMe ?? 'Back to Me'),
              subtitle: Text(l10n?.meMySpaces ?? 'My spaces'),
              onTap: () => go('/me', push: false),
            ),
            const Divider(),
            for (final e in navigation) tile(e),
            if (administration.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
                child: Text(
                  l10n?.settingsSectionAdministration ?? 'Administration',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              for (final e in administration) tile(e),
            ],
            const Divider(),
            for (final e in account) tile(e),
          ],
        ),
      ),
    );
  }
}
