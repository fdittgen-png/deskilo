// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — every route the router registers is classified in
// route_classes.dart, and every rule there names a route that exists.
//
// The policy refuses what it does not know, so a GoRoute added without
// a rule is a screen nobody can open — reachable in a widget test that
// pumps it directly, dead in the app. The other direction rots too: a
// rule for a route that was deleted keeps a boundary alive for nothing.
// #1863 — both are read from the live GoRouter
// (test/helpers/router_paths.dart), not from a regexp over router.dart.
import 'dart:io';

import 'package:deskilo/app/route_classes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/router_paths.dart';

void main() {
  testWidgets('every router path has a class', (tester) async {
    final app = await bootRouter(tester);
    final unknown = registeredRoutePaths(app.router.configuration.routes)
        .where((p) => classifyRoute(p) == RouteClass.unknown)
        .toSet()
        .toList()
      ..sort();
    expect(
      unknown,
      isEmpty,
      reason: 'Add a RouteRule in lib/app/route_classes.dart for each of '
          'these, saying what it needs (public entry, native account, '
          'operator, workspace). Unclassified routes are refused.',
    );
  });

  testWidgets('every rule names a registered route', (tester) async {
    final app = await bootRouter(tester);
    final registered =
        registeredRoutePaths(app.router.configuration.routes).toSet();
    final dead = routeRules
        .map((r) => r.pattern)
        .where((p) => !registered.contains(p))
        .toList();
    expect(
      dead,
      isEmpty,
      reason: 'These rules match no GoRoute in lib/app/router.dart — '
          'delete them, or register the route they were written for.',
    );
  });

  test('the router asks the policy and keeps no rule of its own', () {
    final source = File('lib/app/router.dart').readAsStringSync();
    expect(source, contains('settleDestination('));
    // The top-level redirect decides nothing the policy decides: these
    // were the literals of the closure it replaced (#1650 C3).
    final closure = source.substring(
      source.indexOf('redirect: (context, state) {'),
      source.indexOf('routes: ['),
    );
    for (final literal in [
      "'/auth'",
      "'/consent'",
      "'/onboarding",
      "'/pending'",
      "'/kiosk",
      "'/reserve'",
    ]) {
      expect(closure, isNot(contains(literal)),
          reason: 'the top-level redirect names $literal — that rule '
              'belongs in route_policy.dart, where the table can test it');
    }
  });

  test('a parameter matches one non-empty segment, never more', () {
    expect(classifyRoute('/member/abc'), RouteClass.workspace);
    expect(classifyRoute('/member'), RouteClass.unknown);
    expect(classifyRoute('/member/abc/def'), RouteClass.unknown);
    expect(classifyRoute('/member/'), RouteClass.unknown);
    expect(classifyRoute('/editor/level/l1'), RouteClass.workspace);
    expect(classifyRoute('/server/new-instance'), RouteClass.operator);
    expect(classifyRoute('/serverx'), RouteClass.unknown);
    expect(classifyRoute('/auth'), RouteClass.publicEntry);
    expect(classifyRoute('/profiles'), RouteClass.nativeAccount);
  });
}
