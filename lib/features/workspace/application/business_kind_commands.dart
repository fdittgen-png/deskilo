// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3549/#3550 — saving the kind of business: the two registry settings in
// one call (set_business_kind, 0710, which keeps the primary kind out of the
// further ones, a swap included), then the features the owner confirmed in
// the proposal, written against the flags they were read as.
import '../domain/business_kind.dart';
import '../domain/workspace_feature.dart';
import '../domain/workspace_repository.dart';

class BusinessKindCommands {
  const BusinessKindCommands(this._kinds, this._workspaces);

  final BusinessKindRepository _kinds;
  final WorkspaceRepository _workspaces;

  /// Saves [kind] and [moreKinds] for [workspaceId], then writes [flags]
  /// (the confirmed part of the proposal) conditioned on [raw], the stored
  /// set it was planned on. Throws the repository's FeatureFlagsConflict
  /// when the flags moved meanwhile (the kind is saved, no feature written).
  Future<void> save(
    String workspaceId, {
    required String kind,
    required List<String> moreKinds,
    required Map<String, bool> flags,
    required Set<WorkspaceFeature> raw,
  }) async {
    await _kinds.setKind(workspaceId, kind: kind, moreKinds: moreKinds);
    if (flags.isEmpty) return;
    final byKey = WorkspaceFeature.values.asNameMap();
    await _workspaces.setFeatureFlags(
      workspaceId,
      flags,
      expected: {for (final key in flags.keys) key: raw.contains(byKey[key])},
    );
  }
}
