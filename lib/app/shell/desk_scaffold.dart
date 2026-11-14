// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3603 (desk F2) — the business on a desk: from the expanded window class
// the navigation stays beside every page. An expanded window shows the
// rail; a large one the sidebar, which the person may narrow to the rail
// (kept per device). On Windows, macOS and the web alike; compact and
// medium windows keep the bar or the drawer, and the navigation-style
// setting applies to them only. The top bar names the page and carries the
// alerts, help and account; the search arrives in its slot with #3610.
// Tab moves through the navigation, then the top bar, then the page.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/navigation/navigation_style.dart';
import '../../core/ui/adaptive/window_class.dart';
import '../../core/ui/kit/form_scroll.dart';
import '../route_classes.dart';
import 'desk_navigation.dart';
import 'desk_page_entry.dart';
import 'desk_page_frame.dart';
import 'desk_top_bar.dart';
import 'shell_app_bar.dart';

/// Whether [context]'s window shows the desk: the expanded class or wider,
/// at a text size the sidebar still holds on one line.
bool _showsDesk(BuildContext context) =>
    WindowClass.of(context).atLeast(WindowClass.expanded) &&
    MediaQuery.textScalerOf(context).scale(100) <= kWideNavigationMaxTextScale;

/// Whether the desk is shown around [path] in [context]'s window: a route
/// shown on the desk, a window that holds it, and for the account's
/// settings ([workspaceChromeAccountRoutes]) a business selected.
bool deskShownAt(
  BuildContext context,
  String path, {
  required bool inBusiness,
}) =>
    chromeOf(path) == RouteChrome.desk &&
    _showsDesk(context) &&
    (!workspaceChromeAccountRoutes.contains(path) || inBusiness);

/// The desk around one page.
class DeskScaffold extends ConsumerWidget {
  const DeskScaffold({
    required this.navigation,
    required this.title,
    required this.body,
    this.titleWidth = 0,
    this.controls = const [],
    this.path = '',
    this.scrim,
    super.key,
  });

  /// The page's address: its reading column (app_frame.dart).
  final String path;

  /// While a window (a dialog, a sheet) is open over the page: its scrim,
  /// under which the navigation and the top bar rest, taking no input.
  final Color? scrim;

  /// The business's navigation: the rail when [rail], else the sidebar.
  final Widget Function({required bool rail}) navigation;

  /// The page's title in the top bar: its crumbs, given whether they wrap.
  final Widget Function({required bool wraps}) title;

  /// How wide the title is on one line (#3893).
  final double titleWidth;

  /// The top bar's search, alerts, help and account; they leave the bar, in
  /// the order of their priority, before the title is cut.
  final List<ShellBarControl> controls;

  final Widget body;

  /// The rail's width: an icon over a short label.
  static const double railWidth = 80;

  /// The sidebar's width: a menu label on one line (#2313).
  static const double sidebarWidth = 272;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = WindowClass.of(context).atLeast(WindowClass.large);
    final collapsed = ref.watch(deskRailCollapsedProvider).value ?? false;
    final rail = !large || collapsed;
    // The window's title is the app's (window_title.dart, #3605).
    return Scaffold(
      body: _FocusLeavesEmptyPages(
        child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Row(
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: FocusTraversalGroup(
                child: _Chrome(
                  scrim: scrim,
                  child: SizedBox(
                    key: const ValueKey('desk-navigation'),
                    width: rail ? railWidth : sidebarWidth,
                    child: Column(
                      children: [
                        Expanded(child: navigation(rail: rail)),
                        if (large) _NavigationToggle(collapsed: collapsed),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: FocusTraversalGroup(
                      child: _Chrome(
                        scrim: scrim,
                        child: DeskTopBar(
                          title: title,
                          titleWidth: titleWidth,
                          controls: controls,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: FocusTraversalGroup(
                        // #3946 — a form is walked in the order it is built.
                        policy: PageTraversalPolicy(),
                        // The page's semantics must not hide the navigation.
                        child: Semantics(
                          container: true,
                          // #3603 — the window is the desk's. #3798 — the
                          // navigator spans the page area, so what a page
                          // opens over itself (a dialog, a sheet, a panel,
                          // their scrim) stands in the page area; each page
                          // is laid in the measure its route declares
                          // (#3604) as it is built (desk_page_frame.dart).
                          child: KeyedSubtree(
                            key: deskPageKey,
                            child: DeskPageFrame(child: body),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// #3943 — Tab and Shift+Tab on the desk: the next stop as Flutter finds
/// it, or, when nothing moved (a page with no control of its own: its
/// route's scope holds the keyboard and has nowhere to send it), the desk's
/// first stop going forward and its last going back. A page never keeps
/// the keyboard it cannot pass on.
class _FocusLeavesEmptyPages extends StatelessWidget {
  const _FocusLeavesEmptyPages({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      NextFocusIntent: CallbackAction<NextFocusIntent>(
        onInvoke: (_) => _move(context, forward: true),
      ),
      PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
        onInvoke: (_) => _move(context, forward: false),
      ),
    },
    child: child,
  );

  static Object? _move(BuildContext desk, {required bool forward}) {
    // #3946 — a page entered from outside starts at its first stop.
    if (forward && deskPageToStart(desk, () => _move(desk, forward: true))) {
      return null;
    }
    final focus = FocusManager.instance.primaryFocus;
    // A page's own scope with no stop in it: Flutter would enter the group
    // before it at its first stop, so the desk chooses both ways itself.
    final emptyPage =
        focus is FocusScopeNode &&
        !focus.traversalDescendants.any(
          (n) => n.canRequestFocus && !n.skipTraversal,
        );
    final moved =
        !emptyPage &&
        focus != null &&
        (forward ? focus.nextFocus() : focus.previousFocus());
    if (moved) return null;
    final scope = Focus.maybeOf(desk) ?? FocusManager.instance.rootScope;
    final stops = [
      for (final n in scope.traversalDescendants)
        if (n.canRequestFocus && !n.skipTraversal && n is! FocusScopeNode) n,
    ];
    if (stops.isEmpty) return null;
    // The desk's first stop in the order Tab walks (navigation, top bar,
    // page), going back its last: the top bar's last control, not the one
    // the tree happens to build last.
    final walked = OrderedTraversalPolicy()
        .sortDescendants(stops, stops.first)
        .toList();
    (forward ? walked.first : walked.last).requestFocus();
    return null;
  }
}

/// The desk's own controls, resting under [scrim] while a window is open
/// over the page: no pointer, no key, the same shade as the page's.
class _Chrome extends StatelessWidget {
  const _Chrome({required this.scrim, required this.child});

  final Color? scrim;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shade = scrim;
    final resting = shade != null;
    return Stack(
      children: [
        IgnorePointer(
          ignoring: resting,
          child: ExcludeFocus(excluding: resting, child: child),
        ),
        if (shade != null)
          Positioned.fill(
            child: ColoredBox(key: const ValueKey('desk-scrim'), color: shade),
          ),
      ],
    );
  }
}

/// Narrows the sidebar to the rail, or widens it back.
class _NavigationToggle extends ConsumerWidget {
  const _NavigationToggle({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return IconButton(
      key: const ValueKey('desk-navigation-toggle'),
      tooltip: collapsed ? l10n.deskNavExpand : l10n.deskNavCollapse,
      icon: Icon(collapsed ? Icons.menu_open : Icons.menu),
      onPressed: () => ref
          .read(deskRailCollapsedProvider.notifier)
          .set(collapsed: !collapsed),
    );
  }
}
