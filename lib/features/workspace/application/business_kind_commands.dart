// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3549/#3550 — saving the kind of business: the two registry settings in
// one call (set_business_kind, 0710, which keeps the primary kind out of the
// further ones, a swap included), then the features the owner confirmed in
// the proposal, written against the flags they were read as.
//
// #4168 — the owner confirmed a particular profile: the kind as it was read
// (its version and the digest of its content, 0834). A profile that changed
// meanwhile is reviewed again, never applied silently, and nothing is written
// for it. The result says which stages happened: the kind saved and its
// features applied, or the kind saved and its features refused because the
// flags moved meanwhile: a saved kind is not a fully applied recipe.
import '../../../core/ids/request_id.dart';
import '../../../core/settings/settings.dart';
import '../domain/business_kind.dart';
import '../domain/business_profile.dart';
import '../domain/feature_flags_write.dart';
import '../domain/workspace_feature.dart';
import '../domain/workspace_repository.dart';

/// What a save did.
enum BusinessKindOutcome {
  /// The kind is saved and the confirmed features are written (or there were none).
  applied,

  /// The kind is saved; the features were refused because the stored flags
  /// moved since the proposal was planned: none was written.
  kindSavedFlagsRefused,
}

/// The profile the owner reviewed is no longer the kind's profile.
class BusinessKindProfileChanged implements Exception {
  const BusinessKindProfileChanged(this.kind);

  final String kind;

  @override
  String toString() => 'BusinessKindProfileChanged($kind)';
}

class BusinessKindCommands {
  const BusinessKindCommands(this._kinds, this._workspaces, this._settings);

  final BusinessKindRepository _kinds;
  final WorkspaceRepository _workspaces;
  final SettingsAdmin _settings;

  /// #4365 -- the type of shop of a business that is a shop: words and examples only.
  Future<void> saveShopType(String workspaceId, String type) => _settings.setValue(
    workspaceId: workspaceId,
    key: businessShopTypeKey,
    value: type,
  );

  /// Saves [kind] and [moreKinds] for [workspaceId], then writes [flags]
  /// (the confirmed part of the proposal) conditioned on [raw], the stored
  /// set it was planned on. [reviewed] is the kind's profile as the owner saw
  /// it: when the registry now holds another version or content, nothing is
  /// written and [BusinessKindProfileChanged] is thrown. When the flags moved
  /// meanwhile the kind stays saved and the result says so.
  Future<BusinessKindOutcome> save(
    String workspaceId, {
    required String kind,
    required List<String> moreKinds,
    required Map<String, bool> flags,
    required Set<WorkspaceFeature> raw,
    required BusinessKind reviewed,
  }) async {
    final byKey = WorkspaceFeature.values.asNameMap();
    final expected = {
      for (final key in flags.keys) key: raw.contains(byKey[key]),
    };
    // a server that records the stages answers for both; an earlier one is
    // written to by the earlier writers below
    try {
      final applied = await _kinds.applyKind(
        workspaceId,
        requestId: newRequestId(),
        reviewed: ReviewedKind(
          kind: kind,
          moreKinds: moreKinds,
          version: reviewed.profileVersion,
          digest: reviewed.profileDigest,
        ),
        flags: flags,
        expected: expected,
      );
      if (applied.kindStage == 'refused') {
        throw BusinessKindProfileChanged(kind);
      }
      return applied.flagsStage == 'refused'
          ? BusinessKindOutcome.kindSavedFlagsRefused
          : BusinessKindOutcome.applied;
    } on BusinessKindApplyUnsupported {
      // fall through to the earlier writers
    }
    final now = (await _kinds.kinds()).where((k) => k.code == kind).firstOrNull;
    if (now == null || !reviewed.sameProfileAs(now)) {
      throw BusinessKindProfileChanged(kind);
    }
    await _kinds.setKind(workspaceId, kind: kind, moreKinds: moreKinds);
    if (flags.isEmpty) return BusinessKindOutcome.applied;
    try {
      await _workspaces.setFeatureFlags(workspaceId, flags, expected: expected);
    } on FeatureFlagsConflict {
      return BusinessKindOutcome.kindSavedFlagsRefused;
    }
    return BusinessKindOutcome.applied;
  }
}
