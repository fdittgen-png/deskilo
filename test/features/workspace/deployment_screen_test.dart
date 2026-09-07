// SPDX-License-Identifier: 0BSD
//
// #988/#990 — the deployment between the two sides of a pair: the
// registry listed, requirements ticked along, the preview before the
// deploy, the journal with a way back, and the permission that decides
// the direction.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/deployment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_deployment_repository.dart';
import '../../helpers/mock_providers.dart';

Future<(FakeWorkspaceRepository, FakeDeploymentRepository)> _pump(
  WidgetTester tester, {
  bool onDev = true,
  bool viewerOwner = true,
  Map<String, dynamic> flags = const {},
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  final base = workspace.workspaces[0];
  final dev = base.copyWith(pairId: 'pair-1', environment: 'dev');
  final prod = base.copyWith(id: 'ws-prod', pairId: 'pair-1', environment: 'prod');
  workspace.workspaces
    ..clear()
    ..addAll(onDev ? [dev, prod] : [prod, dev]);
  if (!viewerOwner) {
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: true);
  }
  final deployment = FakeDeploymentRepository()
    ..environments = {dev.id: 'dev', 'ws-prod': 'prod'}
    ..diffs = {'services': (1, 0, 0), 'vat': (0, 0, 0)};
  await tester.binding.setSurfaceSize(const Size(900, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(
        workspace: workspace, deployment: deployment),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push('/deployment');
  await tester.pumpAndSettle();
  return (workspace, deployment);
}

void main() {
  test('withRequirements ticks what an entity needs, transitively', () {
    final picked =
        withRequirements(['tariffs'], FakeDeploymentRepository.defaultRegistry);
    expect(picked, {'tariffs', 'vat'});
    expect(withRequirements(['roles'], FakeDeploymentRepository.defaultRegistry),
        {'roles'});
  });

  testWidgets('from the dev, an owner previews and deploys to the prod; the '
      'journal takes it and offers the way back', (tester) async {
    final (_, deployment) = await _pump(tester);
    expect(find.byKey(const ValueKey('deploy-entity-vat')), findsOneWidget);
    expect(find.byKey(const ValueKey('deploy-journal-empty')), findsOneWidget);

    // Ticking services ticks VAT along.
    await tester.tap(find.byKey(const ValueKey('deploy-entity-services')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('deploy-entity-vat')))
            .value,
        isTrue);

    await tester.ensureVisible(find.byKey(const ValueKey('deploy-preview')));
    await tester.tap(find.byKey(const ValueKey('deploy-preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('deploy-preview-services')), findsOneWidget);
    expect(find.text('+1 · ~0 · −0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('deploy-confirm')));
    await tester.pumpAndSettle();

    expect(deployment.deployed, hasLength(1));
    expect(deployment.deployed.single.to, 'ws-prod');
    expect(deployment.deployed.single.entities, ['services', 'vat']);
    expect(find.byKey(const ValueKey('deploy-journal-dep-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('deploy-rollback-dep-1')));
    await tester.pumpAndSettle();
    expect(deployment.rolledBack, ['dep-1']);
    expect(find.byKey(const ValueKey('deploy-rollback-dep-1')), findsNothing);
  });

  testWidgets('an admin on the dev may not push to the prod — the reason is '
      'on screen and the button stays off', (tester) async {
    await _pump(tester, viewerOwner: false);
    expect(find.byKey(const ValueKey('deploy-not-allowed')), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('deploy-preview')))
            .onPressed,
        isNull);
  });

  testWidgets('the same admin on the prod may refresh the dev', (tester) async {
    await _pump(tester, viewerOwner: false, onDev: false);
    expect(find.byKey(const ValueKey('deploy-not-allowed')), findsNothing);
    expect(find.text('Deploy to DEV…'), findsOneWidget);
  });

  testWidgets('with the feature off the route bounces to settings',
      (tester) async {
    await _pump(tester, flags: const {'deployments': false});
    expect(find.byKey(const ValueKey('deploy-entity-vat')), findsNothing);
  });
}
