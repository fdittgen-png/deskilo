// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/calendar/presentation/screens/calendar_branch.dart';
import '../features/editor/presentation/screens/editor_screen.dart';
import '../features/members/presentation/screens/directory_screen.dart';
import '../features/editor/presentation/screens/level_canvas_screen.dart';
import '../features/events/presentation/screens/validation_settings_screen.dart';
import '../features/money/presentation/screens/billing_screen.dart';
import '../features/money/presentation/screens/money_screen.dart';
import '../features/money/presentation/screens/invoices_screen.dart';
import '../features/money/presentation/screens/einvoice_config_screen.dart';
import '../features/money/presentation/screens/invoice_register_screen.dart';
import '../features/money/presentation/screens/legal_identity_screen.dart';
import '../features/money/presentation/screens/vat_declarations_screen.dart';
import '../features/reservations/domain/space_code.dart';
import '../features/reservations/presentation/screens/reference_link_screen.dart';
import '../features/workspace/presentation/screens/message_link_screen.dart';
import '../features/workspace/presentation/screens/payment_methods_screen.dart';
import '../features/workspace/presentation/screens/documents_screen.dart';
import '../features/workspace/presentation/screens/roles_screen.dart';
import '../features/money/presentation/screens/vat_screen.dart';
import '../features/money/presentation/screens/services_screen.dart';
import '../features/plan/presentation/screens/accessories_screen.dart';
import '../features/auth/presentation/screens/linked_accounts_screen.dart';
import '../features/help/presentation/screens/help_screen.dart';
import '../features/profile/presentation/screens/developer_screen.dart';
import '../features/workspace/presentation/screens/inbox_screen.dart';
import '../features/profile/presentation/screens/privacy_screen.dart';
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
import '../features/kiosk/presentation/screens/kiosk_gate_screen.dart';
import '../features/kiosk/presentation/screens/kiosk_screen.dart';
import '../features/kiosk/providers/kiosk_mode.dart';
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
    ..listen(myMemberProvider, (_, _) => refresh.value++)
    // Kiosk gate: the accept/reject decision moves the pad between the
    // gate, the locked kiosk view, and the normal app.
    ..listen(kioskModeProvider, (_, _) => refresh.value++);

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
      // The join-QR camera is PART of onboarding (#572): the redirect
      // used to evict it back to the join form the instant it was
      // pushed, because the scanner's only audience is exactly the user
      // with zero workspaces.
      final atScanJoin = state.matchedLocation == '/scan-join';
      final firstRun = state.uri.queryParameters['first'] == '1';
      final list = workspaces.value;
      if (list != null) {
        if (list.isEmpty && !atOnboarding && !atScanJoin) {
          return '/onboarding?first=1';
        }
        if (list.isNotEmpty && atOnboarding && firstRun) return '/reserve';
      }

      // Kiosk lock (0043) behind the kiosk gate (field request): kiosk
      // mode never auto-loads. A kiosk account first CONFIRMS it on the
      // gate — accepted collapses every route to the kiosk plan view
      // until the pad restarts; rejected lets this run of the app behave
      // normally. Regular members can never land on either screen.
      final me = ref.read(myMemberProvider).value;
      final atKiosk = state.matchedLocation == '/kiosk';
      final atGate = state.matchedLocation == '/kiosk-gate';
      // The kioskMode feature (hierarchy pass) turns the whole module
      // off: flagged accounts just behave as regular members.
      if (me != null &&
          me.isKiosk &&
          featureEnabled(WorkspaceFeature.kioskMode)) {
        switch (ref.read(kioskModeProvider)) {
          case KioskModeDecision.pending:
            if (!atGate) return '/kiosk-gate';
          case KioskModeDecision.accepted:
            if (!atKiosk) return '/kiosk';
          case KioskModeDecision.rejected:
            if (atKiosk || atGate) return '/reserve';
        }
      } else if (atKiosk || atGate) {
        return '/reserve';
      }

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
        path: '/kiosk-gate',
        builder: (context, state) => const KioskGateScreen(),
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
          // #687 — the first destination is the MESSAGING CENTRE. The
          // plan moved to Réserver, which since #685 carries the editor
          // and the way back to now, so the tab was drawing the same
          // canvas twice and the slot is better spent.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                // #702 — the inbox: chats, alerts and members, one
                // destination. `MessagesScreen` is now its first face.
                builder: (context, state) => const InboxScreen(),
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
                        : '/messages',
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
                redirect: (context, state) =>
                    featureEnabled(WorkspaceFeature.membersDirectory)
                        ? null
                        : '/messages',
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
                        : '/messages',
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
        // fully offline, no guard. `?topic=` (#606) jumps to the first
        // section whose heading contains the fragment.
        path: '/help',
        builder: (context, state) =>
            HelpScreen(topic: state.uri.queryParameters['topic']),
      ),
      GoRoute(
        // #719 — Privacy & data: who can see my data, who did, export,
        // erasure, the policy. Every member; the tools inside are gated.
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        // Linked accounts (0051): the signed-in user's own identities.
        path: '/linked-accounts',
        builder: (context, state) => const LinkedAccountsScreen(),
      ),
      GoRoute(
        // Events feed (#230, a tab before that): since #702 it is the
        // inbox's Alerts face, so this path REDIRECTS there rather than
        // opening a second copy over the shell. Kept, not deleted —
        // notification taps, stored shortcuts and links already point
        // at it, and a dead path is a worse answer than the feed they
        // were asking for.
        path: '/events',
        redirect: (context, state) {
          if (!featureEnabled(WorkspaceFeature.eventsTab)) return '/messages';
          // Off the routing frame: setting a provider mid-redirect is
          // modifying state while the tree is building.
          Future.microtask(
            () => ref
                .read(inboxTabControllerProvider.notifier)
                .show(InboxTab.alerts),
          );
          return '/messages';
        },
      ),
      // #687 — /plan outlived its tab. Kept as a REDIRECT rather than
      // deleted: "Show on plan" (#182/#576), any stored shortcut and any
      // link someone already sent all point at it, and a dead path is a
      // worse answer than the map they were asking for.
      GoRoute(
        path: '/plan',
        redirect: (context, state) => '/reserve',
      ),
      // Deep links from WhatsApp-mirrored messages (0106): the message
      // itself, a referenced reservation, a referenced space. All ride
      // the memberNotifications gate the messenger rides.
      GoRoute(
        path: '/msg/:id',
        redirect: (context, state) =>
            featureEnabled(WorkspaceFeature.memberNotifications)
                ? null
                : '/messages',
        builder: (context, state) =>
            MessageLinkScreen(noteId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/res/:id',
        builder: (context, state) => ReferenceLinkScreen.reservation(
            id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/space/:kind/:id',
        builder: (context, state) => ReferenceLinkScreen.space(
          kind: SpaceKind.values.asNameMap()[
                  state.pathParameters['kind'] ?? ''] ??
              SpaceKind.seat,
          id: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/workspace-code',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner ? null : '/messages';
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
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner && featureEnabled(WorkspaceFeature.nfcBadges)
              ? null
              : '/messages';
        },
        builder: (context, state) => const NfcConfigScreen(),
      ),
      GoRoute(
        path: '/payment-config',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner && featureEnabled(WorkspaceFeature.onlinePayments)
              ? null
              : '/messages';
        },
        builder: (context, state) => const PaymentConfigScreen(),
      ),
      GoRoute(
        path: '/billing',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner ? null : '/messages';
        },
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: '/invoices',
        redirect: (context, state) =>
            featureEnabled(WorkspaceFeature.invoicing) ? null : '/money',
        builder: (context, state) => const InvoicesScreen(),
      ),
      // The sortable register (0072): every member reads their own, an
      // issuer the whole workspace's.
      GoRoute(
        path: '/invoice-register',
        redirect: (context, state) =>
            featureEnabled(WorkspaceFeature.invoicing) ? null : '/money',
        builder: (context, state) => const InvoiceRegisterScreen(),
      ),
      // Where invoices are POSTED (0073) — owner-only.
      GoRoute(
        path: '/einvoice-config',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner && featureEnabled(WorkspaceFeature.invoicing)
              ? null
              : '/money';
        },
        builder: (context, state) => const EInvoiceConfigScreen(),
      ),
      // The workspace document library (#500) — every member, gated by
      // the documents feature; RLS decides which rows each role sees.
      GoRoute(
        path: '/documents',
        redirect: (context, state) =>
            featureEnabled(WorkspaceFeature.documents) ? null : '/messages',
        builder: (context, state) => const DocumentsScreen(),
      ),
      // #513 — the central role→permission matrix. Anyone with a role
      // can READ it; editing needs manageRoles (enforced in-screen and
      // by the RPC).
      GoRoute(
        path: '/roles',
        redirect: (context, state) =>
            featureEnabled(WorkspaceFeature.roleManagement) ? null : '/messages',
        builder: (context, state) => const RolesScreen(),
      ),
      // The workspace's manual payment methods (#486) — owner-only.
      GoRoute(
        path: '/payment-methods',
        redirect: (context, state) {
          final isOwner =
              ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner ? null : '/money';
        },
        builder: (context, state) => const PaymentMethodsScreen(),
      ),
      // The workspace's legal identity (0069) — owner-only, and only
      // where invoices exist at all.
      GoRoute(
        path: '/legal-identity',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner && featureEnabled(WorkspaceFeature.invoicing)
              ? null
              : '/money';
        },
        builder: (context, state) => const LegalIdentityScreen(),
      ),
      // The workspace's VAT rates (0072) — owner-only, like the identity
      // they belong to.
      // Periodic VAT declarations (#534) — owner-only, needs invoicing
      // AND the vatDeclarations feature; the screen gates the regime.
      GoRoute(
        path: '/vat-declarations',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner &&
                  featureEnabled(WorkspaceFeature.invoicing) &&
                  featureEnabled(WorkspaceFeature.vatDeclarations)
              ? null
              : '/money';
        },
        builder: (context, state) => const VatDeclarationsScreen(),
      ),
      GoRoute(
        path: '/vat',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner && featureEnabled(WorkspaceFeature.vatManagement)
              ? null
              : '/money';
        },
        builder: (context, state) => const VatScreen(),
      ),
      GoRoute(
        path: '/services',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner && featureEnabled(WorkspaceFeature.services)
              ? null
              : '/messages';
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
              : '/messages';
        },
        builder: (context, state) => const AccessoriesScreen(),
      ),
      GoRoute(
        path: '/features',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner ? null : '/messages';
        },
        builder: (context, state) => const FeaturesScreen(),
      ),
      GoRoute(
        path: '/workspace-settings',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner ? null : '/messages';
        },
        builder: (context, state) => const WorkspaceSettingsScreen(),
      ),
      GoRoute(
        path: '/validation',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner ? null : '/messages';
        },
        builder: (context, state) => const ValidationSettingsScreen(),
      ),
      GoRoute(
        path: '/availability',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner ? null : '/messages';
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
          return canAdminister ? null : '/messages';
        },
        builder: (context, state) => const MembersScreen(),
      ),
      GoRoute(
        path: '/editor',
        redirect: (context, state) {
          final isOwner = ref.read(myMemberProvider).value?.actsAsOwner ?? false;
          return isOwner ? null : '/messages';
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
