// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../features/workspace/presentation/widgets/workspace_reports.dart';
//
// The WEB shell's navigation: a hamburger drawer instead of the bottom
// bar and its raised Reserve button. A browser window has the width a
// phone lacks and none of the thumb-reach the bar was built for; the
// drawer keeps the whole height for content and puts EVERY destination
// — the tabs, the Reserve hub, the administration screens, the account
// — grouped by task. Native platforms keep the bar untouched.
import 'package:flutter/material.dart';
import '../../core/l10n/lexicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/navigation_style.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../l10n/app_localizations_en.dart';
import '../../features/workspace/presentation/widgets/workspace_emblem.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../features/events/providers/attention_providers.dart';
import '../../l10n/app_localizations.dart';
import 'shell_destinations.dart';
import '../../features/profile/presentation/widgets/personal_avatar.dart';
import '../../features/task_recorder/presentation/route_classification.dart'
    show taskWizardRoute;

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
  const _Entry(this.key, this.icon, this.label, this.onTap, {this.selected = false, this.route});
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? route;
}

class ShellDrawer extends ConsumerWidget {
  const ShellDrawer({
    super.key,
    required this.tabTitles,
    required this.visibleBranches,
    required this.currentIndex,
    required this.onBranch,
    required this.pendingEvents,
    this.permanent = false,
  });

  final List<String> tabTitles;
  final List<int> visibleBranches;
  final int currentIndex;
  final ValueChanged<int> onBranch;
  final int pendingEvents;
  final bool permanent;

  // #1306 — the bar's own icon table; one list, one set of icons.
  static IconData _branchIcon(int branch) => shellBranchIcon(branch);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final labels = l10n ?? AppLocalizationsEn();
    final theme = Theme.of(context);
    final path = GoRouterState.of(context).uri.path;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final attention = ref.watch(workspaceAttentionProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
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
      if (!permanent) Navigator.of(context).pop();
      if (push) {
        context.push(route);
      } else {
        context.go(route);
      }
    }

    final navigation = <_Entry>[
      if (may(WorkspacePermission.makeReservations))
      _Entry('drawer-reserve', _branchIcon(ShellBranch.reserve),
          lexiconText(context, key: 'shellReserveButton', fallback: l10n?.shellReserveButton ?? 'Reserve'), () {
        if (!permanent) Navigator.of(context).pop();
        onBranch(ShellBranch.reserve);
      }, selected: currentIndex == ShellBranch.reserve),
      for (final branch in visibleBranches)
        _Entry('drawer-tab-$branch', _branchIcon(branch), tabTitles[branch], () {
          if (!permanent) Navigator.of(context).pop();
          onBranch(branch);
        }, selected: currentIndex == branch),
      // Events live in the calendar when it holds the alerts: no entry then.
      if (features.contains(WorkspaceFeature.eventsTab) &&
          !calendarHoldsAlerts(features) &&
          may(WorkspacePermission.useMessages))
        _Entry('drawer-events', Icons.notifications_outlined,
            lexiconText(context, key: 'tabEvents', fallback: l10n?.tabEvents ?? 'Events'), () => go('/events', push: false)),
      // The task wizard — recordings, guides and tools — after Finance and
      // Events (it used to hide behind Help's icons).
      if (features.contains(WorkspaceFeature.taskRecorder))
        _Entry('drawer-task-wizard', Icons.assistant_navigation,
            l10n?.taskWizardTitle ?? 'Task wizard', () => go(taskWizardRoute)),
    ];
    final administration = <_Entry>[
      if (may(WorkspacePermission.workspaceSettings))
        _Entry('drawer-workspace-settings', Icons.business_outlined,
            l10n?.workspaceSettingsTitle ?? 'Workspace',
            () => go('/workspace-settings'), route: '/workspace-settings'),
      if (may(WorkspacePermission.manageMembers))
        _Entry('drawer-members', Icons.group_outlined,
            l10n?.membersTitle ?? 'Members & plans', () => go('/members'), route: '/members'),
      if (may(WorkspacePermission.workspaceSettings))
        _Entry('drawer-availability', Icons.event_busy_outlined,
            l10n?.availabilityTitle ?? 'Availability',
            () => go('/availability'), route: '/availability'),
      if (may(WorkspacePermission.manageRoles) &&
          features.contains(WorkspaceFeature.roleManagement))
        _Entry('drawer-roles', Icons.admin_panel_settings_outlined,
            l10n?.rolesTitle ?? 'Roles', () => go('/roles'), route: '/roles'),
      if ((may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.issueInvoices)) &&
          features.contains(WorkspaceFeature.invoicing))
        _Entry('drawer-invoices', Icons.receipt_long_outlined,
            l10n?.invoicesManage ?? 'Manage invoices',
            () => go('/invoices'), route: '/invoices'),
      if (may(WorkspacePermission.manageIntegrations))
        _Entry('drawer-payment-methods', Icons.account_balance_wallet_outlined,
            l10n?.paymentInstructionsTitle ?? 'Payment instructions',
            () => go('/payment-methods'), route: '/payment-methods'),
      if (may(WorkspacePermission.manageIntegrations) &&
          features.contains(WorkspaceFeature.onlinePayments))
        _Entry('drawer-payment-config', Icons.credit_card_outlined,
            l10n?.payConfigTitle ?? 'Online payments',
            () => go('/payment-config'), route: '/payment-config'),
      if (may(WorkspacePermission.operateKiosk) &&
          features.contains(WorkspaceFeature.nfcBadges))
        _Entry('drawer-nfc-config', Icons.nfc_outlined,
            l10n?.nfcConfigTitle ?? 'RFID / NFC badges', () => go('/nfc-config'), route: '/nfc-config'),
      if (may(WorkspacePermission.manageServices) &&
          features.contains(WorkspaceFeature.services))
        _Entry('drawer-services', Icons.room_service_outlined,
            l10n?.servicesTitle ?? 'Services', () => go('/services'), route: '/services'),
      if (may(WorkspacePermission.manageServices) &&
          features.contains(WorkspaceFeature.accessorySupplements))
        _Entry('drawer-accessories', Icons.chair_outlined,
            l10n?.accessoriesTitle ?? 'Accessories', () => go('/accessories'), route: '/accessories'),
      if (may(WorkspacePermission.manageBilling))
        _Entry('drawer-billing', Icons.tune, l10n?.billingTitle ?? 'Billing',
            () => go('/billing'), route: '/billing'),
      if (may(WorkspacePermission.manageConfiguration))
        _Entry('drawer-features', Icons.toggle_on_outlined,
            l10n?.featuresTitle ?? 'Features', () => go('/features'), route: '/features'),
      // #2137 — editing the plan is delegable through manageSites.
      if (may(WorkspacePermission.manageSites))
        _Entry('drawer-editor', Icons.design_services_outlined,
            l10n?.editorOpenTooltip ?? 'Edit workspace', () => go('/editor'), route: '/editor'),
    ];
    // #2313 — Reporting: every report and the BI in one group, one
    // sub-item per section the Reports page would show this reader.
    final member = ref.watch(myMemberProvider).value;
    final sections = reportingSections(
      features: features,
      permissions: perms,
      isAdmin: member?.isAdmin ?? false,
      actsAsOwner: member?.actsAsOwner ?? false,
    );
    final section = GoRouterState.of(context).uri.queryParameters['section'];
    bool onSection(String id) => path == '/reports' &&
        (section ?? sections.where((s) => s != 'analytics').firstOrNull) == id;
    final reporting = <_Entry>[
      if (sections.contains('finance'))
        _Entry('drawer-reports-finance', Icons.account_balance_outlined, labels.uxReportsFinance,
            () => go('/reports?section=finance'), selected: onSection('finance')),
      if (sections.contains('documents'))
        _Entry('drawer-reports-documents', Icons.summarize_outlined, labels.uxReportsWorkspace,
            () => go('/reports?section=documents'), selected: onSection('documents')),
      // #1923 — the BI area, on every platform.
      if (sections.contains('analytics'))
        _Entry('drawer-bi', Icons.insights_outlined, labels.biTitle, () => go('/bi'), route: '/bi'),
      if (sections.contains('templates'))
        _Entry('drawer-reports-templates', Icons.edit_note_outlined, labels.uxReportsTemplates,
            () => go('/reports?section=templates'), selected: onSection('templates')),
    ];
    final account = <_Entry>[
      if (features.contains(WorkspaceFeature.documents) &&
          (may(WorkspacePermission.viewDocuments) ||
              may(WorkspacePermission.manageDocuments)))
        _Entry('drawer-documents', Icons.folder_open_outlined,
            l10n?.documentsTitle ?? 'Documents', () => go('/documents')),
      _Entry('drawer-privacy', Icons.shield_outlined,
          l10n?.privacyTitle ?? 'Privacy & data', () => go('/privacy')),
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

    // #2313 — one line per entry: a label that wraps onto three lines in
    // a sidebar reads as fragments; it is cut with an ellipsis instead and
    // the tooltip-free full name stays in the semantics label.
    Widget tile(_Entry e) => ListTile(
          key: ValueKey(e.key),
          leading: Icon(e.icon),
          title: Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          horizontalTitleGap: AppSpacing.md,
          minLeadingWidth: 24,
          selected: e.selected || (e.route != null &&
              (path == e.route || path.startsWith('${e.route}/'))),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
          selectedColor: Theme.of(context).colorScheme.onSecondaryContainer,
          // Every badge opens the content it counts (#1306 S3): the events
          // entry while the bell is on, the Calendar entry when the
          // calendar carries the decisions instead.
          trailing: e.key == 'drawer-events' && attention.total > 0
              ? Badge.count(count: attention.total, maxCount: 99)
              : e.key == 'drawer-tab-${ShellBranch.money}' && attention.money > 0
                  ? Badge.count(count: attention.money, maxCount: 99)
              : pendingEvents > 0 && e.key == 'drawer-tab-${ShellBranch.calendar}' &&
                  decisionSignalOnCalendar(features) ? Badge.count(count: pendingEvents, maxCount: 99) : null,
          onTap: e.onTap,
        );

    Widget group(String id, String title, IconData icon, Set<String> keys,
        {List<_Entry>? from}) {
      final entries = (from ?? administration).where((e) => keys.contains(e.key)).toList();
      final active = entries.any((e) => e.selected || path == e.route || path.startsWith('${e.route}/'));
      if (entries.isEmpty) return const SizedBox.shrink();
      return ExpansionTile(
        key: PageStorageKey('drawer-group-$id-$active'),
        initiallyExpanded: active,
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        leading: Icon(icon),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        shape: const Border(), collapsedShape: const Border(),
        children: [for (final e in entries) tile(e)],
      );
    }

    // #2313 — one type for every entry and every group title (Material's
    // navigation-drawer label), so the menu reads as one list.
    final content = SafeArea(
        child: ListTileTheme(
          data: ListTileThemeData(titleTextStyle: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurface)),
          child: ListView(
          padding: AppSpacing.smH,
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
            if (reporting.isNotEmpty) ...[
              const Divider(),
              group('reporting', labels.uxNavReporting, Icons.analytics_outlined, {
                for (final e in reporting) e.key,
              }, from: reporting),
            ],
            if (administration.isNotEmpty) ...[
              const Divider(),
              group('people', labels.uxNavPeople, Icons.group_outlined, {
                'drawer-members', 'drawer-roles', 'drawer-nfc-config',
              }),
              group('finance', labels.uxNavFinance, Icons.receipt_long_outlined, {
                'drawer-invoices', 'drawer-billing', 'drawer-payment-methods',
                'drawer-payment-config',
              }),
              group('workspace', labels.uxNavWorkspace, Icons.business_outlined, {
                'drawer-workspace-settings', 'drawer-availability', 'drawer-services',
                'drawer-accessories', 'drawer-features', 'drawer-editor',
              }),
            ],
            const Divider(),
            for (final e in account) tile(e),
          ],
        ),
      ));
    return permanent
        ? Material(key: const ValueKey('shell-sidebar'),
            color: theme.colorScheme.surfaceContainerLow, child: content)
        : Drawer(key: const ValueKey('shell-drawer'), child: content);
  }
}
