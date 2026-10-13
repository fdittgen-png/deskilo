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
import '../../features/profile/presentation/widgets/personal_avatar.dart';
import '../../features/workspace/domain/member.dart' show CoOwnerStatus;
import '../../features/workspace/domain/workspace_permission.dart';
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
    );
    final navigation = entries.navigation();
    final administration = entries.administration();
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
    int badgeOf(DrawerEntry e) => e.key == 'drawer-events'
        ? attention.total
        : e.key == 'drawer-tab-${ShellBranch.money}'
            ? attention.money
            : e.key == 'drawer-tab-${ShellBranch.calendar}' &&
                    decisionSignalOnCalendar(features)
                ? pendingEvents
                : 0;
    Widget tile(DrawerEntry e) =>
        DrawerTile(entry: e, path: path, badge: badgeOf(e));
    Widget group(String id, String title, IconData icon, Set<String> keys,
            {List<DrawerEntry>? from}) =>
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
