// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/calendar/presentation/screens/calendar_screen.dart';
import '../features/editor/presentation/screens/editor_screen.dart';
import '../features/members/presentation/screens/directory_screen.dart';
import '../features/editor/presentation/screens/level_canvas_screen.dart';
import '../features/events/presentation/screens/events_screen.dart';
import '../features/events/presentation/screens/validation_settings_screen.dart';
import '../features/money/presentation/screens/billing_screen.dart';
import '../features/money/presentation/screens/money_screen.dart';
import '../features/money/presentation/screens/services_screen.dart';
import '../features/plan/presentation/screens/accessories_screen.dart';
import '../features/plan/presentation/screens/plan_screen.dart';
import '../features/auth/presentation/screens/linked_accounts_screen.dart';
import '../features/help/presentation/screens/help_screen.dart';
import '../features/profile/presentation/screens/developer_screen.dart';
import '../features/profile/presentation/screens/profiles_screen.dart';
import '../features/profile/presentation/screens/settings_screen.dart';
import '../features/reservations/presentation/screens/reserve_screen.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/presentation/screens/availability_screen.dart';
import '../features/workspace/presentation/screens/features_screen.dart';
import '../features/workspace/presentation/screens/members_screen.dart';
import '../features/workspace/domain/member.dart';
import '../features/workspace/presentation/screens/onboarding_screen.dart';
import '../features/workspace/presentation/screens/pending_approval_screen.dart';
import '../features/workspace/presentation/screens/scan_join_screen.dart';
import '../features/workspace/presentation/screens/workspace_code_screen.dart';
import '../features/workspace/presentation/screens/workspace_settings_screen.dart';
import '../features/workspace/providers/workspace_providers.dart';
import '../features/kiosk/presentation/screens/kiosk_screen.dart';
import '../features/money/presentation/screens/payment_config_screen.dart';
import '../features/workspace/presentation/screens/nfc_config_screen.dart';
import 'shell/shell_screen.dart';

part 'router.g.dart';

/// Branch indices of the stateful shell (order = bottom-bar order).
/// #230 swapped the third slot: the member directory took the bottom-bar
/// place of the events feed, which moved to the app-bar bell.
abstract final class ShellBranch {
  static const int plan = 0;
  static const int calendar = 1;
  static const int directory = 2;
  static const int money = 3;

  /// The raised centre button's branch — not a bar destination, but a
  /// branch so the bar stays visible and functional on the hub. Core
  /// like Plan: never feature-gated, active by default.
  static const int reserve = 4;
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
    ..listen(enabledFeaturesProvider, (_, _) => refresh.value++)
    // Kiosk lock (0043): the active membership decides whether the app is
    // a wall tablet — re-evaluate when it resolves or changes.
    ..listen(myMemberProvider, (_, _) => refresh.value++);

  /// Whether [feature] is enabled for the active workspace (#146).
  /// Defaults (everything ON) while the workspace is still loading, so
  /// deep links are never bounced during startup.
  bool featureEnabled(WorkspaceFeature feature) =>
      ref.read(enabledFeaturesSyncProvider).contains(feature);

  final router = GoRouter(
    // The Reserve hub is the app's home (the centre button's form): it
    // is what opens on start, after sign-in and after onboarding.
    initialLocation: '/reserve',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return null;
      final signedIn = auth.value != null;
      final atAuth = state.matchedLocation == '/auth';
      if (!signedIn) return atAuth ? null : '/auth';
      if (atAuth) return '/reserve';

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
        if (list.isNotEmpty && atOnboarding && firstRun) return '/reserve';
      }

      // Kiosk lock (0043): a kiosk account IS the wall tablet — every
      // route collapses to the kiosk plan view, and a regular member can
      // never land on it.
      final me = ref.read(myMemberProvider).value;
      final atKiosk = state.matchedLocation == '/kiosk';
      if (me != null && me.isKiosk && !atKiosk) return '/kiosk';
      if ((me == null || !me.isKiosk) && atKiosk) return '/reserve';

      // Pending membership (0052): the waiting room until the validators
      // approve. Profiles stays reachable — the user may be active in
      // another workspace and switch to it.
      final atPending = state.matchedLocation == '/pending';
      final pendingSafe =
          atPending || state.matchedLocation == '/profiles';
      if (me != null &&
          me.status == MemberStatus.pending &&
          !pendingSafe) {
        return '/pending';
      }
      if ((me == null || me.status != MemberStatus.pending) && atPending) {
        return '/reserve';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/kiosk',
        builder: (context, state) => const KioskScreen(),
      ),
      GoRoute(
        path: '/pending',
        builder: (context, state) => const PendingApprovalScreen(),
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
                // Member directory (#224, tab since #230): open to EVERY
                // member and deliberately ungated (core, like Plan) —
                // unlike /members (owner management).
                path: '/directory',
                builder: (context, state) => const DirectoryScreen(),
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
        // In-app help: the bundled wiki user guide — every member,
        // fully offline, no guard.
        path: '/help',
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        // Linked accounts (0051): the signed-in user's own identities.
        path: '/linked-accounts',
        builder: (context, state) => const LinkedAccountsScreen(),
      ),
      GoRoute(
        // Events feed (#230): moved off the bottom bar — the app-bar bell
        // pushes it over the shell like /settings. The feature redirect
        // keeps deep links of gated workspaces safe.
        path: '/events',
        redirect: (context, state) =>
            featureEnabled(WorkspaceFeature.eventsTab) ? null : '/plan',
        builder: (context, state) => const EventsScreen(),
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
        path: '/nfc-config',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.isOwner ?? false;
          return isOwner && featureEnabled(WorkspaceFeature.nfcBadges)
              ? null
              : '/plan';
        },
        builder: (context, state) => const NfcConfigScreen(),
      ),
      GoRoute(
        path: '/payment-config',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.isOwner ?? false;
          return isOwner && featureEnabled(WorkspaceFeature.onlinePayments)
              ? null
              : '/plan';
        },
        builder: (context, state) => const PaymentConfigScreen(),
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
          return canAdminister &&
                  featureEnabled(WorkspaceFeature.accessorySupplements)
              ? null
              : '/plan';
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
        // Admins reach member management too (0044: they set reservation
        // limits and issue badges); owner-only controls gate inside.
        redirect: (context, state) {
          final canAdminister =
              ref.read(myMemberProvider).value?.canAdminister ?? false;
          return canAdminister ? null : '/plan';
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
