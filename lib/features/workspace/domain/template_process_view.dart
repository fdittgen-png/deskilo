// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1330 — a template's feature change-set, read in business terms.
//
// A template carries feature keys (that payload stays as it is: #1276);
// what an owner previews is the business process each flip belongs to.
// This derives that view from the change-set and the one process
// registry the Features screen uses. It introduces no second taxonomy
// and no second payload: a process is where a flip is SHOWN, never
// something the template stores.
import 'workspace_feature.dart';
import 'workspace_process.dart';

/// One flip, under its home.
class ProcessFeatureChange {
  const ProcessFeatureChange({
    required this.feature,
    required this.enabled,
    this.subprocessKey,
  });

  final WorkspaceFeature feature;
  final bool enabled;

  /// Null for a reserved capability no subprocess lists (see
  /// [internalCapabilities]).
  final String? subprocessKey;
}

/// The flips of one process, in registry order.
class ProcessChangeGroup {
  const ProcessChangeGroup({required this.processKey, required this.changes});

  /// Null for the reserved capabilities.
  final String? processKey;
  final List<ProcessFeatureChange> changes;

  int get onCount => changes.where((c) => c.enabled).length;
  int get offCount => changes.length - onCount;
}

/// Groups [featureChanges] (`dbKey -> on`) by process, processes and
/// their flips in registry order, the reserved capabilities last. A key
/// that is not a [WorkspaceFeature] is a newer server's and is left out.
List<ProcessChangeGroup> processViewOf(
  Map<String, bool> featureChanges, {
  List<WorkspaceProcess> processes = workspaceProcesses,
  Map<WorkspaceFeature, String> internal = internalCapabilities,
}) {
  final byName = WorkspaceFeature.values.asNameMap();
  final pending = <WorkspaceFeature, bool>{
    for (final e in featureChanges.entries) ?byName[e.key]: e.value,
  };
  final out = <ProcessChangeGroup>[];
  for (final process in processes) {
    final changes = <ProcessFeatureChange>[];
    for (final sub in process.subprocesses) {
      for (final f in sub.capabilities) {
        final on = pending.remove(f);
        if (on == null) continue;
        changes.add(
          ProcessFeatureChange(feature: f, enabled: on, subprocessKey: sub.key),
        );
      }
    }
    if (changes.isNotEmpty) {
      out.add(ProcessChangeGroup(processKey: process.key, changes: changes));
    }
  }
  final rest = <ProcessFeatureChange>[];
  for (final f in WorkspaceFeature.values) {
    final on = pending[f];
    if (on != null) rest.add(ProcessFeatureChange(feature: f, enabled: on));
  }
  if (rest.isNotEmpty) {
    out.add(ProcessChangeGroup(processKey: null, changes: rest));
  }
  return out;
}
