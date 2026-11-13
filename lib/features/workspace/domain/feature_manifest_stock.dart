// SPDX-License-Identifier: AGPL-3.0-or-later
import 'workspace_feature.dart';

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
};
