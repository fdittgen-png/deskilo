// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the sign-in and linked-accounts routes.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../core/demo/demo_link.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/linked_accounts_screen.dart';
import '../route_env.dart';

/// Routes of the auth feature.
List<RouteBase> authRoutes(RouteEnv env) {
  return [
    GoRoute(
      path: '/auth',
      builder: (_, s) =>
          AuthScreen(
            offerDemo: s.uri.queryParameters['demo'] == '1',
            demoLink: DemoLink.parse(s.uri.queryParameters),
          ),
    ),
    GoRoute(
      // Linked accounts (0051): the signed-in user's own identities.
      path: '/linked-accounts',
      builder: (context, state) => const LinkedAccountsScreen(),
    ),
  ];
}
