// SPDX-License-Identifier: AGPL-3.0-or-later
import 'workspace_feature.dart';

export 'feature_manifest_organisation.dart';

/// #3824 — the stock flags of epic #3823, in display order, after the
/// registry's three parts (`feature_manifest_part1-3.dart`): the goods
/// ledger and, leaf by leaf, every stock flag under it.
const Map<WorkspaceFeature, FeatureManifestEntry> stockFeatureManifest = {
  // #3824 — the goods ledger: where goods are, in which unit, from which
  // lot, and every movement between two places. Asked for, under the
  // catalogue whose rows become its items; the parent of every later stock
  // flag (#3823). Off: the shelf count of 0135 works exactly as before.
  WorkspaceFeature.stockManagement: FeatureManifestEntry(
    feature: WorkspaceFeature.stockManagement,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.services,
    defaultOn: false,
  ),
  // #4169 — lots and expiry: an item tracked by lot or by expiry date, with
  // its shelf life. Asked for, under the goods ledger. Off: no item is
  // offered a tracking, and what was recorded is kept as it is.
  WorkspaceFeature.stockLots: FeatureManifestEntry(
    feature: WorkspaceFeature.stockLots,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockManagement,
    defaultOn: false,
  ),
};
