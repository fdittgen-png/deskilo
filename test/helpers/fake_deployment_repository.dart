// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/workspace/domain/deployment.dart';

/// #988 — the deployment engine in memory: the server's registry, a
/// preview the test seeds, and a journal that records what was asked.
class FakeDeploymentRepository implements DeploymentRepository {
  FakeDeploymentRepository({List<DeployableEntity>? registry})
      : registry = registry ?? defaultRegistry;

  static const defaultRegistry = [
    DeployableEntity(key: 'identity', kind: 'configuration'),
    DeployableEntity(key: 'vat', kind: 'master_data'),
    DeployableEntity(key: 'tariffs', kind: 'master_data', requires: ['vat']),
    DeployableEntity(key: 'services', kind: 'master_data', requires: ['vat']),
    DeployableEntity(key: 'packages', kind: 'master_data', requires: ['vat']),
    DeployableEntity(
        key: 'accessories', kind: 'master_data', requires: ['vat']),
    DeployableEntity(key: 'sites', kind: 'master_data'),
    DeployableEntity(key: 'booking_rules', kind: 'configuration'),
    DeployableEntity(key: 'validation_rules', kind: 'configuration'),
    DeployableEntity(key: 'roles', kind: 'configuration'),
    DeployableEntity(key: 'reminders', kind: 'configuration'),
    DeployableEntity(key: 'document_design', kind: 'reports'),
    DeployableEntity(key: 'document_links', kind: 'configuration'),
    DeployableEntity(key: 'closure_days', kind: 'configuration'),
    DeployableEntity(key: 'invitations', kind: 'configuration'),
    DeployableEntity(key: 'features', kind: 'configuration'),
  ];

  final List<DeployableEntity> registry;

  /// What the preview answers per entity key (added, changed, removed).
  Map<String, (int, int, int)> diffs = {};

  /// Every deploy asked, in order.
  final List<({String from, String to, List<String> entities})> deployed = [];
  final List<String> rolledBack = [];
  final List<Deployment> journalRows = [];

  /// The environment of each workspace id the fake knows ('dev'/'prod').
  Map<String, String> environments = {};

  DeploymentDirection _direction(String to) =>
      environments[to] == 'prod'
          ? DeploymentDirection.devToProd
          : DeploymentDirection.prodToDev;

  @override
  Future<List<DeployableEntity>> entities() async => registry;

  @override
  Future<DeploymentPreview> preview(
      String fromWorkspaceId, String toWorkspaceId, List<String> entities) async {
    return DeploymentPreview(
      direction: _direction(toWorkspaceId),
      entries: [
        for (final e in registry)
          if (entities.contains(e.key))
            EntityDiff(
              key: e.key,
              kind: e.kind,
              added: diffs[e.key]?.$1 ?? 0,
              changed: diffs[e.key]?.$2 ?? 0,
              removed: diffs[e.key]?.$3 ?? 0,
            ),
      ],
    );
  }

  @override
  Future<String> deploy(
      String fromWorkspaceId, String toWorkspaceId, List<String> entities) async {
    deployed.add((from: fromWorkspaceId, to: toWorkspaceId, entities: entities));
    final id = 'dep-${deployed.length}';
    journalRows.insert(
      0,
      Deployment(
        id: id,
        fromWorkspaceId: fromWorkspaceId,
        toWorkspaceId: toWorkspaceId,
        direction: _direction(toWorkspaceId),
        entities: entities,
        actorName: 'Flo',
        createdAt: DateTime.utc(2026, 9, 7, 10, deployed.length),
      ),
    );
    return id;
  }

  @override
  Future<void> rollback(String deploymentId) async {
    rolledBack.add(deploymentId);
    final i = journalRows.indexWhere((d) => d.id == deploymentId);
    if (i >= 0) {
      final d = journalRows[i];
      journalRows[i] = Deployment(
        id: d.id,
        fromWorkspaceId: d.fromWorkspaceId,
        toWorkspaceId: d.toWorkspaceId,
        direction: d.direction,
        entities: d.entities,
        actorName: d.actorName,
        createdAt: d.createdAt,
        rolledBackAt: DateTime.utc(2026, 9, 7, 11),
      );
    }
  }

  @override
  Future<List<Deployment>> journal(String pairId) async => journalRows;
}
