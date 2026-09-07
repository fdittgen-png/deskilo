// SPDX-License-Identifier: 0BSD
//
// #1008 — with a system navigation bar at the bottom, nothing of the app
// sits under it: not the shell's own bar, not a sheet's buttons.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_deployment_repository.dart';
import '../helpers/mock_providers.dart';

void main() {
  testWidgets('the shell bottom bar and a sheet\'s buttons stay above a '
      '100 px navigation bar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 100);
    tester.view.padding = const FakeViewPadding(bottom: 100);
    addTearDown(tester.view.reset);
    final workspace = FakeWorkspaceRepository.withWorkspace();
    final base = workspace.workspaces[0];
    workspace.workspaces
      ..clear()
      ..addAll([
        base.copyWith(pairId: 'pair-1', environment: 'dev'),
        base.copyWith(id: 'ws-prod', pairId: 'pair-1', environment: 'prod'),
      ]);
    final deployment = FakeDeploymentRepository()
      ..environments = {base.id: 'dev', 'ws-prod': 'prod'};
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(
          workspace: workspace, deployment: deployment),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();

    final bar = find.byType(ShellBottomBar);
    expect(bar, findsOneWidget);
    expect(tester.getRect(bar).bottom, lessThanOrEqualTo(700));

    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/deployment');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('deploy-entity-roles')));
    await tester.pumpAndSettle();
    final list = find.descendant(
        of: find.byKey(const ValueKey('deploy-list')),
        matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('deploy-preview')), 200,
        scrollable: list.first);
    await tester.tap(find.byKey(const ValueKey('deploy-preview')));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const ValueKey('deploy-confirm'));
    expect(confirm, findsOneWidget);
    expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(700));
  });
}
