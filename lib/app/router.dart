// SPDX-License-Identifier: MIT
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/calendar/presentation/screens/calendar_screen.dart';
import '../features/editor/presentation/screens/editor_screen.dart';
import '../features/editor/presentation/screens/level_canvas_screen.dart';
import '../features/events/presentation/screens/events_screen.dart';
import '../features/money/presentation/screens/money_screen.dart';
import '../features/plan/presentation/screens/plan_screen.dart';
import '../features/profile/presentation/screens/profiles_screen.dart';
import '../features/profile/presentation/screens/settings_screen.dart';
import '../features/workspace/presentation/screens/members_screen.dart';
import '../features/workspace/presentation/screens/onboarding_screen.dart';
import '../features/workspace/presentation/screens/scan_join_screen.dart';
import '../features/workspace/presentation/screens/workspace_code_screen.dart';
import '../features/workspace/providers/workspace_providers.dart';
import 'shell/shell_screen.dart';

part 'router.g.dart';

/// Branch indices of the stateful shell (order = bottom-bar order).
abstract final class ShellBranch {
  static const int plan = 0;
  static const int calendar = 1;
  static const int events = 2;
  static const int money = 3;
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final refresh = ValueNotifier(0);
  ref
    ..onDispose(refresh.dispose)
    ..listen(authStateProvider, (_, _) => refresh.value++)
    ..listen(myWorkspacesProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: '/plan',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return null;
      final signedIn = auth.value != null;
      final atAuth = state.matchedLocation == '/auth';
      if (!signedIn) return atAuth ? null : '/auth';
      if (atAuth) return '/plan';

      // Signed in: a user without any workspace lands on onboarding. The
      // `first` flag marks the forced first-run visit — only that visit is
      // bounced to /plan once a workspace exists, so deliberately opening
      // onboarding from Profiles (#89 add-a-profile) is never hijacked.
      final workspaces = ref.read(myWorkspacesProvider);
      final atOnboarding = state.matchedLocation == '/onboarding';
      final firstRun = state.uri.queryParameters['first'] == '1';
      final list = workspaces.value;
      if (list != null) {
        if (list.isEmpty && !atOnboarding) return '/onboarding?first=1';
        if (list.isNotEmpty && atOnboarding && firstRun) return '/plan';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
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
      GoRoute(
        path: '/profiles',
        builder: (context, state) => const ProfilesScreen(),
      ),
      GoRoute(
        path: '/workspace-code',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.isOwner ?? false;
          return isOwner ? null : '/plan';
        },
        builder: (context, state) => const WorkspaceCodeScreen(),
      ),
      GoRoute(
        path: '/scan-join',
        builder: (context, state) => const ScanJoinScreen(),
      ),
      GoRoute(
        path: '/members',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.isOwner ?? false;
          return isOwner ? null : '/plan';
        },
        builder: (context, state) => const MembersScreen(),
      ),
      GoRoute(
        path: '/editor',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.isOwner ?? false;
          return isOwner ? null : '/plan';
        },
        builder: (context, state) => const EditorScreen(),
        routes: [
          GoRoute(
            path: 'level/:levelId',
            builder: (context, state) => LevelCanvasScreen(
              levelId: state.pathParameters['levelId']!,
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
