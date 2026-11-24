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
    // #3729 — its server side is the stock registries, ledger and templates
    // of 0746 to 0748: an installation below 748 does not offer it, nor any
    // feature under it.
    since: 748,
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
  // #4362 — RFID tags on items, units, lots and places, stored like a barcode and unique per
  // business; a tag may name one piece. Asked for, under the goods ledger. Off: no tag is bound and
  // a tag read is not recognised.
  WorkspaceFeature.stockTags: FeatureManifestEntry(
    feature: WorkspaceFeature.stockTags,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockManagement,
    defaultOn: false,
  ),
  // #4359 — a scanner that types, and the camera, fill any goods sheet: a code is read as a barcode, a
  // place label, a lot label or a tag. Asked for, under the goods ledger; off: the sheets take no scan.
  WorkspaceFeature.stockScanning: FeatureManifestEntry(
    feature: WorkspaceFeature.stockScanning,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockManagement,
    defaultOn: false,
  ),
  // #4184 — counter receipts: an immutable receipt of a sale at the counter, numbered once, with its tender. Asked for, under standalone invoicing. Off: nothing changes.
  WorkspaceFeature.counterReceipts: FeatureManifestEntry(
    feature: WorkspaceFeature.counterReceipts,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.standaloneInvoicing,
    defaultOn: false,
  ),
  // #4367 — till sessions: a till is opened with its float, counted at the close, and the day is closed with its report. Asked for, under counter receipts. Off: sales need no session.
  WorkspaceFeature.counterTillSessions: FeatureManifestEntry(
    feature: WorkspaceFeature.counterTillSessions,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.counterReceipts,
    defaultOn: false,
  ),
  // #4364 — UHF bulk reads: many tags read at once to receive, move and count, resolved in batches; nothing is sent until the user confirms. Asked for, under RFID tags. Off: tags are read one at a time.
  WorkspaceFeature.stockTagReads: FeatureManifestEntry(
    feature: WorkspaceFeature.stockTagReads,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockTags,
    defaultOn: false,
  ),
  // #4431 — the expiry report: every lot or piece on hand that is expired at a chosen date or expires after it, printed from
  // the report engine with a layout the business can edit. Asked for, under stock management.
  WorkspaceFeature.stockExpiryReport: FeatureManifestEntry(
    feature: WorkspaceFeature.stockExpiryReport,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockManagement,
    defaultOn: false,
  ),
  // #4435 — handling units: goods move in the pallet or carton they were received in, or in the store's own repackaged units,
  // and stay traceable through the repack. Asked for, under stock management.
  WorkspaceFeature.stockHandlingUnits: FeatureManifestEntry(
    feature: WorkspaceFeature.stockHandlingUnits,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.stockManagement,
    defaultOn: false,
  ),
  // #4373 — the till keeps selling for cash when it is offline, and the sales are sent once the connection returns. Asked for, under till sessions.
  WorkspaceFeature.counterOfflineCash: FeatureManifestEntry(
    feature: WorkspaceFeature.counterOfflineCash,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.counterTillSessions,
    defaultOn: false,
  ),
  // #4442 — the owner and the admins keep the business's own units of measure and their conversions (1 km = 1000 m). It
  // requires nothing: invoice and quote lines of a business without any stock are priced in these units as much as items.
  // Asked for; the built-in units are there whether it is on or not.
  WorkspaceFeature.unitsOfMeasure: FeatureManifestEntry(
    feature: WorkspaceFeature.unitsOfMeasure,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
};
