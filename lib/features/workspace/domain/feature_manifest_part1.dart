// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_feature.dart';

// #2386 — the feature registry's data, part 1 of 3 in display
// order. A new flag's entry goes at the end of the last part.
const Map<WorkspaceFeature, FeatureManifestEntry> _manifest1 = {
  WorkspaceFeature.calendarTab:
      FeatureManifestEntry(
      feature: WorkspaceFeature.calendarTab,
      surface: FeatureSurface.calendar,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.eventsTab:
      FeatureManifestEntry(
      feature: WorkspaceFeature.eventsTab,
      surface: FeatureSurface.messages,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.moneyTab:
      FeatureManifestEntry(
      feature: WorkspaceFeature.moneyTab,
      surface: FeatureSurface.money,
      tier: FeatureTier.core,
    ),
  // Money children: they all land charges on the statement, so without
  // the money module they have no surface to land on.
  WorkspaceFeature.services: FeatureManifestEntry(
    feature: WorkspaceFeature.services,
    surface: FeatureSurface.money,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.moneyTab,
  ),
  WorkspaceFeature.accessorySupplements: FeatureManifestEntry(
    feature: WorkspaceFeature.accessorySupplements,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.moneyTab,
  ),
  WorkspaceFeature.onlinePayments: FeatureManifestEntry(
    feature: WorkspaceFeature.onlinePayments,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.moneyTab,
  ),
  // Invoices (0060): the immutable archive + issuing UI.
  WorkspaceFeature.invoicing: FeatureManifestEntry(
    feature: WorkspaceFeature.invoicing,
    surface: FeatureSurface.money,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.moneyTab,
  ),
  // Admins issuing invoices is an OWNER delegation (the adminSeatBlocking
  // idiom) — the server re-checks the flag.
  WorkspaceFeature.adminInvoicing: FeatureManifestEntry(
    feature: WorkspaceFeature.adminInvoicing,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.invoicing,
  ),
  WorkspaceFeature.pdfExport:
      FeatureManifestEntry(
      feature: WorkspaceFeature.pdfExport,
      surface: FeatureSurface.reports,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.seriesBooking:
      FeatureManifestEntry(
      feature: WorkspaceFeature.seriesBooking,
      surface: FeatureSurface.reserve,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.bookForOthers:
      FeatureManifestEntry(
      feature: WorkspaceFeature.bookForOthers,
      surface: FeatureSurface.reserve,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.pushNotifications:
      FeatureManifestEntry(
      feature: WorkspaceFeature.pushNotifications,
      surface: FeatureSurface.messages,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.adminSeatBlocking: FeatureManifestEntry(
    feature: WorkspaceFeature.adminSeatBlocking,
    surface: FeatureSurface.reserve,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  WorkspaceFeature.levelBooking: FeatureManifestEntry(
    feature: WorkspaceFeature.levelBooking,
    surface: FeatureSurface.reserve,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // Admin level assignment is a DELEGATION of level booking.
  WorkspaceFeature.adminLevelAssign: FeatureManifestEntry(
    feature: WorkspaceFeature.adminLevelAssign,
    surface: FeatureSurface.reserve,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.levelBooking,
  ),
  // The wall tablet module (0043): kiosk accounts, badge check-in.
  WorkspaceFeature.kioskMode:
      FeatureManifestEntry(
      feature: WorkspaceFeature.kioskMode,
      surface: FeatureSurface.kiosk,
      tier: FeatureTier.platform,
    ),
  // RFID/NFC badges are kiosk credentials — no kiosk, no tap path.
  WorkspaceFeature.nfcBadges: FeatureManifestEntry(
    feature: WorkspaceFeature.nfcBadges,
    surface: FeatureSurface.kiosk,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.kioskMode,
  ),
  // The community directory tab (#224).
  WorkspaceFeature.membersDirectory:
      FeatureManifestEntry(
      feature: WorkspaceFeature.membersDirectory,
      surface: FeatureSurface.members,
      tier: FeatureTier.core,
    ),
  // WhatsApp affordances (swipe-to-message, group tile, number
  // editing) ride the directory.
  WorkspaceFeature.whatsappIntegration: FeatureManifestEntry(
    feature: WorkspaceFeature.whatsappIntegration,
    surface: FeatureSurface.messages,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.membersDirectory,
  ),
  // Printable per-space QR cards + the scan-to-book flow (#335).
  WorkspaceFeature.spaceQrCodes:
      FeatureManifestEntry(
      feature: WorkspaceFeature.spaceQrCodes,
      surface: FeatureSurface.reserve,
      tier: FeatureTier.core,
    ),
  // Co-ownership (0058): appoint active/passive co-owners with owner
  // permissions and automatic succession. The SERVER-side succession
  // safety net stays on regardless — this gates the appointment UI.
  WorkspaceFeature.coOwner:
      FeatureManifestEntry(
      feature: WorkspaceFeature.coOwner,
      surface: FeatureSurface.members,
      tier: FeatureTier.platform,
    ),
  // End-of-day sweep (#396): reservations never checked in/out complete
  // themselves once their time has passed. Default OFF — it rewrites
  // attendance records, which is an explicit owner decision.
  WorkspaceFeature.autoCheckInOut: FeatureManifestEntry(
    feature: WorkspaceFeature.autoCheckInOut,
    surface: FeatureSurface.reserve,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // Owner data export as an Excel workbook (#395). A read-only
  // convenience, so it follows the default-on rule.
  WorkspaceFeature.dataExport:
      FeatureManifestEntry(
      feature: WorkspaceFeature.dataExport,
      surface: FeatureSurface.settings,
      tier: FeatureTier.core,
    ),
  // Configurable working day + real-hours booking (#446). OFF hides the
  // settings section and the hours granularity option; the 8:00–17:00
  // defaults then apply unchanged.
  WorkspaceFeature.workingHours:
      FeatureManifestEntry(
      feature: WorkspaceFeature.workingHours,
      surface: FeatureSurface.reserve,
      tier: FeatureTier.core,
    ),
  // Owner-written PDF intro/footer template (#454). PDF only — the
  // e-invoice XML never sees it.
  WorkspaceFeature.invoicePdfTemplate: FeatureManifestEntry(
    feature: WorkspaceFeature.invoicePdfTemplate,
    surface: FeatureSurface.reports,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #869 — place the recipient where a window envelope shows it, and
  // reserve the letterhead band above it, so a printed invoice can be
  // folded and posted without the address moving off the window.
  WorkspaceFeature.invoiceAddressWindow: FeatureManifestEntry(
    feature: WorkspaceFeature.invoiceAddressWindow,
    surface: FeatureSurface.reports,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // Member-to-member notes + admin broadcast (#456).
  WorkspaceFeature.memberNotifications:
      FeatureManifestEntry(
      feature: WorkspaceFeature.memberNotifications,
      surface: FeatureSurface.messages,
      tier: FeatureTier.core,
    ),
  // The workspace document library (#500): statutes, guides, financial
  // statements, minutes — federated links to any DMS, role-gated.
  WorkspaceFeature.documents:
      FeatureManifestEntry(
      feature: WorkspaceFeature.documents,
      surface: FeatureSurface.documents,
      tier: FeatureTier.core,
    ),
  // Mahnwesen (#472/#502): reminder rules + due suggestions. OFF keeps
  // the manual per-invoice reminder untouched.
  WorkspaceFeature.dunning: FeatureManifestEntry(
    feature: WorkspaceFeature.dunning,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // The member report suite (#494/#502): the financial agreement and
  // the monthly payments report, self-service and admin-sent.
  WorkspaceFeature.memberReports: FeatureManifestEntry(
    feature: WorkspaceFeature.memberReports,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.moneyTab,
  ),
  // Validated deletion requests for past/checked-in bookings
  // (#492/#502). OFF = such bookings simply cannot be deleted.
  WorkspaceFeature.deletionRequests:
      FeatureManifestEntry(
      feature: WorkspaceFeature.deletionRequests,
      surface: FeatureSurface.reserve,
      tier: FeatureTier.core,
    ),
  // #513 — the centralized role→permission matrix. OFF hides the
  // Role management screen; the DEFAULT permissions still apply (the
  // matrix is then simply not editable in the app).
  WorkspaceFeature.roleManagement:
      FeatureManifestEntry(
      feature: WorkspaceFeature.roleManagement,
      surface: FeatureSurface.members,
      tier: FeatureTier.core,
    ),
  // VAT management (#544): the rates editor and every per-item/tariff
  // rate picker. OFF hides the CONFIG surfaces only — a vat_registered
  // workspace keeps taxing at its stored/default rates (legal math is
  // never toggleable). Under invoicing, like the /vat screen always was.
  WorkspaceFeature.vatManagement: FeatureManifestEntry(
    feature: WorkspaceFeature.vatManagement,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // Periodic VAT declarations (#534/0107) — a child of VAT management;
  // the vat_registered regime gates it further at the screen (an exempt
  // workspace has nothing to declare).
  WorkspaceFeature.vatDeclarations: FeatureManifestEntry(
    feature: WorkspaceFeature.vatDeclarations,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.vatManagement,
  ),
  // Direct delivery to the CUSTOMER's e-invoicing service (#568) — the
  // second leg beside the government platform. Under invoicing: it only
  // ever shows on the send sheet of an issued invoice.
  WorkspaceFeature.einvoiceCustomerDelivery: FeatureManifestEntry(
    feature: WorkspaceFeature.einvoiceCustomerDelivery,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #587 — owners may delete plan objects that reservations reference;
  // the references survive as an audit substitution text. OFF keeps the
  // historic refusal (the server re-checks the flag in the RPC).
  WorkspaceFeature.planObjectDelete:
      FeatureManifestEntry(
      feature: WorkspaceFeature.planObjectDelete,
      surface: FeatureSurface.reserve,
      tier: FeatureTier.core,
    ),
  // #598 — regroup the notification feed by type, day or member. A
  // child of the events feed: no feed, nothing to group.
  WorkspaceFeature.notificationGrouping: FeatureManifestEntry(
    feature: WorkspaceFeature.notificationGrouping,
    surface: FeatureSurface.messages,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.eventsTab,
  ),
  WorkspaceFeature.bookingPolicies:
      FeatureManifestEntry(
      feature: WorkspaceFeature.bookingPolicies,
      surface: FeatureSurface.reserve,
      tier: FeatureTier.core,
    ),
  // #814 — the client-side mirror of the policies, on every surface.
  WorkspaceFeature.bookingGate: FeatureManifestEntry(
    feature: WorkspaceFeature.bookingGate,
    surface: FeatureSurface.reserve,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.bookingPolicies,
  ),
  // #604 — the chair-tag functionality (#585): configuring a tag on a
  // seat and resolving a tapped tag to that seat.
  WorkspaceFeature.nfcSeatTags:
      FeatureManifestEntry(
      feature: WorkspaceFeature.nfcSeatTags,
      surface: FeatureSurface.kiosk,
      tier: FeatureTier.platform,
    ),
  // #604 — barcode/QR badge issuance, beside nfcBadges: both are badge
  // credentials the kiosk accepts, so both sit under kioskMode.
  WorkspaceFeature.qrBadges: FeatureManifestEntry(
    feature: WorkspaceFeature.qrBadges,
    surface: FeatureSurface.kiosk,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.kioskMode,
  ),
  // #616 — the kiosk receipt shows the member's profile photo.
  WorkspaceFeature.kioskMemberPhotos: FeatureManifestEntry(
    feature: WorkspaceFeature.kioskMemberPhotos,
    surface: FeatureSurface.kiosk,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.kioskMode,
  ),
  // #802 — the subscription is billed ahead of its month; what the month
  // actually cost is billed after it. Two documents, each switchable on
  // its own: an owner can bill subscriptions in advance and keep settling
  // the extras by hand, or the reverse.
  WorkspaceFeature.subscriptionInvoices: FeatureManifestEntry(
    feature: WorkspaceFeature.subscriptionInvoices,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  WorkspaceFeature.usageInvoices: FeatureManifestEntry(
    feature: WorkspaceFeature.usageInvoices,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #804 — regrouping several open invoices into one demand. Useful with
  // the two above and independent of them: a workspace that never split
  // its invoices can still consolidate a member's arrears.
  WorkspaceFeature.invoiceSettlement: FeatureManifestEntry(
    feature: WorkspaceFeature.invoiceSettlement,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #812 — the process view: journey bar, next move, stage strip.
  WorkspaceFeature.invoiceJourney: FeatureManifestEntry(
    feature: WorkspaceFeature.invoiceJourney,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #798 — swipe a message right to quote it, left to take it back
  // while it is still unread.
  WorkspaceFeature.messageGestures:
      FeatureManifestEntry(
      feature: WorkspaceFeature.messageGestures,
      surface: FeatureSurface.messages,
      tier: FeatureTier.core,
    ),
  // #793 — monograms that tell members apart wherever an avatar has no
  // photo to show.
  WorkspaceFeature.uniqueMonograms:
      FeatureManifestEntry(
      feature: WorkspaceFeature.uniqueMonograms,
      surface: FeatureSurface.members,
      tier: FeatureTier.core,
    ),
  // #620 — occupant profile photos on the Plan tab and Reserve hub
  // maps, kiosk or not.
  WorkspaceFeature.planMemberPhotos:
      FeatureManifestEntry(
      feature: WorkspaceFeature.planMemberPhotos,
      surface: FeatureSurface.reserve,
      tier: FeatureTier.platform,
    ),
  // #711 — a member's own numbers, dates, clock and zone. Default ON;
  // OFF makes every member read as the app always did (the UI
  // language's home region, 24-hour clock, workspace zone) and hides
  // the Settings section.
  WorkspaceFeature.regionalFormats:
      FeatureManifestEntry(
      feature: WorkspaceFeature.regionalFormats,
      surface: FeatureSurface.everywhere,
      tier: FeatureTier.core,
    ),
  // #718 — the calendar as the dated view of everything: one feed of
  // reservations, check-ins, alerts, messages, money and reminders for
  // a day or a range, each row linking to its source. OFF: the calendar
  // shows reservations only, as it did before.
  WorkspaceFeature.calendarHub:
      FeatureManifestEntry(
      feature: WorkspaceFeature.calendarHub,
      surface: FeatureSurface.calendar,
      tier: FeatureTier.core,
    ),
  // #818 — the views over the hub's feed.
  WorkspaceFeature.calendarViews: FeatureManifestEntry(
    feature: WorkspaceFeature.calendarViews,
    surface: FeatureSurface.calendar,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.calendarHub,
  ),
  // #821 — the reworked Messages tab.
  WorkspaceFeature.messagesHub:
      FeatureManifestEntry(
      feature: WorkspaceFeature.messagesHub,
      surface: FeatureSurface.messages,
      tier: FeatureTier.core,
    ),
  // #822 — the full-screen report designer over the template editor.
  WorkspaceFeature.reportDesigner: FeatureManifestEntry(
    feature: WorkspaceFeature.reportDesigner,
    surface: FeatureSurface.reports,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicePdfTemplate,
  ),
};
