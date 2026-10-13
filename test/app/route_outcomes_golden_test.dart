// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — the router's outcome for EVERY registered route, for five
// identities with every feature on and with every feature off, frozen in
// test/app/fixtures/route_outcomes.golden. A refactor of the router, the
// route lists or the access policy passes when this file does not change.
// It records what the router does today (unverified as to intent): a route
// whose outcome is wrong is fixed in its own change, which rewrites the
// line. Rewrite the file with `UPDATE_ROUTE_OUTCOMES=1 flutter test
// test/app/route_outcomes_golden_test.dart`.
import 'dart:io';

import 'package:deskilo/core/demo/data/auth_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/router_paths.dart';

const _golden = 'test/app/fixtures/route_outcomes.golden';

typedef _Identity = ({
  String name,
  FakeAuthRepository Function() auth,
  FakeWorkspaceRepository Function(Map<String, dynamic> flags) workspace,
});

FakeWorkspaceRepository _as(
  Map<String, dynamic> flags, {
  required bool admin,
  required bool owner,
}) {
  final repo = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  repo.myMember = repo.myMember.copyWith(isAdmin: admin, isOwner: owner);
  return repo;
}

final List<_Identity> _identities = [
  (
    name: 'signed-out',
    auth: FakeAuthRepository.new,
    workspace: (f) => FakeWorkspaceRepository.withWorkspace(featureFlags: f),
  ),
  (
    name: 'no-space',
    auth: FakeAuthRepository.signedIn,
    workspace: (f) => FakeWorkspaceRepository(),
  ),
  (
    name: 'member',
    auth: FakeAuthRepository.signedIn,
    workspace: (f) => _as(f, admin: false, owner: false),
  ),
  (
    name: 'admin',
    auth: FakeAuthRepository.signedIn,
    workspace: (f) => _as(f, admin: true, owner: false),
  ),
  (
    name: 'owner',
    auth: FakeAuthRepository.signedIn,
    workspace: (f) => _as(f, admin: true, owner: true),
  ),
];

void main() {
  testWidgets('every route, every identity, features on and off', (
    tester,
  ) async {
    final lines = <String>[];
    for (final identity in _identities) {
      for (final on in [true, false]) {
        final flags = {
          if (!on) for (final f in WorkspaceFeature.values) f.dbKey: false,
        };
        final app = await bootRouter(
          tester,
          auth: identity.auth(),
          workspace: identity.workspace(flags),
        );
        final paths = registeredRoutePaths(app.router.configuration.routes)
          ..sort();
        for (final p in paths) {
          final location = concreteRoute(p);
          final landed = await resolveRoute(app, location);
          lines.add(
            '${identity.name} ${on ? 'on ' : 'off'} $p -> '
            '${landed == location ? '(open)' : landed}',
          );
        }
        // A fresh app per case: the next boot replaces this tree.
        await tester.pumpWidget(const SizedBox());
      }
    }
    final text = '${lines.join('\n')}\n';
    final file = File(_golden);
    if (Platform.environment['UPDATE_ROUTE_OUTCOMES'] == '1') {
      file.writeAsStringSync(text);
      return;
    }
    expect(text, file.readAsStringSync());
  });
}
