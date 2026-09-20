// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — deploying between the two sides of a pair: what is ticked, and
// that nothing moves before a preview said what would change.
//
// **The ticks.** An entity carries what it requires, so ticking one
// ticks those too — `withRequirements` has always done that. Unticking
// was the half that lived in the screen, and it only removed the entities
// that named the unticked one DIRECTLY. With A requiring B requiring C,
// unticking C left A ticked and B gone, and the deployment went out
// asking for A without what A needs. Removal is transitive here, which
// is the same sentence as the addition read backwards.
//
// **The order.** Preview, confirm, deploy — three steps around ONE set
// of entities, and the screen held that set in a field between them. So
// [Deployments.apply] takes the PREVIEWED deployment rather than a
// selection: what is written is what was shown, and a selection that
// changed while the confirmation sheet was open cannot slip through it.
import '../domain/deployment.dart';

/// The ticks after flipping [key] [on] within [selected].
///
/// Ticking one ticks everything it requires; unticking one unticks
/// everything that required it, transitively.
Set<String> selectionAfter({
  required Iterable<String> selected,
  required List<DeployableEntity> registry,
  required String key,
  required bool on,
}) {
  if (on) {
    return withRequirements([...selected, key], registry);
  }
  final out = {...selected}..remove(key);
  final dropped = {key};
  var changed = true;
  while (changed) {
    changed = false;
    for (final entity in registry) {
      if (!out.contains(entity.key)) continue;
      if (entity.requires.any(dropped.contains)) {
        out.remove(entity.key);
        dropped.add(entity.key);
        changed = true;
      }
    }
  }
  return out;
}

/// A preview, and the deployment it describes.
///
/// The entities are the CLOSED selection the preview was computed for,
/// so [Deployments.apply] can only write what was shown.
class PreviewedDeployment {
  const PreviewedDeployment({
    required this.fromWorkspaceId,
    required this.toWorkspaceId,
    required this.entities,
    required this.preview,
  });

  final String fromWorkspaceId;
  final String toWorkspaceId;
  final List<String> entities;
  final DeploymentPreview preview;
}

/// Deploying configuration between twins, as the decisions behind it.
class Deployments {
  const Deployments(this._deployments);

  final DeploymentRepository _deployments;

  /// The server's entity registry and the pair's journal.
  Future<({List<DeployableEntity> registry, List<Deployment> journal})> board(
    String pairId,
  ) async =>
      (
        registry: await _deployments.entities(),
        journal: await _deployments.journal(pairId),
      );

  /// What deploying [selection] would change — over the CLOSED
  /// selection, so the preview can never describe less than what the
  /// deployment would write.
  Future<PreviewedDeployment> examine({
    required String fromWorkspaceId,
    required String toWorkspaceId,
    required Iterable<String> selection,
    required List<DeployableEntity> registry,
  }) async {
    final entities = withRequirements(selection, registry).toList()..sort();
    return PreviewedDeployment(
      fromWorkspaceId: fromWorkspaceId,
      toWorkspaceId: toWorkspaceId,
      entities: entities,
      preview: await _deployments.preview(
        fromWorkspaceId,
        toWorkspaceId,
        entities,
      ),
    );
  }

  /// Deploys exactly what [previewed] described. Returns the journal id.
  Future<String> apply(PreviewedDeployment previewed) => _deployments.deploy(
        previewed.fromWorkspaceId,
        previewed.toWorkspaceId,
        previewed.entities,
      );

  Future<void> rollBack(String deploymentId) =>
      _deployments.rollback(deploymentId);
}
