// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: discovery, connections, the account messenger and the public page editor.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/directory/presentation/account_messenger_screen.dart';
import '../../features/directory/presentation/connections_screen.dart';
import '../../features/directory/presentation/directory_screen.dart'
    as discovery;
import '../../features/directory/presentation/public_page_editor.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the directory feature.
List<RouteBase> directoryRoutes(RouteEnv env) {
  return [
    GoRoute(
      path: '/discover',
      builder: (context, state) => const discovery.DirectoryScreen(),
    ),
    GoRoute(
      path: '/connections',
      builder: (context, state) => const ConnectionsScreen(),
    ),
    GoRoute(
      path: '/account-messages',
      builder: (context, state) => AccountMessengerScreen(
        source: state.uri.queryParameters['source'] ?? '',
        recipient: state.uri.queryParameters['recipient'],
        name: state.uri.queryParameters['name'] ?? '',
      ),
    ),
    GoRoute(
      path: '/settings/public-page',
      redirect: env.guard(
        const RouteAccess(bypass: RoleBypass.owner, to: '/profiles'),
      ),
      builder: (context, state) => const PublicPageEditor(),
    ),
  ];
}
