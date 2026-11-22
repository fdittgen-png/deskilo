// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- the engagements' routes: the list and one engagement. One
// feature (serviceFulfilment) guards both; the server still decides who acts.
import 'package:go_router/go_router.dart';

import '../../features/money/presentation/screens/service_fulfilment_screen.dart';
import '../../features/money/presentation/screens/service_fulfilments_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the serviceFulfilment feature.
List<RouteBase> serviceFulfilmentRoutes(RouteEnv env) {
  final guard = env.guard(
    const RouteAccess(features: [WorkspaceFeature.serviceFulfilment], to: '/money'),
  );
  return [
    GoRoute(
      path: '/money/engagements',
      redirect: guard,
      builder: (context, state) => const ServiceFulfilmentsScreen(),
    ),
    GoRoute(
      path: '/money/engagements/:id',
      redirect: guard,
      builder: (context, state) => ServiceFulfilmentScreen(fulfilmentId: state.pathParameters['id']!),
    ),
  ];
}
