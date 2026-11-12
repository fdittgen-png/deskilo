// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3603 (desk F2, second part) — the business on a desk, around the whole
// app rather than inside its routes. From the expanded window class a page
// whose route is shown on the desk (route_classes.dart) is drawn beside the
// navigation, under a top bar that names its place, in a window titled
// after it; the five tabs and every page opened over them alike. The desk is
// drawn around the router's own navigator: the pages, their back arrows,
// dialogs and sheets are exactly where they are without it, and a phone
// never meets it. Being above the navigator, the desk brings its own overlay
// (tooltips, menus) and the router (go, push); while a dialog or a sheet is
// open over the page, the navigation beside it rests under the same scrim.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/l10n/context_l10n.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'desk_scaffold.dart';
import 'shell_app_bar.dart';
import 'shell_destinations.dart';
import 'shell_drawer.dart';
import 'shell_menu.dart';
import 'shell_tabs.dart';

part 'desk_frame.g.dart';

/// Watches the router's navigator for a window opened over the page (a
/// dialog, a sheet, a menu page): the desk's navigation takes no input while
/// one is open, and lies under its scrim.
class DeskModalObserver extends NavigatorObserver {
  final List<PopupRoute<dynamic>> _open = [];

  /// The scrim of the window on top; null while none is open.
  final ValueNotifier<Color?> scrim = ValueNotifier(null);

  void _changed() => scrim.value = _open.isEmpty
      ? null
      : (_open.last.barrierColor ?? Colors.transparent);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      _open.add(route);
      _changed();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _gone(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _gone(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _gone(oldRoute);
    if (newRoute is PopupRoute) didPush(newRoute, null);
  }

  void _gone(Route<dynamic> route) {
    if (_open.remove(route)) _changed();
  }
}

/// The router navigator's window watch, one per app.
@Riverpod(keepAlive: true)
DeskModalObserver deskModalObserver(Ref ref) => DeskModalObserver();

/// The tab a path is, or -1 for a page outside the tabs.
int _branchOf(String path) => switch (path) {
  '/messages' || '/workspace-overview' => ShellBranch.messages,
  '/calendar' => ShellBranch.calendar,
  '/directory' => ShellBranch.directory,
  '/money' => ShellBranch.money,
  '/reserve' => ShellBranch.reserve,
  _ => -1,
};

/// Where each tab opens, for a tab chosen on the desk.
String _branchLocation(int branch) => switch (branch) {
  ShellBranch.messages => '/messages',
  ShellBranch.calendar => '/calendar',
  ShellBranch.directory => '/directory',
  ShellBranch.money => '/money',
  _ => '/reserve',
};

/// The desk around [child], the router's navigator, for the page at [path].
class DeskFrame extends StatelessWidget {
  const DeskFrame({
    required this.router,
    required this.path,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) => InheritedGoRouter(
    goRouter: router,
    child: Overlay.wrap(
      child: _Desk(path: path, child: child),
    ),
  );
}

class _Desk extends ConsumerWidget {
  const _Desk({required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final router = GoRouter.of(context);
    final tabTitles = shellTabTitles(context, l10n);
    final navs = shellNavFor(
      ref.watch(enabledFeaturesSyncProvider),
      ref.watch(myPermissionsProvider),
    );
    final visibleBranches = [for (final n in navs) n.branch];
    final pendingEvents = ref.watch(myPendingEventCountProvider).value ?? 0;
    final branch = _branchOf(path);
    void onBranch(int b) => router.go(_branchLocation(b));
    final crumbs = ShellMenu.of(
      context,
      ref,
      permanent: true,
      tabs: (
        tabTitles: tabTitles,
        visibleBranches: visibleBranches,
        navs: navs,
        currentIndex: branch,
        onBranch: onBranch,
      ),
    ).crumbsOf(path);
    return ValueListenableBuilder(
      valueListenable: ref.watch(deskModalObserverProvider).scrim,
      builder: (context, scrim, _) => DeskScaffold(
        navigation: ({required rail}) => ShellDrawer(
          permanent: true,
          rail: rail,
          tabTitles: tabTitles,
          visibleBranches: visibleBranches,
          navs: navs,
          currentIndex: branch,
          pendingEvents: pendingEvents,
          onBranch: onBranch,
        ),
        title: _DeskBreadcrumb(crumbs: crumbs, router: router),
        place: crumbs.lastOrNull?.label,
        actions: shellBarActions(context, ref, currentIndex: branch),
        path: path,
        scrim: scrim,
        body: child,
      ),
    );
  }
}

/// The place on screen as the sidebar shows it: "Purchases › Suppliers".
/// The last part is the page's place; the record shown (a member's name)
/// comes with the page's own leaf, not here.
class _DeskBreadcrumb extends StatelessWidget {
  const _DeskBreadcrumb({required this.crumbs, required this.router});

  final List<DeskCrumb> crumbs;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget part(DeskCrumb crumb, {required bool last}) {
      final text = Text(
        crumb.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: last
            ? null
            : theme.textTheme.titleMedium?.copyWith(color: muted),
      );
      final entry = crumb.entry;
      if (entry == null) return text;
      // The entry's own page: from a page opened on it, the way back.
      final route = entry.route;
      return TextButton(
        key: ValueKey('desk-crumb-${entry.key}'),
        onPressed: route == null ? entry.onTap : () => router.go(route),
        style: TextButton.styleFrom(
          foregroundColor: last ? theme.colorScheme.onSurface : muted,
          textStyle: last ? theme.textTheme.titleLarge : null,
        ),
        child: text,
      );
    }

    return Row(
      key: const ValueKey('desk-breadcrumb'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, crumb) in crumbs.indexed) ...[
          if (i > 0) Icon(Icons.chevron_right, color: muted),
          Flexible(child: part(crumb, last: i == crumbs.length - 1)),
        ],
      ],
    );
  }
}
