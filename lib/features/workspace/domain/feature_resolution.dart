// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The effective feature set: the stored switches over the registry chain
// (#800) and, since #2454, over the availability of the workspace country.
// Re-exported by workspace_feature.dart, so callers do not change.
import 'workspace_feature.dart';

/// Applies the hierarchy to a RAW resolved set: a feature stays only
/// while its whole `requires` chain is present. The stored child flag
/// survives a parent toggle — switch the parent back on and the child
/// returns exactly as configured.
Set<WorkspaceFeature> effectiveFeatures(
  Set<WorkspaceFeature> raw, {
  String? country,
}) {
  bool chainOn(WorkspaceFeature feature) {
    var current = featureManifest[feature]?.requires;
    while (current != null) {
      if (!raw.contains(current)) return false;
      current = featureManifest[current]?.requires;
    }
    return true;
  }

  return {
    for (final feature in raw)
      if (chainOn(feature) &&
          featureAvailableIn(featureManifest[feature]?.availableIn, country))
        feature,
  };
}
