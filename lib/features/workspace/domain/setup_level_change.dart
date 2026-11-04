// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 (ADR 0047 §3) — choosing a level per process changes the space's
// features, and only for the processes whose level the owner changed: a
// recommendation never switches off what a process the owner left alone
// already uses. The change is written against its read-set, like every
// feature write (0245), so a concurrent change is refused, not overwritten.
import 'setup_levels.dart';
import 'workspace_feature.dart';

/// #3300 — whether [country] offers [f]: a level never switches on (or
/// off) a feature the space's country does not offer, and such a feature
/// never holds a level back; its stored switch is kept as it is.
bool _offered(WorkspaceFeature f, String? country) =>
    featureAvailableIn(featureManifest[f]?.availableIn, country);

/// Each process's level as the stored features say: the highest level
/// whose features and those of every level below it are all on.
SetupLevelVector currentSetupLevels(
  Set<WorkspaceFeature> on, {
  String? country,
}) => {
  for (final MapEntry(key: process, value: levels) in setupLevels.entries)
    process: () {
      var reached = levels.first.id;
      for (final level in levels) {
        if (!on.containsAll(
          level.features.where((f) => _offered(f, country)),
        )) {
          break;
        }
        reached = level.id;
      }
      return reached;
    }(),
};

/// What choosing [chosen] over [current] writes.
class SetupLevelChange {
  const SetupLevelChange({
    required this.processes,
    required this.switchOn,
    required this.switchOff,
    required this.flags,
    required this.expected,
  });

  /// The processes whose level changes.
  final Set<SetupProcess> processes;

  /// The features it switches on and off, in registry order.
  final List<WorkspaceFeature> switchOn;
  final List<WorkspaceFeature> switchOff;

  /// The delta to write, keyed by `dbKey`, and the read-set it rests on.
  final Map<String, bool> flags;
  final Map<String, bool> expected;

  bool get isEmpty => flags.isEmpty;
}

/// The change from [current] to [chosen], given the RAW stored [stored]
/// features: only processes whose level differs take part.
SetupLevelChange planSetupLevels({
  required Set<WorkspaceFeature> stored,
  required SetupLevelVector current,
  required SetupLevelVector chosen,
  String? country,
}) {
  final changed = {
    for (final MapEntry(key: process, value: level) in chosen.entries)
      if (current[process] != level) process,
  };
  final delta = setupFeatureDelta({for (final p in changed) p: chosen[p]!});
  final on = [
    for (final f in WorkspaceFeature.values)
      if (delta.on.contains(f) && !stored.contains(f) && _offered(f, country))
        f,
  ];
  final off = [
    for (final f in WorkspaceFeature.values)
      if (delta.off.contains(f) && stored.contains(f) && _offered(f, country))
        f,
  ];
  return SetupLevelChange(
    processes: changed,
    switchOn: on,
    switchOff: off,
    flags: {
      for (final f in on) f.dbKey: true,
      for (final f in off) f.dbKey: false,
    },
    expected: {
      for (final f in [...on, ...off]) f.dbKey: stored.contains(f),
    },
  );
}
