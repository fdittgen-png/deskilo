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
  // #4171 — receiving a delivery into stock: put away once, into explicit
  // places and new lots, with its origin kept. Asked for, under the goods
  // ledger. Off: a delivery is recorded as before and no stock moves.
  WorkspaceFeature.stockReceiving: FeatureManifestEntry(
    feature: WorkspaceFeature.stockReceiving,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockManagement,
    defaultOn: false,
  ),
  // #4170 — taking goods out for use or as a loss, with the reason and the lot.
  // Asked for, under the goods ledger. Off: no consumption or loss is offered;
  // transfers and receiving need only the ledger.
  WorkspaceFeature.stockTakeOut: FeatureManifestEntry(
    feature: WorkspaceFeature.stockTakeOut,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockManagement,
    defaultOn: false,
  ),
  // #4294 — reorder points per item and site, low-stock alerts in the inbox and a
  // replenishment list. Asked for, under the goods ledger. Off: no point is set, no
  // alert is raised and no list is offered; the ledger is unaffected.
  WorkspaceFeature.stockReorder: FeatureManifestEntry(
    feature: WorkspaceFeature.stockReorder,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockManagement,
    defaultOn: false,
  ),
  // #4172 — a customer return, a supplier return and a correction of a movement, each
  // bounded by the movement it reverses. Asked for, under the goods ledger. Off: no
  // return and no correction is offered; the ledger is unaffected.
  WorkspaceFeature.stockReturns: FeatureManifestEntry(
    feature: WorkspaceFeature.stockReturns,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockManagement,
    defaultOn: false,
  ),
  // #4172 — a count of an item at a place, recorded by whoever manages the stock and applied
  // by whoever approves adjustments, only while the stock has not moved since. Asked for,
  // under the goods ledger. Off: no count is recorded; the ledger is unaffected.
  WorkspaceFeature.stockCounts: FeatureManifestEntry(
    feature: WorkspaceFeature.stockCounts,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockManagement,
    defaultOn: false,
  ),
  // #4295 — scheduled cycle counts of chosen places, items or high-value goods while the shop
  // stays open; each counted line is a count of #4172, approved there. Asked for, under the
  // counts. Off: no plan runs and no task is made; the ledger is unaffected.
  WorkspaceFeature.stockCycleCounts: FeatureManifestEntry(
    feature: WorkspaceFeature.stockCycleCounts,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockCounts,
    defaultOn: false,
  ),
  // #4361 — item groups: shared settings that items inherit and may override, with history. Asked for, under the goods ledger. Off: items keep their own values exactly as before.
  WorkspaceFeature.stockItemGroups: FeatureManifestEntry(
    feature: WorkspaceFeature.stockItemGroups,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockManagement,
    defaultOn: false,
  ),
};
