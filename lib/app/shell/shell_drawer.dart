// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The WEB shell's navigation: a hamburger drawer instead of the bottom
// bar and its raised Reserve button. A browser window has the width a
// phone lacks and none of the thumb-reach the bar was built for; the
// drawer keeps the whole height for content and puts EVERY destination
// — the tabs, the Reserve hub, the administration screens, the account
// — grouped by task. Native platforms keep the bar untouched.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/navigation/navigation_style.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/events/providers/attention_providers.dart';
import '../../features/money/providers/purchase_providers.dart';
import '../../features/profile/presentation/widgets/personal_avatar.dart';
import '../../features/workspace/domain/member.dart' show CoOwnerStatus;
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/presentation/widgets/setup_resume_banner.dart' show setupGuideOpenFor;
import '../../features/workspace/presentation/widgets/workspace_emblem.dart';
import '../../features/workspace/presentation/widgets/workspace_reports.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'shell_destinations.dart';
import 'shell_drawer_entries.dart';
import 'shell_drawer_tiles.dart';

part 'shell_drawer.g.dart';

/// #2414 — the navigation a device that never chose gets. "Everyday
/// only" is a member whose permissions in this space are the everyday
/// six at most; outside a space (Me), one who runs no space at all.
@Riverpod(keepAlive: true)
NavigationStyle navigationDefault(Ref ref) {
  final inSpace = ref.watch(myMemberProvider).value != null;
  final everydayOnly = inSpace
      ? holdsOnlyEverydayPermissions(ref.watch(myPermissionsProvider))
      : !(ref.watch(myMembershipsProvider).value ?? const []).any(
          (m) => m.isOwner || m.isAdmin || m.coOwner == CoOwnerStatus.active);
  return defaultNavigationStyle(
    isPhone: ref.watch(deviceIsPhoneProvider),
    everydayOnly: everydayOnly,
  );
}

/// #3070 — the documents waiting for the signed-in person's decision; read
/// only for who may decide, so nobody else loads the list for a badge.
int waitingApprovals(
  WidgetRef ref,
  String? workspaceId,
  Set<WorkspaceFeature> features,
  Set<WorkspacePermission> permissions,
) {
  if (workspaceId == null ||
      !features.contains(WorkspaceFeature.purchases) ||
      !permissions.contains(WorkspacePermission.approveExpenses)) {
    return 0;
  }
  return ref.watch(pendingApprovalsProvider(workspaceId)).value?.length ?? 0;
}

/// Whether the shell navigates through the drawer — the web build
/// always, native per the user's choice (#969) or the device's default
/// (#2414), and tests that ask for it.
@Riverpod(keepAlive: true)
bool webShell(Ref ref) => shellUsesMenu(
      platformIsWeb: ref.watch(platformIsWebProvider),
      override: ref.watch(navigationStyleControllerProvider).value,
      fallback: ref.watch(navigationDefaultProvider),
    );

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
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final labels = l10n;
    final theme = Theme.of(context);
    final path = GoRouterState.of(context).uri.path;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final attention = ref.watch(workspaceAttentionProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final perms = ref.watch(myPermissionsProvider);
    // #1598 — the effective permission set, watched, decides the account
    // entry's name in the drawer exactly as it does in the app bar.
    final accountMenu = showsMemberAccountMenu(
      features: features,
      permissions: ref.watch(myPermissionsProvider),
    );

    void go(String route, {bool push = true}) {
      if (!permanent) Navigator.of(context).pop();
      if (push) {
        unawaited(context.push(route));
      } else {
        context.go(route);
      }
    }

    final entries = DrawerEntries(
      context: context,
      features: features,
      permissions: perms,
      accountMenu: accountMenu,
      permanent: permanent,
      visibleBranches: visibleBranches,
      tabTitles: tabTitles,
      currentIndex: currentIndex,
      onBranch: onBranch,
      go: go,
      setupOpen: setupGuideOpenFor(ref, workspace?.id),
    );
    final navigation = entries.navigation();
    final administration = [...entries.setupGuide(), ...entries.administration()];
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
    final reporting = entries.reporting(sections: sections, onSection: onSection);
    final account = entries.account();

    // Every badge opens the content it counts (#1306 S3): the events
    // entry while the bell is on, the Calendar entry when the calendar
    // carries the decisions instead.
    final badges = <String, int>{
      'drawer-events': attention.total,
      'drawer-tab-${ShellBranch.money}': attention.money,
      if (decisionSignalOnCalendar(features))
        'drawer-tab-${ShellBranch.calendar}': pendingEvents,
      'drawer-purchase-approvals': waitingApprovals(
        ref,
        workspace?.id,
        features,
        perms,
      ),
    };
    int badgeOf(DrawerEntry e) => badges[e.key] ?? 0;
    Widget tile(DrawerEntry e) =>
        DrawerTile(entry: e, path: path, badge: badgeOf(e));
    Widget group(String id, String title, IconData icon, Set<String> keys,
            {List<DrawerEntry>? from, List<Widget> after = const []}) =>
        DrawerGroup(
          id: id,
          title: title,
          icon: icon,
          entries: [
            for (final e in from ?? administration)
              if (keys.contains(e.key)) e,
          ],
          path: path,
          tile: tile,
          after: after,
        );

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
              title: Text(l10n.spaceBackToMe),
              subtitle: Text(l10n.meMySpaces),
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
            if (administration.isNotEmpty) const Divider(),
            // Each group hides itself when empty. A financial permission
            // must not depend on having an unrelated administration door.
            group('people', labels.uxNavPeople, Icons.group_outlined, {
              'drawer-members', 'drawer-roles', 'drawer-nfc-config',
            }),
            ..._financeGroups(group, tile, entries, administration),
            group('workspace', labels.uxNavWorkspace, Icons.business_outlined, {
              'drawer-setup-guide', 'drawer-workspace-settings', 'drawer-availability',
              'drawer-features', 'drawer-editor',
            }),
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

typedef _GroupBuilder = Widget Function(
  String id,
  String title,
  IconData icon,
  Set<String> keys, {
  List<DrawerEntry>? from,
  List<Widget> after,
});

/// The sales, purchases and finance groups of the drawer: Sales and
/// Purchases open their pages and carry what is sold, Finance carries the
/// accounting and VAT sub-group.
List<Widget> _financeGroups(
  _GroupBuilder group,
  Widget Function(DrawerEntry) tile,
  DrawerEntries entries,
  List<DrawerEntry> administration,
) {
  final labels = entries.l10n;
  final money = entries.money();
  final accounting = entries.accounting();
  final all = [...money, ...administration];
  return [
    group('sales', labels.hubSalesTitle, Icons.sell_outlined, {
      'drawer-sales', 'drawer-invoices', 'drawer-services',
      'drawer-accessories',
    }, from: all),
    group('purchases', labels.navPurchasesGroup, Icons.shopping_cart_outlined, {
      'drawer-purchases', 'drawer-suppliers', 'drawer-purchase-approvals',
    }, from: all),
    group('finance', labels.uxNavFinance, Icons.receipt_long_outlined, {
      'drawer-cash', 'drawer-billing', 'drawer-payment-methods',
      'drawer-payment-config',
    }, from: all, after: [
      // Built only with a door inside: an empty sub-group would keep the
      // Finance header for a member with no finance entry at all.
      if (accounting.isNotEmpty)
        group('accounting', labels.hubAccountingTitle, Icons.menu_book_outlined, {
          for (final e in accounting) e.key,
        }, from: accounting),
    ]),
  ];
}
