// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3550 — a business kind proposes the features its business needs. The
// kind's profile (public.business_kinds.feature_profile: flag key → on/off)
// is read against what the workspace has now, and becomes a proposal: what
// would switch on, what would switch off (a switched-off parent takes its
// subtree with it), and the flags to write if the owner confirms. Nothing is
// written here and nothing changes silently: the caller shows the proposal
// and writes [BusinessKindProposal.flags] through the feature-write path only
// on confirm. Pure Dart.
import 'package:meta/meta.dart';

import 'workspace_feature.dart';

/// What choosing a kind would change.
@immutable
class BusinessKindProposal {
  const BusinessKindProposal({
    required this.switchesOn,
    required this.switchesOff,
    required this.flags,
    this.unknownKeys = const [],
  });

  /// Features that become effective, in registry order.
  final List<WorkspaceFeature> switchesOn;

  /// Features that stop being effective, in registry order: the profile's
  /// own offs and every dependant they take with them.
  final List<WorkspaceFeature> switchesOff;

  /// The stored flags to write on confirm: the profile's values, and for a
  /// feature it switches on, the parents that feature needs.
  final Map<String, bool> flags;

  /// #3730 — the profile's keys this app does not know, in profile order.
  /// Leaving them out would change what confirming means (the server
  /// records the whole profile as reviewed), so a proposal with any is
  /// shown but never applied ([applicable]).
  final List<String> unknownKeys;

  /// Whether confirming may write this proposal: every key is known.
  bool get applicable => unknownKeys.isEmpty;

  /// Whether choosing the kind changes nothing that works today.
  bool get isEmpty =>
      switchesOn.isEmpty && switchesOff.isEmpty && unknownKeys.isEmpty;
}

/// The proposal of a kind whose [profile] maps flag keys to on/off, for a
/// workspace whose stored flags resolve to [raw]. A key the registry does
/// not know is never written: it is named in
/// [BusinessKindProposal.unknownKeys] and the proposal is not applicable.
BusinessKindProposal proposalFor({
  required Map<String, bool> profile,
  required Set<WorkspaceFeature> raw,
  String? country,
}) {
  final byKey = WorkspaceFeature.values.asNameMap();
  final flags = <String, bool>{};
  final unknownKeys = <String>[];
  for (final entry in profile.entries) {
    final feature = byKey[entry.key];
    if (feature == null) {
      unknownKeys.add(entry.key);
      continue;
    }
    flags[feature.dbKey] = entry.value;
    if (entry.value) {
      for (final parent in requirementChain(feature)) {
        flags.putIfAbsent(parent.dbKey, () => true);
      }
    }
  }
  final next = {...raw};
  for (final entry in flags.entries) {
    final feature = byKey[entry.key]!;
    entry.value ? next.add(feature) : next.remove(feature);
  }
  final before = effectiveFeatures(raw, country: country);
  final after = effectiveFeatures(next, country: country);
  return BusinessKindProposal(
    switchesOn: [
      for (final f in featureManifest.keys)
        if (after.contains(f) && !before.contains(f)) f,
    ],
    switchesOff: [
      for (final f in featureManifest.keys)
        if (before.contains(f) && !after.contains(f)) f,
    ],
    flags: flags,
    unknownKeys: unknownKeys,
  );
}
