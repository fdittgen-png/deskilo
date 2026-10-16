// SPDX-License-Identifier: AGPL-3.0-or-later

part 'feature_manifest_part1.dart';
part 'feature_manifest_part2.dart';
part 'feature_manifest_part3.dart';

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

  /// #1372 — the demonstration workspace: an invented space anyone can
  /// open from the sign-in screen, with its own people, bookings and
  /// bills, and no account. Off, the offer does not appear.
  ///
  /// It used to mean the blur of #970, which anonymised a LIVE workspace
  /// for a recording. That was retired in #1380: the recording problem
  /// is #1514's and has nothing to do with a space full of invented
  /// people.
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
  workspaceLibrary,

  /// #1273 — a level holding exactly one room is named by the level on the
  /// member surfaces: "2e étage · Table 3", not "Bureau 1 · Table 3". A
  /// second room brings both names back; the editor always shows rooms.
  singleRoomLevelNames,
  publicHolidays,
  workspaceVocabulary,

  /// #1279 — carnets: prepaid half-days a workspace sells, spent across
  /// months when a member books beyond their subscription, charged once.
  carnets,

  /// #1289 — workspace branding: a brand seed colour the app's light,
  /// dark and warm themes derive from, an office fill palette and a
  /// curated seat palette, carried by a template. Off, the app is
  /// pixel-identical to the product's own palette.
  workspaceBranding,

  /// #1287 — roles a workspace defines itself, each an ADDITIVE set of
  /// permissions on top of a member's base role (ADR 0029). Off, the
  /// four built-in roles are all there are, which is what every space
  /// had before.
  customRoles,

  /// #1288 — questions a workspace asks its members beyond the identity
  /// form's own fields: a committee role, a joining date, an emergency
  /// contact. The definitions travel with a template; the answers are
  /// keyed to the MEMBERSHIP, so one space's question never follows
  /// somebody into another. Off, the identity form is what it was.
  customFields,

  /// #1247 — one place that answers *does anything need me?*, ranked by
  /// what the delay costs. Platform and default OFF: a space with two
  /// members and no invoicing does not want a decision surface.
  decisionSurface,

  /// #1514 — filming the app without filming the members: while it is
  /// on, every name, e-mail, telephone number, address and photograph
  /// belongs to an invented person, so a screenshot or a screen
  /// recording of THIS workspace — its real plan, its real bookings,
  /// its real figures — carries no personal data. Platform, default
  /// OFF: it is switched on for the length of a shoot and off after.
  recordingPrivacy,

  /// #1598 — a member who administers nothing meets no Réglages. The
  /// gear becomes **My account**: the same screen, which already shows
  /// a member only their own account, membership and preferences,
  /// under the name that says so. Platform, default OFF: a space that
  /// never asked keeps the gear it has always had.
  memberAccountMenu,

  /// #1607 — the MCP interface is AVAILABLE to this workspace: an AI
  /// assistant may be connected to DesKilo through it. Availability,
  /// never authorization — switching it on enrols nobody, approves no
  /// request, grants no role and registers no client. Each person
  /// still needs an owner-configured grant approved by the instance
  /// administrator, and every call keeps answering to the permissions
  /// the app already applies. Platform, default OFF: no workspace is
  /// reachable by a machine it never asked to be reachable by.
  mcpAccess,

  /// #1643 — a member saves ONE of their own bookings as an RFC 5545
  /// calendar file for the calendar they already keep. A snapshot of
  /// the instant, the resource and the venue — no amount, no name, no
  /// note, no link — under a UID that identifies the booking without
  /// naming it. Nothing is written to any calendar and nothing syncs:
  /// a retime after the save does not follow the file. Core, default
  /// ON: an interoperability courtesy every space can extend.
  calendarFileExport,

  /// #1654 — the Get started card on the Reserve hub: after a join or a
  /// creation, one compact, dismissible card names the workspace the
  /// person is in and suggests ONE permitted next action — choose a time
  /// to book, read their own membership, or open the help — where the
  /// features, the permissions and the loaded data support it. It reads
  /// what the hub already loaded, writes nothing but its own dismissal,
  /// and never submits a booking. Core, default ON: optional help a
  /// space can hide; OFF hides the card and nothing else.
  memberGettingStarted,

  /// #2185 — favourites and 0-5 star ratings on every bookable place
  /// (seat, desk, office, level): a member's own marks, an average the
  /// others see, and the same two through an assistant. Reserve, Core,
  /// default ON, requiring nothing; OFF hides the hearts and the stars and
  /// refuses the writes, and nothing else follows it.
  placeFeedback,

  /// Explicitly published public workspace page; never private occupancy.
  publicListings,

  /// #1824 — "Write to the hosts" on a published space page: a signed-in
  /// person outside the space starts an inquiry that only they and the
  /// space's hosts (owners, plus administrators who opted in as public
  /// contacts) can read. Core, default ON: it acts only where a page is
  /// published ([publicListings]), and the server refuses an inquiry
  /// without one; OFF removes the button and the Inquiries view, and
  /// stored inquiries stay untouched.
  spaceInquiries,

  /// #1824 — forwarding a message into another conversation the
  /// forwarder takes part in. The copy names its origin, the original
  /// conversation is told who forwarded it where, and an author can lock
  /// a message against it. Core, default ON: OFF refuses forwards OUT of
  /// this space; account messages always allow it.
  messageForwarding,

  /// #1824 — the messenger's screens refuse screen capture where the
  /// platform allows it (Android, macOS, Windows), hide content while the
  /// screen is recorded and announce screenshots (iOS), and blur plus
  /// watermark on the web. Core, default ON: confidentiality is the
  /// default, a space may choose otherwise; account messages are always
  /// protected.
  captureProtection,

  /// #2051 — an owner imports the official public holidays of the
  /// workspace's country, and of one region where they differ, from an
  /// open-data source, deselects the days the space stays open, and
  /// imports the rest as closure days. Platform, default OFF, under
  /// publicHolidays: the SQL generator stays the offline fallback.
  holidayImport,

  /// #1918 — seat utilisation on the Availability screen: reserved over
  /// offered seat-hours for a month, computed by the server under the
  /// one KPI contract, with its definition, numerator, denominator and
  /// data quality on demand. Platform, default OFF.
  capacityKpi,

  /// #1869 — the accounting owner of a legal entity: a book profile per
  /// issuer (functional currency, fiscal year, accounting basis) and ONE
  /// authority mode — pre-accounting, a local book, or an external
  /// authoritative system. Platform, default OFF, under invoicing:
  /// member balances and invoices work without it.
  accountingBook,

  /// #2085 — where a role is given and what it gives: a Roles section on
  /// each member's page (the Administrator role through the validation
  /// quorum, the workspace's own roles at once), the members holding each
  /// role in its editor, and "What you can do here" for every member.
  /// Under roleManagement; Core, default ON.
  roleAssignment,

  /// #1865 — "Record this task": a person records, on this device and
  /// for themselves, the semantic steps of a task on the workspace's
  /// screens, reviews them and exports a minimized file. Nothing is
  /// uploaded. Gates recording on workspace screens only; the local
  /// workbench and its outputs are not workspace features. Platform,
  /// default OFF.
  taskRecorder,

  /// #1835 — guest participation: a person who is NOT a member asks to
  /// visit this space and a host admits them, as a relationship of its
  /// own — no membership, subscription, role or assistant eligibility is
  /// created by it. Gates asking and admitting on this workspace; a
  /// person's own visits are theirs to read whatever the flag says. Core,
  /// default OFF: a space admits guests deliberately.
  guestParticipation,

  /// #2216 — mentions in group conversations: picking someone puts a
  /// mention of that person in the message, the server accepts only
  /// people who are in the conversation, and the person mentioned is
  /// notified even when they muted it. Core, default ON, under
  /// memberNotifications; OFF writes a plain `@Name` that notifies nobody.
  messageMentions,

  /// #2354 — the place of supply per catalogue service: property-connected
  /// (the default: taxed where the building stands) or a general service
  /// (mail handling, a virtual office) that a business elsewhere
  /// self-assesses. Platform, default ON, under vatManagement; OFF hides
  /// the choice and every new charge is property-connected.
  supplyClassification,

  /// #2354 — a customer's VAT number checked against VIES, the consultation
  /// number kept as evidence: a general service reverse-charged to a
  /// business abroad is issued only once its number was found valid.
  /// Platform, default ON, under supplyClassification; OFF keeps those
  /// invoices outside the app.
  viesVerification,

  /// #2354 — the recapitulative statement (EU sales list: DES, ZM, 349):
  /// reverse-charged services per customer VAT number and month as a CSV,
  /// and a notice on Invoicing while one is due. Platform, default ON.
  recapitulativeStatement,

  /// #2357 — input VAT: an expense states its VAT rate and deductible
  /// share, and the VAT return subtracts it. Platform, default ON, under
  /// vatDeclarations; OFF hides the fields (output VAT only).
  inputVat,

  /// #2484 — the settings editor (platform tier, default ON; OFF hides it).
  configurableSettings,

  /// #2362 — a seller in the United States issues in sales-tax mode: net
  /// prices, the tax of the site's postal code stated apart, taxability per
  /// kind of line, exemption certificates. Platform, default ON, under
  /// invoicing; OFF: such a seller cannot issue.
  salesTax,

  /// #2631 — a meeting room on the plan, booked in its own slot; a parking
  /// of standard, EV and accessible slots, booked per day (both default OFF).
  meetingRooms,
  parking;

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
/// #1221 — WHERE a feature shows up, which is the question an owner
/// actually asks about a list of a hundred switches. The tier answers
/// "should I have this"; the surface answers "where would I see it".
///
/// The screen groups by this, so a surface is a place in the app and
/// never a department: an owner looking for the VAT one thinks "Money",
/// not "finance domain".
enum FeatureSurface {
  reserve,
  calendar,
  members,
  money,
  messages,
  documents,
  kiosk,
  reports,
  settings,

  /// No single home — it changes how the whole app behaves.
  everywhere,
}

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
    required this.surface,
    this.defaultOn = true,
    this.requires,
  });

  final WorkspaceFeature feature;

  /// #1063 — whether a NEW workspace starts with this. Required, with no
  /// default, so that a flag cannot be added without somebody deciding
  /// which tier it belongs to.
  final FeatureTier tier;

  /// #1221 — where in the app this shows up. Required, with no default,
  /// for the same reason [tier] is: a flag cannot arrive without
  /// somebody saying where its owner would go looking for it.
  final FeatureSurface surface;

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
  ..._manifest1, ..._manifest2, ..._manifest3,
};

/// #2566 — a flag nobody has chosen is what a NEW workspace stores for it:
/// a core flag follows `defaultOn`, a platform flag is off. SQL twin:
/// `feature_raw`.
bool _unchosenFeatureIsOn(FeatureManifestEntry entry) =>
    entry.tier == FeatureTier.core && entry.defaultOn;

/// #2566 — the platform flags registered on by default (what an absent key
/// used to resolve to); the demo and the server choice state them.
Map<String, bool> get platformFeaturesOnByDefault => {
      for (final e in featureManifest.values)
        if (e.tier == FeatureTier.platform && e.defaultOn) e.feature.dbKey: true,
    };

/// Resolves the stored [featureFlags] against the registry: unchosen flags
/// ([_unchosenFeatureIsOn]), boolean overrides, unknown keys and
/// non-boolean values ignored so old clients survive new flags.
Set<WorkspaceFeature> resolveEnabledFeatures(
  Map<String, dynamic> featureFlags,
) {
  final enabled = <WorkspaceFeature>{
    for (final entry in featureManifest.entries)
      if (_unchosenFeatureIsOn(entry.value)) entry.key,
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

/// The features [featureFlagsToggleDelta] would switch on ALONGSIDE
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
/// EXPLICIT, every key, rather than an empty object. A stored value is
/// never reinterpreted; a key absent from a stored map resolves the same
/// way (#2566, [_unchosenFeatureIsOn]), so the two cannot disagree.
///
/// A platform feature is written `false` rather than omitted, so that
/// "nobody has chosen yet" and "chosen off" stay distinguishable, and so
/// that a later change to a registry default cannot quietly switch
/// something on in a space that never asked for it.
///
/// #1550 — [withTwin] is the one exception: `environmentPairs` is the
/// feature that SHOWS a pair, so creating the couple and switching off
/// the only place it appears as one is the product contradicting
/// itself. A space created alone still gets it off.
Map<String, bool> defaultFeatureFlagsForNewWorkspace({
  bool withTwin = false,
}) =>
    {
      for (final entry in featureManifest.values)
        entry.feature.dbKey: _unchosenFeatureIsOn(entry),
      if (withTwin) WorkspaceFeature.environmentPairs.dbKey: true,
    };
