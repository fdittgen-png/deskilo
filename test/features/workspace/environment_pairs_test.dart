// SPDX-License-Identifier: 0BSD
//
// #987/#989 — a workspace and its twin as one couple: the pair card in
// Profiles switches sides, the twin is created on demand from the
// environment tile, the onboarding form creates both, and the three
// deploy permissions sit in the matrix with their implication.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> _pump(WidgetTester tester,
    {required FakeWorkspaceRepository workspace, String route = '/profiles'}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(workspace: workspace),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push(route));
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  test('deployToProd implies deployToDev; admins refresh the dev and enter '
      'the prod by default; members hold nothing', () {
    final admin = defaultPermissionsFor(PermissionRole.admin);
    expect(admin, contains(WorkspacePermission.deployToDev));
    expect(admin, contains(WorkspacePermission.accessProd));
    expect(admin, isNot(contains(WorkspacePermission.deployToProd)));
    expect(defaultPermissionsFor(PermissionRole.member), isEmpty);
    expect(defaultPermissionsFor(PermissionRole.owner),
        containsAll(WorkspacePermission.values));
  });

  testWidgets('the pair renders once, as one card, and a chip switches sides',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    final dev = workspace.workspaces[0]
        .copyWith(pairId: 'pair-1', environment: 'dev');
    final prod = dev.copyWith(id: 'ws-prod', environment: 'prod');
    workspace.workspaces
      ..clear()
      ..addAll([dev, prod]);
    await _pump(tester, workspace: workspace);

    expect(find.byKey(const ValueKey('profile-pair-pair-1')), findsOneWidget);
    expect(find.byKey(ValueKey('profile-env-${dev.id}')), findsNothing);
    expect(find.byKey(const ValueKey('profile-env-ws-prod')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-pair-prod-pair-1')));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
    expect(container.read(activeWorkspaceIdProvider).value, 'ws-prod');
    // #996 — the switch is the new default: the next start lands here.
    expect(workspace.serverDefaultWorkspaceId, 'ws-prod');
    expect(container.read(defaultWorkspaceIdProvider).value, 'ws-prod');
  });

  testWidgets('with the flag off the two sides are two ordinary entries',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace(
        featureFlags: const {'environmentPairs': false});
    final dev = workspace.workspaces[0]
        .copyWith(pairId: 'pair-1', environment: 'dev');
    final prod = dev.copyWith(id: 'ws-prod', environment: 'prod');
    workspace.workspaces
      ..clear()
      ..addAll([dev, prod]);
    await _pump(tester, workspace: workspace);
    expect(find.byKey(const ValueKey('profile-pair-pair-1')), findsNothing);
    expect(find.byKey(ValueKey('profile-env-${dev.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-env-ws-prod')), findsOneWidget);
  });

  testWidgets('a lone workspace gets its twin from the environment tile',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await _pump(tester, workspace: workspace, route: '/settings');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('workspace-create-twin')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('workspace-create-twin')));
    await tester.pumpAndSettle();
    expect(workspace.twinsCreated, hasLength(1));
    expect(workspace.workspaces.where((w) => w.pairId == 'pair-1'),
        hasLength(2));
  });
}
