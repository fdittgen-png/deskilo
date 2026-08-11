// SPDX-License-Identifier: 0BSD

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
  accessorySupplements,
  onlinePayments,
  pdfExport,
  seriesBooking,
  bookForOthers,
  pushNotifications,
  adminSeatBlocking,
  levelBooking,
  adminLevelAssign,
  kioskMode,
  nfcBadges,
  membersDirectory,
  whatsappIntegration,
  spaceQrCodes,
  coOwner,
  invoicing,
  adminInvoicing,
  autoCheckInOut,
  dataExport,
  workingHours,
  invoicePdfTemplate,
  memberNotifications,
  documents,
  dunning,
  memberReports,
  deletionRequests,
  roleManagement,
  vatManagement,
  vatDeclarations;

  /// The key of this feature inside `workspaces.feature_flags`.
  String get dbKey => name;
}

/// Registry entry of one toggleable feature (mirrors tankstellen's
/// manifest). [requires] expresses the feature HIERARCHY: a feature is
/// only EFFECTIVE while its whole prerequisite chain is enabled — the
/// Features screen renders children indented under their parent and
/// [effectiveFeatures] drops orphans, so switching a parent off takes
/// its whole subtree out of the app without erasing the owner's stored
/// child choices.
class FeatureManifestEntry {
  const FeatureManifestEntry({
    required this.feature,
    this.defaultOn = true,
    this.requires,
  });

  final WorkspaceFeature feature;

  /// Whether the feature is enabled when the workspace row carries no
  /// override for it.
  final bool defaultOn;

  /// The parent feature this one needs, or null for a root feature.
  final WorkspaceFeature? requires;
}

/// The declarative feature registry, in DISPLAY order: children follow
/// their parent. Everything ships enabled except the explicit owner
/// decisions (seat-blocking delegation #161, accessory billing #170,
/// online payments, whole-space booking 0050 and its admin delegation).
const Map<WorkspaceFeature, FeatureManifestEntry> featureManifest = {
  WorkspaceFeature.calendarTab:
      FeatureManifestEntry(feature: WorkspaceFeature.calendarTab),
  WorkspaceFeature.eventsTab:
      FeatureManifestEntry(feature: WorkspaceFeature.eventsTab),
  WorkspaceFeature.moneyTab:
      FeatureManifestEntry(feature: WorkspaceFeature.moneyTab),
  // Money children: they all land charges on the statement, so without
  // the money module they have no surface to land on.
  WorkspaceFeature.services: FeatureManifestEntry(
    feature: WorkspaceFeature.services,
    requires: WorkspaceFeature.moneyTab,
  ),
  WorkspaceFeature.accessorySupplements: FeatureManifestEntry(
    feature: WorkspaceFeature.accessorySupplements,
    defaultOn: false,
    requires: WorkspaceFeature.moneyTab,
  ),
  WorkspaceFeature.onlinePayments: FeatureManifestEntry(
    feature: WorkspaceFeature.onlinePayments,
    defaultOn: false,
    requires: WorkspaceFeature.moneyTab,
  ),
  // Invoices (0060): the immutable archive + issuing UI.
  WorkspaceFeature.invoicing: FeatureManifestEntry(
    feature: WorkspaceFeature.invoicing,
    requires: WorkspaceFeature.moneyTab,
  ),
  // Admins issuing invoices is an OWNER delegation (the adminSeatBlocking
  // idiom) — the server re-checks the flag.
  WorkspaceFeature.adminInvoicing: FeatureManifestEntry(
    feature: WorkspaceFeature.adminInvoicing,
    defaultOn: false,
    requires: WorkspaceFeature.invoicing,
  ),
  WorkspaceFeature.pdfExport:
      FeatureManifestEntry(feature: WorkspaceFeature.pdfExport),
  WorkspaceFeature.seriesBooking:
      FeatureManifestEntry(feature: WorkspaceFeature.seriesBooking),
  WorkspaceFeature.bookForOthers:
      FeatureManifestEntry(feature: WorkspaceFeature.bookForOthers),
  WorkspaceFeature.pushNotifications:
      FeatureManifestEntry(feature: WorkspaceFeature.pushNotifications),
  WorkspaceFeature.adminSeatBlocking: FeatureManifestEntry(
    feature: WorkspaceFeature.adminSeatBlocking,
    defaultOn: false,
  ),
  WorkspaceFeature.levelBooking: FeatureManifestEntry(
    feature: WorkspaceFeature.levelBooking,
    defaultOn: false,
  ),
  // Admin level assignment is a DELEGATION of level booking.
  WorkspaceFeature.adminLevelAssign: FeatureManifestEntry(
    feature: WorkspaceFeature.adminLevelAssign,
    defaultOn: false,
    requires: WorkspaceFeature.levelBooking,
  ),
  // The wall tablet module (0043): kiosk accounts, badge check-in.
  WorkspaceFeature.kioskMode:
      FeatureManifestEntry(feature: WorkspaceFeature.kioskMode),
  // RFID/NFC badges are kiosk credentials — no kiosk, no tap path.
  WorkspaceFeature.nfcBadges: FeatureManifestEntry(
    feature: WorkspaceFeature.nfcBadges,
    requires: WorkspaceFeature.kioskMode,
  ),
  // The community directory tab (#224).
  WorkspaceFeature.membersDirectory:
      FeatureManifestEntry(feature: WorkspaceFeature.membersDirectory),
  // WhatsApp affordances (swipe-to-message, group tile, number
  // editing) ride the directory.
  WorkspaceFeature.whatsappIntegration: FeatureManifestEntry(
    feature: WorkspaceFeature.whatsappIntegration,
    requires: WorkspaceFeature.membersDirectory,
  ),
  // Printable per-space QR cards + the scan-to-book flow (#335).
  WorkspaceFeature.spaceQrCodes:
      FeatureManifestEntry(feature: WorkspaceFeature.spaceQrCodes),
  // Co-ownership (0058): appoint active/passive co-owners with owner
  // permissions and automatic succession. The SERVER-side succession
  // safety net stays on regardless — this gates the appointment UI.
  WorkspaceFeature.coOwner:
      FeatureManifestEntry(feature: WorkspaceFeature.coOwner),
  // End-of-day sweep (#396): reservations never checked in/out complete
  // themselves once their time has passed. Default OFF — it rewrites
  // attendance records, which is an explicit owner decision.
  WorkspaceFeature.autoCheckInOut: FeatureManifestEntry(
    feature: WorkspaceFeature.autoCheckInOut,
    defaultOn: false,
  ),
  // Owner data export as an Excel workbook (#395). A read-only
  // convenience, so it follows the default-on rule.
  WorkspaceFeature.dataExport:
      FeatureManifestEntry(feature: WorkspaceFeature.dataExport),
  // Configurable working day + real-hours booking (#446). OFF hides the
  // settings section and the hours granularity option; the 8:00–17:00
  // defaults then apply unchanged.
  WorkspaceFeature.workingHours:
      FeatureManifestEntry(feature: WorkspaceFeature.workingHours),
  // Owner-written PDF intro/footer template (#454). PDF only — the
  // e-invoice XML never sees it.
  WorkspaceFeature.invoicePdfTemplate: FeatureManifestEntry(
    feature: WorkspaceFeature.invoicePdfTemplate,
    requires: WorkspaceFeature.invoicing,
  ),
  // Member-to-member notes + admin broadcast (#456).
  WorkspaceFeature.memberNotifications:
      FeatureManifestEntry(feature: WorkspaceFeature.memberNotifications),
  // The workspace document library (#500): statutes, guides, financial
  // statements, minutes — federated links to any DMS, role-gated.
  WorkspaceFeature.documents:
      FeatureManifestEntry(feature: WorkspaceFeature.documents),
  // Mahnwesen (#472/#502): reminder rules + due suggestions. OFF keeps
  // the manual per-invoice reminder untouched.
  WorkspaceFeature.dunning: FeatureManifestEntry(
    feature: WorkspaceFeature.dunning,
    requires: WorkspaceFeature.invoicing,
  ),
  // The member report suite (#494/#502): the financial agreement and
  // the monthly payments report, self-service and admin-sent.
  WorkspaceFeature.memberReports:
      FeatureManifestEntry(feature: WorkspaceFeature.memberReports),
  // Validated deletion requests for past/checked-in bookings
  // (#492/#502). OFF = such bookings simply cannot be deleted.
  WorkspaceFeature.deletionRequests:
      FeatureManifestEntry(feature: WorkspaceFeature.deletionRequests),
  // #513 — the centralized role→permission matrix. OFF hides the
  // Role management screen; the DEFAULT permissions still apply (the
  // matrix is then simply not editable in the app).
  WorkspaceFeature.roleManagement:
      FeatureManifestEntry(feature: WorkspaceFeature.roleManagement),
  // VAT management (#544): the rates editor and every per-item/tariff
  // rate picker. OFF hides the CONFIG surfaces only — a vat_registered
  // workspace keeps taxing at its stored/default rates (legal math is
  // never toggleable). Under invoicing, like the /vat screen always was.
  WorkspaceFeature.vatManagement: FeatureManifestEntry(
    feature: WorkspaceFeature.vatManagement,
    requires: WorkspaceFeature.invoicing,
  ),
  // Periodic VAT declarations (#534/0107) — a child of VAT management;
  // the vat_registered regime gates it further at the screen (an exempt
  // workspace has nothing to declare).
  WorkspaceFeature.vatDeclarations: FeatureManifestEntry(
    feature: WorkspaceFeature.vatDeclarations,
    requires: WorkspaceFeature.vatManagement,
  ),
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

/// Applies the hierarchy to a RAW resolved set: a feature stays only
/// while its whole `requires` chain is present. The stored child flag
/// survives a parent toggle — switch the parent back on and the child
/// returns exactly as configured.
Set<WorkspaceFeature> effectiveFeatures(Set<WorkspaceFeature> raw) {
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
      if (chainOn(feature)) feature,
  };
}
