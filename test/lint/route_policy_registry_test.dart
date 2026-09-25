// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — every route the router registers is classified in
// route_classes.dart, and every rule there names a route that exists.
//
// The policy refuses what it does not know, so a GoRoute added without
// a rule is a screen nobody can open — reachable in a widget test that
// pumps it directly, dead in the app. The other direction rots too: a
// rule for a route that was deleted keeps a boundary alive for nothing.
// Both are read from the source, the same way route_registry_test pins
// the count.
import 'dart:io';

import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/app/schema_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// The absolute paths router.dart registers. A relative `path:` (a
/// nested GoRoute) is joined to the last absolute one above it.
Set<String> routerPaths() {
  final source = File('lib/app/router.dart').readAsStringSync();
  final paths = <String>{};
  var parent = '';
  for (final m in RegExp(r"path:\s*(?:'([^']+)'|(kSchemaUpdateRoute))")
      .allMatches(source)) {
    final raw = m.group(1) ?? kSchemaUpdateRoute;
    if (raw.startsWith('/')) {
      parent = raw;
      paths.add(raw);
    } else {
      paths.add('$parent/$raw');
    }
  }
  return paths;
}

void main() {
  test('every router path has a class', () {
    final unknown = routerPaths()
        .where((p) => classifyRoute(p) == RouteClass.unknown)
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

  test('every rule names a registered route', () {
    final registered = routerPaths();
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
