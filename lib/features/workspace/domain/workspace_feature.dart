// SPDX-License-Identifier: MIT

/// Per-workspace toggleable features (#146). The owner switches them
/// on/off for the whole workspace; every member's client applies the
/// flags on connect. The enum name is the jsonb key stored in
/// `workspaces.feature_flags` — an absent key means the feature's
/// registry default (ON).
enum WorkspaceFeature {
  calendarTab,
  eventsTab,
  moneyTab,
  services,
  pdfExport,
  seriesBooking,
  bookForOthers,
  pushNotifications;

  /// The key of this feature inside `workspaces.feature_flags`.
  String get dbKey => name;
}

/// Registry entry of one toggleable feature. Extension point (mirrors
/// tankstellen's manifest): a `List<WorkspaceFeature> requires` field can
/// be added here to express prerequisite features as a DAG — resolve
/// would then drop features whose prerequisites are off.
class FeatureManifestEntry {
  const FeatureManifestEntry({required this.feature, this.defaultOn = true});

  final WorkspaceFeature feature;

  /// Whether the feature is enabled when the workspace row carries no
  /// override for it.
  final bool defaultOn;
}

/// The declarative feature registry: every feature ships enabled.
const Map<WorkspaceFeature, FeatureManifestEntry> featureManifest = {
  WorkspaceFeature.calendarTab:
      FeatureManifestEntry(feature: WorkspaceFeature.calendarTab),
  WorkspaceFeature.eventsTab:
      FeatureManifestEntry(feature: WorkspaceFeature.eventsTab),
  WorkspaceFeature.moneyTab:
      FeatureManifestEntry(feature: WorkspaceFeature.moneyTab),
  WorkspaceFeature.services:
      FeatureManifestEntry(feature: WorkspaceFeature.services),
  WorkspaceFeature.pdfExport:
      FeatureManifestEntry(feature: WorkspaceFeature.pdfExport),
  WorkspaceFeature.seriesBooking:
      FeatureManifestEntry(feature: WorkspaceFeature.seriesBooking),
  WorkspaceFeature.bookForOthers:
      FeatureManifestEntry(feature: WorkspaceFeature.bookForOthers),
  WorkspaceFeature.pushNotifications:
      FeatureManifestEntry(feature: WorkspaceFeature.pushNotifications),
};

/// Resolves the stored [featureFlags] jsonb against the registry: start
/// from the defaults, apply boolean overrides, ignore unknown keys and
/// non-boolean values so old clients survive new flags (and vice versa).
Set<WorkspaceFeature> resolveEnabledFeatures(
  Map<String, dynamic> featureFlags,
) {
  final enabled = <WorkspaceFeature>{
    for (final entry in featureManifest.entries)
      if (entry.value.defaultOn) entry.key,
  };
  final byName = WorkspaceFeature.values.asNameMap();
  for (final entry in featureFlags.entries) {
    final feature = byName[entry.key];
    final value = entry.value;
    if (feature == null || value is! bool) continue;
    value ? enabled.add(feature) : enabled.remove(feature);
  }
  return enabled;
}
