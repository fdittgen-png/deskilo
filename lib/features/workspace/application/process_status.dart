// SPDX-License-Identifier: 0BSD
//
// #1327 — how a stored feature map reads as process state.
//
// The overview on the Features screen shows one card per business
// process. What each card says must be COMPUTED from what the workspace
// row already holds — process state is never persisted (#1323, rule 9).
// This file is that computation, and nothing else: no Flutter, no
// repository, no localisation. A widget reads the result; it does not
// re-derive dependencies (#1327, "consume #1326").
//
// ## The four states, as the #1327 audit defines them
//
// * **Active** — every selectable capability of the process is
//   effective.
// * **Partial** — some are.
// * **Available** — none are.
// * **Needs attention** — at least one capability is stored ON but held
//   back by a switched-off prerequisite: `resolveEnabledFeatures` minus
//   `effectiveFeatures`. It outranks the other three on the card,
//   because it is the one state where the switch and the app disagree
//   (#800) and the owner has something to do.
//
// "Blocked" is not here. The #1326 resolver never refuses an
// activation — it pulls prerequisites in — so there is no data source
// for a process that cannot be switched on.
import '../domain/workspace_feature.dart';
import '../domain/workspace_process.dart';
import 'resolve_processes.dart';

/// What a process card, or a subprocess row, says about itself.
enum ProcessState { active, partial, available, needsAttention }

/// The overview's filter chips.
enum ProcessFilter { all, active, available, needsAttention }

/// A capability that is stored on and yet does nothing, and the nearest
/// switched-off prerequisite it waits for.
typedef HeldBackCapability = ({
  WorkspaceFeature feature,
  WorkspaceFeature waitingFor,
});

/// A prerequisite that lives in ANOTHER process and that switching this
/// process on would bring with it — the card's dependency warning.
typedef OutsidePrerequisite = ({WorkspaceFeature feature, String processKey});

class SubprocessStatus {
  const SubprocessStatus({
    required this.subprocess,
    required this.state,
    required this.enabled,
    required this.off,
    required this.heldBack,
  });

  final WorkspaceSubprocess subprocess;
  final ProcessState state;

  /// Effective capabilities, in registry order.
  final List<WorkspaceFeature> enabled;

  /// Capabilities not stored on, in registry order.
  final List<WorkspaceFeature> off;

  /// Stored on, but waiting for a prerequisite.
  final List<HeldBackCapability> heldBack;

  int get capabilityCount => enabled.length + off.length + heldBack.length;
}

class ProcessStatus {
  const ProcessStatus({
    required this.process,
    required this.state,
    required this.subprocesses,
    required this.activeSubprocessCount,
    required this.outsidePrerequisites,
  });

  final WorkspaceProcess process;
  final ProcessState state;
  final List<SubprocessStatus> subprocesses;

  /// Subprocesses whose every capability is effective — read through
  /// the resolver's own `activeSubprocesses`.
  final int activeSubprocessCount;

  /// Empty for an active process: nothing is left to bring in.
  final List<OutsidePrerequisite> outsidePrerequisites;

  int get enabledCount =>
      subprocesses.fold(0, (sum, s) => sum + s.enabled.length);
  int get capabilityCount =>
      subprocesses.fold(0, (sum, s) => sum + s.capabilityCount);
  int get heldBackCount =>
      subprocesses.fold(0, (sum, s) => sum + s.heldBack.length);

  /// Whether this card belongs under [filter].
  ///
  /// The chips ask what an owner asks, so they overlap where the
  /// answer does: a PARTIAL process is both in use (Active) and has
  /// something left to switch on (Available). Needs attention is its
  /// own question.
  bool matches(ProcessFilter filter) => switch (filter) {
    ProcessFilter.all => true,
    ProcessFilter.active => enabledCount > 0,
    ProcessFilter.available => enabledCount < capabilityCount,
    ProcessFilter.needsAttention => heldBackCount > 0,
  };
}

/// The state of every process in [processes], given the RAW stored set.
List<ProcessStatus> processStatuses(
  Set<WorkspaceFeature> raw, {
  List<WorkspaceProcess> processes = workspaceProcesses,
  Map<WorkspaceFeature, String> internal = internalCapabilities,
}) {
  final effective = effectiveFeatures(raw);
  final fullyActive = activeSubprocesses(
    active: effective,
    processes: processes,
    internal: internal,
  ).toSet();
  final home = <WorkspaceFeature, String>{
    for (final process in processes)
      for (final subprocess in process.subprocesses)
        for (final feature in subprocess.capabilities) feature: process.key,
  };

  return [
    for (final process in processes)
      _process(process, raw, effective, fullyActive, home, processes, internal),
  ];
}

ProcessStatus _process(
  WorkspaceProcess process,
  Set<WorkspaceFeature> raw,
  Set<WorkspaceFeature> effective,
  Set<String> fullyActive,
  Map<WorkspaceFeature, String> home,
  List<WorkspaceProcess> processes,
  Map<WorkspaceFeature, String> internal,
) {
  final subprocesses = [
    for (final subprocess in process.subprocesses)
      _subprocess(subprocess, raw, effective, internal),
  ];
  final state = _stateOf(
    enabled: subprocesses.fold(0, (sum, s) => sum + s.enabled.length),
    total: subprocesses.fold(0, (sum, s) => sum + s.capabilityCount),
    heldBack: subprocesses.any((s) => s.heldBack.isNotEmpty),
  );

  // What switching the whole process on would pull in from elsewhere —
  // the #1326 preview, read, never applied here.
  final preview = resolveActivation(
    active: raw,
    subprocessKeys: [for (final s in process.subprocesses) s.key],
    processes: processes,
    internal: internal,
  );
  final outside = state == ProcessState.active
      ? const <OutsidePrerequisite>[]
      : [
          for (final capability in preview.capabilities)
            if (capability.reason == CapabilityReason.prerequisite &&
                home[capability.feature] != null &&
                home[capability.feature] != process.key)
              (
                feature: capability.feature,
                processKey: home[capability.feature]!,
              ),
        ];

  return ProcessStatus(
    process: process,
    state: state,
    subprocesses: subprocesses,
    activeSubprocessCount: process.subprocesses
        .where((s) => fullyActive.contains(s.key))
        .length,
    outsidePrerequisites: outside,
  );
}

SubprocessStatus _subprocess(
  WorkspaceSubprocess subprocess,
  Set<WorkspaceFeature> raw,
  Set<WorkspaceFeature> effective,
  Map<WorkspaceFeature, String> internal,
) {
  final enabled = <WorkspaceFeature>[];
  final off = <WorkspaceFeature>[];
  final heldBack = <HeldBackCapability>[];
  for (final feature in subprocess.capabilities) {
    if (internal.containsKey(feature)) continue;
    if (effective.contains(feature)) {
      enabled.add(feature);
    } else if (raw.contains(feature)) {
      heldBack.add((
        feature: feature,
        // Nearest first: the switch the owner has to find.
        waitingFor: requirementChain(
          feature,
        ).firstWhere((parent) => !raw.contains(parent)),
      ));
    } else {
      off.add(feature);
    }
  }
  return SubprocessStatus(
    subprocess: subprocess,
    state: _stateOf(
      enabled: enabled.length,
      total: enabled.length + off.length + heldBack.length,
      heldBack: heldBack.isNotEmpty,
    ),
    enabled: enabled,
    off: off,
    heldBack: heldBack,
  );
}

ProcessState _stateOf({
  required int enabled,
  required int total,
  required bool heldBack,
}) {
  if (heldBack) return ProcessState.needsAttention;
  if (enabled == 0) return ProcessState.available;
  if (enabled == total) return ProcessState.active;
  return ProcessState.partial;
}
