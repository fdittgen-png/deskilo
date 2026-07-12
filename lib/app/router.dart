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
import '../features/events/presentation/screens/validation_settings_screen.dart';
import '../features/money/presentation/screens/billing_screen.dart';
import '../features/money/presentation/screens/money_screen.dart';
import '../features/money/presentation/screens/services_screen.dart';
import '../features/plan/presentation/screens/accessories_screen.dart';
import '../features/plan/presentation/screens/plan_screen.dart';
import '../features/profile/presentation/screens/developer_screen.dart';
import '../features/profile/presentation/screens/profiles_screen.dart';
import '../features/profile/presentation/screens/settings_screen.dart';
import '../features/reservations/presentation/screens/reserve_screen.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/presentation/screens/availability_screen.dart';
import '../features/workspace/presentation/screens/features_screen.dart';
import '../features/workspace/presentation/screens/members_screen.dart';
import '../features/workspace/presentation/screens/onboarding_screen.dart';
import '../features/workspace/presentation/screens/scan_join_screen.dart';
import '../features/workspace/presentation/screens/workspace_code_screen.dart';
import '../features/workspace/presentation/screens/workspace_settings_screen.dart';
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
    ..listen(myWorkspacesProvider, (_, _) => refresh.value++)
    // Feature flags follow the ACTIVE workspace (#146): switching
    // profiles must re-evaluate the redirects even when the workspace
    // list itself did not change.
    ..listen(enabledFeaturesProvider, (_, _) => refresh.value++);

  /// Whether [feature] is enabled for the active workspace (#146).
  /// Defaults (everything ON) while the workspace is still loading, so
  /// deep links are never bounced during startup.
  bool featureEnabled(WorkspaceFeature feature) =>
      ref.read(enabledFeaturesSyncProvider).contains(feature);

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
                redirect: (context, state) =>
                    featureEnabled(WorkspaceFeature.calendarTab)
                        ? null
                        : '/plan',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events',
                redirect: (context, state) =>
                    featureEnabled(WorkspaceFeature.eventsTab)
                        ? null
                        : '/plan',
                builder: (context, state) => const EventsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/money',
                redirect: (context, state) =>
                    featureEnabled(WorkspaceFeature.moneyTab)
                        ? null
                        : '/plan',
                builder: (context, state) => const MoneyScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        // Root-level (outside the shell) like /settings: the reservation
        // flow covers the bottom bar (#207; #208 fills in the real flow).
        path: '/reserve',
        builder: (context, state) => const ReservePlaceholderScreen(),
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
        // No owner guard (#144): developer mode is local diagnostics,
        // available to every member.
        path: '/developer',
        builder: (context, state) => const DeveloperScreen(),
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
        path: '/billing',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.isOwner ?? false;
          return isOwner ? null : '/plan';
        },
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: '/services',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.isOwner ?? false;
          return isOwner && featureEnabled(WorkspaceFeature.services)
              ? null
              : '/plan';
        },
        builder: (context, state) => const ServicesScreen(),
      ),
      GoRoute(
        // Owner AND admins (#167, epic decision): catalog management is a
        // canAdminister capability, not owner-only.
        path: '/accessories',
        redirect: (context, state) {
          final canAdminister =
              ref.read(myMemberProvider).value?.canAdminister ?? false;
          return canAdminister ? null : '/plan';
        },
        builder: (context, state) => const AccessoriesScreen(),
      ),
      GoRoute(
        path: '/features',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.isOwner ?? false;
          return isOwner ? null : '/plan';
        },
        builder: (context, state) => const FeaturesScreen(),
      ),
      GoRoute(
        path: '/workspace-settings',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.isOwner ?? false;
          return isOwner ? null : '/plan';
        },
        builder: (context, state) => const WorkspaceSettingsScreen(),
      ),
      GoRoute(
        path: '/validation',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.isOwner ?? false;
          return isOwner ? null : '/plan';
        },
        builder: (context, state) => const ValidationSettingsScreen(),
      ),
      GoRoute(
        path: '/availability',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.isOwner ?? false;
          return isOwner ? null : '/plan';
        },
        builder: (context, state) => const AvailabilityScreen(),
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
