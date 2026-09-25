// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — the route policy resolves every entry state to ONE exact
// destination, for a stated reason, and the destination is never itself
// redirected. Each row is a request, the facts, the first hop and — when
// the hops go further — where they settle. The fixed-point property over
// every route and every fact lives in route_policy_grid_test.dart; this
// is the table a person reads to know what the app does.
import 'package:deskilo/app/route_policy.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

bool _wizardOff(WorkspaceFeature f) => f != WorkspaceFeature.instanceWizard;

const out = RouteFacts(auth: AuthFact.signedOut);
const member = RouteFacts(auth: AuthFact.signedIn);
const zero = RouteFacts(auth: AuthFact.signedIn, workspaces: WorkspacesFact.none);
const pendingA = RouteFacts(auth: AuthFact.signedIn, membership: MembershipFact.pending);
const unconsented = RouteFacts(auth: AuthFact.signedIn, privacy: PrivacyFact.notAccepted);
const profileDown = RouteFacts(auth: AuthFact.signedIn, privacy: PrivacyFact.unavailable);
const listDown = RouteFacts(auth: AuthFact.signedIn, workspaces: WorkspacesFact.unavailable);
const behindOut = RouteFacts(auth: AuthFact.signedOut, schema: SchemaCompatibility.behind);
const behindIn = RouteFacts(auth: AuthFact.signedIn, schema: SchemaCompatibility.behind);
const gate = RouteFacts(auth: AuthFact.signedIn, kiosk: KioskFact.gatePending);
const locked = RouteFacts(auth: AuthFact.signedIn, kiosk: KioskFact.locked);
const released = RouteFacts(auth: AuthFact.signedIn, kiosk: KioskFact.released);

typedef Row = (String name, String at, RouteFacts facts, String? first, RouteReason? why, String? settled);

Row stay(String name, String at, RouteFacts facts) => (name, at, facts, null, null, null);
Row go(String name, String at, RouteFacts facts, String to, RouteReason why, {String? settled}) =>
    (name, at, facts, to, why, settled);

final rows = <Row>[
  // signed out
  go('signed out: a workspace route asks to sign in', '/reserve', out, '/auth', RouteReason.signInRequired),
  stay('signed out: the server chooser is reachable', '/server', out),
  stay('signed out: the help is reachable', '/help', out),
  stay('signed out: the privacy page is reachable', '/privacy', out),
  stay('signed out: the wizard authorises itself', '/server/new-instance', out),
  go('signed out: an account page asks to sign in', '/profiles', out, '/auth', RouteReason.signInRequired),
  go('signed out: an unknown route is refused to sign-in', '/nowhere', out, '/auth', RouteReason.unknownRoute),
  go('signed out: the schema notice with a current schema', '/server-update', out, '/reserve', RouteReason.schemaCurrent, settled: '/auth'),
  stay('still loading: nothing moves', '/money', const RouteFacts(auth: AuthFact.loading)),
  // the #1649 states own the sign-in screen
  go('verification required: the target waits', '/reserve', const RouteFacts(auth: AuthFact.verificationRequired), '/auth', RouteReason.signInRequired),
  stay('verification required: stays on sign-in', '/auth', const RouteFacts(auth: AuthFact.verificationRequired)),
  go('recovery in progress: the target waits', '/money', const RouteFacts(auth: AuthFact.recoveryInProgress), '/auth', RouteReason.signInRequired),
  stay('recovery in progress: stays on sign-in', '/auth', const RouteFacts(auth: AuthFact.recoveryInProgress)),
  // signed in
  go('signed in on sign-in goes home', '/auth', member, '/reserve', RouteReason.alreadySignedIn),
  go('signed in on sign-in returns to the validated target', '/auth', const RouteFacts(auth: AuthFact.signedIn, home: '/money'), '/money', RouteReason.alreadySignedIn),
  stay('member: a workspace route opens', '/reserve', member),
  stay("member: a permission route is the guard's business", '/settings', member),
  go('unknown route is refused home', '/nowhere', member, '/reserve', RouteReason.unknownRoute),
  go('unknown route with no workspace settles on onboarding', '/nowhere', zero, '/reserve', RouteReason.unknownRoute, settled: '/onboarding?first=1'),
  // consent
  go('not accepted: a workspace route asks for consent', '/reserve', unconsented, '/consent', RouteReason.consentRequired),
  go('not accepted: an account page asks for consent', '/profiles', unconsented, '/consent', RouteReason.consentRequired),
  stay('not accepted: the help stays open', '/help', unconsented),
  stay('not accepted: the server chooser stays open', '/server', unconsented),
  stay('not accepted: the consent itself stays', '/consent', unconsented),
  go('profile unavailable: its own reason, not a fresh acceptance', '/reserve', profileDown, '/consent', RouteReason.profileUnavailable),
  stay('profile unavailable: the consent screen stays (retry lives there)', '/consent', profileDown),
  go('accepted: the consent bounces home', '/consent', member, '/reserve', RouteReason.consentAlreadyGiven),
  stay('accepted: reviewing the consent stays', '/consent?review=1', member),
  stay('profile loading: nothing moves', '/reserve', const RouteFacts(auth: AuthFact.signedIn, privacy: PrivacyFact.loading)),
  // zero workspaces
  go('no workspace: a workspace route goes to onboarding', '/reserve', zero, '/onboarding?first=1', RouteReason.noWorkspace),
  stay('no workspace: the account pages open', '/profiles', zero),
  stay('no workspace: linked accounts open', '/linked-accounts', zero),
  stay('no workspace: the server chooser opens', '/server', zero),
  stay('no workspace: the help opens', '/help', zero),
  stay('no workspace: onboarding opens', '/onboarding?first=1', zero),
  stay('no workspace: the join scanner opens', '/scan-join', zero),
  stay('no workspace: the wizard is not behind a workspace flag', '/server/new-instance', const RouteFacts(auth: AuthFact.signedIn, workspaces: WorkspacesFact.none, featureEnabled: _wizardOff)),
  stay('instance admin without membership reviews the server', '/server', zero),
  stay('workspaces loading: nothing moves', '/reserve', const RouteFacts(auth: AuthFact.signedIn, workspaces: WorkspacesFact.loading)),
  // unavailable is not "none"
  go('unavailable: the chooser, never a creation demand', '/reserve', listDown, '/profiles', RouteReason.workspacesUnavailable),
  stay('unavailable: the chooser stays', '/profiles', listDown),
  stay('unavailable: a deliberate onboarding visit still opens', '/onboarding', listDown),
  // with a workspace
  go('first-run onboarding bounces once a workspace exists', '/onboarding?first=1', member, '/reserve', RouteReason.firstRunDone),
  stay('a deliberate onboarding visit is never hijacked', '/onboarding', member),
  go('wizard off in the workspace sends to the server screen', '/server/new-instance', const RouteFacts(auth: AuthFact.signedIn, featureEnabled: _wizardOff), '/server', RouteReason.featureOff),
  stay('wizard on opens', '/server/new-instance', member),
  // pending A / active B
  go('pending: a workspace route waits', '/reserve', pendingA, '/pending', RouteReason.membershipPending),
  go('pending: money waits too', '/money', pendingA, '/pending', RouteReason.membershipPending),
  stay('pending: the waiting room stays', '/pending', pendingA),
  stay('pending: the help stays open', '/help', pendingA),
  stay('pending: the account pages stay open', '/profiles', pendingA),
  stay('pending: switching identity stays open', '/linked-accounts', pendingA),
  go('active in B: the waiting room bounces home', '/pending', member, '/reserve', RouteReason.notPending),
  stay('no membership row: nothing moves', '/reserve', const RouteFacts(auth: AuthFact.signedIn, membership: MembershipFact.none)),
  // kiosk
  go('kiosk gate pending owns every route', '/help', gate, '/kiosk-gate', RouteReason.kioskGate),
  stay('kiosk gate stays', '/kiosk-gate', gate),
  go('kiosk locked collapses to the kiosk', '/reserve', locked, '/kiosk', RouteReason.kioskLocked),
  stay('kiosk locked stays', '/kiosk', locked),
  go('kiosk rejected leaves the kiosk view', '/kiosk', released, '/reserve', RouteReason.kioskReleased),
  go('a regular member never lands on the kiosk', '/kiosk', member, '/reserve', RouteReason.kioskReleased),
  go('a regular member never lands on the gate', '/kiosk-gate', member, '/reserve', RouteReason.kioskReleased),
  // schema behind
  go('behind: every route goes to the notice', '/money', behindIn, '/server-update', RouteReason.schemaBehind),
  go('behind, signed out: the notice, not sign-in', '/auth', behindOut, '/server-update', RouteReason.schemaBehind),
  stay('behind: the server screen is the way out', '/server', behindOut),
  stay('behind: the wizard is the way out', '/server/new-instance', behindOut),
  stay('behind: the notice stays', '/server-update', behindIn),
  go('current: the notice bounces home', '/server-update', member, '/reserve', RouteReason.schemaCurrent),
];

void main() {
  for (final (name, at, facts, first, why, settled) in rows) {
    test(name, () {
      final request = RouteRequest.parse(at);
      final hop = resolveDestination(request, facts);
      expect(hop.redirect, first, reason: 'first hop from $at');
      expect(hop.reason, why);
      final end = settleDestination(request, facts);
      expect(end.reason, isNot(RouteReason.loopAverted));
      expect(end.redirect, settled ?? first, reason: 'where $at settles');
      final landing = end.redirect ?? at;
      expect(resolveDestination(RouteRequest.parse(landing), facts).redirect,
          isNull, reason: '$landing is redirected again — a loop by another name');
    });
  }
}
