// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — the shell route: its builder and the five destination branches.

import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/screens/calendar_branch.dart';
import '../../features/members/presentation/screens/directory_screen.dart';
import '../../features/money/presentation/screens/money_screen.dart';
import '../../features/reservations/presentation/screens/reserve_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/presentation/screens/inbox_screen.dart';
import '../route_access.dart';
import '../route_env.dart';
import 'shell_screen.dart';

/// The shell around the five destinations.
StatefulShellRoute shellRoute(RouteEnv env) => StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) =>
      ShellScreen(navigationShell: navigationShell),
  branches: [
    // #687 — the first destination is the MESSAGING CENTRE. The
    // plan moved to Réserver, which since #685 carries the editor
    // and the way back to now, so the tab was drawing the same
    // canvas twice and the slot is better spent.
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/messages',
          // The calendar hub holds the alerts and events: this path
          // (a fallback target all over the router) opens it.
          redirect: (context, state) =>
              env.featureEnabled(WorkspaceFeature.calendarTab) &&
                  env.featureEnabled(WorkspaceFeature.calendarHub) &&
                  env.featureEnabled(WorkspaceFeature.eventsTab)
              ? '/calendar'
              : null,
          // The workspace's alerts and requests, plus one door to the
          // messenger in Me (#2210: the old conversation list is gone).
          builder: (context, state) => const InboxScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/calendar',
          redirect: env.guard(
            const RouteAccess(features: [WorkspaceFeature.calendarTab]),
          ),
          // #718 — the hub when the feature is on, the classic
          // reservations calendar when it is off; picked per build.
          builder: (context, state) => const CalendarBranch(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          // Member directory (#224, tab since #230; briefly an
          // inbox face in #702, a tab again in #707) — gated by
          // the membersDirectory feature.
          path: '/directory',
          redirect: env.guard(
            const RouteAccess(features: [WorkspaceFeature.membersDirectory]),
          ),
          builder: (context, state) => const DirectoryScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/money',
          redirect: env.guard(
            const RouteAccess(features: [WorkspaceFeature.moneyTab]),
          ),
          builder: (context, state) => const MoneyScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          // The Reserve hub behind the raised centre button. A
          // shell branch (not a pushed route) so the bottom bar
          // stays visible and functional on the hub; ungated.
          path: '/reserve',
          builder: (context, state) => const ReserveScreen(),
        ),
      ],
    ),
  ],
);
