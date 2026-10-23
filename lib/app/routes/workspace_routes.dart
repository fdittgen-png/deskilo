// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: workspace entry (pending, onboarding, scan to join) and the workspace's own screens: conversation, library, documents, roles, settings, reports, BI, members, deployment.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../core/ui/wizard_navigation.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/plan/presentation/widgets/setup_places_step.dart';
import '../../features/workspace/domain/bi_modules.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/presentation/screens/attention_screen.dart';
import '../../features/workspace/presentation/screens/availability_screen.dart';
import '../../features/workspace/presentation/screens/bi_screen.dart';
import '../../features/workspace/presentation/screens/colours_screen.dart';
import '../../features/workspace/presentation/screens/deployment_screen.dart';
import '../../features/workspace/presentation/screens/documents_screen.dart';
import '../../features/workspace/presentation/screens/features_screen.dart';
import '../../features/workspace/presentation/screens/members_screen.dart';
import '../../features/workspace/presentation/screens/nfc_config_screen.dart';
import '../../features/workspace/presentation/screens/onboarding_screen.dart';
import '../../features/workspace/presentation/screens/payment_methods_screen.dart';
import '../../features/workspace/presentation/screens/pending_approval_screen.dart';
import '../../features/workspace/presentation/screens/questions_screen.dart';
import '../../features/workspace/presentation/screens/roles_of_space_screen.dart';
import '../../features/workspace/presentation/screens/roles_screen.dart';
import '../../features/workspace/presentation/screens/scan_join_screen.dart';
import '../../features/workspace/presentation/screens/setup_guide_screen.dart';
import '../../features/workspace/presentation/screens/setup_launch_screen.dart';
import '../../features/workspace/presentation/screens/setup_levels_screen.dart';
import '../../features/workspace/presentation/screens/setup_step_screen.dart';
import '../../features/workspace/presentation/screens/sites_screen.dart';
import '../../features/workspace/presentation/screens/what_you_can_do_screen.dart';
import '../../features/workspace/presentation/screens/wording_screen.dart';
import '../../features/workspace/presentation/screens/workspace_applications_screen.dart';
import '../../features/workspace/presentation/screens/workspace_code_screen.dart';
import '../../features/workspace/presentation/screens/workspace_library_screen.dart';
import '../../features/workspace/presentation/screens/workspace_overview_screen.dart';
import '../../features/workspace/presentation/screens/workspace_settings_screen.dart';
import '../../features/workspace/presentation/widgets/conversation_thread.dart';
import '../../features/workspace/presentation/widgets/workspace_reports.dart';
import '../route_access.dart';
import '../route_env.dart';
import 'setup_grow_pages.dart';
import 'setup_run_pages.dart';

/// Routes of the workspace feature.
List<RouteBase> workspaceRoutes(RouteEnv env) => [
  ..._entryRoutes(env),
  ..._settingsRoutes(env),
  ..._configurationRoutes(env),
  ..._peopleRoutes(env),
];

List<RouteBase> _entryRoutes(RouteEnv env) {
  final onboardingNavigation = WizardNavigationController();
  return [
    GoRoute(
      path: '/pending',
      builder: (context, state) => const PendingApprovalScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      onExit: (_, _) => env.ref.read(authStateProvider).value == null
          ? true
          : onboardingNavigation.requestExit(),
      builder: (context, state) => OnboardingScreen(
        navigation: onboardingNavigation,
        joinFirst: state.uri.queryParameters['join'] == '1',
      ),
    ),
    // Deep links from WhatsApp-mirrored messages (0106): the message
    // itself, a referenced reservation, a referenced space. All ride
    // the memberNotifications gate the messenger rides.
    // #821 — a conversation as a page, deep-linkable; a ROOT route like
    // /res/:id, so it covers the bottom bar and never collides with the
    // shell branch's own page key.
    GoRoute(
      path: '/conversation/:conversationId',
      // #1151 — the deep links ride the memberNotifications gate the
      // comment above always claimed; now the route does too.
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.memberNotifications]),
      ),
      builder: (context, state) => ConversationThreadPage(
        conversationId: state.pathParameters['conversationId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/workspace-code',
      redirect: env.guard(
        const RouteAccess(permission: WorkspacePermission.manageConfiguration),
      ),
      builder: (context, state) => const WorkspaceCodeScreen(),
    ),
    GoRoute(
      path: '/scan-join',
      builder: (context, state) => const ScanJoinScreen(),
    ),
    GoRoute(
      path: '/applications',
      builder: (context, state) => const WorkspaceApplicationsScreen(),
    ),
  ];
}

List<RouteBase> _settingsRoutes(RouteEnv env) {
  return [
    GoRoute(
      // #1120 — the workspace library.
      path: '/library',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.workspaceLibrary],
          to: '/workspace-settings',
        ),
      ),
      builder: (context, state) => const WorkspaceLibraryScreen(),
    ),
    // The workspace document library (#500) — every member, gated by
    // the documents feature; RLS decides which rows each role sees.
    GoRoute(
      path: '/documents',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.documents]),
      ),
      builder: (context, state) => const DocumentsScreen(),
    ),
    GoRoute(
      path: '/roles',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.roleManagement]),
      ),
      builder: (context, state) => const RolesScreen(),
    ),
    // #945 — the workspace's sites.
    GoRoute(
      path: '/settings/sites',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.multiSite],
          to: '/settings',
        ),
      ),
      builder: (context, state) => const SitesScreen(),
    ),
    // #1277 — the words this space uses instead of the product's.
    GoRoute(
      path: '/settings/wording',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.workspaceVocabulary],
          to: '/settings',
        ),
      ),
      builder: (context, state) => const WordingScreen(),
    ),
    // #1289 — the colour this space gives the app.
    GoRoute(
      path: '/settings/colours',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.workspaceBranding],
          to: '/settings',
        ),
      ),
      builder: (context, state) => const ColoursScreen(),
    ),
    // #1528 — the roles this space defines for itself.
    GoRoute(
      path: '/settings/roles-of-this-space',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.customRoles],
          to: '/settings',
        ),
      ),
      builder: (context, state) => const RolesOfSpaceScreen(),
    ),
    // #1288 — the questions this space asks its members.
    GoRoute(
      path: '/settings/questions',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.customFields],
          to: '/settings',
        ),
      ),
      builder: (context, state) => const QuestionsScreen(),
    ),
    GoRoute(
      path: '/reports',
      redirect: env.guard(
        RouteAccess(
          when: (c) => workspaceReportsAvailable(
            c.enabledFeatures,
            c.permissions,
            isAdmin: c.isAdmin,
          ),
          to: '/settings',
        ),
      ),
      builder: (context, state) => WorkspaceSettingsScreen(
        reportsOnly: true,
        reportSection: state.uri.queryParameters['section'],
      ), // #2313
    ),
    GoRoute(
      path: '/availability',
      redirect: env.guard(
        const RouteAccess(permission: WorkspacePermission.workspaceSettings),
      ),
      builder: (context, state) => const AvailabilityScreen(),
    ),
  ];
}

List<RouteBase> _configurationRoutes(RouteEnv env) {
  return [
    GoRoute(
      path: '/nfc-config',
      redirect: env.guard(
        const RouteAccess(
          permission: WorkspacePermission.operateKiosk,
          features: [WorkspaceFeature.nfcBadges],
        ),
      ),
      builder: (context, state) => const NfcConfigScreen(),
    ),
    // The workspace's manual payment methods (#486) — owner-only.
    GoRoute(
      path: '/payment-methods',
      redirect: env.guard(
        const RouteAccess(
          permission: WorkspacePermission.manageIntegrations,
          to: '/money',
        ),
      ),
      builder: (context, state) => const PaymentMethodsScreen(),
    ),
    // The workspace's VAT rates (0072) — owner-only, like the identity
    // they belong to.
    // Periodic VAT declarations (#534) — owner-only, needs invoicing
    // AND the vatDeclarations feature; the screen gates the regime.
    // #988/#990 — the deployment between the two sides of a pair:
    // the feature, a deploy permission, and a twin to deploy to.
    GoRoute(
      path: '/deployment',
      redirect: env.guard(
        RouteAccess(
          features: const [WorkspaceFeature.deployments],
          permission: WorkspacePermission.deployToDev,
          when: (c) => c.hasPairedTwin,
          to: '/settings',
        ),
      ),
      builder: (context, state) => const DeploymentScreen(),
    ),
    GoRoute(
      path: '/features',
      redirect: env.guard(
        const RouteAccess(permission: WorkspacePermission.manageConfiguration),
      ),
      builder: (context, state) => const FeaturesScreen(),
    ),
    GoRoute(
      path: '/workspace-settings',
      redirect: env.guard(
        const RouteAccess(permission: WorkspacePermission.workspaceSettings),
      ),
      builder: (context, state) => const WorkspaceSettingsScreen(),
    ),
  ];
}

List<RouteBase> _peopleRoutes(RouteEnv env) {
  return [
    // #1247 — one place that answers "does anything need me?".
    // Appended last: route pins are positional.
    GoRoute(
      path: '/attention',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.decisionSurface],
          to: '/',
        ),
      ),
      builder: (context, state) => const AttentionScreen(),
    ),
    // #2869 — the setup guide: one task list from creation to opening.
    GoRoute(
      path: '/setup',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.setupGuide],
          permission: WorkspacePermission.manageConfiguration,
          to: '/workspace-settings',
        ),
      ),
      builder: (context, state) => const SetupGuideScreen(),
    ),
    // #2868 — what the space does: a level per process from plain answers.
    GoRoute(
      path: '/setup/levels',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.setupGuide],
          permission: WorkspacePermission.manageConfiguration,
          to: '/workspace-settings',
        ),
      ),
      builder: (context, state) => const SetupLevelsScreen(),
    ),
    // #2876 — check the answers and go live.
    GoRoute(
      path: '/setup/launch',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.setupGuide],
          permission: WorkspacePermission.manageConfiguration,
          to: '/workspace-settings',
        ),
      ),
      builder: (context, state) => const SetupLaunchScreen(),
    ),
    // #2870 — one step of the guide: its form beside what members will see.
    GoRoute(
      path: '/setup/step/:id',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.setupGuide],
          permission: WorkspacePermission.manageConfiguration,
          to: '/workspace-settings',
        ),
      ),
      builder: (context, state) =>
          SetupStepScreen(
            stepId: state.pathParameters['id'] ?? '',
            placesStep: SetupPlacesStep.new,
            runPages: setupRunPages,
            growPages: setupGrowPages,
          ),
    ),
    // #2583 — the overview: what needs the person, then the figures.
    GoRoute(
      path: '/workspace-overview',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.workspaceOverview],
          to: '/',
        ),
      ),
      builder: (context, state) => const WorkspaceOverviewScreen(),
    ),
    // #1923 — Business analytics: only with a module this reader may see.
    GoRoute(
      path: '/bi',
      redirect: env.guard(
        RouteAccess(
          when: (c) => biAvailable(
            features: c.enabledFeatures,
            permissions: c.permissions,
          ),
        ),
      ),
      builder: (context, state) => const BiScreen(),
    ),
    GoRoute(
      path: '/members',
      // Admins reach member management too (0044: they set reservation
      // limits and issue badges); owner-only controls gate inside.
      redirect: env.guard(
        const RouteAccess(
          permission: WorkspacePermission.manageMembers,
          bypass: RoleBypass.administrator,
        ),
      ),
      builder: (context, state) => const MembersScreen(),
    ),
    // #2085 — what my roles give me here (or, for whoever administers
    // members or roles, what someone else's give them).
    GoRoute(
      path: '/settings/what-you-can-do',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.roleAssignment],
          to: '/settings',
        ),
      ),
      builder: (context, state) =>
          WhatYouCanDoScreen(memberId: state.uri.queryParameters['member']),
    ),
  ];
}
