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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: featureFlags,
        ),
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
