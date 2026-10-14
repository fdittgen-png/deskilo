// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: assistant access: confirmations, the person's assistants, the installation console, the workspace policy and setup, and OAuth consent.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/mcp/presentation/assistant_setup_screen.dart';
import '../../features/mcp/presentation/assistants_screen.dart';
import '../../features/mcp/presentation/connect_assistant_screen.dart';
import '../../features/mcp/presentation/eligibility_review_screen.dart';
import '../../features/mcp/presentation/instance_assistants_screen.dart';
import '../../features/mcp/presentation/mcp_confirmation_screen.dart';
import '../../features/mcp/presentation/mcp_policy_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../oauth_consent_route.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the mcp feature.
List<RouteBase> mcpRoutes(RouteEnv env) {
  return [
    // #1619 — an assistant's high-impact request, confirmed by its
    // person. The server answers only them; see the screen's doc.
    GoRoute(
      path: '/mcp/confirm/:id',
      builder: (context, state) =>
          McpConfirmationScreen(confirmationId: state.pathParameters['id']!),
    ),
    // #1628 — the person's own assistant access on this database.
    GoRoute(
      path: '/assistants',
      builder: (context, state) => const AssistantsScreen(),
    ),
    // #1827 B — the installation's assistant switches, for the instance
    // operator (the server refuses everyone else; 0341).
    GoRoute(
      path: '/installation/assistants',
      builder: (context, state) => const InstanceAssistantsScreen(),
    ),
    // #1627 — database administrators review eligibility; the server
    // checks administrator status and the second factor on every call.
    GoRoute(
      path: '/database/assistant-approvals',
      builder: (context, state) => const EligibilityReviewScreen(),
    ),
    // #1626/#1826 — what this workspace exposes: whoever holds
    // manageIntegrations (owners always; the matrix delegates it). Not
    // behind mcpAccess, so it can always be narrowed or switched off.
    GoRoute(
      path: '/settings/assistants',
      redirect: env.guard(
        const RouteAccess(permission: WorkspacePermission.manageIntegrations),
      ),
      builder: (context, state) => const McpPolicyScreen(),
    ),
    // #1827 — the guided setup, for the same people. Not behind mcpAccess:
    // turning it on is one of its steps.
    GoRoute(
      path: '/settings/assistant-setup',
      redirect: env.guard(
        const RouteAccess(permission: WorkspacePermission.manageIntegrations),
      ),
      builder: (context, state) => const AssistantSetupScreen(),
    ),
    // #1648 — the protected client purpose selects identity or MCP consent.
    // Every consent call requires the app's native session.
    GoRoute(
      path: '/oauth/consent',
      builder: (context, state) => OAuthConsentRoute(
        authorizationId: state.uri.queryParameters['authorization_id'] ?? '',
      ),
    ),
    // #2145 — Connect an assistant, for every member where mcpAccess is on.
    GoRoute(
      path: connectAssistantRoute,
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.mcpAccess],
          to: '/assistants',
        ),
      ),
      builder: (context, state) => const ConnectAssistantScreen(),
    ),
  ];
}
