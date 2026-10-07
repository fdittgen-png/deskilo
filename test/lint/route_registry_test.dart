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
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/router_paths.dart';

/// What an owner can still open with EVERY feature switched off: the
/// account, entry and settings routes no flag owns. Reviewed 2026-10-01
/// (#1863). A route that joins this set lost its feature gate, or was
/// added without one; a route that leaves it gained one. Either way the
/// change is a decision, so it is written here.
const Set<String> _openWithEveryFeatureOff = {
  '/me',
  '/onboarding',
  '/messages',
  '/reserve',
  '/settings',
  '/profiles',
  '/server',
  '/developer',
  '/help',
  '/privacy',
  '/linked-accounts',
  '/workspace-code',
  '/scan-join',
  '/mcp/confirm/:id',
  '/assistants',
  '/database/assistant-approvals',
  // #1827 B — installation-wide, for the instance operator: no workspace
  // flag owns it; the server (0341) refuses everyone else.
  '/installation/assistants',
  '/settings/assistants',
  '/settings/assistant-setup',
  '/oauth/consent',
  '/billing',
  '/payment-methods',
  '/features',
  '/workspace-settings',
  '/validation',
  '/availability',
  '/members',
  '/editor',
  '/editor/level/:levelId',
  '/account-activity',
  '/discover',
  // #2211 — a published public profile: readable by anyone, signed in or
  // not, whatever the workspace's flags (it is not a workspace screen).
  '/p/:id',
  '/connections',
  '/account-messages',
  '/settings/public-page',
  '/applications',
  // #1865 — the account's own recordings on this device: reading,
  // exporting and deleting them never needs a workspace flag; starting a
  // recording is gated by taskRecorder inside the screen.
  '/task-recorder',
  '/task-wizard',
  // #1872 — the local workbench: no account, no workspace, no flag.
  '/task-workbench',
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
}
