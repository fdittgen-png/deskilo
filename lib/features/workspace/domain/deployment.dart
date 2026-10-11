// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/system_columns.dart';
import '../../../core/data/json_reader.dart';

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

  /// #998 — the document designs: every report kind, preset, language.
  bool get isReports => kind == 'reports';

  factory DeployableEntity.fromJson(Map<dynamic, dynamic> json) {
    final r = JsonReader.of(json, context: 'deployable_entity');
    return DeployableEntity(
      key: r.stringOr('key'),
      kind: r.stringOr('kind', 'configuration'),
      requires: [for (final x in r.list('requires')) '$x'],
      workspaceKeys: [for (final k in r.list('workspace_keys')) '$k'],
      tables: [for (final t in r.list('tables')) '$t'],
    );
  }
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

  factory EntityDiff.fromJson(Map<dynamic, dynamic> json) {
    final r = JsonReader.of(json, context: 'entity_diff');
    return EntityDiff(
      key: r.stringOr('key'),
      kind: r.stringOr('kind', 'configuration'),
      added: r.intOrNull('added') ?? 0,
      changed: r.intOrNull('changed') ?? 0,
      removed: r.intOrNull('removed') ?? 0,
      details: [for (final d in r.list('details')) '$d'],
    );
  }
}

class DeploymentPreview {
  const DeploymentPreview({required this.direction, required this.entries});

  final DeploymentDirection direction;
  final List<EntityDiff> entries;

  bool get isNoop => entries.every((e) => e.isNoop);

  factory DeploymentPreview.fromJson(Map<dynamic, dynamic> json) {
    final r = JsonReader.of(json, context: 'deployment_preview');
    return DeploymentPreview(
      direction: DeploymentDirection.fromWire(r.stringOrNull('direction')),
      entries: r.objects('entities', (row) => EntityDiff.fromJson(row.json)),
    );
  }
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
