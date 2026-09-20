// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1329 — the ONE way a process intent becomes a feature-flag write.
//
// ## The protocol
//
//   authoritative current state → canonical resolver (#1326) → impact
//   preview → confirmation → conditional delta write → awaited
//   authoritative refetch → exact result
//
// [planProcessChange] is the preview: pure Dart over the raw stored set,
// it says what the write is, what it drags along, what it revives or
// holds back, and — the part the write is conditioned on — every flag
// the decision rested on, with the value it was read as. [applyProcessChange]
// is the write: the delta goes to `set_feature_flags` WITH that read-set,
// and the server refuses under its row lock if any of it moved (0245).
//
// ## What deactivation does and does not erase
//
// The resolver refuses to switch a capability off while a stored-on
// dependant still needs it. That refusal is the preview: the owner then
// chooses between keeping things as they are, switching off what they
// asked for and leaving the dependants' stored choices in place (they
// become ineffective — #800's lazy deactivation, and switching the parent
// back on restores them), or explicitly switching the dependants off too.
// Nothing is erased that the owner did not name.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/feature_flags_write.dart';
import '../domain/workspace.dart';
import '../domain/workspace_feature.dart';
import '../domain/workspace_process.dart';
import '../providers/workspace_providers.dart';
import 'resolve_processes.dart';

/// How a deactivation that would orphan stored-on dependants proceeds.
enum DeactivationMode {
  /// The resolver's answer: refuse, and name the dependants.
  refuse,

  /// Switch off what was asked for; dependants keep their stored choice
  /// and wait, ineffective, for the prerequisite to come back.
  keepDependants,

  /// Also switch the dependants off — a distinct, explicit intent.
  removeDependants,
}

/// A preview and the exact write it stands for.
class ProcessChangePlan {
  const ProcessChangePlan({
    required this.activate,
    required this.subprocessKeys,
    required this.changeSet,
    required this.flags,
    required this.expected,
    this.revived = const [],
    this.heldBack = const [],
    this.alsoOff = const [],
  });

  final bool activate;
  final List<String> subprocessKeys;

  /// The resolver's answer, unchanged: the reasoned capability list and,
  /// for a refused deactivation, who blocks it.
  final ProcessChangeSet changeSet;

  /// The delta to write, keyed by `dbKey`. Empty when the intent is
  /// already satisfied, which makes a repeated intent a no-op.
  final Map<String, bool> flags;

  /// The read-set: every flag the preview rested on, as it was read.
  final Map<String, bool> expected;

  /// Activation: stored-on capabilities that were held back and become
  /// effective again because their prerequisite comes on.
  final List<WorkspaceFeature> revived;

  /// Deactivation with [DeactivationMode.keepDependants]: stored-on
  /// dependants that stay stored and stop working.
  final List<WorkspaceFeature> heldBack;

  /// Deactivation with [DeactivationMode.removeDependants]: dependants
  /// switched off alongside what was asked for.
  final List<WorkspaceFeature> alsoOff;

  bool get isBlocked => changeSet.isBlocked;
  bool get nothingToDo => flags.isEmpty && !isBlocked;

  /// What the write switches on or off, in registry order.
  List<WorkspaceFeature> get written => [
        for (final feature in WorkspaceFeature.values)
          if (flags.containsKey(feature.dbKey)) feature,
      ];
}

/// The preview of switching [subprocessKeys] on or off, given the RAW
/// stored set [raw].
ProcessChangePlan planProcessChange({
  required Set<WorkspaceFeature> raw,
  required Iterable<String> subprocessKeys,
  required bool activate,
  DeactivationMode mode = DeactivationMode.refuse,
  List<WorkspaceProcess> processes = workspaceProcesses,
  Map<WorkspaceFeature, String> internal = internalCapabilities,
}) {
  final keys = subprocessKeys.toList();
  bool stored(WorkspaceFeature f) => raw.contains(f);

  if (activate) {
    final set = resolveActivation(
      active: raw,
      subprocessKeys: keys,
      processes: processes,
      internal: internal,
    );
    final turnedOn = {
      for (final c in set.capabilities)
        if (!raw.contains(c.feature)) c.feature,
    };
    final before = effectiveFeatures(raw);
    final after = effectiveFeatures({...raw, ...turnedOn});
    final revived = [
      for (final feature in WorkspaceFeature.values)
        if (after.contains(feature) &&
            !before.contains(feature) &&
            !turnedOn.contains(feature))
          feature,
    ];
    return ProcessChangePlan(
      activate: true,
      subprocessKeys: keys,
      changeSet: set,
      flags: set.flags,
      expected: {
        for (final c in set.capabilities) c.feature.dbKey: stored(c.feature),
        for (final f in revived) f.dbKey: true,
      },
      revived: revived,
    );
  }

  final set = resolveDeactivation(
    active: raw,
    subprocessKeys: keys,
    processes: processes,
    internal: internal,
  );
  final requested = <WorkspaceFeature>[
    for (final feature in WorkspaceFeature.values)
      if (raw.contains(feature) &&
          !internal.containsKey(feature) &&
          keys.any(
              (k) => capabilitiesOf(k, processes: processes).contains(feature)))
        feature,
  ];
  // Every stored-on dependant of what is asked off, whether the resolver
  // refused over it or not: its value is part of the decision.
  final dependants = <WorkspaceFeature>[
    for (final feature in WorkspaceFeature.values)
      if (raw.contains(feature) &&
          !requested.contains(feature) &&
          requested.any((r) => requirementChain(feature).contains(r)))
        feature,
  ];
  final expected = {
    for (final f in requested) f.dbKey: true,
    for (final f in dependants) f.dbKey: true,
  };
  if (!set.isBlocked || mode == DeactivationMode.refuse) {
    return ProcessChangePlan(
      activate: false,
      subprocessKeys: keys,
      changeSet: set,
      flags: set.flags,
      expected: expected,
    );
  }
  final alsoOff = mode == DeactivationMode.removeDependants;
  return ProcessChangePlan(
    activate: false,
    subprocessKeys: keys,
    changeSet: set,
    flags: {
      for (final f in requested) f.dbKey: false,
      if (alsoOff)
        for (final f in dependants) f.dbKey: false,
    },
    expected: expected,
    heldBack: alsoOff ? const [] : dependants,
    alsoOff: alsoOff ? dependants : const [],
  );
}

/// What [applyProcessChange] answered.
enum ProcessApplyResult { applied, nothingToDo }

/// Writes [plan]'s delta conditioned on its read-set, then waits for the
/// workspace chain to hold the row the server confirmed.
///
/// Throws [FeatureFlagsConflict] when the read-set moved (nothing was
/// written) and [FeatureFlagsUnconfirmed] when the write went through
/// but the refetch did not. A repeated identical plan is a no-op: its
/// delta is empty once applied.
Future<ProcessApplyResult> applyProcessChange(
  WidgetRef ref, {
  required Workspace workspace,
  required ProcessChangePlan plan,
}) async {
  // A refused deactivation has an empty delta; one the owner resolved
  // (kept or removed the dependants) carries its flags and still reports
  // `isBlocked`, which is the resolver's answer, not a veto on the write.
  if (plan.flags.isEmpty) {
    return ProcessApplyResult.nothingToDo;
  }
  await ref.read(workspaceRepositoryProvider).setFeatureFlags(
        workspace.id,
        plan.flags,
        expected: plan.expected,
      );
  // The forced refetch (#963): the chain re-derives the features from the
  // new row, and the screen shows what the server holds, not what it
  // hoped. A refetch that fails is reported as such, never as success.
  ref.invalidate(myWorkspacesProvider);
  try {
    await ref.read(myWorkspacesProvider.future);
  } catch (e, st) {
    // trace-exempt: rethrown typed with its stack; the sheet traces and says the write is unconfirmed.
    Error.throwWithStackTrace(FeatureFlagsUnconfirmed(e), st);
  }
  return ProcessApplyResult.applied;
}
