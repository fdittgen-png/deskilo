// SPDX-License-Identifier: 0BSD
//
// #1326 — turning "the owner wants these processes" into the exact
// feature map DesKilo must persist.
//
// The process registry (#1325) says which capabilities belong to which
// business subprocess. `featureManifest.requires` says which
// capabilities need which others. Neither answers the question the
// process-first UI asks: *given this intent, what changes?*
//
// ## What this is not
//
// It is not a second feature-state architecture. `WorkspaceFeature`
// remains the capability registry and `featureManifest.requires` the
// only dependency source of truth — this file reads both and invents
// neither. It holds no state, touches no repository, and imports no
// Flutter: the whole point is that a change-set can be examined in a
// test rather than by driving a screen.
//
// ## Why a change-set rather than a new map
//
// `setFeatureFlags` merges what it is given (#963): writing a full map
// from a stale copy of the row put an owner's earlier switches back off.
// So [ProcessChangeSet.flags] carries only what actually changes, keyed
// by `dbKey`, exactly as `featureFlagsToggleDelta` does for one switch.
//
// ## Deactivation refuses rather than cascades
//
// Turning a process off can orphan capabilities another active process
// still needs. Silently disabling them would be the app deciding on the
// owner's behalf; silently leaving them would produce a map
// `effectiveFeatures` then prunes — a green switch and a feature that is
// not there, which is the defect #800 fixed for single toggles. So a
// removal that would orphan something returns [blockedBy] and changes
// nothing. The caller names the dependents and asks.
import '../domain/workspace_feature.dart';
import '../domain/workspace_process.dart';

/// One capability in a change-set, and why it is there.
enum CapabilityReason {
  /// Named by a subprocess the owner selected.
  selected,

  /// Pulled in by `requires` — nobody asked for it directly.
  prerequisite,

  /// Already on before this intent; listed so the UI can say "you
  /// already have this" rather than claiming to have enabled it.
  alreadyActive,
}

/// A capability and the reason it appears, with the chain that brought
/// it when that reason is [CapabilityReason.prerequisite].
class ResolvedCapability {
  const ResolvedCapability({
    required this.feature,
    required this.reason,
    this.neededBy = const [],
  });

  final WorkspaceFeature feature;
  final CapabilityReason reason;

  /// The selected capabilities that reach this one through `requires`.
  /// More than one when a prerequisite is shared — `invoicing` is
  /// reached from five different subprocesses, and the UI should say so
  /// once rather than five times.
  final List<WorkspaceFeature> neededBy;
}

/// Why a deactivation was refused: [feature] would be switched off while
/// [orphans] still need it.
class BlockedRemoval {
  const BlockedRemoval({required this.feature, required this.orphans});

  final WorkspaceFeature feature;

  /// Still-active capabilities whose `requires` chain runs through
  /// [feature]. Never empty — a removal with no orphans is not blocked.
  final List<WorkspaceFeature> orphans;
}

/// Everything the UI needs to explain a change before it is written.
class ProcessChangeSet {
  const ProcessChangeSet({
    required this.capabilities,
    required this.flags,
    required this.blockedBy,
  });

  /// Every capability the intent touches, with its reason.
  final List<ResolvedCapability> capabilities;

  /// What to write, keyed by `dbKey` — only the entries that CHANGE.
  /// Empty when the intent is already satisfied, which is what makes
  /// applying the same intent twice a no-op.
  final Map<String, bool> flags;

  /// Non-empty when a requested removal would orphan an active
  /// capability. [flags] is then empty: nothing is written.
  final List<BlockedRemoval> blockedBy;

  bool get isEmpty => flags.isEmpty && blockedBy.isEmpty;
  bool get isBlocked => blockedBy.isNotEmpty;
}

/// The capabilities a subprocess names, or empty when the key is
/// unknown — an unknown key is the caller's bug and produces no change
/// rather than a half-applied intent.
List<WorkspaceFeature> capabilitiesOf(
  String subprocessKey, {
  List<WorkspaceProcess> processes = workspaceProcesses,
}) {
  for (final process in processes) {
    for (final subprocess in process.subprocesses) {
      if (subprocess.key == subprocessKey) return subprocess.capabilities;
    }
  }
  return const [];
}

/// Every subprocess key the registry knows, in registry order.
List<String> allSubprocessKeys({
  List<WorkspaceProcess> processes = workspaceProcesses,
}) => [
      for (final process in processes)
        for (final subprocess in process.subprocesses) subprocess.key,
    ];

/// What switching [subprocessKeys] ON would change, given [active].
///
/// [active] is the RAW stored set, not the effective one: a capability
/// stored on but orphaned is still stored on, and re-enabling its parent
/// must not claim to have enabled the child again.
ProcessChangeSet resolveActivation({
  required Set<WorkspaceFeature> active,
  required Iterable<String> subprocessKeys,
  List<WorkspaceProcess> processes = workspaceProcesses,
  Map<WorkspaceFeature, String> internal = internalCapabilities,
}) {
  final selected = <WorkspaceFeature>{};
  for (final key in subprocessKeys) {
    for (final feature in capabilitiesOf(key, processes: processes)) {
      // An internal capability is not selectable: it has no implemented
      // workflow behind it (#1325), so naming it would switch on
      // something no screen can reach.
      if (internal.containsKey(feature)) continue;
      selected.add(feature);
    }
  }

  // The closure, with the chain recorded so a shared prerequisite is
  // explained once and names everything that wanted it.
  final neededBy = <WorkspaceFeature, List<WorkspaceFeature>>{};
  for (final feature in selected) {
    for (final parent in requirementChain(feature)) {
      if (selected.contains(parent)) continue;
      (neededBy[parent] ??= []).add(feature);
    }
  }

  final capabilities = <ResolvedCapability>[
    // Registry order, so the same intent always renders the same list.
    for (final process in processes)
      for (final subprocess in process.subprocesses)
        for (final feature in subprocess.capabilities)
          if (selected.contains(feature))
            ResolvedCapability(
              feature: feature,
              reason: active.contains(feature)
                  ? CapabilityReason.alreadyActive
                  : CapabilityReason.selected,
            ),
    for (final entry in _inRegistryOrder(neededBy.keys, processes))
      ResolvedCapability(
        feature: entry,
        reason: active.contains(entry)
            ? CapabilityReason.alreadyActive
            : CapabilityReason.prerequisite,
        neededBy: neededBy[entry]!..sort((a, b) => a.name.compareTo(b.name)),
      ),
  ];

  return ProcessChangeSet(
    capabilities: capabilities,
    flags: {
      for (final capability in capabilities)
        if (!active.contains(capability.feature))
          capability.feature.dbKey: true,
    },
    blockedBy: const [],
  );
}

/// What switching [subprocessKeys] OFF would change, given [active].
///
/// Refuses rather than cascades: if removing a capability would orphan
/// one that stays active, nothing is written and the orphans are named.
ProcessChangeSet resolveDeactivation({
  required Set<WorkspaceFeature> active,
  required Iterable<String> subprocessKeys,
  List<WorkspaceProcess> processes = workspaceProcesses,
  Map<WorkspaceFeature, String> internal = internalCapabilities,
}) {
  final requested = <WorkspaceFeature>{};
  for (final key in subprocessKeys) {
    for (final feature in capabilitiesOf(key, processes: processes)) {
      if (internal.containsKey(feature)) continue;
      if (active.contains(feature)) requested.add(feature);
    }
  }

  // What would remain on afterwards, and whether anything in it depends
  // on something being removed.
  final remaining = active.difference(requested);
  final blocked = <BlockedRemoval>[];
  for (final feature in _inRegistryOrder(requested, processes)) {
    final orphans = [
      for (final candidate in remaining)
        if (requirementChain(candidate).contains(feature)) candidate,
    ]..sort((a, b) => a.name.compareTo(b.name));
    if (orphans.isNotEmpty) {
      blocked.add(BlockedRemoval(feature: feature, orphans: orphans));
    }
  }

  if (blocked.isNotEmpty) {
    return ProcessChangeSet(
      capabilities: const [],
      flags: const {},
      blockedBy: blocked,
    );
  }

  return ProcessChangeSet(
    capabilities: [
      for (final feature in _inRegistryOrder(requested, processes))
        ResolvedCapability(
          feature: feature,
          reason: CapabilityReason.selected,
        ),
    ],
    flags: {
      for (final feature in _inRegistryOrder(requested, processes))
        feature.dbKey: false,
    },
    blockedBy: const [],
  );
}

/// Which subprocesses a stored feature map satisfies: every selectable
/// capability of the subprocess is active.
///
/// This is how an existing workspace — one configured switch by switch,
/// long before processes existed — is read back as process state.
List<String> activeSubprocesses({
  required Set<WorkspaceFeature> active,
  List<WorkspaceProcess> processes = workspaceProcesses,
  Map<WorkspaceFeature, String> internal = internalCapabilities,
}) => [
      for (final process in processes)
        for (final subprocess in process.subprocesses)
          if (subprocess.capabilities
              .where((f) => !internal.containsKey(f))
              .every(active.contains))
            subprocess.key,
    ];

/// Registry order for an arbitrary set, so output never depends on
/// iteration order of a Set — the determinism the issue asks for.
List<WorkspaceFeature> _inRegistryOrder(
  Iterable<WorkspaceFeature> features,
  List<WorkspaceProcess> processes,
) {
  final wanted = features.toSet();
  final ordered = <WorkspaceFeature>[];
  for (final process in processes) {
    for (final subprocess in process.subprocesses) {
      for (final feature in subprocess.capabilities) {
        if (wanted.remove(feature)) ordered.add(feature);
      }
    }
  }
  // Anything the registry does not place (an internal capability reached
  // through `requires`) keeps enum order, which is also stable.
  for (final feature in WorkspaceFeature.values) {
    if (wanted.remove(feature)) ordered.add(feature);
  }
  return ordered;
}
