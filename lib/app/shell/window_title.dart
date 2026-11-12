// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3605 (the title half of #3613) — the window's, or the browser tab's,
// title names where the person is: "place — business — DesKilo"; with no
// business selected "place — DesKilo"; a page with no place in the business's
// navigation (Me, the account, a public page) the app's name alone. The same
// rule on the desk and off it, so a tab on a phone reads as a window does.
// The place is the one the desk's breadcrumb names (desk_frame.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/ui/kit/page_title.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../route_classes.dart';
import 'desk_frame.dart';
import 'shell_menu.dart';

/// [child], the whole app at [path], under the window title it names.
class WindowTitle extends StatelessWidget {
  const WindowTitle({
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
    child: _Title(path: path, child: child),
  );
}

class _Title extends ConsumerWidget {
  const _Title({required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Only a page of the business has a place in its navigation.
    final place = chromeOf(path) == RouteChrome.desk
        // #3789 — the window's title is the breadcrumb's last crumb.
        ? withPageName(
            deskPlaceOf(context, ref, GoRouter.of(context), path).crumbs,
            PageNameScope.nameOf(context),
          ).lastOrNull?.label
        : null;
    final business = ref.watch(currentWorkspaceProvider).value?.name;
    final app = l10n.appTitle;
    return Title(
      key: const ValueKey('window-title'),
      title: place == null
          ? app
          : business == null
          ? l10n.windowTitleNoBusiness(place, app)
          : l10n.windowTitle(place, business, app),
      color: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }
}
