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
  invoiceAddressWindow,
  memberNotifications,
  documents,
  dunning,
  memberReports,
  deletionRequests,
  roleManagement,
  vatManagement,
  vatDeclarations,
  einvoiceCustomerDelivery,
  planObjectDelete,
  notificationGrouping,
  bookingPolicies,
  nfcSeatTags,
  qrBadges,
  kioskMemberPhotos,
  formHelpHints,
  uiAnimations,
  planMemberPhotos,
  badgeSignIn,
  regionalFormats,
  calendarHub,
  dataAccessLog,
  memberDataExport,
  financeFaces,
  paymentReminders,
  supplyExpenses,
  validationScopes,
  validationChain,
  richMessageRefs,
  calendarValidations,
  usageRecords,
  reportDesignExchange,
  reportLayouts,
  personalInfo,
  managedProfiles,
  managedProfileAccess,
  numberSequences,
  workspaceStatus,
  expenseRepartitionWizard,
  multiSite,
  siteDocuments,
  vatGroups,
  vatRateHistory,
  vatCounterparty,
  environmentPairs,
  deployments,
  seatDayTimeline,
  memberPaymentTerms,
  reportTexts,
  usageReport,
  vatReport,
  letterStandard,
  priceNegotiations,

  /// #767 — recurring scheduled expenses (internet, phone, electricity):
  /// the schedule is validated once, each due occurrence is presented to
  /// the member — matching amount lands settled, a deviation explains
  /// itself and passes the expense validation.
  scheduledExpenses,

  /// #793 — the avatar monogram identifies ONE member: the initials of
  /// the first and family name, lengthened on a clash and numbered only
  /// when the letters run out. OFF keeps the single first letter, which
  /// drew three identical `M` circles in a workspace of three Mathieus.
  uniqueMonograms,

  /// #798 — the two swipes on a message everyone already knows from
  /// their phone: RIGHT quotes it into the reply, LEFT takes an unread
  /// message back after confirming. OFF leaves the long-press delete.
  messageGestures,

  /// #802 — the subscription invoice, raised BEFORE the month it pays
  /// for. Off, the fee stays on the whole-month invoice as it always was.
  subscriptionInvoices,

  /// #802 — the end-of-month invoice for what the month actually cost
  /// beyond the subscription. Off, the extras stay on the whole-month
  /// invoice.
  usageInvoices,

  /// #804 — several open invoices regrouped into one the member pays,
  /// with the originals kept and traceable.
  invoiceSettlement,

  /// #812 — the journey of an invoice told as one process on every
  /// screen: Issued → Payment → Confirmation → Closed, whose move it is
  /// and what that move is. OFF keeps the plain status chips.
  invoiceJourney,

  /// #814 — the booking gate: every surface asks the availability
  /// parameters BEFORE offering a window (closed day, past, horizon,
  /// durations, outside-hours mode, walk-up rules), the calendar views
  /// draw closed days as closed, and a legend names the seat states.
  /// OFF keeps the server's after-the-fact refusals.
  bookingGate,

  /// #818 — the Calendar tab as three views (agenda, week, month) with
  /// per-day markers, closed days, relative day headers and the due
  /// dates. OFF keeps the plain day/range selector over the feed.
  calendarViews,

  /// #821 — the Messages tab reworked: one inbox bar with All / Unread /
  /// Archived and search, pin / mute / archive / mark unread on a
  /// thread, the thread as a full-screen page with date separators, the
  /// composer's attach menu and draft. OFF keeps the two-bar inbox and
  /// the sheet thread.
  messagesHub,

  /// #822 — the report editor as a full-screen designer: direct
  /// manipulation, undo, side-by-side preview, image size/alignment.
  reportDesigner,

  /// #825 — one page per member: identity, presence, bookings, contact,
  /// money, and the admin controls grouped with their current values.
  memberPage,

  /// #827 — the invoicing wizard: one guided month-close process.
  invoicingWizard,

  /// #828 — shared expenses distributed over the members, reversals as
  /// credit notes.
  expenseRepartition,

  /// #831 — settled sources fold under their settlement: documentation
  /// only, a stamped PDF the one affordance left.
  settlementFold,

  /// #916 — the space file carries the whole configuration (tariffs,
  /// legal identity, rules, governance, document designs, sites) and
  /// importing it applies it, even on a space with bookings.
  configurationTransfer,

  /// #969 — the user picks the shell's navigation: the classic bottom
  /// bar with the round button, or the menu the web uses.
  navigationStyle,

  /// #970 — demo mode: a per-device switch that replaces every name,
  /// e-mail and address on screen by invented ones.
  demoMode,

  /// #977 — the wizard that creates and configures a new instance.
  instanceWizard,

  /// #1110 — a discreet line saying how each member got here: founded
  /// the space, joined by invitation, or had the profile created for
  /// them. It is not a status and carries no judgement; it is the fact,
  /// recorded once when the row was written and otherwise lost.
  memberOrigin,

  /// #1119 — whoever invites somebody chooses whether that person also
  /// reaches the production twin. Two answers, not three: 0185's
  /// invariant is `prod ⊆ dev`, so the question is "does this person
  /// touch production", never "which of two parallel worlds".
  memberEnvironments,

  /// #1120 — the workspace library: save this space's floor plan as a
  /// template, decide who may see it, invite people to it by address, and
  /// start from what others offer. The builtin template needs no flag —
  /// a new space starts with a room either way.
  workspaceLibrary;

  /// The key of this feature inside `workspaces.feature_flags`.
  String get dbKey => name;
}

/// #1063 — what a workspace meets on its FIRST day, and what it has to
/// ask for.
///
/// The registry has a hundred entries. Every one of them is behind a
/// flag, which is the right architecture; what was wrong is that the
/// default was "all of it", so a fifteen-person community met VAT
/// groups, positioned report layouts, environment pairs and deployment
/// beside the six things it actually needed.
///
/// This is a property, not a mechanism. [core] is what every deployment
/// needs — the floor plan, reservations, members, memberships, the
/// ledger, payments, invoices, basic administration. [platform] is what
/// only a sophisticated operator needs, and a new workspace starts
/// without it.
///
/// It changes NO existing workspace: the tier decides what
/// [defaultFeatureFlagsForNewWorkspace] writes AT CREATION, and a
/// workspace that already exists keeps exactly the flags it has.
/// A migration that silently switched a live workspace's features off
/// would be a data-loss bug wearing a feature flag.
enum FeatureTier {
  /// Day one, every deployment.
  core,

  /// Asked for, never assumed.
  platform,
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
    required this.tier,
    this.defaultOn = true,
    this.requires,
  });

  final WorkspaceFeature feature;

  /// #1063 — whether a NEW workspace starts with this. Required, with no
  /// default, so that a flag cannot be added without somebody deciding
  /// which tier it belongs to.
  final FeatureTier tier;

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
      FeatureManifestEntry(
      feature: WorkspaceFeature.calendarTab,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.eventsTab:
      FeatureManifestEntry(
      feature: WorkspaceFeature.eventsTab,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.moneyTab:
      FeatureManifestEntry(
      feature: WorkspaceFeature.moneyTab,
      tier: FeatureTier.core,
    ),
  // Money children: they all land charges on the statement, so without
  // the money module they have no surface to land on.
  WorkspaceFeature.services: FeatureManifestEntry(
    feature: WorkspaceFeature.services,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.moneyTab,
  ),
  WorkspaceFeature.accessorySupplements: FeatureManifestEntry(
    feature: WorkspaceFeature.accessorySupplements,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.moneyTab,
  ),
  WorkspaceFeature.onlinePayments: FeatureManifestEntry(
    feature: WorkspaceFeature.onlinePayments,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.moneyTab,
  ),
  // Invoices (0060): the immutable archive + issuing UI.
  WorkspaceFeature.invoicing: FeatureManifestEntry(
    feature: WorkspaceFeature.invoicing,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.moneyTab,
  ),
  // Admins issuing invoices is an OWNER delegation (the adminSeatBlocking
  // idiom) — the server re-checks the flag.
  WorkspaceFeature.adminInvoicing: FeatureManifestEntry(
    feature: WorkspaceFeature.adminInvoicing,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.invoicing,
  ),
  WorkspaceFeature.pdfExport:
      FeatureManifestEntry(
      feature: WorkspaceFeature.pdfExport,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.seriesBooking:
      FeatureManifestEntry(
      feature: WorkspaceFeature.seriesBooking,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.bookForOthers:
      FeatureManifestEntry(
      feature: WorkspaceFeature.bookForOthers,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.pushNotifications:
      FeatureManifestEntry(
      feature: WorkspaceFeature.pushNotifications,
      tier: FeatureTier.core,
    ),
  WorkspaceFeature.adminSeatBlocking: FeatureManifestEntry(
    feature: WorkspaceFeature.adminSeatBlocking,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  WorkspaceFeature.levelBooking: FeatureManifestEntry(
    feature: WorkspaceFeature.levelBooking,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // Admin level assignment is a DELEGATION of level booking.
  WorkspaceFeature.adminLevelAssign: FeatureManifestEntry(
    feature: WorkspaceFeature.adminLevelAssign,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.levelBooking,
  ),
  // The wall tablet module (0043): kiosk accounts, badge check-in.
  WorkspaceFeature.kioskMode:
      FeatureManifestEntry(
      feature: WorkspaceFeature.kioskMode,
      tier: FeatureTier.platform,
    ),
  // RFID/NFC badges are kiosk credentials — no kiosk, no tap path.
  WorkspaceFeature.nfcBadges: FeatureManifestEntry(
    feature: WorkspaceFeature.nfcBadges,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.kioskMode,
  ),
  // The community directory tab (#224).
  WorkspaceFeature.membersDirectory:
      FeatureManifestEntry(
      feature: WorkspaceFeature.membersDirectory,
      tier: FeatureTier.core,
    ),
  // WhatsApp affordances (swipe-to-message, group tile, number
  // editing) ride the directory.
  WorkspaceFeature.whatsappIntegration: FeatureManifestEntry(
    feature: WorkspaceFeature.whatsappIntegration,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.membersDirectory,
  ),
  // Printable per-space QR cards + the scan-to-book flow (#335).
  WorkspaceFeature.spaceQrCodes:
      FeatureManifestEntry(
      feature: WorkspaceFeature.spaceQrCodes,
      tier: FeatureTier.core,
    ),
  // Co-ownership (0058): appoint active/passive co-owners with owner
  // permissions and automatic succession. The SERVER-side succession
  // safety net stays on regardless — this gates the appointment UI.
  WorkspaceFeature.coOwner:
      FeatureManifestEntry(
      feature: WorkspaceFeature.coOwner,
      tier: FeatureTier.platform,
    ),
  // End-of-day sweep (#396): reservations never checked in/out complete
  // themselves once their time has passed. Default OFF — it rewrites
  // attendance records, which is an explicit owner decision.
  WorkspaceFeature.autoCheckInOut: FeatureManifestEntry(
    feature: WorkspaceFeature.autoCheckInOut,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // Owner data export as an Excel workbook (#395). A read-only
  // convenience, so it follows the default-on rule.
  WorkspaceFeature.dataExport:
      FeatureManifestEntry(
      feature: WorkspaceFeature.dataExport,
      tier: FeatureTier.core,
    ),
  // Configurable working day + real-hours booking (#446). OFF hides the
  // settings section and the hours granularity option; the 8:00–17:00
  // defaults then apply unchanged.
  WorkspaceFeature.workingHours:
      FeatureManifestEntry(
      feature: WorkspaceFeature.workingHours,
      tier: FeatureTier.core,
    ),
  // Owner-written PDF intro/footer template (#454). PDF only — the
  // e-invoice XML never sees it.
  WorkspaceFeature.invoicePdfTemplate: FeatureManifestEntry(
    feature: WorkspaceFeature.invoicePdfTemplate,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #869 — place the recipient where a window envelope shows it, and
  // reserve the letterhead band above it, so a printed invoice can be
  // folded and posted without the address moving off the window.
  WorkspaceFeature.invoiceAddressWindow: FeatureManifestEntry(
    feature: WorkspaceFeature.invoiceAddressWindow,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // Member-to-member notes + admin broadcast (#456).
  WorkspaceFeature.memberNotifications:
      FeatureManifestEntry(
      feature: WorkspaceFeature.memberNotifications,
      tier: FeatureTier.core,
    ),
  // The workspace document library (#500): statutes, guides, financial
  // statements, minutes — federated links to any DMS, role-gated.
  WorkspaceFeature.documents:
      FeatureManifestEntry(
      feature: WorkspaceFeature.documents,
      tier: FeatureTier.core,
    ),
  // Mahnwesen (#472/#502): reminder rules + due suggestions. OFF keeps
  // the manual per-invoice reminder untouched.
  WorkspaceFeature.dunning: FeatureManifestEntry(
    feature: WorkspaceFeature.dunning,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // The member report suite (#494/#502): the financial agreement and
  // the monthly payments report, self-service and admin-sent.
  WorkspaceFeature.memberReports: FeatureManifestEntry(
    feature: WorkspaceFeature.memberReports,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.moneyTab,
  ),
  // Validated deletion requests for past/checked-in bookings
  // (#492/#502). OFF = such bookings simply cannot be deleted.
  WorkspaceFeature.deletionRequests:
      FeatureManifestEntry(
      feature: WorkspaceFeature.deletionRequests,
      tier: FeatureTier.core,
    ),
  // #513 — the centralized role→permission matrix. OFF hides the
  // Role management screen; the DEFAULT permissions still apply (the
  // matrix is then simply not editable in the app).
  WorkspaceFeature.roleManagement:
      FeatureManifestEntry(
      feature: WorkspaceFeature.roleManagement,
      tier: FeatureTier.core,
    ),
  // VAT management (#544): the rates editor and every per-item/tariff
  // rate picker. OFF hides the CONFIG surfaces only — a vat_registered
  // workspace keeps taxing at its stored/default rates (legal math is
  // never toggleable). Under invoicing, like the /vat screen always was.
  WorkspaceFeature.vatManagement: FeatureManifestEntry(
    feature: WorkspaceFeature.vatManagement,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // Periodic VAT declarations (#534/0107) — a child of VAT management;
  // the vat_registered regime gates it further at the screen (an exempt
  // workspace has nothing to declare).
  WorkspaceFeature.vatDeclarations: FeatureManifestEntry(
    feature: WorkspaceFeature.vatDeclarations,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.vatManagement,
  ),
  // Direct delivery to the CUSTOMER's e-invoicing service (#568) — the
  // second leg beside the government platform. Under invoicing: it only
  // ever shows on the send sheet of an issued invoice.
  WorkspaceFeature.einvoiceCustomerDelivery: FeatureManifestEntry(
    feature: WorkspaceFeature.einvoiceCustomerDelivery,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #587 — owners may delete plan objects that reservations reference;
  // the references survive as an audit substitution text. OFF keeps the
  // historic refusal (the server re-checks the flag in the RPC).
  WorkspaceFeature.planObjectDelete:
      FeatureManifestEntry(
      feature: WorkspaceFeature.planObjectDelete,
      tier: FeatureTier.core,
    ),
  // #598 — regroup the notification feed by type, day or member. A
  // child of the events feed: no feed, nothing to group.
  WorkspaceFeature.notificationGrouping: FeatureManifestEntry(
    feature: WorkspaceFeature.notificationGrouping,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.eventsTab,
  ),
  WorkspaceFeature.bookingPolicies:
      FeatureManifestEntry(
      feature: WorkspaceFeature.bookingPolicies,
      tier: FeatureTier.core,
    ),
  // #814 — the client-side mirror of the policies, on every surface.
  WorkspaceFeature.bookingGate: FeatureManifestEntry(
    feature: WorkspaceFeature.bookingGate,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.bookingPolicies,
  ),
  // #604 — the chair-tag functionality (#585): configuring a tag on a
  // seat and resolving a tapped tag to that seat.
  WorkspaceFeature.nfcSeatTags:
      FeatureManifestEntry(
      feature: WorkspaceFeature.nfcSeatTags,
      tier: FeatureTier.platform,
    ),
  // #604 — barcode/QR badge issuance, beside nfcBadges: both are badge
  // credentials the kiosk accepts, so both sit under kioskMode.
  WorkspaceFeature.qrBadges: FeatureManifestEntry(
    feature: WorkspaceFeature.qrBadges,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.kioskMode,
  ),
  // #616 — the kiosk receipt shows the member's profile photo.
  WorkspaceFeature.kioskMemberPhotos: FeatureManifestEntry(
    feature: WorkspaceFeature.kioskMemberPhotos,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.kioskMode,
  ),
  // #802 — the subscription is billed ahead of its month; what the month
  // actually cost is billed after it. Two documents, each switchable on
  // its own: an owner can bill subscriptions in advance and keep settling
  // the extras by hand, or the reverse.
  WorkspaceFeature.subscriptionInvoices: FeatureManifestEntry(
    feature: WorkspaceFeature.subscriptionInvoices,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  WorkspaceFeature.usageInvoices: FeatureManifestEntry(
    feature: WorkspaceFeature.usageInvoices,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #804 — regrouping several open invoices into one demand. Useful with
  // the two above and independent of them: a workspace that never split
  // its invoices can still consolidate a member's arrears.
  WorkspaceFeature.invoiceSettlement: FeatureManifestEntry(
    feature: WorkspaceFeature.invoiceSettlement,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #812 — the process view: journey bar, next move, stage strip.
  WorkspaceFeature.invoiceJourney: FeatureManifestEntry(
    feature: WorkspaceFeature.invoiceJourney,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #798 — swipe a message right to quote it, left to take it back
  // while it is still unread.
  WorkspaceFeature.messageGestures:
      FeatureManifestEntry(
      feature: WorkspaceFeature.messageGestures,
      tier: FeatureTier.core,
    ),
  // #793 — monograms that tell members apart wherever an avatar has no
  // photo to show.
  WorkspaceFeature.uniqueMonograms:
      FeatureManifestEntry(
      feature: WorkspaceFeature.uniqueMonograms,
      tier: FeatureTier.core,
    ),
  // #620 — occupant profile photos on the Plan tab and Reserve hub
  // maps, kiosk or not.
  WorkspaceFeature.planMemberPhotos:
      FeatureManifestEntry(
      feature: WorkspaceFeature.planMemberPhotos,
      tier: FeatureTier.platform,
    ),
  // #711 — a member's own numbers, dates, clock and zone. Default ON;
  // OFF makes every member read as the app always did (the UI
  // language's home region, 24-hour clock, workspace zone) and hides
  // the Settings section.
  WorkspaceFeature.regionalFormats:
      FeatureManifestEntry(
      feature: WorkspaceFeature.regionalFormats,
      tier: FeatureTier.core,
    ),
  // #718 — the calendar as the dated view of everything: one feed of
  // reservations, check-ins, alerts, messages, money and reminders for
  // a day or a range, each row linking to its source. OFF: the calendar
  // shows reservations only, as it did before.
  WorkspaceFeature.calendarHub:
      FeatureManifestEntry(
      feature: WorkspaceFeature.calendarHub,
      tier: FeatureTier.core,
    ),
  // #818 — the views over the hub's feed.
  WorkspaceFeature.calendarViews: FeatureManifestEntry(
    feature: WorkspaceFeature.calendarViews,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.calendarHub,
  ),
  // #821 — the reworked Messages tab.
  WorkspaceFeature.messagesHub:
      FeatureManifestEntry(
      feature: WorkspaceFeature.messagesHub,
      tier: FeatureTier.core,
    ),
  // #822 — the full-screen report designer over the template editor.
  WorkspaceFeature.reportDesigner: FeatureManifestEntry(
    feature: WorkspaceFeature.reportDesigner,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicePdfTemplate,
  ),
  // #825 — the member page over the directory's profile sheet.
  WorkspaceFeature.memberPage: FeatureManifestEntry(
    feature: WorkspaceFeature.memberPage,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.membersDirectory,
  ),
  // #827 — the guided month-close process over the invoicing hub.
  WorkspaceFeature.invoicingWizard: FeatureManifestEntry(
    feature: WorkspaceFeature.invoicingWizard,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #828 — a shared expense split over the members onto their next
  // usage invoice; the reverse as credit notes.
  WorkspaceFeature.expenseRepartition: FeatureManifestEntry(
    feature: WorkspaceFeature.expenseRepartition,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #831 — the fold of settled sources under their settlement.
  WorkspaceFeature.settlementFold: FeatureManifestEntry(
    feature: WorkspaceFeature.settlementFold,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoiceSettlement,
  ),
  // #916 — the exported space IS the space: the file's <configuration>
  // section and the plan attributes travel with the export and apply on
  // import. Child of the data export it extends.
  WorkspaceFeature.configurationTransfer: FeatureManifestEntry(
    feature: WorkspaceFeature.configurationTransfer,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.dataExport,
  ),
  // #969 — a per-device preference in Settings; off hides the choice
  // and every device keeps its platform's default.
  WorkspaceFeature.navigationStyle: FeatureManifestEntry(
    feature: WorkspaceFeature.navigationStyle,
    tier: FeatureTier.core,
  ),
  // #970 — demo mode; off hides the switch and nothing is invented.
  WorkspaceFeature.demoMode: FeatureManifestEntry(
    feature: WorkspaceFeature.demoMode,
    tier: FeatureTier.platform,
  ),
  // #977 — the instance wizard on the Server screen; off leaves the
  // manual how-to alone.
  WorkspaceFeature.instanceWizard: FeatureManifestEntry(
    feature: WorkspaceFeature.instanceWizard,
    tier: FeatureTier.platform,
  ),
  // #719 — "who accessed my data": the server-written log of reads of
  // another member's finances, shown to the subject. OFF hides the row;
  // the log is still written, because the record is not optional.
  WorkspaceFeature.dataAccessLog: FeatureManifestEntry(
    feature: WorkspaceFeature.dataAccessLog,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.moneyTab,
  ),
  // #719 — export my data (art. 20) and leave with erasure (art. 17)
  // from Settings → Privacy & data.
  WorkspaceFeature.memberDataExport:
      FeatureManifestEntry(
      feature: WorkspaceFeature.memberDataExport,
      tier: FeatureTier.core,
    ),
  // #720 — Finances as three faces (Payments · Consumption · Invoices)
  // under one period chooser. OFF keeps the single column.
  WorkspaceFeature.financeFaces: FeatureManifestEntry(
    feature: WorkspaceFeature.financeFaces,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.moneyTab,
  ),
  // #726 — automatic payment reminders: the dunning levels applied by a
  // daily sweep (or by an admin opening Finances), each one an event in
  // the member's feed and a push. Child of dunning.
  WorkspaceFeature.paymentReminders: FeatureManifestEntry(
    feature: WorkspaceFeature.paymentReminders,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.dunning,
  ),
  // #731 — an expense can be a SUPPLY: validated, it restocks (or
  // creates) a consumable service with a unit price and a stock count.
  WorkspaceFeature.supplyExpenses: FeatureManifestEntry(
    feature: WorkspaceFeature.supplyExpenses,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.services,
  ),
  // #732 — a validation rule names its scope: admins, listed persons of
  // any role, or every member. Off: owner + admins as before.
  WorkspaceFeature.validationScopes:
      FeatureManifestEntry(
      feature: WorkspaceFeature.validationScopes,
      tier: FeatureTier.platform,
    ),
  // #840 — a rule may ask for its validations one after another, and may
  // let the owner (never an admin) sign off on their own act.
  WorkspaceFeature.validationChain:
      FeatureManifestEntry(
      feature: WorkspaceFeature.validationChain,
      tier: FeatureTier.platform,
    ),
  // #842 — a message can point at an alert, at the validation behind
  // one, and at the financial documents people argue about.
  WorkspaceFeature.richMessageRefs: FeatureManifestEntry(
    feature: WorkspaceFeature.richMessageRefs,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.memberNotifications,
  ),
  // #843 — decisions on the timeline, at the moment they were taken.
  WorkspaceFeature.calendarValidations: FeatureManifestEntry(
    feature: WorkspaceFeature.calendarValidations,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.calendarHub,
  ),
  // #833 — every counted booking leaves a record, and an early
  // departure can be corrected through the validation rules.
  WorkspaceFeature.usageRecords: FeatureManifestEntry(
    feature: WorkspaceFeature.usageRecords,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #864 — a report design leaves as a self-describing file and comes
  // back the same way, so it can be edited outside the app.
  WorkspaceFeature.reportDesignExchange: FeatureManifestEntry(
    feature: WorkspaceFeature.reportDesignExchange,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.reportDesigner,
  ),
  // #875 — positioned layouts: a design states its geometry, the PDF
  // prints it; a document with a layout is drawn by it, the rest unchanged.
  WorkspaceFeature.reportLayouts: FeatureManifestEntry(
    feature: WorkspaceFeature.reportLayouts,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.reportDesigner,
  ),
  // #886 — the person's structured identity (name, postal address,
  // phone, e-mail, ids) on their settings, printed by every document.
  WorkspaceFeature.personalInfo:
      FeatureManifestEntry(
      feature: WorkspaceFeature.personalInfo,
      tier: FeatureTier.core,
    ),
  // #887 — members an admin runs until the person claims them with a
  // bound invitation; they live on the members list.
  WorkspaceFeature.managedProfiles: FeatureManifestEntry(
    feature: WorkspaceFeature.managedProfiles,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.membersDirectory,
  ),
  // #914 — narrowing WHO may administer one managed profile. Off, every
  // owner and admin may, which is what #887 shipped; the identity is
  // protected either way (#915), because a protection you can switch
  // off protects nobody.
  // #925 — the owner sets how each journal numbers its documents. The
  // NUMBERS are drawn in the database whether this is on or off; the
  // flag only shows the settings screen, because a series nobody has
  // reason to change is not a control everybody needs to see.
  WorkspaceFeature.numberSequences: FeatureManifestEntry(
    feature: WorkspaceFeature.numberSequences,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.invoicing,
  ),
  // #934 — the treasurer's view: what the workspace invoiced, collected,
  // reimbursed and shared out over a range of months, on screen and as
  // a printable report.
  WorkspaceFeature.workspaceStatus: FeatureManifestEntry(
    feature: WorkspaceFeature.workspaceStatus,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.invoicing,
  ),
  // #934 — the guided repartition: a shared cost proposed over the
  // members by subscription share, adjustable, remembered as the rule.
  WorkspaceFeature.expenseRepartitionWizard: FeatureManifestEntry(
    feature: WorkspaceFeature.expenseRepartitionWizard,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.expenseRepartition,
  ),
  // #945 — sites: levels grouped by address, a member's home site, the
  // document naming the site it concerns (#946). Off, the workspace has
  // its one address as before.
  WorkspaceFeature.multiSite: FeatureManifestEntry(
    feature: WorkspaceFeature.multiSite,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #946 — documents name the site they concern: the member's home
  // site's address and registration on the seller side, the other
  // sites the month stood at in the details.
  WorkspaceFeature.siteDocuments: FeatureManifestEntry(
    feature: WorkspaceFeature.siteDocuments,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.multiSite,
  ),
  // #947 — each rate carries its fiscal group: the law's category, the
  // outside-base rule, the exemption reason. Off: bare percentages.
  WorkspaceFeature.vatGroups: FeatureManifestEntry(
    feature: WorkspaceFeature.vatGroups,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.vatManagement,
  ),
  // #985 — a rate is a family of dated versions: a change by law is a
  // new value from a date, never an edit. Off: one value per rate.
  WorkspaceFeature.vatRateHistory: FeatureManifestEntry(
    feature: WorkspaceFeature.vatRateHistory,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.vatManagement,
  ),
  // #985 — who the buyer is for VAT, set per member: domestic, reverse
  // charge, outside the EU, exempt. Off: the automatic rule only.
  WorkspaceFeature.vatCounterparty: FeatureManifestEntry(
    feature: WorkspaceFeature.vatCounterparty,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.vatManagement,
  ),
  // #987 — a workspace and its twin as one couple: the paired card in
  // Profiles and the twin action. Off: two unrelated entries.
  WorkspaceFeature.environmentPairs: FeatureManifestEntry(
    feature: WorkspaceFeature.environmentPairs,
    tier: FeatureTier.platform,
    defaultOn: true,
  ),
  // #988/#990 — entities deployed between the two sides of a pair, with
  // a preview and a journal. Off: the twins stay separate hands.
  WorkspaceFeature.deployments: FeatureManifestEntry(
    feature: WorkspaceFeature.deployments,
    tier: FeatureTier.platform,
    defaultOn: true,
    requires: WorkspaceFeature.environmentPairs,
  ),
  WorkspaceFeature.managedProfileAccess: FeatureManifestEntry(
    feature: WorkspaceFeature.managedProfileAccess,
    tier: FeatureTier.platform,
    // OFF by default: the rule nobody narrowed is exactly what #887
    // shipped, so a space that never needs to restrict anything is not
    // shown a control it would have to think about. Turning it on is
    // what says "several admins here, and not all of them for this".
    defaultOn: false,
    requires: WorkspaceFeature.managedProfiles,
  ),
  // #903 — a part-booked seat looks part-booked, and a shared one opens
  // its day: who has it, when, what is still free.
  WorkspaceFeature.seatDayTimeline:
      FeatureManifestEntry(
      feature: WorkspaceFeature.seatDayTimeline,
      tier: FeatureTier.core,
    ),
  // #881 — a member's own payment conditions, changed by validated request.
  WorkspaceFeature.memberPaymentTerms: FeatureManifestEntry(
    feature: WorkspaceFeature.memberPaymentTerms,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #873 — the month-end consumption report, from the usage records.
  WorkspaceFeature.usageReport: FeatureManifestEntry(
    feature: WorkspaceFeature.usageReport,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.usageRecords,
  ),
  // #880 — the owner's own texts, `{{ text.<key> }}`, per language.
  WorkspaceFeature.reportTexts: FeatureManifestEntry(
    feature: WorkspaceFeature.reportTexts,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.reportDesigner,
  ),
  // #874 — every person-facing document folds into a window envelope:
  // a kind without a design renders its default positioned layout.
  WorkspaceFeature.letterStandard: FeatureManifestEntry(
    feature: WorkspaceFeature.letterStandard,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.reportLayouts,
  ),
  // #878 — the period's VAT positions as a letter and a CSV.
  WorkspaceFeature.vatReport: FeatureManifestEntry(
    feature: WorkspaceFeature.vatReport,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.vatDeclarations,
  ),
  // #739 — the tariff is the default; a member may have their own deal,
  // proposed by finance admins, validated, seen by the member and them.
  WorkspaceFeature.priceNegotiations: FeatureManifestEntry(
    feature: WorkspaceFeature.priceNegotiations,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.moneyTab,
  ),
  // #767 — subscriptions the space pays for keep paying themselves:
  // schedule once, validate once, confirm each occurrence.
  WorkspaceFeature.scheduledExpenses: FeatureManifestEntry(
    feature: WorkspaceFeature.scheduledExpenses,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.moneyTab,
  ),
  // #662 — signing IN by scanning a badge, then a PIN. Under nfcBadges
  // rather than kioskMode: it needs badges to EXIST, and turning badge
  // issuance off must take the login button with it, or the button
  // offers a credential nobody can hold. Default OFF — a workspace opts
  // in to its shared tablet being a login surface.
  WorkspaceFeature.badgeSignIn: FeatureManifestEntry(
    feature: WorkspaceFeature.badgeSignIn,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.nfcBadges,
    defaultOn: false,
  ),
  // #606 — dismissible contextual help hints on forms and screens, each
  // deep-linking into the matching guide section. Default ON: they are
  // exactly for the members who have not found their way around yet.
  WorkspaceFeature.formHelpHints:
      FeatureManifestEntry(
      feature: WorkspaceFeature.formHelpHints,
      tier: FeatureTier.core,
    ),
  // #611 — the motion pass: purposeful animations (route transitions,
  // view cross-fades, state-colour changes, feedback moments). Default
  // ON; OFF returns the whole app to instant transitions. Reduced
  // motion (the OS accessibility setting) overrides regardless.
  WorkspaceFeature.uiAnimations:
      FeatureManifestEntry(
      feature: WorkspaceFeature.uiAnimations,
      tier: FeatureTier.core,
    ),
  // #1110 — how each member got here, on their own profile and on the
  // member sheet for anyone who manages members. Default OFF: it is new
  // information about real people, and a workspace should decide to show
  // it rather than find it already there.
  WorkspaceFeature.memberOrigin: FeatureManifestEntry(
    feature: WorkspaceFeature.memberOrigin,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.membersDirectory,
  ),
  // #1119 — the environment choice on an invitation. Under
  // environmentPairs, because a workspace with no twin has nothing to
  // choose between, and OFF by default like every other opt-in that
  // adds a question to a form somebody already knows.
  WorkspaceFeature.memberEnvironments: FeatureManifestEntry(
    feature: WorkspaceFeature.memberEnvironments,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.environmentPairs,
  ),
  // #1120 — sharing a floor plan is asked for, never assumed.
  WorkspaceFeature.workspaceLibrary: FeatureManifestEntry(
    feature: WorkspaceFeature.workspaceLibrary,
    tier: FeatureTier.platform,
    defaultOn: false,
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

/// Everything [feature] NEEDS in order to work, nearest parent first
/// (#800).
///
/// The registry has always expressed the hierarchy downwards — a child
/// is ineffective while its parent is off. Read upwards it answers the
/// question an owner actually asks at the switch: "what does this one
/// need?"
List<WorkspaceFeature> requirementChain(WorkspaceFeature feature) {
  final chain = <WorkspaceFeature>[];
  var current = featureManifest[feature]?.requires;
  // The registry is authored by hand; a cycle would hang the UI rather
  // than fail a test, so the visited set makes that impossible.
  final seen = <WorkspaceFeature>{feature};
  while (current != null && seen.add(current)) {
    chain.add(current);
    current = featureManifest[current]?.requires;
  }
  return chain;
}

/// Everything that would stop working if [feature] were switched off —
/// its whole subtree, not just its direct children.
List<WorkspaceFeature> dependentFeatures(WorkspaceFeature feature) => [
      for (final candidate in featureManifest.keys)
        if (candidate != feature && requirementChain(candidate).contains(feature))
          candidate,
    ];

/// The flag map to write when the owner flips [feature] to [value]
/// (#800), given the currently stored set [raw].
///
/// Turning a feature ON turns its whole requirement chain on with it.
/// Before this, a switch could be flipped on and simply not work,
/// because something above it was off — the owner saw a green switch and
/// a feature that was not there.
///
/// Turning one OFF leaves its dependants stored exactly as configured.
/// They are already ineffective ([effectiveFeatures] drops them), and
/// erasing the choices would mean the owner has to rebuild the subtree
/// by hand after switching the parent back on.
Map<WorkspaceFeature, bool> featureFlagsAfterToggle({
  required Set<WorkspaceFeature> raw,
  required WorkspaceFeature feature,
  required bool value,
}) {
  final next = {
    for (final known in featureManifest.keys) known: raw.contains(known),
  };
  next[feature] = value;
  if (value) {
    for (final required in requirementChain(feature)) {
      next[required] = true;
    }
  }
  return next;
}

/// What ONE toggle writes (#963): the feature itself and, when it goes
/// on, everything it needs — nothing else. The row is merged on the
/// server, so a screen holding an older copy of the row cannot undo a
/// switch someone (or itself, a moment ago) flipped in between.
Map<WorkspaceFeature, bool> featureFlagsToggleDelta({
  required WorkspaceFeature feature,
  required bool value,
}) => {
      feature: value,
      if (value)
        for (final required in requirementChain(feature)) required: true,
    };

/// The features [featureFlagsAfterToggle] would switch on ALONGSIDE
/// [feature] — empty when its chain is already on. The UI names them, so
/// enabling one thing never silently changes another.
List<WorkspaceFeature> alsoEnabledWith({
  required Set<WorkspaceFeature> raw,
  required WorkspaceFeature feature,
}) =>
    [
      for (final required in requirementChain(feature))
        if (!raw.contains(required)) required,
    ];

/// #1063 — the flags a NEW workspace is created with.
///
/// EXPLICIT, every key, rather than an empty object left to resolve
/// against the registry defaults. That is the whole design: resolution
/// is unchanged, so a workspace that already exists keeps exactly what
/// it has, and the tier decides only what gets written the first time.
/// An implicit rule would have reached backwards into every live
/// workspace the moment it changed.
///
/// A platform feature is written `false` rather than omitted, so that
/// "nobody has chosen yet" and "chosen off" stay distinguishable, and so
/// that a later change to a registry default cannot quietly switch
/// something on in a space that never asked for it.
Map<String, bool> defaultFeatureFlagsForNewWorkspace() => {
      for (final entry in featureManifest.values)
        entry.feature.dbKey: entry.tier == FeatureTier.core && entry.defaultOn,
    };

/// The features of one tier, in registry order — the Features screen
/// renders them under their own heading.
List<WorkspaceFeature> featuresOfTier(FeatureTier tier) => [
      for (final entry in featureManifest.values)
        if (entry.tier == tier) entry.feature,
    ];
