// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/backend/backend_uri.dart';
import '../core/backend/schema_version.dart';
import '../core/i18n/regional_formats_section.dart';
import '../core/ui/wizard_navigation.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/auth/presentation/screens/linked_accounts_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/calendar/presentation/screens/calendar_branch.dart';
import '../features/calendar/providers/calendar_view_request.dart';
import '../features/directory/presentation/account_messenger_screen.dart';
import '../features/directory/presentation/connections_screen.dart';
import '../features/directory/presentation/directory_screen.dart' as discovery;
import '../features/directory/presentation/public_page_editor.dart';
import '../features/editor/presentation/screens/editor_screen.dart';
import '../features/editor/presentation/screens/level_canvas_screen.dart';
import '../features/events/presentation/screens/validation_settings_screen.dart';
import '../features/help/presentation/screens/help_screen.dart';
import '../features/kiosk/presentation/screens/kiosk_gate_screen.dart';
import '../features/kiosk/presentation/screens/kiosk_screen.dart';
import '../features/kiosk/providers/kiosk_mode.dart';
import '../features/mcp/presentation/assistant_setup_screen.dart';
import '../features/mcp/presentation/assistants_screen.dart';
import '../features/mcp/presentation/connect_assistant_screen.dart';
import '../features/mcp/presentation/eligibility_review_screen.dart';
import '../features/mcp/presentation/instance_assistants_screen.dart';
import '../features/mcp/presentation/mcp_confirmation_screen.dart';
import '../features/mcp/presentation/mcp_policy_screen.dart';
import '../features/me/presentation/me_shell.dart';
import '../features/me/presentation/public_person_screen.dart';
import '../features/members/presentation/screens/directory_screen.dart';
import '../features/members/presentation/screens/managed_profile_screen.dart';
import '../features/members/presentation/screens/member_page.dart';
import '../features/money/domain/invoicing_wizard.dart';
import '../features/money/presentation/screens/billing_screen.dart';
import '../features/money/presentation/screens/einvoice_config_screen.dart';
import '../features/money/presentation/screens/invoice_register_screen.dart';
import '../features/money/presentation/screens/invoices_screen.dart';
import '../features/money/presentation/screens/invoicing_wizard_screen.dart';
import '../features/money/presentation/screens/legal_identity_screen.dart';
import '../features/money/presentation/screens/money_screen.dart';
import '../features/money/presentation/screens/my_finances_screen.dart';
import '../features/money/presentation/screens/my_payment_terms_screen.dart';
import '../features/money/presentation/screens/number_sequences_screen.dart';
import '../features/money/presentation/screens/payment_config_screen.dart';
import '../features/money/presentation/screens/repartition_wizard_screen.dart';
import '../features/money/presentation/screens/report_editor_screen.dart';
import '../features/money/presentation/screens/services_screen.dart';
import '../features/money/presentation/screens/vat_declarations_screen.dart';
import '../features/money/presentation/screens/vat_screen.dart';
import '../features/money/presentation/screens/workspace_status_screen.dart';
import '../features/plan/presentation/screens/accessories_screen.dart';
import '../features/profile/presentation/screens/backend_screen.dart';
import '../features/profile/presentation/screens/consent_screen.dart';
import '../features/profile/presentation/screens/developer_screen.dart';
import '../features/profile/presentation/screens/new_instance_screen.dart';
import '../features/profile/presentation/screens/personal_info_screen.dart';
import '../features/profile/presentation/screens/privacy_screen.dart';
import '../features/profile/presentation/screens/profiles_screen.dart';
import '../features/profile/presentation/screens/schema_update_screen.dart';
import '../features/profile/presentation/screens/settings_screen.dart';
import '../features/profile/providers/profile_providers.dart';
import '../features/reservations/domain/space_code.dart';
import '../features/reservations/presentation/screens/reference_link_screen.dart';
import '../features/reservations/presentation/screens/reserve_screen.dart';
import '../features/task_recorder/presentation/route_classification.dart'
    show taskRecorderRoute, taskWizardRoute, taskWorkbenchRoute;
import '../features/task_recorder/presentation/screens/task_recorder_screen.dart';
import '../features/task_recorder/presentation/screens/task_wizard_screen.dart';
import '../features/task_recorder/presentation/screens/task_workbench_screen.dart';
import '../features/task_recorder/presentation/ui_capture.dart'
    show RecorderWindowObserver;
import '../features/workspace/domain/bi_modules.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/domain/workspace_permission.dart';
import '../features/workspace/presentation/screens/attention_screen.dart';
import '../features/workspace/presentation/screens/availability_screen.dart';
import '../features/workspace/presentation/screens/bi_screen.dart';
import '../features/workspace/presentation/screens/colours_screen.dart';
import '../features/workspace/presentation/screens/deployment_screen.dart';
import '../features/workspace/presentation/screens/documents_screen.dart';
import '../features/workspace/presentation/screens/features_screen.dart';
import '../features/workspace/presentation/screens/inbox_screen.dart';
import '../features/workspace/presentation/screens/members_screen.dart';
import '../features/workspace/presentation/screens/nfc_config_screen.dart';
import '../features/workspace/presentation/screens/onboarding_screen.dart';
import '../features/workspace/presentation/screens/payment_methods_screen.dart';
import '../features/workspace/presentation/screens/pending_approval_screen.dart';
import '../features/workspace/presentation/screens/questions_screen.dart';
import '../features/workspace/presentation/screens/roles_of_space_screen.dart';
import '../features/workspace/presentation/screens/roles_screen.dart';
import '../features/workspace/presentation/screens/scan_join_screen.dart';
import '../features/workspace/presentation/screens/sites_screen.dart';
import '../features/workspace/presentation/screens/what_you_can_do_screen.dart';
import '../features/workspace/presentation/screens/wording_screen.dart';
import '../features/workspace/presentation/screens/workspace_applications_screen.dart';
import '../features/workspace/presentation/screens/workspace_code_screen.dart';
import '../features/workspace/presentation/screens/workspace_library_screen.dart';
import '../features/workspace/presentation/screens/workspace_settings_screen.dart';
import '../features/workspace/presentation/widgets/conversation_thread.dart';
import '../features/workspace/presentation/widgets/workspace_reports.dart';
import '../features/workspace/providers/workspace_providers.dart';
import 'entry_intents.dart';
import 'entry_resumption.dart';
import 'oauth_consent_route.dart';
import 'page_routes.dart';
import 'route_access.dart';
import 'route_env.dart';
import 'route_redirect.dart';
import 'schema_gate.dart';
import 'shell/shell_screen.dart';

export 'shell/shell_destinations.dart' show ShellBranch;

part 'router.g.dart';

// #1306 — ShellBranch lives beside the one destination list that uses it.

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final refresh = ValueNotifier(0);
  late final GoRouter router;
  // #1650 — a refresh re-asks the redirect about where the person IS
  // (entry_resumption.dart says why the reported location is not that).
  void reask() {
    reportCurrentLocation(router);
    refresh.value++;
  }

  ref
    ..onDispose(refresh.dispose)
    ..listen(authStateProvider, (_, _) => reask())
    ..listen(myWorkspacesProvider, (_, _) => reask())
    // Feature flags follow the ACTIVE workspace (#146): switching
    // profiles must re-evaluate the redirects even when the workspace
    // list itself did not change.
    ..listen(enabledFeaturesProvider, (_, _) => reask())
    // Kiosk lock (0043): the active membership decides whether the app is
    // a wall tablet — re-evaluate when it resolves or changes.
    ..listen(myMemberProvider, (_, _) => reask())
    ..listen(activeWorkspaceIdProvider, (_, _) => reask()) // #1823
    // Kiosk gate: the accept/reject decision moves the pad between the
    // gate, the locked kiosk view, and the normal app.
    ..listen(kioskModeProvider, (_, _) => reask())
    // #751 — the consent gate reads the profile's accepted policy version:
    // re-evaluate when the profile resolves, and after an acceptance.
    ..listen(myProfileProvider, (_, _) => reask())
    ..listen(requiredPrivacyVersionProvider, (_, _) => reask()) // #1914
    ..listen(schemaCompatibilityProvider, (_, _) => reask()) // #1312
    // #1650 — the continuation restored from the device, or captured on
    // the way to sign-in: its destination is where sign-in returns to.
    ..listen(entryIntentsProvider, (_, _) => reask());

  final env = RouteEnv(ref);
  final onboardingNavigation = WizardNavigationController();
  router = GoRouter(
    // The Reserve hub is the app's home (the centre button's form): it
    // is what opens on start, after sign-in and after onboarding.
    initialLocation: '/reserve',
    refreshListenable: refresh,
    // #2142 — tells a live task recording that a window opened or
    // closed; does nothing while none is live.
    observers: [RecorderWindowObserver()],
    // #1650 — the rules live in route_policy.dart as a pure function over
    // facts; this closure only collects the facts and asks. Building them
    // reads; nothing here writes.
    redirect: (context, state) => appRedirect(env, state),
    routes: [
      GoRoute(path: '/auth', builder: (_, s) => AuthScreen(offerDemo: s.uri.queryParameters['demo'] == '1')),
      for (final page in openedPages) page.route(), // #2388
      GoRoute(path: '/me', builder: (context, state) => // #1823 the Me layer
          MeShell(tab: MeTab.fromQuery(state.uri.queryParameters['tab']))),
      GoRoute(
        path: '/kiosk-gate',
        builder: (context, state) => const KioskGateScreen(),
      ),
      GoRoute(path: '/kiosk', builder: (context, state) => const KioskScreen()),
      GoRoute(
        path: '/pending',
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        onExit: (_, _) => ref.read(authStateProvider).value == null
            ? true : onboardingNavigation.requestExit(),
        builder: (context, state) => OnboardingScreen(navigation: onboardingNavigation,
            joinFirst: state.uri.queryParameters['join'] == '1'),
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
                redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.calendarTab])),
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
                redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.membersDirectory])),
                builder: (context, state) => const DirectoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/money',
                redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.moneyTab])),
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
      // #780 — which Supabase instance this device talks to. Outside the
      // workspace shell on purpose: it must be reachable when no
      // workspace can be loaded, which is exactly when it is needed.
      // #977 — the instance wizard, beside the server screen it serves.
      GoRoute(
        // #1650 — its instanceWizard boundary is the policy's: a
        // workspace's flag, applied only when there is a workspace.
        path: '/server/new-instance',
        builder: (context, state) => const NewInstanceScreen(),
      ),
      GoRoute(
        path: '/server',
        builder: (context, state) => BackendScreen(
            candidate: state.extra is BackendDescriptor ? state.extra! as BackendDescriptor : null),
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
            HelpScreen(
              topic: state.uri.queryParameters['topic'],
              anchor: state.uri.queryParameters['anchor'],
            ),
      ),
      GoRoute(
        // #751 — the GDPR consent; ?review=1 reads it without the gate.
        path: '/consent',
        builder: (context, state) =>
            ConsentScreen(review: state.uri.queryParameters['review'] == '1'),
      ),
      GoRoute(
        // #719 — Privacy & data: who can see my data, who did, export,
        // erasure, the policy. Every member; the tools inside are gated.
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        // #734 — Region & formats as a screen of its own.
        path: '/formats',
        // #1151 — gated like every feature-owned route.
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.regionalFormats], to: '/settings')),
        builder: (context, state) => const RegionalFormatsScreen(),
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
          if (!env.featureEnabled(WorkspaceFeature.eventsTab)) return '/messages';
          // The calendar hub holds the alerts: ask it for its Alerts view.
          final inCalendar = env.featureEnabled(WorkspaceFeature.calendarTab) &&
              env.featureEnabled(WorkspaceFeature.calendarHub);
          // Off the routing frame: setting a provider mid-redirect is
          // modifying state while the tree is building.
          unawaited(Future.microtask(
            () => inCalendar
                ? ref.read(calendarAlertsRequestProvider.notifier).request()
                : ref
                    .read(inboxTabControllerProvider.notifier)
                    .show(InboxTab.alerts),
          ));
          return inCalendar ? '/calendar' : '/messages';
        },
      ),
      // #687 — /plan outlived its tab. Kept as a REDIRECT rather than
      // deleted: "Show on plan" (#182/#576), any stored shortcut and any
      // link someone already sent all point at it, and a dead path is a
      // worse answer than the map they were asking for.
      GoRoute(path: '/plan', redirect: (context, state) => '/reserve'),
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
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.memberNotifications])),
        builder: (context, state) => ConversationThreadPage(
          conversationId: state.pathParameters['conversationId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/res/:id',
        // #1151 — the deep links ride the memberNotifications gate the
        // comment above always claimed; now the route does too.
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.memberNotifications])),
        builder: (context, state) => ReferenceLinkScreen.reservation(
          id: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/space/:kind/:id',
        // #1151 — the deep links ride the memberNotifications gate the
        // comment above always claimed; now the route does too.
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.memberNotifications])),
        builder: (context, state) => ReferenceLinkScreen.space(
          kind:
              SpaceKind.values.asNameMap()[state.pathParameters['kind'] ??
                  ''] ??
              SpaceKind.seat,
          id: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        // #1120 — the workspace library.
        path: '/library',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.workspaceLibrary], to: '/workspace-settings')),
        builder: (context, state) => const WorkspaceLibraryScreen(),
      ),
      GoRoute(
        path: '/workspace-code',
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.manageConfiguration)),
        builder: (context, state) => const WorkspaceCodeScreen(),
      ),
      GoRoute(
        path: '/scan-join',
        builder: (context, state) => const ScanJoinScreen(),
      ),
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
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.manageIntegrations)),
        builder: (context, state) => const McpPolicyScreen(),
      ),
      // #1827 — the guided setup, for the same people. Not behind mcpAccess:
      // turning it on is one of its steps.
      GoRoute(
        path: '/settings/assistant-setup',
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.manageIntegrations)),
        builder: (context, state) => const AssistantSetupScreen(),
      ),
      // #1648 — the protected client purpose selects identity or MCP consent.
      // Every consent call requires the app's native session.
      GoRoute(
        path: '/oauth/consent',
        builder: (context, state) => OAuthConsentRoute(
            authorizationId: state.uri.queryParameters['authorization_id'] ?? ''),
      ),
      GoRoute(
        path: '/nfc-config',
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.operateKiosk, features: [WorkspaceFeature.nfcBadges])),
        builder: (context, state) => const NfcConfigScreen(),
      ),
      GoRoute(
        path: '/payment-config',
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.manageIntegrations, features: [WorkspaceFeature.onlinePayments])),
        builder: (context, state) => const PaymentConfigScreen(),
      ),
      GoRoute(
        path: '/billing',
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.manageBilling)),
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: '/invoices',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.invoicing], to: '/money')),
        builder: (context, state) => const InvoicesScreen(),
      ),
      // The sortable register (0072): every member reads their own, an
      // issuer the whole workspace's.
      GoRoute(
        path: '/invoice-register',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.invoicing], to: '/money')),
        builder: (context, state) => const InvoiceRegisterScreen(),
      ),
      // Where invoices are POSTED (0073) — owner-only.
      GoRoute(
        path: '/einvoice-config',
        // #2137 — the credentials RPCs ask manageIntegrations.
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.manageIntegrations, features: [WorkspaceFeature.invoicing], to: '/money')),
        builder: (context, state) => const EInvoiceConfigScreen(),
      ),
      // The workspace document library (#500) — every member, gated by
      // the documents feature; RLS decides which rows each role sees.
      GoRoute(
        path: '/documents',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.documents])),
        builder: (context, state) => const DocumentsScreen(),
      ),
      // #513 — the central role→permission matrix. Anyone with a role
      // can READ it; editing needs manageRoles (enforced in-screen and
      // by the RPC).
      // #827 — the invoicing wizard.
      GoRoute(
        path: '/invoicing/wizard',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.invoicingWizard], to: '/money')),
        builder: (context, state) => InvoicingWizardScreen(
          initialRun: WizardRun.values
              .asNameMap()[state.uri.queryParameters['run'] ?? ''],
        ),
      ),
      // #825 — one page per member.
      GoRoute(
        path: '/member/:memberId',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.memberPage], to: '/directory')),
        builder: (context, state) =>
            MemberPage(memberId: state.pathParameters['memberId'] ?? ''),
      ),
      // #822 — the report editor as a full-screen designer.
      GoRoute(
        path: '/report-editor',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.reportDesigner], to: '/money')),
        builder: (context, state) => const ReportEditorScreen(),
      ),
      GoRoute(
        path: '/roles',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.roleManagement])),
        builder: (context, state) => const RolesScreen(),
      ),
      // #886 — the person's identity as the documents print it.
      GoRoute(
        path: '/settings/personal-info',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.personalInfo], to: '/settings')),
        builder: (context, state) => const PersonalInfoScreen(),
      ),
      // #902 — the conditions this member's documents print, read-only.
      GoRoute(
        path: '/settings/payment-terms',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.memberPaymentTerms], to: '/settings')),
        builder: (context, state) => const MyPaymentTermsScreen(),
      ),
      // #945 — the workspace's sites.
      GoRoute(
        path: '/settings/sites',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.multiSite], to: '/settings')),
        builder: (context, state) => const SitesScreen(),
      ),
      // #934 — the treasurer's view, and the guided repartition.
      GoRoute(
        path: '/money/status',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.workspaceStatus], to: '/money')),
        builder: (context, state) => const WorkspaceStatusScreen(),
      ),
      GoRoute(
        path: '/money/repartition-wizard',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.expenseRepartitionWizard], to: '/money')),
        builder: (context, state) => const RepartitionWizardScreen(),
      ),
      // #1277 — the words this space uses instead of the product's.
      GoRoute(
        path: '/settings/wording',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.workspaceVocabulary], to: '/settings')),
        builder: (context, state) => const WordingScreen(),
      ),
      // #1289 — the colour this space gives the app.
      GoRoute(
        path: '/settings/colours',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.workspaceBranding], to: '/settings')),
        builder: (context, state) => const ColoursScreen(),
      ),
      // #1528 — the roles this space defines for itself.
      GoRoute(
        path: '/settings/roles-of-this-space',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.customRoles], to: '/settings')),
        builder: (context, state) => const RolesOfSpaceScreen(),
      ),
      // #1288 — the questions this space asks its members.
      GoRoute(
        path: '/settings/questions',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.customFields], to: '/settings')),
        builder: (context, state) => const QuestionsScreen(),
      ),
      // #1247 — one place that answers "does anything need me?".
      // Appended last: route pins are positional.
      GoRoute(
        path: '/attention',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.decisionSurface], to: '/')),
        builder: (context, state) => const AttentionScreen(),
      ),
      // #925 — how every journal numbers its documents, one screen.
      GoRoute(
        path: '/settings/number-sequences',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.numberSequences], to: '/settings')),
        builder: (context, state) => const NumberSequencesScreen(),
      ),
      // #887 — create or edit a managed member's identity.
      GoRoute(
        path: '/members/managed',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.managedProfiles], to: '/members')),
        builder: (context, state) => ManagedProfileScreen(
          memberId: state.uri.queryParameters['member'],
        ),
      ),
      // The workspace's manual payment methods (#486) — owner-only.
      GoRoute(
        path: '/payment-methods',
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.manageIntegrations, to: '/money')),
        builder: (context, state) => const PaymentMethodsScreen(),
      ),
      // The workspace's legal identity (0069) — owner-only, and only
      // where invoices exist at all.
      GoRoute(
        path: '/legal-identity',
        redirect: env.guard(const RouteAccess(
            features: [WorkspaceFeature.invoicing],
            bypass: RoleBypass.owner,
            to: '/money')),
        builder: (context, state) => const LegalIdentityScreen(),
      ),
      // The workspace's VAT rates (0072) — owner-only, like the identity
      // they belong to.
      // Periodic VAT declarations (#534) — owner-only, needs invoicing
      // AND the vatDeclarations feature; the screen gates the regime.
      // #988/#990 — the deployment between the two sides of a pair:
      // the feature, a deploy permission, and a twin to deploy to.
      GoRoute(
        path: '/deployment',
        redirect: env.guard(RouteAccess(
            features: const [WorkspaceFeature.deployments],
            permission: WorkspacePermission.deployToDev,
            when: (c) => c.hasPairedTwin,
            to: '/settings')),
        builder: (context, state) => const DeploymentScreen(),
      ),
      GoRoute(
        path: '/vat-declarations',
        redirect: env.guard(const RouteAccess(
            features: [
              WorkspaceFeature.invoicing,
              WorkspaceFeature.vatDeclarations,
            ],
            bypass: RoleBypass.owner,
            to: '/money')),
        builder: (context, state) => const VatDeclarationsScreen(),
      ),
      GoRoute(
        path: '/vat',
        // #2137 — set_vat_rates asks manageBilling.
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.manageBilling, features: [WorkspaceFeature.vatManagement], to: '/money')),
        builder: (context, state) => const VatScreen(),
      ),
      GoRoute(
        path: '/services',
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.manageServices, features: [WorkspaceFeature.services])),
        builder: (context, state) => const ServicesScreen(),
      ),
      GoRoute(
        // Owner AND admins (#167, epic decision): catalog management is a
        // canAdminister capability, not owner-only.
        path: '/accessories',
        redirect: env.guard(const RouteAccess(
            features: [WorkspaceFeature.accessorySupplements],
            permission: WorkspacePermission.manageServices,
            bypass: RoleBypass.administrator)),
        builder: (context, state) => const AccessoriesScreen(),
      ),
      GoRoute(
        path: '/features',
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.manageConfiguration)),
        builder: (context, state) => const FeaturesScreen(),
      ),
      GoRoute(
        path: '/reports',
        redirect: env.guard(RouteAccess(
            when: (c) => workspaceReportsAvailable(c.enabledFeatures, c.permissions,
                isAdmin: c.isAdmin),
            to: '/settings')),
        builder: (context, state) => WorkspaceSettingsScreen(reportsOnly: true, reportSection: state.uri.queryParameters['section']), // #2313
      ),
      GoRoute(
        path: '/workspace-settings',
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.workspaceSettings)),
        builder: (context, state) => const WorkspaceSettingsScreen(),
      ),
      GoRoute(
        path: '/validation',
        // #816 — the `manageValidation` permission, which the server's
        // write policy now asks too (0144); owners always hold it.
        redirect: env.guard(
            const RouteAccess(permission: WorkspacePermission.manageValidation)),
        builder: (context, state) => const ValidationSettingsScreen(),
      ),
      // #1923 — Business analytics: only with a module this reader may see.
      GoRoute(
        path: '/bi',
        redirect: env.guard(RouteAccess(
            when: (c) => biAvailable(
                features: c.enabledFeatures, permissions: c.permissions))),
        builder: (context, state) => const BiScreen(),
      ),
      GoRoute(
        path: '/availability',
        redirect: env.guard(const RouteAccess(permission: WorkspacePermission.workspaceSettings)),
        builder: (context, state) => const AvailabilityScreen(),
      ),
      GoRoute(
        path: '/members',
        // Admins reach member management too (0044: they set reservation
        // limits and issue badges); owner-only controls gate inside.
        redirect: env.guard(const RouteAccess(
            permission: WorkspacePermission.manageMembers,
            bypass: RoleBypass.administrator)),
        builder: (context, state) => const MembersScreen(),
      ),
      GoRoute(
        path: '/editor',
        // #2137 — the owner, or whoever holds manageSites (0363).
        redirect: env.guard(const RouteAccess(
            permission: WorkspacePermission.manageSites,
            bypass: RoleBypass.owner)),
        builder: (context, state) => const EditorScreen(),
        routes: [
          GoRoute(
            path: 'level/:levelId',
            builder: (context, state) =>
                LevelCanvasScreen(levelId: state.pathParameters['levelId']!),
          ),
        ],
      ),
      // #1312 — where a server older than this app sends every route.
      GoRoute(path: kSchemaUpdateRoute,
          builder: (context, state) => const SchemaUpdateScreen()),
      // Account history and applicant chat survive a refused membership.
      GoRoute(path: '/account-activity',
          builder: (context, state) => MyFinancesScreen(
              workspaceId: state.uri.queryParameters['workspace'])),
      GoRoute(path: '/discover',builder:(context,state)=>const discovery.DirectoryScreen()),
      GoRoute(path: '/p/:id', builder: (context, state) => PublicPersonScreen(userId: state.pathParameters['id'] ?? '')), // #2211
      GoRoute(path: '/connections',builder:(context,state)=>const ConnectionsScreen()),
      GoRoute(path: '/account-messages',builder:(context,state)=>AccountMessengerScreen(
        source:state.uri.queryParameters['source']??'',recipient:state.uri.queryParameters['recipient'],name:state.uri.queryParameters['name']??'')),
      GoRoute(path: '/settings/public-page',redirect:env.guard(const RouteAccess(bypass:RoleBypass.owner,to:'/profiles')),builder:(context,state)=>const PublicPageEditor()),
      GoRoute(path: '/applications',
          builder: (context, state) => const WorkspaceApplicationsScreen()),
      // #2085 — what my roles give me here (or, for whoever administers
      // members or roles, what someone else's give them).
      GoRoute(
        path: '/settings/what-you-can-do',
        redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.roleAssignment], to: '/settings')),
        builder: (context, state) => WhatYouCanDoScreen(
            memberId: state.uri.queryParameters['member']),
      ),
      // The task wizard: guides, recordings and tools, one screen.
      GoRoute(path: taskWizardRoute,
          builder: (context, state) => const TaskWizardScreen()),
      // #1865 — this account's own recordings on this device. Account-
      // level: reading, exporting and deleting them never needs a flag;
      // Start is gated by taskRecorder inside the screen.
      GoRoute(path: taskRecorderRoute,
          builder: (context, state) => const TaskRecorderScreen()),
      // #1872 — the local task workbench: no account, no workspace.
      GoRoute(path: taskWorkbenchRoute,
          builder: (context, state) => const TaskWorkbenchScreen()),
      // #2145 — Connect an assistant, for every member where mcpAccess is on.
      GoRoute(path: connectAssistantRoute,
          redirect: env.guard(const RouteAccess(features: [WorkspaceFeature.mcpAccess], to: '/assistants')),
          builder: (context, state) => const ConnectAssistantScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  // #1650 — the continuation is spent where the person arrives.
  void arrived() => spendOnArrival(router, ref);
  router.routerDelegate.addListener(arrived);
  ref.onDispose(() => router.routerDelegate.removeListener(arrived));
  return router;
}
