// SPDX-License-Identifier: MIT
import 'package:go_router/go_router.dart';

import '../features/calendar/presentation/screens/calendar_screen.dart';
import '../features/events/presentation/screens/events_screen.dart';
import '../features/money/presentation/screens/money_screen.dart';
import '../features/plan/presentation/screens/plan_screen.dart';
import '../features/profile/presentation/screens/settings_screen.dart';
import 'shell/shell_screen.dart';

/// Branch indices of the stateful shell (order = bottom-bar order).
abstract final class ShellBranch {
  static const int plan = 0;
  static const int calendar = 1;
  static const int events = 2;
  static const int money = 3;
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/plan',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events',
                builder: (context, state) => const EventsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/money',
                builder: (context, state) => const MoneyScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
