// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1851 B — one feature switch, previewed and written against the state
// it was decided on.
//
// The same protocol as a process change (process_activation.dart, #1329),
// for the single switch of the Features screen:
//
//   raw stored set → plan (delta, what comes on with it, what waits,
//   which experimental features need consent, the read-set) → consent
//   when needed → conditional delta write → forced refetch.
//
// The read-set is every flag the decision rested on: the switch, each
// prerequisite it drags on, and — when switching off — every stored-on
// dependant that will wait for it. If any of them moved between the
// preview and the write, `set_feature_flags` refuses under its row lock
// (0245) and nothing is written; the screen refetches and asks again. The
// server also rechecks the owner's permission on the write itself, so a
// role taken away after the preview writes nothing.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/feature_flags_write.dart';
import '../domain/feature_operation.dart';
import '../domain/workspace.dart';
import '../domain/workspace_feature.dart';
import '../providers/workspace_providers.dart';

/// The preview of one switch and the exact write it stands for.
class FeatureSwitchPlan {
  const FeatureSwitchPlan({
    required this.feature,
    required this.value,
    required this.flags,
    required this.expected,
    this.alsoOn = const [],
    this.waiting = const [],
    this.needsConsent = const [],
  });

  final WorkspaceFeature feature;
  final bool value;

  /// The delta written (registry keys); empty when nothing changes.
  final Map<String, bool> flags;

  /// The read-set the write is conditioned on.
  final Map<String, bool> expected;

  /// Prerequisites switched on alongside, not on yet.
  final List<WorkspaceFeature> alsoOn;

  /// Stored-on dependants that stop working while this is off; their
  /// own switches stay as they are and come back with it.
  final List<WorkspaceFeature> waiting;

  /// Alpha or beta features this switch turns on, each needing a yes.
  final List<WorkspaceFeature> needsConsent;

  bool get isNoOp => flags.isEmpty;
}

bool _needsOptIn(WorkspaceFeature f) => featureNeedsOptIn(f);

/// The plan for switching [feature] to [value] over the [raw] stored set.
/// [needsOptIn] says which features ask for consent (#1851 A's rule; a
/// test hands in its own).
FeatureSwitchPlan planFeatureSwitch({
  required Set<WorkspaceFeature> raw,
  required WorkspaceFeature feature,
  required bool value,
  bool Function(WorkspaceFeature) needsOptIn = _needsOptIn,
}) {
  final delta = featureFlagsToggleDelta(feature: feature, value: value);
  final changes = {
    for (final e in delta.entries)
      if (raw.contains(e.key) != e.value) e.key: e.value,
  };
  final alsoOn = value
      ? alsoEnabledWith(raw: raw, feature: feature)
      : const <WorkspaceFeature>[];
  final waiting = value
      ? const <WorkspaceFeature>[]
      : [
          for (final f in WorkspaceFeature.values)
            if (raw.contains(f) && requirementChain(f).contains(feature)) f,
        ];
  return FeatureSwitchPlan(
    feature: feature,
    value: value,
    flags: {for (final e in changes.entries) e.key.dbKey: e.value},
    expected: {
      for (final f in delta.keys) f.dbKey: raw.contains(f),
      for (final f in waiting) f.dbKey: true,
    },
    alsoOn: alsoOn,
    waiting: waiting,
    needsConsent: [
      for (final f in changes.keys)
        if (changes[f]! && needsOptIn(f)) f,
    ],
  );
}

/// Writes [plan]'s delta conditioned on its read-set and waits for the
/// workspace chain to hold what the server confirmed.
///
/// Throws [FeatureFlagsConflict] when the read-set moved (nothing was
/// written) and [FeatureFlagsUnconfirmed] when the write went through but
/// the refetch did not. A no-op plan writes nothing.
Future<void> applyFeatureSwitch(
  WidgetRef ref, {
  required Workspace workspace,
  required FeatureSwitchPlan plan,
}) async {
  if (plan.isNoOp) return;
  await ref
      .read(workspaceRepositoryProvider)
      .setFeatureFlags(workspace.id, plan.flags, expected: plan.expected);
  ref.invalidate(myWorkspacesProvider);
  try {
    await ref.read(myWorkspacesProvider.future);
  } catch (e, st) {
    // trace-exempt: rethrown typed with its stack; the screen traces and says the write is unconfirmed.
    Error.throwWithStackTrace(FeatureFlagsUnconfirmed(e), st);
  }
}
