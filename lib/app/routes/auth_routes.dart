// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the sign-in and linked-accounts routes.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../core/demo/demo_link.dart';
import '../../core/demo/presentation/demo_entry_screen.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/linked_accounts_screen.dart';
import '../route_env.dart';

/// Routes of the auth feature.
List<RouteBase> authRoutes(RouteEnv env) {
  return [
    // `/auth?demo=1&...` is redirected to `/demo` by the route policy, so
    // this screen is only ever the sign-in.
    GoRoute(path: '/auth', builder: (_, s) => const AuthScreen()),
    // #3235 — the demo's neutral public entry, signed in or not.
    GoRoute(
      path: '/demo',
      builder: (_, s) =>
          DemoEntryScreen(link: DemoLink.parse(s.uri.queryParameters)),
    ),
    GoRoute(
      // Linked accounts (0051): the signed-in user's own identities.
      path: '/linked-accounts',
      builder: (context, state) => const LinkedAccountsScreen(),
    ),
  ];
}
