// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2865 — the setup checklist's "Set up" buttons open the screen the
// server names. 0280 named `/settings` for the legal identity, the
// payment details and the sites: a real route, but the PERSON's settings,
// so the owner landed on their own profile. A route that merely exists
// is not enough; it must be a workspace screen.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The person's own screens: never the place to configure a space.
const _personalRouteFiles = {'profile_routes.dart', 'me_routes.dart'};

/// The functions whose rows carry a setup route, in their latest body.
const _setupFunctions = [
  'template_local_slot_catalogue',
  'workspace_readiness',
];

void main() {
  final migrations = sqlFiles('supabase/migrations');

  final workspaceRoutes = <String>{};
  final personalRoutes = <String>{};
  for (final f in filesWithExtension('lib/app/routes', '.dart')) {
    final name = f.uri.pathSegments.last;
    final paths = RegExp(r"path: '(/[^']*)'")
        .allMatches(f.readAsStringSync())
        .map((m) => m.group(1)!);
    (_personalRouteFiles.contains(name) ? personalRoutes : workspaceRoutes)
        .addAll(paths);
  }
  // Routes declared away from the route files (the shell's `/reserve`)
  // are in the access registry.
  workspaceRoutes.addAll(
    RegExp(r"RouteRule\('(/[^']*)'")
        .allMatches(File('lib/app/route_classes.dart').readAsStringSync())
        .map((m) => m.group(1)!)
        .where((r) => !personalRoutes.contains(r)),
  );

  for (final fn in _setupFunctions) {
    test('every route $fn sends is a workspace screen (#2865)', () {
      final latest = migrations.lastWhere(
        (f) => f.readAsStringSync().contains('function public.$fn('),
      );
      final routes = RegExp(r"""(?:"route":\s*"|'route',\s*')(/[^"']*)""")
          .allMatches(latest.readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
      expect(routes, isNotEmpty, reason: '${latest.path} names no route');
      final wrong = [
        for (final r in routes)
          if (personalRoutes.contains(r) && !workspaceRoutes.contains(r))
            '$r (a personal screen)'
          else if (!workspaceRoutes.contains(r))
            '$r (no such route)',
      ];
      expect(wrong, isEmpty, reason: '${latest.path}: ${wrong.join(', ')}');
    });
  }
}
