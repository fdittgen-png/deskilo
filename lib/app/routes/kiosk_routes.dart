// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the wall-tablet gate and the locked kiosk view.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/kiosk/presentation/screens/kiosk_gate_screen.dart';
import '../../features/kiosk/presentation/screens/kiosk_screen.dart';
import '../route_env.dart';

/// Routes of the kiosk feature.
List<RouteBase> kioskRoutes(RouteEnv env) {
  return [
    GoRoute(
      path: '/kiosk-gate',
      builder: (context, state) => const KioskGateScreen(),
    ),
    GoRoute(path: '/kiosk', builder: (context, state) => const KioskScreen()),
  ];
}
