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
import '../../core/ui/app_frame.dart';
import '../route_classes.dart';
import 'desk_navigation.dart';

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
    this.actions = const [],
    this.search,
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

  /// The page's title in the top bar.
  final Widget title;

  /// The top bar's alerts, help and account.
  final List<Widget> actions;

  /// The top bar's search (#3610); nothing until then.
  final Widget? search;

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
      body: FocusTraversalGroup(
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
                        child: AppBar(
                          key: const ValueKey('desk-top-bar'),
                          automaticallyImplyLeading: false,
                          title: title,
                          actions: [?search, ...actions],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: FocusTraversalGroup(
                        // The page's semantics must not hide the navigation.
                        child: Semantics(
                          container: true,
                          // #3603 — the window is the desk's; the reading
                          // column (or a canvas's wider one) is the page's,
                          // and the windows opened over it stay within it.
                          child: AppFrame(
                            key: const ValueKey('desk-page'),
                            inside: true,
                            maxWidth: frameWidthFor(path),
                            child: body,
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
    );
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
