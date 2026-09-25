// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — the route-requirements policy, beside the router and out of it.
//
// The router's redirect used to be one 120-line closure reading nine
// providers, and its rules had grown boundaries nobody had chosen: every
// signed-out route bounced to /auth, the Server screen included, so a
// person could not even say WHICH server before signing in; the
// zero-workspace rule let only onboarding through, so a fresh account
// could not reach its own account pages or the help; a pending
// membership locked the person out of switching to the workspace where
// they were active. Each was a redirect that was right for the route it
// was written against and wrong for the routes added since.
//
// So the rules are here, as a pure function over FACTS the router
// collects — signed in or not, consent given or not, how many
// workspaces, which membership, kiosk or not — over the classes in
// route_classes.dart. A public entry needs nothing; a native account page
// needs a session and consent and NO workspace; an operator control is
// authorised by its own credentials in its own flow; a workspace route
// needs a membership; a route nobody registered is refused. This is
// classification and navigation, not authorisation: every screen behind
// a workspace route still asks its permission, and the server enforces
// its own.
//
// `resolveDestination` returns one hop; `settleDestination` follows the
// hops to the fixed point, and the table in test/app/route_policy_test.dart
// proves that every row settles in one — a redirect that lands on a
// location the policy would redirect again is a loop by another name.
import '../core/instance/schema_compatibility.dart';
import '../features/workspace/domain/workspace_feature.dart';
import 'route_classes.dart';
import 'schema_gate.dart';

/// What was asked for: a path and its query, never a whole URL.
class RouteRequest {
  const RouteRequest(this.location, {this.query = const {}});

  factory RouteRequest.parse(String location) {
    final uri = Uri.parse(location);
    return RouteRequest(uri.path, query: uri.queryParameters);
  }

  final String location;
  final Map<String, String> query;
}

/// The session, as the router sees it. The two #1649 states between
/// signed out and signed in are named so a table can say what each
/// resolves to: both stay on the sign-in screen, which owns the step,
/// and the intent that brought the person there is retained, not lost.
enum AuthFact {
  loading,
  signedOut,
  verificationRequired,
  recoveryInProgress,
  signedIn,
}

/// The consent, once the profile query has settled. `unavailable` is a
/// failed fetch: it is NOT "not accepted" — the consent screen shows a
/// retry, never a fresh legal acceptance over an unknown state.
enum PrivacyFact { loading, accepted, notAccepted, unavailable }

/// The membership list. `unavailable` is a failed fetch: it is NOT
/// "none", so it never becomes a demand to create a workspace.
enum WorkspacesFact { loading, none, some, unavailable }

/// My row in the ACTIVE workspace.
enum MembershipFact { loading, none, active, pending, inactive }

/// The wall-tablet lock (0043), already combined with the kioskMode flag
/// by whoever builds the facts: a kiosk account with the module off is
/// [notKiosk].
enum KioskFact { notKiosk, gatePending, locked, released }

bool _everythingOn(WorkspaceFeature _) => true;

/// Everything the policy is allowed to know. Building it reads; the
/// policy itself writes nothing.
class RouteFacts {
  const RouteFacts({
    required this.auth,
    this.schema = SchemaCompatibility.unknown,
    this.privacy = PrivacyFact.accepted,
    this.workspaces = WorkspacesFact.some,
    this.membership = MembershipFact.active,
    this.kiosk = KioskFact.notKiosk,
    this.featureEnabled = _everythingOn,
    this.home = kDefaultHome,
  });

  final AuthFact auth;
  final SchemaCompatibility schema;
  final PrivacyFact privacy;
  final WorkspacesFact workspaces;
  final MembershipFact membership;
  final KioskFact kiosk;
  final bool Function(WorkspaceFeature) featureEnabled;

  /// The validated destination a signed-in person returns to: the
  /// original intent when there is one (#1650 C3), else [kDefaultHome].
  final String home;

  bool get signedIn => auth == AuthFact.signedIn;
}

/// Why a hop was taken — a table asserts the reason beside the location,
/// so two rules sending to the same screen for different causes stay
/// distinguishable.
enum RouteReason {
  schemaBehind,
  schemaCurrent,
  signInRequired,
  alreadySignedIn,
  kioskGate,
  kioskLocked,
  kioskReleased,
  consentRequired,
  profileUnavailable,
  consentAlreadyGiven,
  noWorkspace,
  workspacesUnavailable,
  firstRunDone,
  membershipPending,
  notPending,
  featureOff,
  unknownRoute,

  /// `settleDestination` saw a location twice. The safe answer is to
  /// stay where the person asked: staying cannot loop.
  loopAverted,
}

/// One hop: stay, or go to [redirect] because [reason].
class RouteDecision {
  const RouteDecision.stay()
      : redirect = null,
        reason = null;
  const RouteDecision.go(String this.redirect, this.reason);
  const RouteDecision._averted()
      : redirect = null,
        reason = RouteReason.loopAverted;

  final String? redirect;
  final RouteReason? reason;

  bool get stays => redirect == null;

  @override
  String toString() =>
      stays ? 'stay${reason == null ? '' : ' ($reason)'}' : '$redirect ($reason)';
}

/// The policy: one hop for [request] under [facts]. Pure — reads its
/// arguments and nothing else, writes nothing.
RouteDecision resolveDestination(RouteRequest request, RouteFacts facts) {
  final path = request.location;
  // #1312 — a server older than the app gates every route but the way
  // out, and is then the ONLY rule; an unanswered check changes nothing.
  final schemaGate = schemaGateRedirect(facts.schema, path);
  if (facts.schema == SchemaCompatibility.behind) {
    return schemaGate == null
        ? const RouteDecision.stay()
        : RouteDecision.go(schemaGate, RouteReason.schemaBehind);
  }
  if (schemaGate != null) {
    return RouteDecision.go(facts.home, RouteReason.schemaCurrent);
  }
  if (facts.auth == AuthFact.loading) return const RouteDecision.stay();

  final kind = classifyRoute(path);
  final home = facts.home;
  if (!facts.signedIn) {
    return switch (kind) {
      RouteClass.publicEntry || RouteClass.operator =>
        const RouteDecision.stay(),
      RouteClass.unknown => const RouteDecision.go(
          '/auth', RouteReason.unknownRoute),
      _ => const RouteDecision.go('/auth', RouteReason.signInRequired),
    };
  }
  if (path == '/auth') {
    return RouteDecision.go(home, RouteReason.alreadySignedIn);
  }
  if (kind == RouteClass.unknown) {
    return RouteDecision.go(home, RouteReason.unknownRoute);
  }

  // Kiosk lock (0043) behind the kiosk gate: accepted collapses every
  // route to the kiosk view until the pad restarts; rejected lets this
  // run behave normally. A wall device has no personal consent to give,
  // so the lock is decided before the consent (#771).
  final atKiosk = path == '/kiosk';
  final atGate = path == '/kiosk-gate';
  switch (facts.kiosk) {
    case KioskFact.gatePending:
      if (!atGate) return const RouteDecision.go('/kiosk-gate', RouteReason.kioskGate);
      return const RouteDecision.stay();
    case KioskFact.locked:
      if (!atKiosk) return const RouteDecision.go('/kiosk', RouteReason.kioskLocked);
      return const RouteDecision.stay();
    case KioskFact.released:
    case KioskFact.notKiosk:
      if (atKiosk || atGate) {
        return RouteDecision.go(home, RouteReason.kioskReleased);
      }
  }

  // #751 — the GDPR consent gates everything but the public entries and
  // itself. Fails CLOSED once the profile query has settled; a fetch
  // that FAILED is its own reason, and the screen it lands on answers it
  // with a retry rather than an acceptance form.
  final atConsent = path == '/consent';
  final consentFree = atConsent || kind == RouteClass.publicEntry;
  switch (facts.privacy) {
    case PrivacyFact.loading:
      break;
    case PrivacyFact.accepted:
      if (atConsent && request.query['review'] != '1') {
        return RouteDecision.go(home, RouteReason.consentAlreadyGiven);
      }
    case PrivacyFact.notAccepted:
      if (!consentFree) {
        return const RouteDecision.go('/consent', RouteReason.consentRequired);
      }
    case PrivacyFact.unavailable:
      if (!consentFree) {
        return const RouteDecision.go('/consent', RouteReason.profileUnavailable);
      }
  }

  switch (kind) {
    case RouteClass.publicEntry:
      return const RouteDecision.stay();
    case RouteClass.nativeAccount:
      // The forced first-run visit to onboarding (`first=1`) is bounced
      // once a workspace exists; a deliberate visit (#89 add a profile)
      // is never hijacked.
      if (path == '/onboarding' &&
          request.query['first'] == '1' &&
          facts.workspaces == WorkspacesFact.some) {
        return RouteDecision.go(home, RouteReason.firstRunDone);
      }
      return const RouteDecision.stay();
    case RouteClass.operator:
      // #977 — the wizard's flag is a WORKSPACE's answer; with no
      // workspace there is nobody to have switched it off.
      if (facts.workspaces == WorkspacesFact.some &&
          !facts.featureEnabled(WorkspaceFeature.instanceWizard)) {
        return const RouteDecision.go('/server', RouteReason.featureOff);
      }
      return const RouteDecision.stay();
    case RouteClass.workspace:
    case RouteClass.unknown:
      break;
  }

  switch (facts.workspaces) {
    case WorkspacesFact.loading:
      return const RouteDecision.stay();
    case WorkspacesFact.none:
      return const RouteDecision.go(
          '/onboarding?first=1', RouteReason.noWorkspace);
    case WorkspacesFact.unavailable:
      // Not "none": the chooser shows the failure and offers the retry;
      // onboarding would demand a creation over an unknown state.
      return const RouteDecision.go(
          '/profiles', RouteReason.workspacesUnavailable);
    case WorkspacesFact.some:
      break;
  }

  // Pending membership (0052): the waiting room until the validators
  // approve. Account pages stay reachable above — the person may be
  // active in another workspace and switch to it.
  final atPending = path == '/pending';
  if (facts.membership == MembershipFact.pending) {
    return atPending
        ? const RouteDecision.stay()
        : const RouteDecision.go('/pending', RouteReason.membershipPending);
  }
  if (atPending) return RouteDecision.go(home, RouteReason.notPending);
  return const RouteDecision.stay();
}

/// Follows [resolveDestination] to its fixed point. The router calls this
/// so one navigation is one redirect; a location seen twice is a loop,
/// which is averted by staying put (and reported, so a test can fail on
/// it) rather than handed to GoRouter's redirect limit.
RouteDecision settleDestination(RouteRequest request, RouteFacts facts) {
  final first = resolveDestination(request, facts);
  if (first.stays) return first;
  final seen = <String>{request.location};
  var hop = first;
  while (true) {
    final target = RouteRequest.parse(hop.redirect!);
    if (!seen.add(target.location)) return const RouteDecision._averted();
    final next = resolveDestination(target, facts);
    if (next.stays) return RouteDecision.go(hop.redirect!, first.reason!);
    hop = next;
  }
}
