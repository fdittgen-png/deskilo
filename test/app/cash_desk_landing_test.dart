// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4096 — `/money/cash` at the desk forwards, by design (#3926), to the first
// Cash door the person may open: the status page while the space shows it,
// otherwise the purchases. Nobody is refused: an administrator lands on a
// page of theirs. A phone keeps the cash page. The router's golden records
// the forwarding as a `@desk` line.
import 'package:deskilo/core/demo/data/auth_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/router_paths.dart';

Future<String> _cashAsAdmin(
  WidgetTester tester, {
  required Size size,
  required bool status,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {
      WorkspaceFeature.workspaceStatus.dbKey: status,
      WorkspaceFeature.purchases.dbKey: true,
    },
  );
  repo.myMember = repo.myMember.copyWith(isAdmin: true, isOwner: false);
  final app = await bootRouter(
    tester,
    auth: FakeAuthRepository.signedIn(),
    workspace: repo,
  );
  return resolveRoute(app, '/money/cash');
}

void main() {
  testWidgets('at the desk an administrator lands on the status page', (
    tester,
  ) async {
    expect(
      await _cashAsAdmin(tester, size: const Size(1440, 900), status: true),
      '/money/status',
    );
  });

  testWidgets('with the status page off, on the purchases', (tester) async {
    expect(
      await _cashAsAdmin(tester, size: const Size(1440, 900), status: false),
      '/money/purchases',
    );
  });

  testWidgets('on a phone the cash page opens', (tester) async {
    expect(
      await _cashAsAdmin(tester, size: const Size(390, 844), status: true),
      '/money/cash',
    );
  });
}
