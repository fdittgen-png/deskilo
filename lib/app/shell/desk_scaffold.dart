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
import 'package:go_router/go_router.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/navigation/navigation_style.dart';
import '../../core/ui/adaptive/window_class.dart';
import '../../core/ui/app_frame.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../route_classes.dart';
import 'desk_navigation.dart';

/// Whether [context]'s window shows the desk: the expanded class or wider,
/// at a text size the sidebar still holds on one line.
bool showsDesk(BuildContext context) =>
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
    showsDesk(context) &&
    (!workspaceChromeAccountRoutes.contains(path) || inBusiness);

/// Material's default horizontal inset of a dialog (its own private
/// `_defaultInsetPadding`), for a theme that sets none.
const double kMaterialDialogInset = 40;

/// #3603 — the windows opened over a desk page (dialogs) keep the width
/// the page's column gave them before the desk took the window: the
/// column less the dialog's insets on each side.
ThemeData deskOverlayTheme(ThemeData theme, String path) {
  final inset =
      theme.dialogTheme.insetPadding?.horizontal ?? 2 * kMaterialDialogInset;
  return theme.copyWith(
    dialogTheme: theme.dialogTheme.copyWith(
      constraints: BoxConstraints(maxWidth: frameWidthFor(path) - inset),
    ),
  );
}

/// The desk around one page.
class DeskScaffold extends ConsumerWidget {
  const DeskScaffold({
    required this.navigation,
    required this.title,
    required this.body,
    this.actions = const [],
    this.search,
    this.place,
    super.key,
  });

  /// The label of the place on screen, for the window's (or the browser
  /// tab's) title: "place — business".
  final String? place;

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
    // #3603 — the window names the place and the business; with no
    // business selected, the app alone.
    final business = ref.watch(currentWorkspaceProvider).value?.name;
    return Title(
      title: business == null
          ? context.l10n.appTitle
          : place == null
          ? business
          : '$place — $business',
      color: Theme.of(context).colorScheme.primary,
      child: Scaffold(
        body: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Row(
            children: [
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: FocusTraversalGroup(
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
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: FocusTraversalGroup(
                        child: AppBar(
                          key: const ValueKey('desk-top-bar'),
                          automaticallyImplyLeading: false,
                          title: title,
                          actions: [?search, ...actions],
                        ),
                      ),
                    ),
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(3),
                        child: FocusTraversalGroup(
                          // The page's semantics must not hide the navigation.
                          // #3603 — the window is the desk's; the reading
                        // column (or a canvas's wider one) is the page's.
                        child: Semantics(
                          container: true,
                          child: AppFrame(
                            inside: true,
                            maxWidth: frameWidthFor(
                              GoRouterState.of(context).uri.path,
                            ),
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
      ),
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
