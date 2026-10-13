// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — the router's one global redirect. The rules live in
// route_policy.dart as a pure function over facts, and who may open which
// workspace screen in route_access.dart; this file only collects the facts
// and asks. Building them reads; nothing here writes except the two things
// a redirect has always done (hold an invitation link, keep a signed-out
// request).
//
// Navigation policy, not security: the backend stays authoritative.
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/backend/schema_version.dart';
import '../core/instance/schema_compatibility.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/kiosk/providers/kiosk_mode.dart';
import '../features/profile/providers/profile_providers.dart';
import '../features/workspace/application/pending_invitation.dart';
import '../features/workspace/domain/member.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/providers/workspace_providers.dart';
import '../features/workspace/providers/workspace_roles_providers.dart';
import 'entry_intent.dart';
import 'entry_intents.dart';
import 'entry_resumption.dart';
import 'route_access.dart';
import 'route_classes.dart';
import 'route_env.dart';
import 'route_policy.dart';

/// Where [state] is redirected, or null to stay.
String? appRedirect(RouteEnv env, GoRouterState state) {
  final ref = env.ref;
  if (!ref.mounted) return null; // a rebuilt router may be asked once more
  // #1652 — an invitation link opened from outside: the link (and the
  // code in it) leaves the location at once, is held in memory for
  // the join field, and Join is selected. Nothing is joined here.
  if (isInvitationLink(state.uri)) {
    ref
        .read(arrivedInvitationsProvider)
        .hold(Uri(scheme: 'deskilo', host: 'join', query: state.uri.query)
            .toString());
    return const EntryIntent.join('invitation-link').destination;
  }
  final intent = ref.read(entryIntentsProvider);
  final auth = ref.read(authStateProvider);
  // Nothing else is read until the session is known: a read flushes a
  // provider the scheduler is about to rebuild, and while a scope is
  // being updated that is a rebuild twice in one frame. The policy
  // knows AuthFact.loading for its table; the router never sends it.
  if (auth.isLoading) return null;
  final facts = _factsOf(env, intent, signedIn: auth.value != null);
  final request =
      RouteRequest(state.uri.path, query: state.uri.queryParameters);
  final decision = settleDestination(request, facts);
  // #1650 — the one write the redirect asks for: a signed-out
  // person's request, kept as the place to come back to. Spending
  // happens on arrival (entry_resumption.dart), never here.
  if (decision.reason == RouteReason.signInRequired) {
    captureRequest(ref, state.uri, intent);
  }
  if (decision.redirect == null &&
      _refusedByPermissions(env, facts, state.uri.path)) {
    return landingFor(env.permissions);
  }
  return decision.redirect;
}

/// Beyond what every member has, a screen opens only for someone who
/// holds one of its permissions (route_access.dart). Skipped while the
/// roles are still being read: a delegate's grants arrive with them, and a
/// deep link must not bounce on the first frame.
bool _refusedByPermissions(RouteEnv env, RouteFacts facts, String path) {
  final ref = env.ref;
  return facts.membership == MembershipFact.active &&
      !_isKioskAccount(env, ref.read(myMemberProvider).value) &&
      !ref.read(workspaceRoleAssignmentsProvider).isLoading &&
      // Permissions come from the workspace's matrix: until it is read,
      // nobody holds anything yet and nobody is bounced for it.
      ref.read(currentWorkspaceProvider).value != null &&
      !mayOpen(path, env.permissions);
}

bool _isKioskAccount(RouteEnv env, Member? me) =>
    me != null && me.isKiosk && env.featureEnabled(WorkspaceFeature.kioskMode);

RouteFacts _factsOf(
  RouteEnv env,
  EntryIntent? intent, {
  required bool signedIn,
}) {
  final ref = env.ref;
  final profile = ref.read(myProfileProvider);
  final workspaces = ref.read(myWorkspacesProvider);
  final member = ref.read(myMemberProvider);
  final chosen = ref.read(activeWorkspaceIdProvider);
  final me = member.value;
  final kioskAccount = _isKioskAccount(env, me);
  return RouteFacts(
    schema: ref.read(schemaCompatibilityProvider).value ??
        SchemaCompatibility.unknown,
    auth: signedIn ? AuthFact.signedIn : AuthFact.signedOut,
    privacy: privacyFactOf(
        loading: profile.isLoading,
        failed: profile.hasError,
        accepted: profile.value?.privacyAcceptedVersion ==
            ref.read(requiredPrivacyVersionProvider)),
    // A list being REFRESHED is loading, whatever it held before: the
    // signed-out answer is an empty list, and reading it as "none"
    // in the frame after sign-in sent everybody through onboarding.
    workspaces: workspacesFactOf(
        loading: workspaces.isLoading,
        count: workspaces.value?.length,
        failed: workspaces.hasError),
    membership: member.isLoading && !member.hasValue
        ? MembershipFact.loading
        : switch (me?.status) {
            null => MembershipFact.none,
            MemberStatus.active => MembershipFact.active,
            MemberStatus.pending => MembershipFact.pending,
            _ => MembershipFact.inactive,
          },
    space: spaceFactOf(
        resolving: chosen.isLoading, // #1823: a refresh is not an answer
        chosen: chosen.value,
        spaces: [...?workspaces.value?.map((w) => w.id)]),
    kiosk: !kioskAccount
        ? KioskFact.notKiosk
        : switch (ref.read(kioskModeProvider)) {
            KioskModeDecision.pending => KioskFact.gatePending,
            KioskModeDecision.accepted => KioskFact.locked,
            KioskModeDecision.rejected => KioskFact.released,
          },
    featureEnabled: env.featureEnabled,
    home: intent?.destination ?? kDefaultHome,
  );
}
