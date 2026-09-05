// SPDX-License-Identifier: 0BSD
//
// The WEB shell's navigation: a hamburger drawer instead of the bottom
// bar and its raised Reserve button. A browser window has the width a
// phone lacks and none of the thumb-reach the bar was built for; the
// drawer keeps the whole height for content and puts EVERY destination
// — the tabs, the Reserve hub, the administration screens, the account
// — one tap away. Native platforms keep the bar untouched.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../router.dart';

/// Whether the shell navigates through the drawer — the web build, and
/// tests that ask for it.
final webShellProvider = Provider<bool>((_) => kIsWeb);

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

  static IconData _branchIcon(int branch) => switch (branch) {
        ShellBranch.calendar => Icons.calendar_month_outlined,
        ShellBranch.directory => Icons.people_outline,
        ShellBranch.money => Icons.account_balance_wallet_outlined,
        ShellBranch.reserve => Icons.event_seat_outlined,
        _ => Icons.forum_outlined,
      };

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
          l10n?.shellReserveButton ?? 'Reserve', () {
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
            l10n?.tabEvents ?? 'Events', () => go('/events', push: false)),
    ];
    final administration = <_Entry>[
      if (isOwner)
        _Entry('drawer-workspace-settings', Icons.business_outlined,
            l10n?.workspaceSettingsTitle ?? 'Workspace',
            () => go('/workspace-settings')),
      if (showAdminSection)
        _Entry('drawer-members', Icons.group_outlined,
            l10n?.membersTitle ?? 'Members & plans', () => go('/members')),
      if (isOwner)
        _Entry('drawer-availability', Icons.event_busy_outlined,
            l10n?.availabilityTitle ?? 'Availability',
            () => go('/availability')),
      if (showAdminSection &&
          features.contains(WorkspaceFeature.roleManagement))
        _Entry('drawer-roles', Icons.admin_panel_settings_outlined,
            l10n?.rolesTitle ?? 'Role management', () => go('/roles')),
      if (showAdminSection && features.contains(WorkspaceFeature.invoicing))
        _Entry('drawer-invoices', Icons.receipt_long_outlined,
            l10n?.settingsBillingReports ?? 'Billing & reports',
            () => go('/invoices')),
      if (isOwner)
        _Entry('drawer-payment-methods', Icons.account_balance_wallet_outlined,
            l10n?.paymentInstructionsTitle ?? 'Payment instructions',
            () => go('/payment-methods')),
      if (isOwner && features.contains(WorkspaceFeature.onlinePayments))
        _Entry('drawer-payment-config', Icons.credit_card_outlined,
            l10n?.payConfigTitle ?? 'Online payments',
            () => go('/payment-config')),
      if (isOwner && features.contains(WorkspaceFeature.nfcBadges))
        _Entry('drawer-nfc-config', Icons.nfc_outlined,
            l10n?.nfcConfigTitle ?? 'RFID / NFC badges', () => go('/nfc-config')),
      if (isOwner && features.contains(WorkspaceFeature.services))
        _Entry('drawer-services', Icons.room_service_outlined,
            l10n?.servicesTitle ?? 'Services', () => go('/services')),
      if (canAdminister &&
          features.contains(WorkspaceFeature.accessorySupplements))
        _Entry('drawer-accessories', Icons.chair_outlined,
            l10n?.accessoriesTitle ?? 'Accessories', () => go('/accessories')),
      if (isOwner)
        _Entry('drawer-billing', Icons.tune, l10n?.billingTitle ?? 'Billing',
            () => go('/billing')),
      if (isOwner)
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
      _Entry('drawer-settings', Icons.settings_outlined,
          l10n?.settingsTitle ?? 'Settings', () => go('/settings')),
    ];

    Widget tile(_Entry e) => ListTile(
          key: ValueKey(e.key),
          leading: Icon(e.icon),
          title: Text(e.label),
          selected: e.selected,
          trailing: e.key == 'drawer-events' && pendingEvents > 0
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
              child: Text(
                workspace?.name ?? 'DesKilo',
                key: const ValueKey('drawer-workspace-name'),
                style: theme.textTheme.titleLarge,
              ),
            ),
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
