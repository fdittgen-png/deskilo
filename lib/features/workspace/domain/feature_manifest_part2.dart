// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_feature.dart';

// #2386 — the feature registry's data, part 2 of 3 in display
// order. A new flag's entry goes at the end of the last part.
const Map<WorkspaceFeature, FeatureManifestEntry> _manifest2 = {
  // #825 — the member page over the directory's profile sheet.
  WorkspaceFeature.memberPage: FeatureManifestEntry(
    feature: WorkspaceFeature.memberPage,
    surface: FeatureSurface.members,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.membersDirectory,
  ),
  // #827 — the guided month-close process over the invoicing hub.
  WorkspaceFeature.invoicingWizard: FeatureManifestEntry(
    feature: WorkspaceFeature.invoicingWizard,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #828 — a shared expense split over the members onto their next
  // usage invoice; the reverse as credit notes.
  WorkspaceFeature.expenseRepartition: FeatureManifestEntry(
    feature: WorkspaceFeature.expenseRepartition,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #831 — the fold of settled sources under their settlement.
  WorkspaceFeature.settlementFold: FeatureManifestEntry(
    feature: WorkspaceFeature.settlementFold,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoiceSettlement,
  ),
  // #916 — the exported space IS the space: the file's <configuration>
  // section and the plan attributes travel with the export and apply on
  // import. Child of the data export it extends.
  WorkspaceFeature.configurationTransfer: FeatureManifestEntry(
    feature: WorkspaceFeature.configurationTransfer,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.dataExport,
  ),
  // #969 — a per-device preference in Settings; off hides the choice
  // and every device keeps its platform's default.
  WorkspaceFeature.navigationStyle: FeatureManifestEntry(
    feature: WorkspaceFeature.navigationStyle,
    surface: FeatureSurface.everywhere,
    tier: FeatureTier.core,
  ),
  // #970 — demo mode; off hides the switch and nothing is invented.
  WorkspaceFeature.demoMode: FeatureManifestEntry(
    feature: WorkspaceFeature.demoMode,
    surface: FeatureSurface.everywhere,
    tier: FeatureTier.platform,
  ),
  // #977 — the instance wizard on the Server screen; off leaves the
  // manual how-to alone.
  WorkspaceFeature.instanceWizard: FeatureManifestEntry(
    feature: WorkspaceFeature.instanceWizard,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
  ),
  // #719 — "who accessed my data": the server-written log of reads of
  // another member's finances, shown to the subject. OFF hides the row;
  // the log is still written, because the record is not optional.
  WorkspaceFeature.dataAccessLog: FeatureManifestEntry(
    feature: WorkspaceFeature.dataAccessLog,
    surface: FeatureSurface.members,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.moneyTab,
  ),
  // #719 — export my data (art. 20) and leave with erasure (art. 17)
  // from Settings → Privacy & data.
  WorkspaceFeature.memberDataExport:
      FeatureManifestEntry(
      feature: WorkspaceFeature.memberDataExport,
      surface: FeatureSurface.members,
      tier: FeatureTier.core,
    ),
  // #720 — Finances as three faces (Payments · Consumption · Invoices)
  // under one period chooser. OFF keeps the single column.
  WorkspaceFeature.financeFaces: FeatureManifestEntry(
    feature: WorkspaceFeature.financeFaces,
    surface: FeatureSurface.money,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.moneyTab,
  ),
  // #726 — automatic payment reminders: the dunning levels applied by a
  // daily sweep (or by an admin opening Finances), each one an event in
  // the member's feed and a push. Child of dunning.
  WorkspaceFeature.paymentReminders: FeatureManifestEntry(
    feature: WorkspaceFeature.paymentReminders,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.dunning,
  ),
  // #731 — an expense can be a SUPPLY: validated, it restocks (or
  // creates) a consumable service with a unit price and a stock count.
  WorkspaceFeature.supplyExpenses: FeatureManifestEntry(
    feature: WorkspaceFeature.supplyExpenses,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.services,
  ),
  // #732 — a validation rule names its scope: admins, listed persons of
  // any role, or every member. Off: owner + admins as before.
  WorkspaceFeature.validationScopes:
      FeatureManifestEntry(
      feature: WorkspaceFeature.validationScopes,
      surface: FeatureSurface.settings,
      tier: FeatureTier.platform,
    ),
  // #840 — a rule may ask for its validations one after another, and may
  // let the owner (never an admin) sign off on their own act.
  WorkspaceFeature.validationChain:
      FeatureManifestEntry(
      feature: WorkspaceFeature.validationChain,
      surface: FeatureSurface.settings,
      tier: FeatureTier.platform,
    ),
  // #842 — a message can point at an alert, at the validation behind
  // one, and at the financial documents people argue about.
  WorkspaceFeature.richMessageRefs: FeatureManifestEntry(
    feature: WorkspaceFeature.richMessageRefs,
    surface: FeatureSurface.messages,
    tier: FeatureTier.core,
    requires: WorkspaceFeature.memberNotifications,
  ),
  // #843 — decisions on the timeline, at the moment they were taken.
  WorkspaceFeature.calendarValidations: FeatureManifestEntry(
    feature: WorkspaceFeature.calendarValidations,
    surface: FeatureSurface.calendar,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.calendarHub,
  ),
  // #833 — every counted booking leaves a record, and an early
  // departure can be corrected through the validation rules.
  WorkspaceFeature.usageRecords: FeatureManifestEntry(
    feature: WorkspaceFeature.usageRecords,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #864 — a report design leaves as a self-describing file and comes
  // back the same way, so it can be edited outside the app.
  WorkspaceFeature.reportDesignExchange: FeatureManifestEntry(
    feature: WorkspaceFeature.reportDesignExchange,
    surface: FeatureSurface.reports,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.reportDesigner,
  ),
  // #875 — positioned layouts: a design states its geometry, the PDF
  // prints it; a document with a layout is drawn by it, the rest unchanged.
  WorkspaceFeature.reportLayouts: FeatureManifestEntry(
    feature: WorkspaceFeature.reportLayouts,
    surface: FeatureSurface.reports,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.reportDesigner,
  ),
  // #886 — the person's structured identity (name, postal address,
  // phone, e-mail, ids) on their settings, printed by every document.
  WorkspaceFeature.personalInfo:
      FeatureManifestEntry(
      feature: WorkspaceFeature.personalInfo,
      surface: FeatureSurface.members,
      tier: FeatureTier.core,
    ),
  // #887 — members an admin runs until the person claims them with a
  // bound invitation; they live on the members list.
  WorkspaceFeature.managedProfiles: FeatureManifestEntry(
    feature: WorkspaceFeature.managedProfiles,
    surface: FeatureSurface.members,
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
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.invoicing,
  ),
  // #934 — the treasurer's view: what the workspace invoiced, collected,
  // reimbursed and shared out over a range of months, on screen and as
  // a printable report.
  WorkspaceFeature.workspaceStatus: FeatureManifestEntry(
    feature: WorkspaceFeature.workspaceStatus,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.invoicing,
  ),
  // #934 — the guided repartition: a shared cost proposed over the
  // members by subscription share, adjustable, remembered as the rule.
  WorkspaceFeature.expenseRepartitionWizard: FeatureManifestEntry(
    feature: WorkspaceFeature.expenseRepartitionWizard,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.expenseRepartition,
  ),
  // #945 — sites: levels grouped by address, a member's home site, the
  // document naming the site it concerns (#946). Off, the workspace has
  // its one address as before.
  WorkspaceFeature.multiSite: FeatureManifestEntry(
    feature: WorkspaceFeature.multiSite,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #946 — documents name the site they concern: the member's home
  // site's address and registration on the seller side, the other
  // sites the month stood at in the details.
  WorkspaceFeature.siteDocuments: FeatureManifestEntry(
    feature: WorkspaceFeature.siteDocuments,
    surface: FeatureSurface.documents,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.multiSite,
  ),
  // #947 — each rate carries its fiscal group: the law's category, the
  // outside-base rule, the exemption reason. Off: bare percentages.
  WorkspaceFeature.vatGroups: FeatureManifestEntry(
    feature: WorkspaceFeature.vatGroups,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.vatManagement,
  ),
  // #985 — a rate is a family of dated versions: a change by law is a
  // new value from a date, never an edit. Off: one value per rate.
  WorkspaceFeature.vatRateHistory: FeatureManifestEntry(
    feature: WorkspaceFeature.vatRateHistory,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.vatManagement,
  ),
  // #985 — who the buyer is for VAT, set per member: domestic, reverse
  // charge, outside the EU, exempt. Off: the automatic rule only.
  WorkspaceFeature.vatCounterparty: FeatureManifestEntry(
    feature: WorkspaceFeature.vatCounterparty,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.vatManagement,
  ),
  // #987 — a workspace and its twin as one couple: the paired card in
  // Profiles and the twin action. Off: two unrelated entries.
  WorkspaceFeature.environmentPairs: FeatureManifestEntry(
    feature: WorkspaceFeature.environmentPairs,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
  ),
  // #988/#990 — entities deployed between the two sides of a pair, with
  // a preview and a journal. Off: the twins stay separate hands.
  WorkspaceFeature.deployments: FeatureManifestEntry(
    feature: WorkspaceFeature.deployments,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.environmentPairs,
  ),
  WorkspaceFeature.managedProfileAccess: FeatureManifestEntry(
    feature: WorkspaceFeature.managedProfileAccess,
    surface: FeatureSurface.members,
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
      surface: FeatureSurface.reserve,
      tier: FeatureTier.core,
    ),
  // #881 — a member's own payment conditions, changed by validated request.
  WorkspaceFeature.memberPaymentTerms: FeatureManifestEntry(
    feature: WorkspaceFeature.memberPaymentTerms,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.invoicing,
  ),
  // #873 — the month-end consumption report, from the usage records.
  WorkspaceFeature.usageReport: FeatureManifestEntry(
    feature: WorkspaceFeature.usageReport,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.usageRecords,
  ),
  // #880 — the owner's own texts, `{{ text.<key> }}`, per language.
  WorkspaceFeature.reportTexts: FeatureManifestEntry(
    feature: WorkspaceFeature.reportTexts,
    surface: FeatureSurface.reports,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.reportDesigner,
  ),
  // #874 — every person-facing document folds into a window envelope:
  // a kind without a design renders its default positioned layout.
  WorkspaceFeature.letterStandard: FeatureManifestEntry(
    feature: WorkspaceFeature.letterStandard,
    surface: FeatureSurface.reports,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.reportLayouts,
  ),
  // #878 — the period's VAT positions as a letter and a CSV.
  WorkspaceFeature.vatReport: FeatureManifestEntry(
    feature: WorkspaceFeature.vatReport,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.vatDeclarations,
  ),
  // #739 — the tariff is the default; a member may have their own deal,
  // proposed by finance admins, validated, seen by the member and them.
  WorkspaceFeature.priceNegotiations: FeatureManifestEntry(
    feature: WorkspaceFeature.priceNegotiations,
    surface: FeatureSurface.money,
    tier: FeatureTier.platform,
    requires: WorkspaceFeature.moneyTab,
  ),
  // #767 — subscriptions the space pays for keep paying themselves:
  // schedule once, validate once, confirm each occurrence.
  WorkspaceFeature.scheduledExpenses: FeatureManifestEntry(
    feature: WorkspaceFeature.scheduledExpenses,
    surface: FeatureSurface.money,
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
    surface: FeatureSurface.kiosk,
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
      surface: FeatureSurface.everywhere,
      tier: FeatureTier.core,
    ),
  // #611 — the motion pass: purposeful animations (route transitions,
  // view cross-fades, state-colour changes, feedback moments). Default
  // ON; OFF returns the whole app to instant transitions. Reduced
  // motion (the OS accessibility setting) overrides regardless.
  WorkspaceFeature.uiAnimations:
      FeatureManifestEntry(
      feature: WorkspaceFeature.uiAnimations,
      surface: FeatureSurface.everywhere,
      tier: FeatureTier.core,
    ),
  // #1110 — how each member got here, on their own profile and on the
  // member sheet for anyone who manages members. Default OFF: it is new
  // information about real people, and a workspace should decide to show
  // it rather than find it already there.
  WorkspaceFeature.memberOrigin: FeatureManifestEntry(
    feature: WorkspaceFeature.memberOrigin,
    surface: FeatureSurface.members,
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
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    defaultOn: false,
    requires: WorkspaceFeature.environmentPairs,
  ),
  // #1120 — sharing a floor plan is asked for, never assumed.
  WorkspaceFeature.workspaceLibrary: FeatureManifestEntry(
    feature: WorkspaceFeature.workspaceLibrary,
    surface: FeatureSurface.documents,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
  // #1273 — a label rule, not a new surface: every workspace started from
  // `tiny` has single-room levels, so it is Core and on.
  WorkspaceFeature.singleRoomLevelNames: FeatureManifestEntry(
    feature: WorkspaceFeature.singleRoomLevelNames,
    surface: FeatureSurface.reserve,
    tier: FeatureTier.core,
  ),
  // #1274 — generating closure days changes what a subscription
  // includes, so it is asked for rather than assumed: Platform, off.
  WorkspaceFeature.publicHolidays: FeatureManifestEntry(
    feature: WorkspaceFeature.publicHolidays,
    surface: FeatureSurface.settings,
    tier: FeatureTier.platform,
    defaultOn: false,
  ),
};
