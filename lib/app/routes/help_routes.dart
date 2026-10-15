// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the in-app help.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/help/presentation/screens/help_screen.dart';
import '../route_env.dart';

/// Routes of the help feature.
List<RouteBase> helpRoutes(RouteEnv env) {
  return [
    GoRoute(
      // In-app help: the bundled wiki user guide — every member,
      // fully offline, no guard. `?topic=` (#606) jumps to the first
      // section whose heading contains the fragment.
      path: '/help',
      builder: (context, state) => HelpScreen(
        topic: state.uri.queryParameters['topic'],
        anchor: state.uri.queryParameters['anchor'],
      ),
    ),
  ];
}
