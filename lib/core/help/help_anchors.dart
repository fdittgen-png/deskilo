// SPDX-License-Identifier: 0BSD

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

  /// The top of a band; the next one starts where it ends.
  static const billingBandTo = 'user.money.billing.band-to';

  /// What a month in the band costs, used or not.
  static const billingBandFee = 'user.money.billing.band-fee';

  /// The price of one half-day past the allowance.
  static const billingBandOverage = 'user.money.billing.band-overage';

  /// Which percentages a member may pick.
  static const billingLevels = 'user.money.billing.levels';

  /// One percentage: a share of the month's working half-days.
  static const billingLevelValue = 'user.money.billing.level-value';

  /// A percentage off the list, for one member.
  static const billingCustomLevel = 'user.money.billing.custom-level';

  /// Days sold for a price, bought rather than subscribed.
  static const billingPackages = 'user.money.billing.packages';

  /// Name, days and price, then add.
  static const billingPackageNew = 'user.money.billing.package-new';

  /// What the shop and the invoice line call it.
  static const billingPackageName = 'user.money.billing.package-name';

  /// How many days the package grants.
  static const billingPackageDays = 'user.money.billing.package-days';

  /// The price of the whole package, with its VAT group.
  static const billingPackagePrice = 'user.money.billing.package-price';

  /// Which design an invoice prints with, per kind and per language.
  static const reportsInvoiceTemplate = 'user.money.reports.invoice-template';

  /// How many reminders, how long after the term, and what they say.
  static const remindersRules = 'user.money.reminders.rules';

  /// When the month is billed — the subscription line goes ahead of it.
  static const billingSchedule = 'user.money.billing.schedule';

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
  static const profileDemoMode = 'user.profile.settings.demo-mode';

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

  /// The name every occurrence carries.
  static const expenseWhat = 'user.money.expenses.what';

  /// What one occurrence costs, and what changing it does not touch.
  static const expenseAmount = 'user.money.expenses.amount';

  /// The longer text, for whoever validates it.
  static const expenseDescription = 'user.money.expenses.description';

  /// The date the first one falls due; the series counts from here.
  static const expenseStartsOn = 'user.money.expenses.starts-on';

  /// The interval between occurrences.
  static const expenseEvery = 'user.money.expenses.every';

  /// How many occurrences to raise.
  static const expenseTimes = 'user.money.expenses.times';

  /// The date after which nothing more is raised.
  static const expenseEndsOn = 'user.money.expenses.ends-on';

  // ── money · services ───────────────────────────────────────────────
  /// Anything sold that is not a seat.
  static const serviceOverview = 'user.money.services.overview';

  /// What the invoice line says.
  static const serviceName = 'user.money.services.name';

  /// One unit's price, with its VAT group.
  static const servicePrice = 'user.money.services.price';

  /// Whether it can still be sold.
  static const serviceActive = 'user.money.services.active';

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

  // ── environments · the pair and the deployment ─────────────────────
  /// Why a development twin exists at all.
  static const envPairWhy = 'env.pair.why';

  /// Creating the pair, and the twin a lone workspace gets on demand.
  static const envPairCreate = 'env.pair.create';

  /// The three permissions, and the two rules that follow from them.
  static const envPairPermissions = 'env.pair.permissions';

  /// The deployment screen: a deployment writes the side you stand on.
  static const envDeployScreen = 'env.deploy.screen';

  /// The entity table — what travels, grouped and with its needs.
  static const envDeployEntities = 'env.deploy.entities';

  /// The floor plan is merged, never replaced.
  static const envDeployPlan = 'env.deploy.plan';

  /// The preview and the confirmation that name the side being written.
  static const envDeployPreview = 'env.deploy.preview';

  /// The journal, and the rollback that must be undone in order.
  static const envDeployJournal = 'env.deploy.journal';

  /// What never travels: members, money, credentials, counters.
  static const envDeployNever = 'env.deploy.never';

  /// Every anchor the app points at — the lint's left-hand side.
  static const all = <String>{
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
    envPairWhy,
    envPairCreate,
    envPairPermissions,
    envDeployScreen,
    envDeployEntities,
    envDeployPlan,
    envDeployPreview,
    envDeployJournal,
    envDeployNever,
    billingFeeBands,
    billingBandTo,
    billingBandFee,
    billingBandOverage,
    billingLevels,
    billingLevelValue,
    billingCustomLevel,
    billingPackages,
    billingPackageNew,
    billingPackageName,
    billingPackageDays,
    billingPackagePrice,
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
    expenseWhat,
    expenseAmount,
    expenseDescription,
    expenseStartsOn,
    expenseEvery,
    expenseTimes,
    expenseEndsOn,
    serviceOverview,
    serviceName,
    servicePrice,
    serviceActive,
    workspaceCountry,
    workspaceCurrencyTimezone,
    workspaceLanguage,
    workspaceAddress,
    workspaceWhatsappGroup,
    workspaceInvitationMessage,
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
    profileDemoMode,
    profileFrontCamera,
  };

  /// The screenshot that documents [anchor], by the naming rule.
  static String imageFor(String anchor) => '${anchor.replaceAll('.', '-')}.jpg';
}
