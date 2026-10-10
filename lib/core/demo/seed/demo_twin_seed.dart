// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2327 — the space's development twin (#987/#990): a second workspace
// in the same pair, where the owner tries a change before deploying it.
// The space a visitor lands in stays the production side; the twin is
// listed beside it, and the deployment journal shows what already moved
// between the two.
import '../../../features/workspace/domain/deployment.dart';
import '../data/deployment_repository.dart';
import '../data/workspace_repository.dart';
import '../demo_clock.dart';

/// The pair both sides share, and the development side's id.
const demoPairId = 'demo-pair';
const demoTwinId = 'ws-1-dev';

void seedDemoTwin(
  FakeWorkspaceRepository workspaces,
  FakeDeploymentRepository deployments,
  DateTime now, {
  required String actorName,
}) {
  final i = workspaces.workspaces.indexWhere((w) => w.id == 'ws-1');
  if (i < 0) return;
  final production = workspaces.workspaces[i].copyWith(pairId: demoPairId);
  workspaces.workspaces[i] = production;
  // The symbol is the one thing a twin never carries (0378): two
  // workspaces never wear the same letters on the same colour.
  workspaces.workspaces.add(
    production.copyWith(
      id: demoTwinId,
      environment: 'dev',
      branding: {
        for (final e in production.branding.entries)
          if (!e.key.startsWith('symbol_')) e.key: e.value,
      },
    ),
  );

  deployments
    ..environments = {'ws-1': 'prod', demoTwinId: 'dev'}
    // What a preview finds on the development side today.
    ..diffs = {
      'tariffs': (1, 1, 0),
      'booking_rules': (0, 1, 0),
      'document_design': (0, 1, 0),
    };

  final today = demoDateOf(now);
  DateTime at(int daysAgo, int hour) {
    final d = today.subtract(Duration(days: daysAgo));
    return demoAt(d.year, d.month, d.day, hour);
  }

  Deployment toProduction(
    String id,
    List<String> entities,
    DateTime at, {
    DateTime? rolledBackAt,
  }) => Deployment(
    id: id,
    fromWorkspaceId: demoTwinId,
    toWorkspaceId: 'ws-1',
    direction: DeploymentDirection.devToProd,
    entities: entities,
    actorName: actorName,
    createdAt: at,
    rolledBackAt: rolledBackAt,
  );

  // Newest first, as the journal reads.
  deployments.journalRows.addAll([
    toProduction('demo-deploy-3', ['booking_rules'], at(12, 18)),
    toProduction(
      'demo-deploy-2',
      ['document_design'],
      at(20, 19),
      rolledBackAt: at(20, 20),
    ),
    toProduction('demo-deploy-1', ['vat', 'tariffs'], at(41, 18)),
  ]);
}
