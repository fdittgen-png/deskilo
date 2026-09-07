// SPDX-License-Identifier: 0BSD
import '../../../core/data/system_columns.dart';

/// #988 — the direction a deployment travels, named after the sides.
enum DeploymentDirection {
  devToProd('dev_to_prod'),
  prodToDev('prod_to_dev');

  const DeploymentDirection(this.wire);
  final String wire;

  static DeploymentDirection fromWire(String? wire) => values
      .firstWhere((d) => d.wire == wire, orElse: () => prodToDev);
}

/// #988 — one deployable slice of the configuration: its key, its kind
/// (configuration or master data), what it depends on, and the
/// workspace keys and tables it owns. The server's registry
/// (`deployable_entities`) is the source; this is its reading.
class DeployableEntity {
  const DeployableEntity({
    required this.key,
    required this.kind,
    this.requires = const [],
    this.workspaceKeys = const [],
    this.tables = const [],
  });

  final String key;
  final String kind;
  final List<String> requires;
  final List<String> workspaceKeys;
  final List<String> tables;

  bool get isMasterData => kind == 'master_data';

  factory DeployableEntity.fromJson(Map<dynamic, dynamic> json) =>
      DeployableEntity(
        key: json['key'] as String? ?? '',
        kind: json['kind'] as String? ?? 'configuration',
        requires: [for (final r in json['requires'] as List? ?? const []) '$r'],
        workspaceKeys: [
          for (final k in json['workspace_keys'] as List? ?? const []) '$k'
        ],
        tables: [for (final t in json['tables'] as List? ?? const []) '$t'],
      );
}

/// #988 — what a deployment would do to one entity on the target.
class EntityDiff {
  const EntityDiff({
    required this.key,
    required this.kind,
    this.added = 0,
    this.changed = 0,
    this.removed = 0,
    this.details = const [],
  });

  final String key;
  final String kind;
  final int added;
  final int changed;
  final int removed;

  /// `+key`, `~key`, `-key` per row, or the workspace key that differs.
  final List<String> details;

  bool get isNoop => added == 0 && changed == 0 && removed == 0;

  factory EntityDiff.fromJson(Map<dynamic, dynamic> json) => EntityDiff(
        key: json['key'] as String? ?? '',
        kind: json['kind'] as String? ?? 'configuration',
        added: (json['added'] as num?)?.toInt() ?? 0,
        changed: (json['changed'] as num?)?.toInt() ?? 0,
        removed: (json['removed'] as num?)?.toInt() ?? 0,
        details: [for (final d in json['details'] as List? ?? const []) '$d'],
      );
}

class DeploymentPreview {
  const DeploymentPreview({required this.direction, required this.entries});

  final DeploymentDirection direction;
  final List<EntityDiff> entries;

  bool get isNoop => entries.every((e) => e.isNoop);

  factory DeploymentPreview.fromJson(Map<dynamic, dynamic> json) =>
      DeploymentPreview(
        direction: DeploymentDirection.fromWire(json['direction'] as String?),
        entries: [
          for (final e in json['entities'] as List? ?? const [])
            EntityDiff.fromJson(e as Map),
        ],
      );
}

/// #988 — one line of the journal: who deployed what, when, in which
/// direction, and whether it was rolled back.
class Deployment implements SystemStamped {
  const Deployment({
    required this.id,
    required this.fromWorkspaceId,
    required this.toWorkspaceId,
    required this.direction,
    required this.entities,
    this.summary = const [],
    this.actorName = '',
    this.createdAt,
    this.rolledBackAt,
    this.system = SystemColumns.none,
  });

  final String id;
  final String fromWorkspaceId;
  final String toWorkspaceId;
  final DeploymentDirection direction;
  final List<String> entities;
  final List<EntityDiff> summary;
  final String actorName;
  final DateTime? createdAt;
  final DateTime? rolledBackAt;

  @override
  final SystemColumns system;

  bool get isRolledBack => rolledBackAt != null;

  factory Deployment.fromRow(Map<dynamic, dynamic> row) => Deployment(
        system: SystemColumns.fromRow(row),
        id: row['id'] as String,
        fromWorkspaceId: row['from_workspace_id'] as String? ?? '',
        toWorkspaceId: row['to_workspace_id'] as String? ?? '',
        direction: DeploymentDirection.fromWire(row['direction'] as String?),
        entities: [for (final e in row['entities'] as List? ?? const []) '$e'],
        summary: [
          for (final s in row['summary'] as List? ?? const [])
            EntityDiff.fromJson(s as Map),
        ],
        actorName: row['actor_name'] as String? ?? '',
        createdAt: row['created_at'] == null
            ? null
            : DateTime.tryParse(row['created_at'] as String)?.toUtc(),
        rolledBackAt: row['rolled_back_at'] == null
            ? null
            : DateTime.tryParse(row['rolled_back_at'] as String)?.toUtc(),
      );
}

/// #988 — the deployment boundary: the registry, the preview, the
/// deploy, the rollback, the journal. The server decides direction and
/// permission; the client only asks.
abstract interface class DeploymentRepository {
  Future<List<DeployableEntity>> entities();

  Future<DeploymentPreview> preview(
      String fromWorkspaceId, String toWorkspaceId, List<String> entities);

  /// Returns the journal id.
  Future<String> deploy(
      String fromWorkspaceId, String toWorkspaceId, List<String> entities);

  Future<void> rollback(String deploymentId);

  Future<List<Deployment>> journal(String pairId);
}

/// The entities [selected] plus everything they require, transitively —
/// what the screen deploys when the owner ticks one.
Set<String> withRequirements(
    Iterable<String> selected, List<DeployableEntity> registry) {
  final byKey = {for (final e in registry) e.key: e};
  final out = <String>{};
  final queue = [...selected];
  while (queue.isNotEmpty) {
    final key = queue.removeLast();
    if (!out.add(key)) continue;
    queue.addAll(byKey[key]?.requires ?? const []);
  }
  return out;
}
