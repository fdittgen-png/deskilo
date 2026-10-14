// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the Me layer and public profiles.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/me/presentation/me_shell.dart';
import '../../features/me/presentation/public_person_screen.dart';
import '../route_env.dart';

/// Routes of the me feature.
List<RouteBase> meRoutes(RouteEnv env) {
  return [
    GoRoute(
      path: '/me',
      builder:
          (context, state) => // #1823 the Me layer
              MeShell(tab: MeTab.fromQuery(state.uri.queryParameters['tab'])),
    ),
    GoRoute(
      path: '/p/:id',
      builder: (context, state) =>
          PublicPersonScreen(userId: state.pathParameters['id'] ?? ''),
    ), // #2211
  ];
}
