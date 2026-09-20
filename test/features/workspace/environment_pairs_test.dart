// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #987/#989 — a workspace and its twin as one couple: the pair card in
// Profiles switches sides, the twin is created on demand from the
// environment tile, the onboarding form creates both, and the three
// deploy permissions sit in the matrix with their implication.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
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

  // ── #1550 — the pair a person asked for is shown as a pair ──────

  testWidgets('a space created WITH its twin renders as one card',
      (tester) async {
    // The regression that shipped: since #1063 creation writes every
    // Platform flag `false` explicitly, and `environmentPairs` is the
    // feature that SHOWS a pair — so the product created the couple and
    // switched off the only place it appears as one. Built from the
    // real creation defaults, because a hand-written map would have
    // gone on passing while the product was broken.
    final workspace = FakeWorkspaceRepository.withWorkspace(
        featureFlags: defaultFeatureFlagsForNewWorkspace(withTwin: true));
    final dev = workspace.workspaces[0]
        .copyWith(pairId: 'pair-1', environment: 'dev');
    final prod = dev.copyWith(id: 'ws-prod', environment: 'prod');
    workspace.workspaces
      ..clear()
      ..addAll([dev, prod]);
    await _pump(tester, workspace: workspace);

    expect(find.byKey(const ValueKey('profile-pair-pair-1')), findsOneWidget,
        reason: 'asking for a pair and being shown two spaces is the '
            'product contradicting itself');
    expect(find.byKey(ValueKey('profile-env-${dev.id}')), findsNothing);
    expect(find.byKey(const ValueKey('profile-env-ws-prod')), findsNothing);
  });

  testWidgets('a space created ALONE is still one ordinary entry',
      (tester) async {
    // The other half of the rule: the flag keeps saying what was
    // chosen, so a lone space is not given a couple it never asked for.
    final workspace = FakeWorkspaceRepository.withWorkspace(
        featureFlags: defaultFeatureFlagsForNewWorkspace());
    await _pump(tester, workspace: workspace);

    final id = workspace.workspaces[0].id;
    expect(find.byKey(ValueKey('profile-env-$id')), findsOneWidget);
  });

  testWidgets('the DEV side decides for the couple, so no side shows twice',
      (tester) async {
    // `toggleWorkspaceFeature` writes the side you are standing on, so
    // dev-on / prod-off is a state a person reaches by switching the
    // couple on from the dev. Asking each row about its own flag
    // rendered the card AND an ordinary prod row: the same space twice.
    final workspace = FakeWorkspaceRepository.withWorkspace();
    final dev = workspace.workspaces[0].copyWith(
        pairId: 'pair-1',
        environment: 'dev',
        featureFlags: const {'environmentPairs': true});
    final prod = dev.copyWith(
        id: 'ws-prod',
        environment: 'prod',
        featureFlags: const {'environmentPairs': false});
    workspace.workspaces
      ..clear()
      ..addAll([dev, prod]);
    await _pump(tester, workspace: workspace);

    expect(find.byKey(const ValueKey('profile-pair-pair-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-env-ws-prod')), findsNothing,
        reason: 'the card already stands for the prod side');
  });

  testWidgets('a lone workspace gets its twin from the environment tile',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await _pump(tester, workspace: workspace, route: '/settings');
    final twin = find.byKey(const ValueKey('workspace-create-twin'));
    await tester.scrollUntilVisible(twin, 300,
        scrollable: find.byType(Scrollable).first);
    // #1235 — `scrollUntilVisible` stops the moment the row is BUILT,
    // which on a list this long leaves it straddling the bottom edge;
    // the tap then lands outside the viewport and does nothing. Eight
    // more device pixels of help symbol above it were enough to expose
    // that. `ensureVisible` puts the row where a finger could reach it.
    await tester.ensureVisible(twin);
    await tester.pumpAndSettle();
    await tester.tap(twin);
    await tester.pumpAndSettle();
    expect(workspace.twinsCreated, hasLength(1));
    expect(workspace.workspaces.where((w) => w.pairId == 'pair-1'),
        hasLength(2));
  });
}
