// SPDX-License-Identifier: AGPL-3.0-or-later

/// #1016 — the identity a help symbol, a guide heading, a screenshot and
/// its crops all share.
///
/// One dotted id, lower case, never translated:
/// `<guide>.<module>.<screen>.<object>`. The guides carry it as an HTML
/// comment on the line above the heading it names — invisible on GitHub
/// and in the app — and `tool/build_help.dart` compiles those comments
/// into `assets/help/<lang>.anchors.json`, so the help screen jumps to
/// the exact paragraph instead of the first heading whose text happens
/// to contain the topic.
///
/// The same id, with the dots turned into dashes, names that object's
/// screenshot in `docs/wiki/images/`.
///
/// `test/lint/help_anchor_test.dart` refuses an anchor that is missing
/// from any of the five guides, a duplicate, and a malformed id.
abstract final class HelpAnchor {
  // ── money · VAT ────────────────────────────────────────────────────
  /// The rate table: names, percentages, groups, the default star.
  static const moneyVatRates = 'user.money.vat.rates';

  /// The fiscal group a rate carries and what falls in each.
  static const moneyVatGroups = 'user.money.vat.groups';

  /// The periodic declaration built from the period's invoices.
  static const moneyVatDeclaration = 'user.money.vat.declaration';

  /// Out of scope, exempt or charging — what the norm then demands.
  static const moneyVatRegime = 'user.money.vat.regime';

  /// The intra-community number, checked for its country's shape.
  static const moneyVatNumber = 'user.money.vat.number';

  /// The account collected VAT is posted to.
  static const moneyVatAccount = 'user.money.vat.account';

  /// The statutory sentence a seller who charges no VAT prints.
  static const moneyVatExemptionReason = 'user.money.vat.exemption-reason';

  // ── money · legal identity and invoice mentions ────────────────────
  /// SIREN, SIRET, HRB, CIF — the seller's registration number.
  static const legalLegalId = 'user.money.legal.legal-id';

  /// Street, post code and city — what the e-invoice carries.
  static const legalAddress = 'user.money.legal.address';

  /// Company or association — which clause defaults a document prints.
  static const legalSellerKind = 'user.money.legal.seller-kind';

  /// What the organisation legally is, printed under its name.
  static const legalForm = 'user.money.legal.legal-form';

  /// The register a reader can check the seller with.
  static const legalRegistration = 'user.money.legal.registration';

  /// When the money is due, and what the reminders count from.
  static const legalPaymentTerms = 'user.money.legal.payment-terms';

  /// The interest a late payment carries.
  static const legalLatePenalty = 'user.money.legal.late-penalty';

  /// The fixed indemnity for collection costs.
  static const legalRecovery = 'user.money.legal.recovery';

  /// Whether paying early earns a discount.
  static const legalEscompte = 'user.money.legal.escompte';

  /// Insurer, policy and geographical cover.
  static const legalInsurance = 'user.money.legal.insurance';

  /// Anything else the trade or the country demands.
  static const legalSpecialMentions = 'user.money.legal.special-mentions';

  // ── money · billing ────────────────────────────────────────────────
  /// The price ladder behind percentage subscriptions.
  static const billingFeeBands = 'user.money.billing.fee-bands';

  /// Which percentages a member may pick.
  static const billingLevels = 'user.money.billing.levels';

  /// Days sold for a price, bought rather than subscribed.
  static const billingPackages = 'user.money.billing.packages';

  /// Name, days and price, then add.
  static const billingPackageNew = 'user.money.billing.package-new';

  /// Which design an invoice prints with, per kind and per language.
  static const reportsInvoiceTemplate = 'user.money.reports.invoice-template';

  /// How many reminders, how long after the term, and what they say.
  static const remindersRules = 'user.money.reminders.rules';

  /// When the month is billed — the subscription line goes ahead of it.
  static const billingSchedule = 'user.money.billing.schedule';

  // ── the remaining surfaces ─────────────────────────────────────────
  /// The sheet only proposes; the server checks on confirm.
  static const reservationsBookingSheet = 'user.reservations.booking-sheet';

  /// The readable name and the walk-in invite, in one.
  static const workspaceCode = 'user.workspace.code';

  /// Which service takes the money, and what is still missing.
  static const paymentsProvider = 'user.money.payments.provider';

  /// What a document calls each way of paying.
  static const paymentsMethods = 'user.money.payments.methods';

  /// The card's UID is stored as a hash, never as itself.
  static const badgesNfc = 'user.badges.nfc';

  /// One account, several spaces; a pair is one card.
  static const profileProfiles = 'user.profile.profiles';

  /// Number and date conventions, per device.
  static const profileRegionalFormats = 'user.profile.settings.regional-formats';

  /// Twelve or twenty-four hours.
  static const profileClock = 'user.profile.settings.clock';

  /// Times as the space's, or converted to yours.
  static const profileDeviceZone = 'user.profile.settings.device-zone';

  /// Which Supabase project the app talks to.
  static const backendServer = 'user.backend.server';

  /// The bundle that makes a self-host identical, not a fork.
  static const backendHow = 'user.backend.how';

  /// What the server enforces, not a set of switches.
  static const privacyVisibility = 'user.privacy.visibility';

  /// Produced on request, so it says what is true then.
  static const privacyExport = 'user.privacy.export';

  /// What the law requires the space to keep cannot go.
  static const privacyErase = 'user.privacy.erase';

  /// What is collected, why, and on what basis.
  static const privacyConsent = 'user.privacy.consent';

  /// Bands, or a positioned layout that wins over them.
  static const reportsEditor = 'user.money.reports.editor';

  /// A level already reached is never sent twice.
  static const remindersAutomatic = 'user.money.reminders.automatic';

  // ── members, roles and features ────────────────────────────────────
  /// The percentage that picks the fee band.
  static const membersSubscription = 'user.members.subscription';

  /// What happens past the allowance, per member.
  static const membersOveragePolicy = 'user.members.overage-policy';

  /// How many OPEN reservations; bounds the backlog.
  static const membersReservationLimit = 'user.members.reservation-limit';

  /// How many OVERLAP in time; never your own.
  static const membersSimultaneous = 'user.members.simultaneous';

  /// What the counterparty makes of the tax.
  static const membersVatTreatment = 'user.members.vat-treatment';

  /// A price recorded as agreed, not typed over the tariff.
  static const membersNegotiation = 'user.members.negotiation';

  /// A co-owner counts as an owner wherever a rule asks.
  static const membersCoOwnership = 'user.members.co-ownership';

  /// Everything an administrator can do for one member.
  static const membersActions = 'user.members.actions';

  /// One function asks it, so revoking a cell revokes it everywhere.
  static const rolesMatrix = 'user.roles.matrix';

  /// The roles a space defines for itself.
  static const rolesSpace = 'user.roles.space';

  /// All of a feature or none — but never the arithmetic already applied.
  static const featuresSwitch = 'user.features.switch';

  // ── validation and the document library ────────────────────────────
  /// Each act has its own rule, and every decision is an event.
  static const validationOverview = 'user.validation.overview';

  /// How many must confirm; more than can is refused.
  static const validationRequiredCount = 'user.validation.required-count';

  /// Any administrator, or a named list.
  static const validationWhoMay = 'user.validation.who-may';

  /// At least one confirmation from an owner.
  static const validationOwnerRequired = 'user.validation.owner-required';

  /// Whether a one-person space works at all.
  static const validationOwnerSelf = 'user.validation.owner-self';

  /// Confirmations collected in list order.
  static const validationSequential = 'user.validation.sequential';

  /// An owner's own request, born settled.
  static const validationAutoOwner = 'user.validation.auto-validate-owner';

  /// The same for admins, independently.
  static const validationAutoAdmin = 'user.validation.auto-validate-admin';

  /// What the library shows and a member searches by.
  static const documentsTitle = 'user.documents.title';

  /// The link, not the file.
  static const documentsUrl = 'user.documents.url';

  /// A label for the reader, not a connection.
  static const documentsProvider = 'user.documents.provider';

  /// How the library groups the entry.
  static const documentsCategory = 'user.documents.category';

  /// Enforced by the server, not hidden in the list.
  static const documentsRole = 'user.documents.role';

  // ── profile · personal settings ────────────────────────────────────
  /// Your number in the member directory.
  static const profileWhatsapp = 'user.profile.settings.whatsapp';

  /// One line beside your name; yours alone to set.
  static const profileStatus = 'user.profile.settings.status';

  /// Which half of the day a booking assumes.
  static const profileDefaultPeriod = 'user.profile.settings.default-period';

  /// What a document naming you as the buyer prints.
  static const profilePersonalInfo = 'user.profile.settings.personal-info';

  /// The free-text address on your invoices.
  static const profileAddress = 'user.profile.settings.address';

  /// What decides a cross-border reverse charge.
  static const profileVatId = 'user.profile.settings.vat-id';

  /// Terms negotiated for you specifically.
  static const profilePaymentTerms = 'user.profile.settings.payment-terms';

  /// Brings back every dismissed hint.
  static const profileRestoreHints = 'user.profile.settings.restore-hints';

  /// The badge, stored only as a hash.
  static const profileBadge = 'user.profile.settings.badge';

  /// The second factor beside the badge.
  static const profileBadgePin = 'user.profile.settings.badge-pin';

  /// The app's language on this device.
  static const profileLanguage = 'user.profile.settings.language';

  /// Light, dark or the signature blend, per device.
  static const profileTheme = 'user.profile.settings.theme';

  /// Bottom bar or side rail.
  static const profileNavigation = 'user.profile.settings.navigation';

  /// Plausible names and amounts, display only.

  /// The front lens, for a wall tablet.
  static const profileFrontCamera = 'user.profile.settings.front-camera';

  // ── workspace · settings and exports ───────────────────────────────
  /// Where the organisation is established.
  static const workspaceCountry = 'user.workspace.settings.country';

  /// The currency, and the zone the space's own clock runs on.
  static const workspaceCurrencyTimezone =
      'user.workspace.settings.currency-timezone';

  /// The language the space speaks by default.
  static const workspaceLanguage = 'user.workspace.settings.language';

  /// The free-text address a paper document prints.
  static const workspaceAddress = 'user.workspace.settings.address';

  /// The group a notice can be posted to.
  static const workspaceWhatsappGroup =
      'user.workspace.settings.whatsapp-group';

  /// The text an invitation carries, per language.
  static const workspaceInvitationMessage =
      'user.workspace.settings.invitation-message';

  /// The words this space uses for the product's own terms.
  static const workspaceWording = 'user.workspace.settings.wording';

  /// The colour this space gives the app.
  static const workspaceColours = 'user.workspace.settings.colours';

  /// How much background shows through a desk on the plan.
  static const workspaceDeskTransparency =
      'user.workspace.settings.desk-transparency';

  /// The whole space as one file, and what is never in it.
  static const exportSpaceXml = 'user.workspace.export.space-xml';

  /// Applying that file here, and what an existing booking refuses.
  static const exportSpaceImport = 'user.workspace.export.space-import';

  /// Every parameter as a readable document.
  static const exportConfigPdf = 'user.workspace.export.config-pdf';

  /// The space itself as a document.
  static const exportWorkspaceReport =
      'user.workspace.export.workspace-report';

  /// One printable QR per place.
  static const exportSpaceQr = 'user.workspace.export.space-qr';

  /// The operational data as a spreadsheet.
  static const exportExcel = 'user.workspace.export.excel';

  // ── money · scheduled expenses ─────────────────────────────────────
  /// A cost that comes back, raised on its own due days.
  static const expenseSchedule = 'user.money.expenses.schedule';

  // ── money · services ───────────────────────────────────────────────
  /// Anything sold that is not a seat.
  static const serviceOverview = 'user.money.services.overview';

  // ── money · electronic invoicing ───────────────────────────────────
  /// Where a structured invoice goes, and with which credentials.
  static const einvoiceOverview = 'user.money.einvoice.overview';

  /// The address the document is posted to.
  static const einvoiceEndpoint = 'user.money.einvoice.endpoint';

  /// The secret, never shown again once saved.
  static const einvoiceToken = 'user.money.einvoice.token';

  /// The HTTP header the token travels in.
  static const einvoiceAuthHeader = 'user.money.einvoice.auth-header';

  /// The multipart field name the document is uploaded under.
  static const einvoiceFileField = 'user.money.einvoice.file-field';

  /// The platform's acceptance environment.
  static const einvoiceUat = 'user.money.einvoice.uat';

  /// The endpoint a development workspace uses, which reaches no state.
  static const einvoiceDev = 'user.money.einvoice.dev';

  // ── workspace · availability and booking rules ─────────────────────
  /// Which weekdays the space is open at all.
  static const availabilityOpenWeekdays =
      'user.workspace.availability.open-weekdays';

  /// Half day, full day, or a grid of N minutes.
  static const availabilityGranularity =
      'user.workspace.availability.granularity';

  /// The working day, which with the granularity defines a half-day.
  static const availabilityWorkingHours =
      'user.workspace.availability.working-hours';

  /// Dates the space is shut whatever the weekday.
  static const availabilityClosureDays =
      'user.workspace.availability.closure-days';

  /// The rules the server enforces on every creation path.
  static const availabilityPolicies = 'user.workspace.availability.policies';

  /// Whether a booking wholly in the past is allowed.
  static const availabilityAllowPast = 'user.workspace.availability.allow-past';

  /// Whether an administrator may end someone else's presence.
  static const availabilityAdminCheckout =
      'user.workspace.availability.admin-checkout';

  /// The four answers to a booking outside the opening hours.
  static const availabilityOutsideHours =
      'user.workspace.availability.outside-hours';

  /// Horizon, minimum and maximum duration, simultaneous bookings.
  static const availabilityLimits = 'user.workspace.availability.limits';

  /// Deploying between the two sides of a space.
  static const advancedDeploy = 'user.advanced.deploy';

  /// The trace, the developer screen and what to do when something fails.
  static const advancedTroubleshooting = 'user.advanced.troubleshooting';

  /// The accountant exports and what each format may claim.
  static const invoicingAccountingExport = 'user.invoicing.accounting-export';

  /// Every anchor the app points at — the lint's left-hand side.
  static const all = <String>{
    advancedDeploy,
    advancedTroubleshooting,
    invoicingAccountingExport,
    moneyVatRates,
    moneyVatGroups,
    moneyVatDeclaration,
    legalSellerKind,
    legalForm,
    legalRegistration,
    legalPaymentTerms,
    legalLatePenalty,
    legalRecovery,
    legalEscompte,
    legalInsurance,
    moneyVatRegime,
    moneyVatNumber,
    moneyVatAccount,
    moneyVatExemptionReason,
    legalLegalId,
    legalAddress,
    legalSpecialMentions,
    billingFeeBands,
    billingLevels,
    billingPackages,
    billingPackageNew,
    availabilityOpenWeekdays,
    availabilityGranularity,
    availabilityWorkingHours,
    availabilityClosureDays,
    availabilityPolicies,
    availabilityAllowPast,
    availabilityAdminCheckout,
    availabilityOutsideHours,
    availabilityLimits,
    einvoiceOverview,
    einvoiceEndpoint,
    einvoiceToken,
    einvoiceAuthHeader,
    einvoiceFileField,
    einvoiceUat,
    einvoiceDev,
    expenseSchedule,
    serviceOverview,
    workspaceCountry,
    workspaceCurrencyTimezone,
    workspaceLanguage,
    workspaceAddress,
    workspaceWhatsappGroup,
    workspaceInvitationMessage,
    workspaceWording,
    workspaceColours,
    workspaceDeskTransparency,
    exportSpaceXml,
    exportSpaceImport,
    exportConfigPdf,
    exportWorkspaceReport,
    exportSpaceQr,
    exportExcel,
    reportsInvoiceTemplate,
    remindersRules,
    billingSchedule,
    profileWhatsapp,
    profileStatus,
    profileDefaultPeriod,
    profilePersonalInfo,
    profileAddress,
    profileVatId,
    profilePaymentTerms,
    profileRestoreHints,
    profileBadge,
    profileBadgePin,
    profileLanguage,
    profileTheme,
    profileNavigation,
    profileFrontCamera,
    validationOverview,
    validationRequiredCount,
    validationWhoMay,
    validationOwnerRequired,
    validationOwnerSelf,
    validationSequential,
    validationAutoOwner,
    validationAutoAdmin,
    documentsTitle,
    documentsUrl,
    documentsProvider,
    documentsCategory,
    documentsRole,
    membersSubscription,
    membersOveragePolicy,
    membersReservationLimit,
    membersSimultaneous,
    membersVatTreatment,
    membersNegotiation,
    membersCoOwnership,
    membersActions,
    rolesMatrix,
    rolesSpace,
    featuresSwitch,
    reservationsBookingSheet,
    workspaceCode,
    paymentsProvider,
    paymentsMethods,
    badgesNfc,
    profileProfiles,
    profileRegionalFormats,
    profileClock,
    profileDeviceZone,
    backendServer,
    backendHow,
    privacyVisibility,
    privacyExport,
    privacyErase,
    privacyConsent,
    reportsEditor,
    remindersAutomatic,
  };

  /// The screenshot that documents [anchor], by the naming rule.
  static String imageFor(String anchor) => '${anchor.replaceAll('.', '-')}.jpg';
}
