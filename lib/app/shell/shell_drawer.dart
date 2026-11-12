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
import '../../features/money/domain/purchase_approval_reads.dart';
import '../../features/money/presentation/widgets/purchases_sheet.dart';
import '../../features/money/providers/purchase_approval_provider.dart';
import '../../features/profile/presentation/widgets/personal_avatar.dart';
import '../../features/workspace/domain/member.dart' show CoOwnerStatus;
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/presentation/widgets/workspace_emblem.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'desk_rail.dart';
import 'purchase_approval_badge.dart';
import 'shell_destinations.dart';
import 'shell_drawer_entries.dart';
import 'shell_drawer_tiles.dart';
import 'shell_menu.dart';
import 'shell_nav_groups.dart';

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
          (m) => m.isOwner || m.isAdmin || m.coOwner == CoOwnerStatus.active,
        );
  return defaultNavigationStyle(
    isPhone: ref.watch(deviceIsPhoneProvider),
    everydayOnly: everydayOnly,
  );
}

/// #3070 — the documents waiting for the signed-in person's decision; read
/// only for who may decide, so nobody else loads the list for a badge.
AsyncValue<PurchaseApprovalPage>? _waitingApprovals(
  WidgetRef ref,
  String? workspaceId,
  Set<WorkspaceFeature> features,
  Set<WorkspacePermission> permissions,
) {
  if (workspaceId == null ||
      !features.contains(WorkspaceFeature.purchases) ||
      !permissions.contains(WorkspacePermission.approveExpenses)) {
    return null;
  }
  return ref.watch(
    purchaseApprovalPageProvider((workspaceId: workspaceId, after: null)),
  );
}

void _openToPay(
  BuildContext context,
  String workspaceId,
  Set<WorkspacePermission> permissions, {
  required bool permanent,
}) {
  final navigator = Navigator.of(context);
  if (!permanent) navigator.pop();
  unawaited(showPurchasesSheet(
    navigator.context,
    workspaceId,
    canCapture: permissions.contains(WorkspacePermission.managePurchases),
    canPay: permissions.contains(WorkspacePermission.recordOutgoingPayments),
    canDecide: permissions.contains(WorkspacePermission.approveExpenses),
    canOffset: permissions.contains(WorkspacePermission.issueInvoices),
    toPay: true,
  ));
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
    this.rail = false,
    this.navs,
  });

  final List<String> tabTitles;
  final List<int> visibleBranches;

  /// #3551 — the destinations of the shell's table; null: one per branch.
  final List<ShellNav>? navs;
  final int currentIndex;
  final ValueChanged<int> onBranch;
  final int pendingEvents;
  final bool permanent;

  /// #3603 — the desk's narrow form: icons with short labels, the groups
  /// as flyouts. Only with [permanent].
  final bool rail;

  // #1306 — the bar's own icon table; one list, one set of icons.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final path = GoRouterState.of(context).uri.path;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final attention = ref.watch(workspaceAttentionProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final perms = ref.watch(myPermissionsProvider);
    final menu = ShellMenu.of(
      context,
      ref,
      permanent: permanent,
      tabs: (
        tabTitles: tabTitles,
        visibleBranches: visibleBranches,
        navs: navs,
        currentIndex: currentIndex,
        onBranch: onBranch,
      ),
      openToPay: workspace == null
          ? null
          : () => _openToPay(context, workspace.id, perms, permanent: permanent),
    );
    final navigation = menu.navigation;
    final administration = menu.administration;
    final account = menu.account;
    final groups = menu.groups;
    void backToMe() {
      if (!permanent) Navigator.of(context).pop();
      context.go('/me');
    }

    // Every badge opens the content it counts (#1306 S3): the events
    // entry while the bell is on, the Calendar entry when the calendar
    // carries the decisions instead.
    final approvals = _waitingApprovals(ref, workspace?.id, features, perms);
    final badges = <String, int>{
      'drawer-events': attention.total,
      'drawer-tab-${ShellBranch.money}': attention.money,
      if (decisionSignalOnCalendar(features))
        'drawer-tab-${ShellBranch.calendar}': pendingEvents,
    };
    int badgeOf(DrawerEntry e) => badges[e.key] ?? 0;
    Widget tile(DrawerEntry e) => DrawerTile(
      entry: e,
      path: path,
      badge: badgeOf(e),
      trailing: e.key == 'drawer-purchase-approvals' && approvals != null
          ? PurchaseApprovalBadge(value: approvals)
          : null,
    );
    // #3603 — the desk's rail: the same destinations and groups.
    if (rail) {
      return DeskRail(
        destinations: navigation,
        groups: groups,
        account: account,
        path: path,
        badgeOf: badgeOf,
        onBackToMe: backToMe,
      );
    }
    // #3603 — a group is open while it or one of its sub-groups is current.
    bool current(NavGroup g) =>
        groupIsCurrent(g.id, g.entries, path) || g.sub.any(current);
    Widget group(NavGroup g) => DrawerGroup(
      id: g.id, title: g.title, icon: g.icon, entries: g.entries,
      path: path, tile: tile, active: current(g),
      after: [for (final s in g.sub) if (!s.isEmpty) group(s)],
    );

    final content = SafeArea(
        child: ListTileTheme(
        data: ListTileThemeData(
          titleTextStyle: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
          child: ListView(
          padding: AppSpacing.smH,
          children: [
            _drawerHeading(workspace?.name ?? 'DesKilo', theme),
            ListTile(
              key: const ValueKey('drawer-back-to-me'),
              leading: const PersonalAvatar(),
              title: Text(l10n.spaceBackToMe),
              subtitle: Text(l10n.meMySpaces),
              onTap: backToMe,
            ),
            const Divider(),
            for (final e in navigation) tile(e),
            if (!groups.first.isEmpty) ...[
              const Divider(),
              group(groups.first),
            ],
            if (administration.isNotEmpty) const Divider(),
            // Each group hides itself when empty (shell_nav_groups.dart).
            for (final g in groups.skip(1)) group(g),
            const Divider(),
            for (final e in account) tile(e),
          ],
        ),
      ),
    );
    return permanent
        ? Material(
            key: const ValueKey('shell-sidebar'),
            color: theme.colorScheme.surfaceContainerLow,
            child: content,
          )
        : Drawer(key: const ValueKey('shell-drawer'), child: content);
  }
}

Widget _drawerHeading(String name, ThemeData theme) => Padding(
  padding: AppSpacing.lgAll,
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Text(name, key: const ValueKey('drawer-workspace-name'), style: theme.textTheme.titleLarge),
    const WorkspaceEmblem(key: ValueKey('drawer-emblem')),
  ]),
);
