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
  memberPaymentTerms,
  reportTexts,
  usageReport,
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
  settlementFold;

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
  // #869 — place the recipient where a window envelope shows it, and
  // reserve the letterhead band above it, so a printed invoice can be
  // folded and posted without the address moving off the window.
  WorkspaceFeature.invoiceAddressWindow: FeatureManifestEntry(
    feature: WorkspaceFeature.invoiceAddressWindow,
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
  WorkspaceFeature.memberReports: FeatureManifestEntry(
    feature: WorkspaceFeature.memberReports,
    requires: WorkspaceFeature.moneyTab,
  ),
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
  // Direct delivery to the CUSTOMER's e-invoicing service (#568) — the
  // second leg beside the government platform. Under invoicing: it only
  // ever shows on the send sheet of an issued invoice.
  WorkspaceFeature.einvoiceCustomerDelivery: FeatureManifestEntry(
    feature: WorkspaceFeature.einvoiceCustomerDelivery,
    requires: WorkspaceFeature.invoicing,
  ),
  // #587 — owners may delete plan objects that reservations reference;
  // the references survive as an audit substitution text. OFF keeps the
  // historic refusal (the server re-checks the flag in the RPC).
  WorkspaceFeature.planObjectDelete:
      FeatureManifestEntry(feature: WorkspaceFeature.planObjectDelete),
  // #598 — regroup the notification feed by type, day or member. A
  // child of the events feed: no feed, nothing to group.
  WorkspaceFeature.notificationGrouping: FeatureManifestEntry(
    feature: WorkspaceFeature.notificationGrouping,
    requires: WorkspaceFeature.eventsTab,
  ),
  WorkspaceFeature.bookingPolicies:
      FeatureManifestEntry(feature: WorkspaceFeature.bookingPolicies),
  // #814 — the client-side mirror of the policies, on every surface.
  WorkspaceFeature.bookingGate: FeatureManifestEntry(
    feature: WorkspaceFeature.bookingGate,
    requires: WorkspaceFeature.bookingPolicies,
  ),
  // #604 — the chair-tag functionality (#585): configuring a tag on a
  // seat and resolving a tapped tag to that seat.
  WorkspaceFeature.nfcSeatTags:
      FeatureManifestEntry(feature: WorkspaceFeature.nfcSeatTags),
  // #604 — barcode/QR badge issuance, beside nfcBadges: both are badge
  // credentials the kiosk accepts, so both sit under kioskMode.
  WorkspaceFeature.qrBadges: FeatureManifestEntry(
    feature: WorkspaceFeature.qrBadges,
    requires: WorkspaceFeature.kioskMode,
  ),
  // #616 — the kiosk receipt shows the member's profile photo.
  WorkspaceFeature.kioskMemberPhotos: FeatureManifestEntry(
    feature: WorkspaceFeature.kioskMemberPhotos,
    requires: WorkspaceFeature.kioskMode,
  ),
  // #802 — the subscription is billed ahead of its month; what the month
  // actually cost is billed after it. Two documents, each switchable on
  // its own: an owner can bill subscriptions in advance and keep settling
  // the extras by hand, or the reverse.
  WorkspaceFeature.subscriptionInvoices: FeatureManifestEntry(
    feature: WorkspaceFeature.subscriptionInvoices,
    requires: WorkspaceFeature.invoicing,
  ),
  WorkspaceFeature.usageInvoices: FeatureManifestEntry(
    feature: WorkspaceFeature.usageInvoices,
    requires: WorkspaceFeature.invoicing,
  ),
  // #804 — regrouping several open invoices into one demand. Useful with
  // the two above and independent of them: a workspace that never split
  // its invoices can still consolidate a member's arrears.
  WorkspaceFeature.invoiceSettlement: FeatureManifestEntry(
    feature: WorkspaceFeature.invoiceSettlement,
    requires: WorkspaceFeature.invoicing,
  ),
  // #812 — the process view: journey bar, next move, stage strip.
  WorkspaceFeature.invoiceJourney: FeatureManifestEntry(
    feature: WorkspaceFeature.invoiceJourney,
    requires: WorkspaceFeature.invoicing,
  ),
  // #798 — swipe a message right to quote it, left to take it back
  // while it is still unread.
  WorkspaceFeature.messageGestures:
      FeatureManifestEntry(feature: WorkspaceFeature.messageGestures),
  // #793 — monograms that tell members apart wherever an avatar has no
  // photo to show.
  WorkspaceFeature.uniqueMonograms:
      FeatureManifestEntry(feature: WorkspaceFeature.uniqueMonograms),
  // #620 — occupant profile photos on the Plan tab and Reserve hub
  // maps, kiosk or not.
  WorkspaceFeature.planMemberPhotos:
      FeatureManifestEntry(feature: WorkspaceFeature.planMemberPhotos),
  // #711 — a member's own numbers, dates, clock and zone. Default ON;
  // OFF makes every member read as the app always did (the UI
  // language's home region, 24-hour clock, workspace zone) and hides
  // the Settings section.
  WorkspaceFeature.regionalFormats:
      FeatureManifestEntry(feature: WorkspaceFeature.regionalFormats),
  // #718 — the calendar as the dated view of everything: one feed of
  // reservations, check-ins, alerts, messages, money and reminders for
  // a day or a range, each row linking to its source. OFF: the calendar
  // shows reservations only, as it did before.
  WorkspaceFeature.calendarHub:
      FeatureManifestEntry(feature: WorkspaceFeature.calendarHub),
  // #818 — the views over the hub's feed.
  WorkspaceFeature.calendarViews: FeatureManifestEntry(
    feature: WorkspaceFeature.calendarViews,
    requires: WorkspaceFeature.calendarHub,
  ),
  // #821 — the reworked Messages tab.
  WorkspaceFeature.messagesHub:
      FeatureManifestEntry(feature: WorkspaceFeature.messagesHub),
  // #822 — the full-screen report designer over the template editor.
  WorkspaceFeature.reportDesigner: FeatureManifestEntry(
    feature: WorkspaceFeature.reportDesigner,
    requires: WorkspaceFeature.invoicePdfTemplate,
  ),
  // #825 — the member page over the directory's profile sheet.
  WorkspaceFeature.memberPage: FeatureManifestEntry(
    feature: WorkspaceFeature.memberPage,
    requires: WorkspaceFeature.membersDirectory,
  ),
  // #827 — the guided month-close process over the invoicing hub.
  WorkspaceFeature.invoicingWizard: FeatureManifestEntry(
    feature: WorkspaceFeature.invoicingWizard,
    requires: WorkspaceFeature.invoicing,
  ),
  // #828 — a shared expense split over the members onto their next
  // usage invoice; the reverse as credit notes.
  WorkspaceFeature.expenseRepartition: FeatureManifestEntry(
    feature: WorkspaceFeature.expenseRepartition,
    requires: WorkspaceFeature.invoicing,
  ),
  // #831 — the fold of settled sources under their settlement.
  WorkspaceFeature.settlementFold: FeatureManifestEntry(
    feature: WorkspaceFeature.settlementFold,
    requires: WorkspaceFeature.invoiceSettlement,
  ),
  // #719 — "who accessed my data": the server-written log of reads of
  // another member's finances, shown to the subject. OFF hides the row;
  // the log is still written, because the record is not optional.
  WorkspaceFeature.dataAccessLog: FeatureManifestEntry(
    feature: WorkspaceFeature.dataAccessLog,
    requires: WorkspaceFeature.moneyTab,
  ),
  // #719 — export my data (art. 20) and leave with erasure (art. 17)
  // from Settings → Privacy & data.
  WorkspaceFeature.memberDataExport:
      FeatureManifestEntry(feature: WorkspaceFeature.memberDataExport),
  // #720 — Finances as three faces (Payments · Consumption · Invoices)
  // under one period chooser. OFF keeps the single column.
  WorkspaceFeature.financeFaces: FeatureManifestEntry(
    feature: WorkspaceFeature.financeFaces,
    requires: WorkspaceFeature.moneyTab,
  ),
  // #726 — automatic payment reminders: the dunning levels applied by a
  // daily sweep (or by an admin opening Finances), each one an event in
  // the member's feed and a push. Child of dunning.
  WorkspaceFeature.paymentReminders: FeatureManifestEntry(
    feature: WorkspaceFeature.paymentReminders,
    requires: WorkspaceFeature.dunning,
  ),
  // #731 — an expense can be a SUPPLY: validated, it restocks (or
  // creates) a consumable service with a unit price and a stock count.
  WorkspaceFeature.supplyExpenses: FeatureManifestEntry(
    feature: WorkspaceFeature.supplyExpenses,
    requires: WorkspaceFeature.services,
  ),
  // #732 — a validation rule names its scope: admins, listed persons of
  // any role, or every member. Off: owner + admins as before.
  WorkspaceFeature.validationScopes:
      FeatureManifestEntry(feature: WorkspaceFeature.validationScopes),
  // #840 — a rule may ask for its validations one after another, and may
  // let the owner (never an admin) sign off on their own act.
  WorkspaceFeature.validationChain:
      FeatureManifestEntry(feature: WorkspaceFeature.validationChain),
  // #842 — a message can point at an alert, at the validation behind
  // one, and at the financial documents people argue about.
  WorkspaceFeature.richMessageRefs: FeatureManifestEntry(
    feature: WorkspaceFeature.richMessageRefs,
    requires: WorkspaceFeature.memberNotifications,
  ),
  // #843 — decisions on the timeline, at the moment they were taken.
  WorkspaceFeature.calendarValidations: FeatureManifestEntry(
    feature: WorkspaceFeature.calendarValidations,
    requires: WorkspaceFeature.calendarHub,
  ),
  // #833 — every counted booking leaves a record, and an early
  // departure can be corrected through the validation rules.
  WorkspaceFeature.usageRecords: FeatureManifestEntry(
    feature: WorkspaceFeature.usageRecords,
    requires: WorkspaceFeature.invoicing,
  ),
  // #864 — a report design leaves as a self-describing file and comes
  // back the same way, so it can be edited outside the app.
  WorkspaceFeature.reportDesignExchange: FeatureManifestEntry(
    feature: WorkspaceFeature.reportDesignExchange,
    requires: WorkspaceFeature.reportDesigner,
  ),
  // #875 — positioned layouts: a design states its geometry, the PDF
  // prints it; a document with a layout is drawn by it, the rest unchanged.
  WorkspaceFeature.reportLayouts: FeatureManifestEntry(
    feature: WorkspaceFeature.reportLayouts,
    requires: WorkspaceFeature.reportDesigner,
  ),
  // #886 — the person's structured identity (name, postal address,
  // phone, e-mail, ids) on their settings, printed by every document.
  WorkspaceFeature.personalInfo:
      FeatureManifestEntry(feature: WorkspaceFeature.personalInfo),
  // #887 — members an admin runs until the person claims them with a
  // bound invitation; they live on the members list.
  WorkspaceFeature.managedProfiles: FeatureManifestEntry(
    feature: WorkspaceFeature.managedProfiles,
    requires: WorkspaceFeature.membersDirectory,
  ),
  // #881 — a member's own payment conditions, changed by validated request.
  WorkspaceFeature.memberPaymentTerms: FeatureManifestEntry(
    feature: WorkspaceFeature.memberPaymentTerms,
    requires: WorkspaceFeature.invoicing,
  // #873 — the month-end consumption report, from the usage records.
  WorkspaceFeature.usageReport: FeatureManifestEntry(
    feature: WorkspaceFeature.usageReport,
    requires: WorkspaceFeature.usageRecords,
  ),
  // #880 — the owner's own texts, `{{ text.<key> }}`, per language.
  WorkspaceFeature.reportTexts: FeatureManifestEntry(
    feature: WorkspaceFeature.reportTexts,
    requires: WorkspaceFeature.reportDesigner,
  ),
  // #739 — the tariff is the default; a member may have their own deal,
  // proposed by finance admins, validated, seen by the member and them.
  WorkspaceFeature.priceNegotiations: FeatureManifestEntry(
    feature: WorkspaceFeature.priceNegotiations,
    requires: WorkspaceFeature.moneyTab,
  ),
  // #767 — subscriptions the space pays for keep paying themselves:
  // schedule once, validate once, confirm each occurrence.
  WorkspaceFeature.scheduledExpenses: FeatureManifestEntry(
    feature: WorkspaceFeature.scheduledExpenses,
    requires: WorkspaceFeature.moneyTab,
  ),
  // #662 — signing IN by scanning a badge, then a PIN. Under nfcBadges
  // rather than kioskMode: it needs badges to EXIST, and turning badge
  // issuance off must take the login button with it, or the button
  // offers a credential nobody can hold. Default OFF — a workspace opts
  // in to its shared tablet being a login surface.
  WorkspaceFeature.badgeSignIn: FeatureManifestEntry(
    feature: WorkspaceFeature.badgeSignIn,
    requires: WorkspaceFeature.nfcBadges,
    defaultOn: false,
  ),
  // #606 — dismissible contextual help hints on forms and screens, each
  // deep-linking into the matching guide section. Default ON: they are
  // exactly for the members who have not found their way around yet.
  WorkspaceFeature.formHelpHints:
      FeatureManifestEntry(feature: WorkspaceFeature.formHelpHints),
  // #611 — the motion pass: purposeful animations (route transitions,
  // view cross-fades, state-colour changes, feedback moments). Default
  // ON; OFF returns the whole app to instant transitions. Reduced
  // motion (the OS accessibility setting) overrides regardless.
  WorkspaceFeature.uiAnimations:
      FeatureManifestEntry(feature: WorkspaceFeature.uiAnimations),
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
