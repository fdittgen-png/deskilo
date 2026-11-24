// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1863 — the routes the app's GoRouter actually registers, read from
// the router object rather than from the spelling of router.dart.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'mock_providers.dart';

/// Every full path registered under [routes], once per GoRoute (so a
/// path registered twice appears twice). Nested relative paths are
/// joined to their parent; shells contribute their children.
List<String> registeredRoutePaths(
  List<RouteBase> routes, [
  String parent = '',
]) {
  final out = <String>[];
  for (final r in routes) {
    if (r is GoRoute) {
      final full = r.path.startsWith('/')
          ? r.path
          : '${parent == '/' ? '' : parent}/${r.path}';
      out
        ..add(full)
        ..addAll(registeredRoutePaths(r.routes, full));
    } else if (r is StatefulShellRoute) {
      for (final b in r.branches) {
        out.addAll(registeredRoutePaths(b.routes, parent));
      }
    } else if (r is ShellRouteBase) {
      out.addAll(registeredRoutePaths(r.routes, parent));
    }
  }
  return out;
}

/// A concrete location for [pattern]: each `:param` becomes `p1`.
String concreteRoute(String pattern) =>
    pattern.split('/').map((s) => s.startsWith(':') ? 'p1' : s).join('/');

/// The app, booted with [featureFlags], and its live router plus a
/// context that can resolve a location through every redirect.
Future<({GoRouter router, BuildContext context})> bootRouter(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
  // #2493 — the identity the router is asked as; the default is the
  // owner of the one seeded workspace, as before.
  FakeAuthRepository? auth,
  FakeWorkspaceRepository? workspace,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        auth: auth,
        workspace:
            workspace ??
            FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Navigator).first);
  final router = ProviderScope.containerOf(context).read(routerProvider);
  return (router: router, context: context);
}

/// Where a deep link to [location] ends after every redirect.
Future<String> resolveRoute(
  ({GoRouter router, BuildContext context}) app,
  String location,
) async {
  final match = await app.router.routeInformationParser
      .parseRouteInformationWithDependencies(
        RouteInformation(uri: Uri.parse(location)),
        app.context,
      );
  return match.uri.path;
}

/// #4422 — the location each symbol of a `Routes` source names: a
/// `static const` path as written, a builder's path with each
/// interpolation as `p1`; the query is not part of the location.
Map<String, String> routeSymbolLocations(String source) {
  final symbol = RegExp(
    r"static (?:const (\w+) =|String (\w+)\([^)]*\)\s*=>)\s*'([^']*)';",
  );
  final interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');
  return {
    for (final m in symbol.allMatches(source))
      (m.group(1) ?? m.group(2))!: m
          .group(3)!
          .replaceAll(interpolation, 'p1')
          .split('?')
          .first,
  };
}

/// The symbols of [source] whose location no pattern of [registered]
/// matches: a link to a page the router does not register.
List<String> unregisteredRouteSymbols(
  String source,
  Iterable<String> registered,
) {
  bool matches(String location, String pattern) {
    final a = location.split('/');
    final b = pattern.split('/');
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i] && !b[i].startsWith(':')) return false;
    }
    return true;
  }

  return [
    for (final e in routeSymbolLocations(source).entries)
      if (!registered.any((p) => matches(e.value, p))) e.key,
  ];
}
