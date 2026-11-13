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
import '../../core/ui/kit/page_title.dart';
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
  final List<PopupRoute<Object?>> _open = [];

  /// The scrim of the window on top; null while none is open.
  final ValueNotifier<Color?> scrim = ValueNotifier(null);

  void _changed() => scrim.value = _open.isEmpty
      ? null
      : (_open.last.barrierColor ?? Colors.transparent);

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    if (route is PopupRoute) {
      _open.add(route);
      _changed();
    }
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) =>
      _gone(route);

  @override
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) =>
      _gone(route);

  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    if (oldRoute != null) _gone(oldRoute);
    if (newRoute is PopupRoute) didPush(newRoute, null);
  }

  void _gone(Route<Object?> route) {
    if (_open.remove(route)) _changed();
  }
}

/// The router navigator's window watch, one per app.
@Riverpod(keepAlive: true)
DeskModalObserver deskModalObserver(Ref ref) => DeskModalObserver();

/// The paths of each tab, read from the router's own stateful shell (the
/// one place they are registered): index = the tab's [ShellBranch].
List<List<String>> _tabPaths(GoRouter router) {
  for (final route in router.configuration.routes) {
    if (route is StatefulShellRoute) {
      return [
        for (final branch in route.branches)
          [
            for (final r in branch.routes)
              if (r is GoRoute) r.path,
          ],
      ];
    }
  }
  return const [];
}

/// The tab [path] is, or -1 for a page outside the tabs.
int _branchOf(List<List<String>> tabs, String path) =>
    tabs.indexWhere((paths) => paths.contains(path));

/// Where a tab opens: the first path its branch registers.
String _branchLocation(List<List<String>> tabs, int branch) =>
    tabs[branch].first;

/// #3605 — where [path] sits in the business's navigation, as the desk's
/// breadcrumb and the window's title name it, and the tabs as the desk offers
/// them. A tab whose place is not a destination here (the overview of a
/// business with places) keeps the title its bar gave it. Needs the router
/// above [context] (InheritedGoRouter).
({List<DeskCrumb> crumbs, ShellTabs tabs}) deskPlaceOf(
  BuildContext context,
  WidgetRef ref,
  GoRouter router,
  String path,
) {
  final l10n = context.l10n;
  final tabTitles = shellTabTitles(context, l10n);
  final navs = shellNavFor(
    ref.watch(enabledFeaturesSyncProvider),
    ref.watch(myPermissionsProvider),
  );
  final paths = _tabPaths(router);
  final branch = _branchOf(paths, path);
  final ShellTabs tabs = (
    tabTitles: tabTitles,
    visibleBranches: [for (final n in navs) n.branch],
    navs: navs,
    currentIndex: branch,
    onBranch: (b) => router.go(_branchLocation(paths, b)),
  );
  final crumbs = ShellMenu.of(
    context,
    ref,
    permanent: true,
    tabs: tabs,
  ).crumbsOf(path);
  final tabTitle = path == '/workspace-overview'
      ? l10n.overviewTitle
      : branch >= 0
      ? tabTitles[branch]
      : null;
  return (
    crumbs: crumbs.isEmpty && tabTitle != null
        ? <DeskCrumb>[(label: tabTitle, entry: null)]
        : crumbs,
    tabs: tabs,
  );
}

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
    final router = GoRouter.of(context);
    final (:crumbs, :tabs) = deskPlaceOf(context, ref, router, path);
    // #3789 — a sub-page's own name follows its place.
    final shown = withPageName(crumbs, PageNameScope.nameOf(context));
    final tabTitles = tabs.tabTitles;
    final visibleBranches = tabs.visibleBranches;
    final navs = tabs.navs;
    final branch = tabs.currentIndex;
    final onBranch = tabs.onBranch;
    final pendingEvents = ref.watch(myPendingEventCountProvider).value ?? 0;
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
        title: ({required wraps}) =>
            _DeskBreadcrumb(crumbs: shown, router: router, wraps: wraps),
        titleWidth: _crumbsWidth(context, shown),
        controls: shellBarControls(context, ref, currentIndex: branch),
        path: path,
        scrim: scrim,
        // #3789 — the selected entry's name, so a page's own bar does not
        // say it a second time (PageTitle).
        body: DeskPlaceLabel(label: shown.lastOrNull?.label, child: child),
      ),
    );
  }
}

/// The place on screen as the sidebar shows it: "Purchases › Suppliers".
/// The last part is the page's place; the record shown (a member's name)
/// comes with the page's own leaf, not here.
class _DeskBreadcrumb extends StatelessWidget {
  const _DeskBreadcrumb({
    required this.crumbs,
    required this.router,
    required this.wraps,
  });

  final List<DeskCrumb> crumbs;
  final GoRouter router;

  /// The page's name takes a second line (#3893).
  final bool wraps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget part(DeskCrumb crumb, {required bool last}) {
      final text = Text(
        crumb.label,
        maxLines: last && wraps ? 2 : 1,
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

/// How wide the crumbs are on one line: each part in its style, a crumb that
/// is a button with the padding of its button, a chevron between.
double _crumbsWidth(BuildContext context, List<DeskCrumb> crumbs) {
  final theme = Theme.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  var width = 0.0;
  for (final (i, crumb) in crumbs.indexed) {
    final last = i == crumbs.length - 1;
    final style = last
        ? theme.textTheme.titleLarge
        : theme.textTheme.titleMedium;
    final painter = TextPainter(
      text: TextSpan(text: crumb.label, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    width += painter.width.ceilToDouble();
    painter.dispose();
    if (crumb.entry != null) width += _crumbButtonPadding;
    if (i > 0) width += _chevronWidth;
  }
  return width;
}

/// The horizontal padding of a crumb's text button, both sides.
const double _crumbButtonPadding = 24;

/// The chevron between two crumbs: an icon's width.
const double _chevronWidth = 24;
