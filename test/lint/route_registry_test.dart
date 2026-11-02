// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Route-registry contract (#1863): a route cannot be added, duplicated
// or ungated silently.
//
// It used to pin how many times `GoRoute(` was spelled in router.dart. A
// count stays the same when a route's path changes or its
// `featureEnabled(...)` redirect goes missing, and moves when a
// correct refactor re-spells a route. This reads the routes the live
// GoRouter registers and resolves a deep link to each through every
// redirect it really has.
//
// Adding a route? Still walk the checklist:
//  1. If the surface belongs to a WorkspaceFeature: `featureEnabled`
//     redirect on the route AND the hidden entry point.
//  2. A RouteRule in lib/app/route_classes.dart
//     (route_policy_registry_test).
//  3. The Features screen itself stays ungated — always reachable.
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/router_paths.dart';

/// #2521 — the STRUCTURAL workspace routes: always on, because switching
/// one off would lock the owner out of running the space or leave the
/// product with nothing to do. Reviewed 2026-10-25 (decision on #2521).
/// Each names why no flag may own it; its sub-options keep their flags.
const Map<String, String> _structural = {
  '/messages': 'the landing and fallback route; pending requests arrive here',
  '/reserve': "the product's home and its core function",
  '/plan': 'alias of /reserve',
  '/pending': 'the waiting room exists before a membership, so no flag is read',
  '/workspace-code': 'joining by invitation is infrastructure (#917, #1652)',
  '/features': 'the switch that turns everything back on (#1327)',
  '/workspace-settings': 'the identity every money and date rule reads',
  '/reports': 'its documents section is part of workspace settings (#2301)',
  '/members': 'admission and roles cannot be managed without it',
  '/editor': 'the plan is what every booking books',
  '/editor/level/:levelId': 'a level of the plan, as /editor',
  '/availability': 'the server always enforces opening days and closures',
  '/validation': 'admission and every pending request run through it',
  '/settings/assistants':
      'narrows assistant exposure; not behind mcpAccess (#1826)',
  '/settings/assistant-setup':
      'turns assistants on; not behind mcpAccess (#1827)',
};

/// The structural routes a deep link never stays on: the alias resolves
/// to its target, and the waiting room opens only for a pending member.
const Set<String> _structuralRedirects = {'/plan', '/pending'};

/// The routes outside any workspace, by class: an account page (the
/// person's own, no workspace decides it), a device page, a public entry
/// (reachable signed out) or the platform (the instance operator's). No
/// workspace flag can own them.
const Map<String, String> _notWorkspace = {
  '/me': 'account',
  '/onboarding': 'account',
  '/settings':
      'account — sign-out and status; workspace sections gate inside (#2521)',
  '/profiles': 'account',
  '/server': 'entry',
  '/developer': 'device — local trace diagnostics (#144, #2521)',
  '/help': 'entry',
  '/privacy': 'entry',
  '/linked-accounts': 'account',
  '/scan-join': 'account',
  '/mcp/confirm/:id': 'account',
  '/assistants': 'account',
  '/database/assistant-approvals': 'account',
  // #1827 B — installation-wide; the server (0341) refuses everyone else.
  '/installation/assistants': 'platform',
  '/oauth/consent': 'account',
  '/account-activity': 'account',
  '/discover': 'entry',
  // #3235 — the demo's public entry: the demoMode flag is answered on the
  // page itself, which says so instead of redirecting.
  '/demo': 'entry',
  // #2211 — readable by anyone, signed in or not.
  '/p/:id': 'entry',
  '/connections': 'account',
  '/account-messages': 'account',
  '/applications': 'account',
  // #1865 — the account's own recordings on this device; starting one is
  // gated by taskRecorder inside the screen.
  '/task-recorder': 'account',
  '/task-wizard': 'account',
  // #2388 — pages opened over an account screen.
  '/me/messages/starred': 'account',
  '/me/messages/new-group': 'account',
  '/account-activity/history': 'account',
  '/help/support-bundle': 'entry',
  // #1872 — the local workbench: no account, no workspace, no flag.
  '/task-workbench': 'device',
};

/// What an owner can still open with EVERY feature switched off: the
/// structural workspace routes and the routes outside any workspace.
/// A route that joins this set lost its feature gate, or was added
/// without one; a route that leaves it gained one. Either way the change
/// is a decision, so it is written above with its reason.
final Set<String> _openWithEveryFeatureOff = {
  ..._structural.keys.where((p) => !_structuralRedirects.contains(p)),
  ..._notWorkspace.keys,
};

void main() {
  testWidgets('the router registers every path once', (tester) async {
    final app = await bootRouter(tester);
    final paths = registeredRoutePaths(app.router.configuration.routes);
    final seen = <String>{};
    final twice = [
      for (final p in paths)
        if (!seen.add(p)) p,
    ];
    expect(paths, isNotEmpty);
    expect(twice, isEmpty, reason: 'registered more than once: $twice');
  });

  testWidgets('with every feature off, only the reviewed routes open', (
    tester,
  ) async {
    final app = await bootRouter(
      tester,
      featureFlags: {for (final f in WorkspaceFeature.values) f.dbKey: false},
    );
    final open = <String>{};
    for (final p in registeredRoutePaths(app.router.configuration.routes)) {
      final location = concreteRoute(p);
      if (await resolveRoute(app, location) == location) open.add(p);
    }
    expect(
      open.difference(_openWithEveryFeatureOff),
      isEmpty,
      reason:
          'these deep links open with every feature off — add the '
          "route's featureEnabled redirect, or review it into the set",
    );
    expect(
      _openWithEveryFeatureOff.difference(open),
      isEmpty,
      reason:
          'these no longer open with every feature off — remove '
          'them from the reviewed set',
    );
  });

  testWidgets('each reviewed route has its class; a structural route that '
      'redirects lands on a structural one', (tester) async {
    final app = await bootRouter(
      tester,
      featureFlags: {for (final f in WorkspaceFeature.values) f.dbKey: false},
    );
    final registered = registeredRoutePaths(app.router.configuration.routes);
    expect(
      _structural.keys.where((p) => !registered.contains(p)),
      isEmpty,
      reason: 'a structural route the router does not register',
    );
    // The class each entry names is the class the route policy applies.
    for (final p in _structural.keys) {
      expect(classifyRoute(p), RouteClass.workspace, reason: p);
    }
    for (final p in _notWorkspace.keys) {
      expect(classifyRoute(p), isNot(RouteClass.workspace), reason: p);
    }
    for (final p in _structuralRedirects) {
      final landing = await resolveRoute(app, concreteRoute(p));
      expect(landing, isNot(p));
      expect(
        _structural.keys,
        contains(landing),
        reason: '$p lands on $landing',
      );
    }
  });
}
