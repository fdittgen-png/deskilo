// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_feature.dart';

// #2386 — the feature registry's data, part 3 of 3 in display
// order. A new flag's entry goes at the end of the last part.
const Map<WorkspaceFeature, FeatureManifestEntry> _manifest3 = {
  // #1277 — the words themselves, so `everywhere`: the legend, the shell
  // destinations and the booking sheet all read them. Off by default —
  // a space that never renames anything is not shown the control, and
  // with no overrides every screen renders exactly as before.
  WorkspaceFeature.workspaceVocabulary: FeatureManifestEntry(
    feature: WorkspaceFeature.workspaceVocabulary,
    surface: FeatureSurface.everywhere,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #1279 — selling prepaid half-days is an offer a workspace makes on
  // purpose, and it bills through the invoices: Platform, off.
  WorkspaceFeature.carnets: FeatureManifestEntry(
    feature: WorkspaceFeature.carnets,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.invoicing,
  ),
  // #1289 — colours are a statement a workspace makes on purpose; the
  // product's own palette is the default and needs no switch: Platform,
  // off. Everywhere, because the theme is the whole app.
  WorkspaceFeature.publicListings: FeatureManifestEntry(
    feature: WorkspaceFeature.publicListings,
    surface: FeatureSurface.settings,
    tier: FeatureTier.core,
    defaultOn: false,
  ),
  WorkspaceFeature.workspaceBranding: FeatureManifestEntry(
    feature: WorkspaceFeature.workspaceBranding,
    surface: FeatureSurface.everywhere,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #1287 — a space with four roles is the product's answer and needs no
  // switch; a bureau with a trésorier asks for this one. Platform, off,
  // and it requires nothing: custom roles are additive, so they work on
  // top of whatever the space already has.
  WorkspaceFeature.customRoles: FeatureManifestEntry(
    feature: WorkspaceFeature.customRoles,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #1288 — it requires nothing: a space with no questions defined
  // renders the identity form it always rendered, and the flag only
  // decides whether the section can exist at all.
  WorkspaceFeature.customFields: FeatureManifestEntry(
    feature: WorkspaceFeature.customFields,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #1247 — `requires` is deliberately empty. Each row's own capability
  // already gates its data, and a surface that needs every feature
  // switched on to be useful is the wrong surface: a space with only
  // membership still has join requests to answer.
  WorkspaceFeature.decisionSurface: FeatureManifestEntry(
    feature: WorkspaceFeature.decisionSurface,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #1514 — `requires` is deliberately empty and the surface is
  // `everywhere`: the substitution happens at the data seam, so it
  // reaches every screen that shows a person at once, and there is no
  // parent feature whose absence would make it meaningless. A space
  // with nothing but a floor plan still has members to protect.
  WorkspaceFeature.recordingPrivacy: FeatureManifestEntry(
    feature: WorkspaceFeature.recordingPrivacy,
    surface: FeatureSurface.everywhere,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #1598 — `requires` is deliberately empty: the gear it renames is
  // unconditional, so there is no parent whose absence would make the
  // choice meaningless. Settings, because Settings is what it renames.
  WorkspaceFeature.memberAccountMenu: FeatureManifestEntry(
    feature: WorkspaceFeature.memberAccountMenu,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #1607 — `requires` is deliberately empty: availability of the MCP
  // interface depends on no other functionality, and what a connected
  // assistant may DO is decided per call by the feature and permission
  // it touches, never by this flag. Settings, because the owner's
  // grant configuration is a setting.
  WorkspaceFeature.mcpAccess: FeatureManifestEntry(
    feature: WorkspaceFeature.mcpAccess,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #1643 — `requires` is empty on purpose: the file is built from the
  // reservation the member already sees, on every surface that opens
  // the detail sheet, so no tab or hub is its prerequisite. Reserve,
  // because that is where a booking is looked at.
  WorkspaceFeature.calendarFileExport: FeatureManifestEntry(
    feature: WorkspaceFeature.calendarFileExport,
    surface: FeatureSurface.reserve,
    tier: FeatureTier.core,
  ),
  // #1654 — `requires` is empty on purpose: the card suggests only what
  // the features already on support, so no tab is its prerequisite.
  // Reserve, because that is where a newly joined member lands.
  WorkspaceFeature.memberGettingStarted: FeatureManifestEntry(
    feature: WorkspaceFeature.memberGettingStarted,
    surface: FeatureSurface.reserve,
    tier: FeatureTier.core,
  ),
  // #2185 — favourites and ratings need no other feature: they decorate
  // the places the Reserve hub already shows.
  WorkspaceFeature.placeFeedback: FeatureManifestEntry(
    feature: WorkspaceFeature.placeFeedback,
    surface: FeatureSurface.reserve,
    tier: FeatureTier.core,
  ),
  // #1824 — an inquiry needs a published page to be asked from, and the
  // server refuses one without it; the flag carries no `requires`, because
  // publicListings is off by default and a default-on child of a
  // default-off parent is a contradiction every builtin template would
  // inherit. The hosts it reaches are named before writing.
  WorkspaceFeature.spaceInquiries: FeatureManifestEntry(
    feature: WorkspaceFeature.spaceInquiries,
    surface: FeatureSurface.messages,
    tier: FeatureTier.core,
  ),
  // #1824 — forwarding and the capture guard are parts of the messenger.
  WorkspaceFeature.messageForwarding: FeatureManifestEntry(
    feature: WorkspaceFeature.messageForwarding,
    surface: FeatureSurface.messages,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.memberNotifications,
  ),
  WorkspaceFeature.captureProtection: FeatureManifestEntry(
    feature: WorkspaceFeature.captureProtection,
    surface: FeatureSurface.messages,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.memberNotifications,
  ),
  // #2051 — closure days written from an open-data list change what a
  // subscription includes, like publicHolidays: asked for, Platform, off.
  WorkspaceFeature.holidayImport: FeatureManifestEntry(
    feature: WorkspaceFeature.holidayImport,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.publicHolidays,
  ),
  // #1918 — a management figure, asked for: Platform, off.
  WorkspaceFeature.capacityKpi: FeatureManifestEntry(
    feature: WorkspaceFeature.capacityKpi,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #1869 — who keeps the official books is a finance decision nobody
  // makes by default: asked for, Platform, off.
  WorkspaceFeature.accountingBook: FeatureManifestEntry(
    feature: WorkspaceFeature.accountingBook,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.invoicing,
  ),
  // #2085 — the place a role is given, and what it gives. Off, the
  // member page keeps its single "Administrator" row.
  WorkspaceFeature.roleAssignment: FeatureManifestEntry(
    feature: WorkspaceFeature.roleAssignment,
    surface: FeatureSurface.members,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.roleManagement,
  ),
  // #1865 — recording a task is something a space offers its people
  // deliberately: asked for, Platform, off.
  WorkspaceFeature.taskRecorder: FeatureManifestEntry(
    feature: WorkspaceFeature.taskRecorder,
    surface: FeatureSurface.everywhere,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #1835 — admitting guests is a decision a space takes, not a default
  // that follows from being a space: Core, off, no parent (a visit needs
  // no published page; the server refuses what it cannot host).
  WorkspaceFeature.guestParticipation: FeatureManifestEntry(
    feature: WorkspaceFeature.guestParticipation,
    surface: FeatureSurface.members,
    tier: FeatureTier.core,
    defaultOn: false,
  ),
  // #2216 — a mention is part of a message: nothing without the messenger.
  WorkspaceFeature.messageMentions: FeatureManifestEntry(
    feature: WorkspaceFeature.messageMentions,
    surface: FeatureSurface.messages,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.memberNotifications,
  ),
  // #2354 — a classification is VAT configuration: under VAT management.
  WorkspaceFeature.supplyClassification: FeatureManifestEntry(
    feature: WorkspaceFeature.supplyClassification,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.vatManagement,
  ),
  // #2354 — evidence for the reverse charge a general service allows.
  WorkspaceFeature.viesVerification: FeatureManifestEntry(
    feature: WorkspaceFeature.viesVerification,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.supplyClassification,
  ),
  // #2354 — a list filed beside the VAT return: under the declarations.
  WorkspaceFeature.recapitulativeStatement: FeatureManifestEntry(
    feature: WorkspaceFeature.recapitulativeStatement,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.vatDeclarations,
    // #2454 — the EC Sales List is an EU obligation: a seller outside the
    // Union files none (evidence: place_of_supply.dart, 0405).
    availableIn: {featureCountriesEu},
  ),
  // #2357 — deductible VAT only matters to a space that files returns.
  WorkspaceFeature.inputVat: FeatureManifestEntry(
    feature: WorkspaceFeature.inputVat,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.vatDeclarations,
  ),
  // #2484 — the settings editor; the stored values apply whether or not it shows.
  WorkspaceFeature.configurableSettings: FeatureManifestEntry(
    feature: WorkspaceFeature.configurableSettings,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
  ),
  // #2362 — sales tax is an invoicing mode of a seller in the United States.
  WorkspaceFeature.salesTax: FeatureManifestEntry(
    feature: WorkspaceFeature.salesTax,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #2631 — a meeting room is a bookable resource of the plan with its own slot.
  WorkspaceFeature.meetingRooms: FeatureManifestEntry(
    feature: WorkspaceFeature.meetingRooms,
    surface: FeatureSurface.reserve,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #2631 — a parking area holds slots booked per day.
  WorkspaceFeature.parking: FeatureManifestEntry(
    feature: WorkspaceFeature.parking,
    surface: FeatureSurface.reserve,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #2504 — WebMCP tools of the web app; the MCP interface must be open.
  WorkspaceFeature.webMcp: FeatureManifestEntry(
    feature: WorkspaceFeature.webMcp,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.mcpAccess,
    defaultOn: false,
  ),
  // #2573 — the purchase document: supplier bills captured beside the
  // member receipts the expense flow already files.
  WorkspaceFeature.purchases: FeatureManifestEntry(
    feature: WorkspaceFeature.purchases,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.moneyTab,
    defaultOn: false,
  ),
  // #2569 — the lease the space holds as tenant: its rent terms generate the
  // scheduled expenses.
  WorkspaceFeature.premisesLease: FeatureManifestEntry(
    feature: WorkspaceFeature.premisesLease,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.scheduledExpenses,
    defaultOn: false,
  ),
};
