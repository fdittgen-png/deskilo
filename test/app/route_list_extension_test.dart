// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — the demonstration that a route is one GoRoute and one RouteAccess
// in a list: a throwaway list, written here and never registered in
// router.dart, is opened only as its declaration says.
import 'package:deskilo/app/route_access.dart';
import 'package:deskilo/app/route_env.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

List<RouteBase> _temporaryRoutes(RouteEnv env) => [
  GoRoute(
    path: '/temporary',
    redirect: env.guard(
      const RouteAccess(
        features: [WorkspaceFeature.invoicing],
        permission: WorkspacePermission.manageBilling,
        to: '/fallback',
      ),
    ),
    builder: (context, state) => const SizedBox(),
  ),
  GoRoute(path: '/fallback', builder: (context, state) => const SizedBox()),
];

final _routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(routes: _temporaryRoutes(RouteEnv(ref))),
);

Future<String> _land(
  WidgetTester tester,
  Set<WorkspaceFeature> features,
  Set<WorkspacePermission> permissions,
) async {
  final container = ProviderContainer(
    overrides: [
      enabledFeaturesSyncProvider.overrideWithValue(features),
      myPermissionsProvider.overrideWithValue(permissions),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(_routerProvider);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  final context = tester.element(find.byType(Navigator).first);
  final match = await router.routeInformationParser
      .parseRouteInformationWithDependencies(
        RouteInformation(uri: Uri.parse('/temporary')),
        context,
      );
  return match.uri.path;
}

void main() {
  testWidgets('a route in a new list opens only for its declaration', (
    tester,
  ) async {
    const both = {WorkspacePermission.manageBilling};
    const invoicing = {WorkspaceFeature.invoicing};
    expect(await _land(tester, invoicing, both), '/temporary');
    expect(await _land(tester, {}, both), '/fallback');
    expect(await _land(tester, invoicing, {}), '/fallback');
  });
}
