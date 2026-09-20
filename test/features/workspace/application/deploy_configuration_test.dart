// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — the two rules of a deployment: a tick carries what it needs,
// and nothing is written that a preview did not describe.
import 'package:deskilo/core/demo/data/deployment_repository.dart';
import 'package:deskilo/features/workspace/application/deploy_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

/// The server's own registry, where `floor_plan` requires `accessories`
/// and `sites`, and `accessories` requires `vat` — two levels deep.
const _registry = FakeDeploymentRepository.defaultRegistry;

void main() {
  group('the ticks', () {
    test('ticking one ticks everything it requires', () {
      expect(
        selectionAfter(
            selected: const [],
            registry: _registry,
            key: 'floor_plan',
            on: true),
        {'floor_plan', 'accessories', 'sites', 'vat'},
      );
    });

    test('unticking one unticks everything that required it, transitively',
        () {
      expect(
        selectionAfter(
            selected: const ['floor_plan', 'accessories', 'sites', 'vat'],
            registry: _registry,
            key: 'vat',
            on: false),
        {'sites'},
        reason: 'floor_plan requires accessories requires vat — deploying '
            'the plan without the VAT rates is asking for half of what it '
            'needs',
      );
    });

    test('unticking leaves what did not depend on it alone', () {
      expect(
        selectionAfter(
            selected: const ['identity', 'vat'],
            registry: _registry,
            key: 'identity',
            on: false),
        {'vat'},
      );
    });
  });

  group('nothing moves before a preview said what would change', () {
    test('the preview is computed over the CLOSED selection', () async {
      final previewed = await Deployments(FakeDeploymentRepository()).examine(
        fromWorkspaceId: 'dev',
        toWorkspaceId: 'prod',
        selection: const ['floor_plan'],
        registry: _registry,
      );
      expect(
        previewed.preview.entries.map((e) => e.key).toSet(),
        {'floor_plan', 'accessories', 'sites', 'vat'},
        reason: 'a preview that describes less than the deployment writes '
            'is not a preview',
      );
    });

    test('the deployment writes exactly what the preview described',
        () async {
      final repo = FakeDeploymentRepository();
      final command = Deployments(repo);
      final previewed = await command.examine(
        fromWorkspaceId: 'dev',
        toWorkspaceId: 'prod',
        selection: const ['floor_plan'],
        registry: _registry,
      );
      await command.apply(previewed);
      expect(repo.deployed.single.entities, previewed.entities);
      expect(previewed.entities,
          ['accessories', 'floor_plan', 'sites', 'vat']);
    });
  });
}
