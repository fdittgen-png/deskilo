// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3603 (desk F2, second part) — every page outside the five tabs, inside
// the desk. One ShellRoute holds the routes the router registers beside the
// tabs; from the expanded window class a page whose route is shown on the
// desk (route_classes.dart) gets the navigation beside it, the top bar
// naming its place and the window titled after it. Below that, and for an
// account or public page, the route's page is returned untouched: a phone
// sees exactly what it saw before. The desk stays one element while the
// pages change under it, so it neither rebuilds its state nor animates.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/context_l10n.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/task_recorder/presentation/ui_capture.dart'
    show RecorderWindowObserver;
import '../../features/workspace/providers/workspace_providers.dart';
import '../route_classes.dart';
import 'desk_scaffold.dart';
import 'shell_app_bar.dart';
import 'shell_destinations.dart';
import 'shell_drawer.dart';
import 'shell_menu.dart';
import 'shell_tabs.dart';

/// The routes registered beside the tabs, inside the desk.
ShellRoute deskRoute(List<RouteBase> routes) => ShellRoute(
  // #2142 — a window opened over a desk page reaches the recording too.
  observers: [RecorderWindowObserver()],
  builder: (context, state, child) => DeskPage(child: child),
  routes: routes,
);

/// Where each tab opens, for a tab chosen from a page outside the tabs.
String _branchLocation(int branch) => switch (branch) {
  ShellBranch.messages => '/messages',
  ShellBranch.calendar => '/calendar',
  ShellBranch.directory => '/directory',
  ShellBranch.money => '/money',
  _ => '/reserve',
};

/// The desk around [child] where its route is shown on the desk, else
/// [child] alone.
class DeskPage extends ConsumerWidget {
  const DeskPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final onDesk =
        chromeOf(path) == RouteChrome.desk &&
        showsDesk(context) &&
        // Settings open outside a business too; the desk only inside one.
        (!workspaceChromeAccountRoutes.contains(path) ||
            ref.watch(currentWorkspaceProvider).value != null);
    if (!onDesk) return child;
    final l10n = context.l10n;
    final tabTitles = shellTabTitles(context, l10n);
    final navs = shellNavFor(
      ref.watch(enabledFeaturesSyncProvider),
      ref.watch(myPermissionsProvider),
    );
    final visibleBranches = [for (final n in navs) n.branch];
    final pendingEvents = ref.watch(myPendingEventCountProvider).value ?? 0;
    void onBranch(int branch) => context.go(_branchLocation(branch));
    // No tab is open here (-1): the route's place selects the entry.
    final crumbs = ShellMenu.of(
      context,
      ref,
      permanent: true,
      tabTitles: tabTitles,
      visibleBranches: visibleBranches,
      navs: navs,
      currentIndex: -1,
      onBranch: onBranch,
    ).crumbsOf(path);
    return DeskScaffold(
      navigation: ({required rail}) => ShellDrawer(
        permanent: true,
        rail: rail,
        tabTitles: tabTitles,
        visibleBranches: visibleBranches,
        navs: navs,
        currentIndex: -1,
        pendingEvents: pendingEvents,
        onBranch: onBranch,
      ),
      title: DeskBreadcrumb(crumbs: crumbs),
      place: crumbs.lastOrNull,
      actions: shellBarActions(context, ref, currentIndex: -1),
      body: child,
    );
  }
}

/// The place on screen as the sidebar shows it: "Purchases › Suppliers".
/// The last part is the page's place; the record shown (a member's name)
/// comes with the page's own leaf, not here.
class DeskBreadcrumb extends StatelessWidget {
  const DeskBreadcrumb({required this.crumbs, super.key});

  final List<String> crumbs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      key: const ValueKey('desk-breadcrumb'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, crumb) in crumbs.indexed) ...[
          if (i > 0) Icon(Icons.chevron_right, color: muted),
          Flexible(
            child: Text(
              crumb,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: i == crumbs.length - 1
                  ? null
                  : theme.textTheme.titleMedium?.copyWith(color: muted),
            ),
          ),
        ],
      ],
    );
  }
}
