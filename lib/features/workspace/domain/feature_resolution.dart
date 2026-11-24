// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The effective feature set: the stored switches over the registry chain
// (#800) and, since #2454, over the availability of the workspace country.
// Re-exported by workspace_feature.dart, so callers do not change.
import 'workspace_feature.dart';

/// #3729 — whether an installation's schema offers a feature.
enum FeatureSchemaState {
  /// The feature and every prerequisite are at or below the schema, or none
  /// states a requirement.
  available,

  /// The feature or a prerequisite needs a newer schema than the installation
  /// runs: not offered anywhere.
  withheld,

  /// The installation's schema could not be established, and a requirement is
  /// stated: no block and no false certainty.
  unknown,
}

/// The verdict of [featureSchemaReadiness]: the state, and for a withheld
/// feature the prerequisite that is missing — the feature itself, or the
/// parent of its chain that needs the most.
class FeatureSchemaReadiness {
  const FeatureSchemaReadiness(this.state, {this.missing, this.missingSince});
  final FeatureSchemaState state;
  final WorkspaceFeature? missing;
  final int? missingSince;

  bool get offered => state != FeatureSchemaState.withheld;
}

/// Does an installation running [schema] (null: not established) offer
/// [feature]? A feature is available only when its own requirement AND those
/// of all its `requires` ancestors are met; the answer for a withheld feature
/// names the ancestor with the highest requirement, so an administrator is
/// told what to update towards.
FeatureSchemaReadiness featureSchemaReadiness(
  WorkspaceFeature feature,
  int? schema, {
  Map<WorkspaceFeature, FeatureManifestEntry>? manifest,
}) {
  final entries = manifest ?? featureManifest;
  WorkspaceFeature? missing;
  int? missingSince;
  var stated = false;
  WorkspaceFeature? current = feature;
  while (current != null) {
    final entry = entries[current];
    final since = entry?.since;
    if (since != null) {
      stated = true;
      if (schema != null && schema < since) {
        if (missingSince == null || since > missingSince) {
          missing = current;
          missingSince = since;
        }
      }
    }
    current = entry?.requires;
  }
  if (missing != null) {
    return FeatureSchemaReadiness(
      FeatureSchemaState.withheld,
      missing: missing,
      missingSince: missingSince,
    );
  }
  return FeatureSchemaReadiness(
    stated && schema == null
        ? FeatureSchemaState.unknown
        : FeatureSchemaState.available,
  );
}

/// Applies the hierarchy to a RAW resolved set: a feature stays only
/// while its whole `requires` chain is present. The stored child flag
/// survives a parent toggle — switch the parent back on and the child
/// returns exactly as configured.
///
/// #3729 — [schema], the schema number of the installation hosting the
/// workspace, withholds what that installation is too old for; null (not
/// established) withholds nothing.
Set<WorkspaceFeature> effectiveFeatures(
  Set<WorkspaceFeature> raw, {
  String? country,
  int? schema,
  Map<WorkspaceFeature, FeatureManifestEntry>? manifest,
}) {
  final entries = manifest ?? featureManifest;
  bool chainOn(WorkspaceFeature feature) {
    var current = entries[feature]?.requires;
    while (current != null) {
      if (!raw.contains(current)) return false;
      current = entries[current]?.requires;
    }
    return true;
  }

  return {
    for (final feature in raw)
      if (chainOn(feature) &&
          featureAvailableIn(entries[feature]?.availableIn, country) &&
          featureSchemaReadiness(feature, schema, manifest: entries).offered)
        feature,
  };
}
