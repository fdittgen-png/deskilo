// SPDX-License-Identifier: AGPL-3.0-or-later

import 'workspace_feature.dart';

/// #1850 — how far a registered capability has been REVIEWED, and where
/// it is in its life, kept beside the registry rather than in a second
/// catalogue.
///
/// Two axes, deliberately independent of each other and of everything
/// else the registry says:
///
/// * [FeatureMaturity] — alpha, beta or stable once someone has assessed
///   the feature against evidence; [FeatureMaturity.unreviewed] until
///   then. A closed issue, a release channel or a test count is not an
///   assessment, so nothing is promoted by code landing.
/// * [FeatureLifecycle] — active, deprecated (still served, being
///   replaced) or retired (gone; the key is kept so it is never reused).
///
/// Neither axis is the requested flag, its effective dependencies, the
/// tier, a permission or the runtime readiness of an installation.
/// Stable + deprecated is legal; so is beta on a switch that is off.
/// Nothing that decides whether a feature runs or who may use it reads
/// this file — the lint in feature_lifecycle_test.dart holds that line.

/// Bumped when the meaning of a stored value changes. A reader that meets
/// a version it does not know treats every entry as unreviewed.
const int _featureAssessmentSchemaVersion = 1;

/// The review axis. Declared in increasing order of assurance.
enum FeatureMaturity { unreviewed, alpha, beta, stable }

/// The life axis.
enum FeatureLifecycle { active, deprecated, retired }

/// What a classification rests on. [evidence] is the assessment of #1850:
/// capability ids of the evidence ledger. [ownerDecision] is the owner's
/// declaration (#2519, 2026-10-13: every shipped feature is beta): it can
/// say beta, never stable, and it says so in its rationale — so a reader can
/// tell a declared beta from an evidenced one.
enum AssessmentBasis { evidence, ownerDecision }

/// A stored or transported maturity name, read safely: anything unknown —
/// a newer build's value, a typo, nothing at all — is
/// [FeatureMaturity.unreviewed], never an assurance it did not state.
FeatureMaturity featureMaturityFromName(String? name, {int? schemaVersion}) {
  if (schemaVersion != null &&
      schemaVersion != _featureAssessmentSchemaVersion) {
    return FeatureMaturity.unreviewed;
  }
  for (final m in FeatureMaturity.values) {
    if (m.name == name) return m;
  }
  return FeatureMaturity.unreviewed;
}

/// The same for the life axis: unknown reads as active, which changes
/// nothing about how the feature runs.
FeatureLifecycle featureLifecycleFromName(String? name) {
  for (final l in FeatureLifecycle.values) {
    if (l.name == name) return l;
  }
  return FeatureLifecycle.active;
}

/// One capability's assessment.
class FeatureAssessment {
  const FeatureAssessment({
    required this.maturity,
    required this.rationale,
    this.lifecycle = FeatureLifecycle.active,
    this.evidence = const [],
    this.basis = AssessmentBasis.evidence,
    this.limitations = '',
    this.replacedBy = const [],
    this.introducedIn,
    this.deprecatedIn,
  });

  /// The explicit "nobody has assessed this yet" state every legacy entry
  /// starts in.
  const FeatureAssessment.unreviewed(this.rationale)
    : maturity = FeatureMaturity.unreviewed,
      lifecycle = FeatureLifecycle.active,
      evidence = const [],
      basis = AssessmentBasis.evidence,
      limitations = '',
      replacedBy = const [],
      introducedIn = null,
      deprecatedIn = null;

  final FeatureMaturity maturity;
  final FeatureLifecycle lifecycle;

  /// Why this classification — required, also for unreviewed.
  final String rationale;

  /// Capability ids of the evidence ledger (docs/product/capabilities.json,
  /// #1634) the classification rests on. Beta and stable need at least one.
  final List<String> evidence;

  /// Whether [evidence] or the owner's declaration carries the maturity.
  final AssessmentBasis basis;
  final String limitations;

  /// Registry keys that take over once this one is deprecated or retired.
  final List<String> replacedBy;
  final String? introducedIn;
  final String? deprecatedIn;
}

const _legacy = FeatureAssessment.unreviewed(
  'No shipped capability in the evidence ledger '
  '(docs/product/capabilities.json) covers it yet; it stays unreviewed '
  'until one does, whatever its age, issue state or test count.',
);

/// The date of the owner's declaration; an [AssessmentBasis.ownerDecision]
/// rationale must carry it so the claim is traceable (#2519).
const _ownerBetaDecisionDate = '2026-10-13';

const _ownerBeta = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  basis: AssessmentBasis.ownerDecision,
  rationale:
      'Owner decision of $_ownerBetaDecisionDate (#2519): every shipped '
      'feature is declared beta. The evidence-based review of #1850 '
      'continues: a feature may gain evidence ids, be raised to stable only '
      'on evidence, or be lowered by the owner.',
  limitations:
      'Declared by the owner; not assessed against the evidence ledger '
      '(docs/product/capabilities.json).',
);

// #1850 B — one assessment per shipped capability of the evidence ledger
// that names the feature. Beta means: assessed, and the capability's
// evidence runs on every change; the ledger's limitations travel with it.
// Stable needs the provider, hardware or operator evidence #1850 C checks.
const _booking = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale:
      '#1850 B: assessed against the evidence ledger (booking): shipped, '
      'with local_integration, unit evidence that runs on every change. '
      'Beta, not stable: no provider, hardware or operator qualification is '
      'recorded.',
  evidence: ['booking'],
  limitations:
      'Single-workspace timezone per booking; recovery of a booking made '
      'against a stale plan is manual.',
);

const _allowances = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale:
      '#1850 B: assessed against the evidence ledger '
      '(membership.allowances): shipped, with local_integration, unit '
      'evidence that runs on every change. Beta, not stable: no provider, '
      'hardware or operator qualification is recorded.',
  evidence: ['membership.allowances'],
  limitations:
      'Allowances are counted per calendar month in the workspace clock; no '
      'pro-rata on a mid-month join.',
);

const _sharedExpenses = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale:
      '#1850 B: assessed against the evidence ledger '
      '(statements.shared_expenses): shipped, with local_integration, unit '
      'evidence that runs on every change. Beta, not stable: no provider, '
      'hardware or operator qualification is recorded.',
  evidence: ['statements.shared_expenses'],
  limitations:
      'Statements are a view of the ledger, not an accounting ledger of the '
      'association; see accounting.export for the books.',
);

const _approvals = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale:
      '#1850 B: assessed against the evidence ledger (approvals): shipped, '
      'with local_integration, unit evidence that runs on every change. '
      'Beta, not stable: no provider, hardware or operator qualification is '
      'recorded.',
  evidence: ['approvals'],
  limitations:
      'Quorums count distinct people by membership, not by device or '
      'session.',
);

const _onlinePayments = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale:
      '#1850 B: assessed against the evidence ledger (payments.stripe, '
      'payments.mollie, payments.paypal, payments.wero): shipped, with '
      'local_integration, provider_sandbox, unit evidence that runs on '
      'every change. Beta, not stable: no provider, hardware or operator '
      'qualification is recorded.',
  evidence: [
    'payments.stripe',
    'payments.mollie',
    'payments.paypal',
    'payments.wero',
  ],
  limitations:
      'payments.stripe: CI runs the real order and webhook handlers against '
      'a stateful local stub through ten settlement scenarios; no Stripe '
      'sandbox has been exercised from this repository: '
      'scripts/payment_sandbox_check.sh is the opt-in test-mode runner, and '
      'without test keys it records not_run, never a pass. Refunds are '
      'recorded by hand. payments.mollie: The reconciliation is proved in a '
      'replayed database; no Mollie sandbox has been exercised from this '
      'repository. payments.paypal: No CI check reaches the PayPal handler; '
      'the Stripe stub says nothing about PayPal. payments.wero: Wero rides '
      'Mollie\'s checkout; nothing beyond the client\'s method handling cites '
      'Wero, so the Mollie reconciliation does not count here.',
);

const _accountingExport = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale:
      '#1850 B: assessed against the evidence ledger (accounting.export): '
      'shipped, with unit evidence that runs on every change. Beta, not '
      'stable: no provider, hardware or operator qualification is recorded.',
  evidence: ['accounting.export'],
  limitations:
      'Format conformance is proved against the published specifications, '
      'not against any accounting software\'s import; no certification is '
      'claimed.',
);

const _invoicing = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale:
      '#1850 B: assessed against the evidence ledger (einvoice.generate): '
      'shipped, with unit evidence that runs on every change. Beta, not '
      'stable: no provider, hardware or operator qualification is recorded.',
  evidence: ['einvoice.generate'],
  limitations:
      'Validated against the norm\'s arithmetic and structure here; '
      'acceptance by a given platform\'s validator is not claimed.',
);

const _vat = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale:
      '#1850 B: assessed against the evidence ledger (accounting.export, '
      'einvoice.generate): shipped, with unit evidence that runs on every '
      'change. Beta, not stable: no provider, hardware or operator '
      'qualification is recorded.',
  evidence: ['accounting.export', 'einvoice.generate'],
  limitations:
      'accounting.export: Format conformance is proved against the '
      'published specifications, not against any accounting software\'s '
      'import; no certification is claimed. einvoice.generate: Validated '
      'against the norm\'s arithmetic and structure here; acceptance by a '
      'given platform\'s validator is not claimed.',
);

const _einvoiceTransmit = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale:
      '#1850 B: assessed against the evidence ledger (einvoice.transmit): '
      'shipped, with unit evidence that runs on every change. Beta, not '
      'stable: no provider, hardware or operator qualification is recorded.',
  evidence: ['einvoice.transmit'],
  limitations:
      'The client\'s hand-off is unit-tested against a fake function; no '
      'transmission to a real or sandbox platform has been recorded.',
);

const _demo = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale:
      '#1850 B: assessed against the evidence ledger (demo): shipped, with '
      'unit evidence that runs on every change. Beta, not stable: no '
      'provider, hardware or operator qualification is recorded.',
  evidence: ['demo'],
  limitations:
      'The Demo\'s reach over the screens is pinned by a lint, not by an '
      'end-to-end run of every journey.',
);

/// Every registered feature's assessment — one explicit line each, so a
/// new flag cannot be added without deciding what it is (the lint fails
/// on a missing key). Unreviewed until evidence says otherwise.
const Map<WorkspaceFeature, FeatureAssessment> featureAssessments = {
  WorkspaceFeature.calendarTab: _ownerBeta,
  WorkspaceFeature.eventsTab: _ownerBeta,
  WorkspaceFeature.moneyTab: _ownerBeta,
  WorkspaceFeature.services: _ownerBeta,
  WorkspaceFeature.accessorySupplements: _ownerBeta,
  WorkspaceFeature.onlinePayments: _onlinePayments,
  WorkspaceFeature.pdfExport: _ownerBeta,
  WorkspaceFeature.seriesBooking: _booking,
  WorkspaceFeature.bookForOthers: _ownerBeta,
  WorkspaceFeature.pushNotifications: _ownerBeta,
  WorkspaceFeature.adminSeatBlocking: _ownerBeta,
  WorkspaceFeature.levelBooking: _ownerBeta,
  WorkspaceFeature.adminLevelAssign: _ownerBeta,
  WorkspaceFeature.kioskMode: _ownerBeta,
  WorkspaceFeature.nfcBadges: _ownerBeta,
  WorkspaceFeature.membersDirectory: _ownerBeta,
  WorkspaceFeature.whatsappIntegration: _ownerBeta,
  WorkspaceFeature.spaceQrCodes: _ownerBeta,
  WorkspaceFeature.coOwner: _ownerBeta,
  WorkspaceFeature.invoicing: _invoicing,
  WorkspaceFeature.adminInvoicing: _ownerBeta,
  WorkspaceFeature.autoCheckInOut: _booking,
  WorkspaceFeature.dataExport: _accountingExport,
  WorkspaceFeature.workingHours: _ownerBeta,
  WorkspaceFeature.invoicePdfTemplate: _ownerBeta,
  WorkspaceFeature.invoiceAddressWindow: _ownerBeta,
  WorkspaceFeature.memberNotifications: _ownerBeta,
  WorkspaceFeature.documents: _ownerBeta,
  WorkspaceFeature.dunning: _ownerBeta,
  WorkspaceFeature.memberReports: _ownerBeta,
  WorkspaceFeature.deletionRequests: _approvals,
  WorkspaceFeature.roleManagement: _ownerBeta,
  WorkspaceFeature.vatManagement: _vat,
  WorkspaceFeature.vatDeclarations: _ownerBeta,
  WorkspaceFeature.einvoiceCustomerDelivery: _einvoiceTransmit,
  WorkspaceFeature.planObjectDelete: _ownerBeta,
  WorkspaceFeature.notificationGrouping: _ownerBeta,
  WorkspaceFeature.bookingPolicies: _booking,
  WorkspaceFeature.nfcSeatTags: _ownerBeta,
  WorkspaceFeature.qrBadges: _ownerBeta,
  WorkspaceFeature.kioskMemberPhotos: _ownerBeta,
  WorkspaceFeature.formHelpHints: _ownerBeta,
  WorkspaceFeature.uiAnimations: _ownerBeta,
  WorkspaceFeature.planMemberPhotos: _ownerBeta,
  WorkspaceFeature.badgeSignIn: _ownerBeta,
  WorkspaceFeature.regionalFormats: _ownerBeta,
  WorkspaceFeature.calendarHub: _ownerBeta,
  WorkspaceFeature.dataAccessLog: _ownerBeta,
  WorkspaceFeature.memberDataExport: _ownerBeta,
  WorkspaceFeature.financeFaces: _sharedExpenses,
  WorkspaceFeature.paymentReminders: _ownerBeta,
  WorkspaceFeature.supplyExpenses: _sharedExpenses,
  WorkspaceFeature.validationScopes: _approvals,
  WorkspaceFeature.validationChain: _approvals,
  WorkspaceFeature.richMessageRefs: _ownerBeta,
  WorkspaceFeature.calendarValidations: _ownerBeta,
  WorkspaceFeature.usageRecords: _allowances,
  WorkspaceFeature.reportDesignExchange: _ownerBeta,
  WorkspaceFeature.reportLayouts: _ownerBeta,
  WorkspaceFeature.personalInfo: _ownerBeta,
  WorkspaceFeature.managedProfiles: _ownerBeta,
  WorkspaceFeature.managedProfileAccess: _ownerBeta,
  WorkspaceFeature.numberSequences: _ownerBeta,
  WorkspaceFeature.workspaceStatus: _ownerBeta,
  WorkspaceFeature.expenseRepartitionWizard: _ownerBeta,
  WorkspaceFeature.multiSite: _ownerBeta,
  WorkspaceFeature.siteDocuments: _legacy,
  WorkspaceFeature.vatGroups: _ownerBeta,
  WorkspaceFeature.vatRateHistory: _ownerBeta,
  WorkspaceFeature.vatCounterparty: _ownerBeta,
  WorkspaceFeature.environmentPairs: _ownerBeta,
  WorkspaceFeature.deployments: _ownerBeta,
  WorkspaceFeature.seatDayTimeline: _ownerBeta,
  WorkspaceFeature.memberPaymentTerms: _ownerBeta,
  WorkspaceFeature.reportTexts: _ownerBeta,
  WorkspaceFeature.usageReport: _ownerBeta,
  WorkspaceFeature.vatReport: _ownerBeta,
  WorkspaceFeature.letterStandard: _ownerBeta,
  WorkspaceFeature.priceNegotiations: _ownerBeta,
  WorkspaceFeature.scheduledExpenses: _ownerBeta,
  WorkspaceFeature.uniqueMonograms: _ownerBeta,
  WorkspaceFeature.messageGestures: _ownerBeta,
  WorkspaceFeature.subscriptionInvoices: _ownerBeta,
  WorkspaceFeature.usageInvoices: _ownerBeta,
  WorkspaceFeature.invoiceSettlement: _ownerBeta,
  WorkspaceFeature.invoiceJourney: _ownerBeta,
  WorkspaceFeature.bookingGate: _booking,
  WorkspaceFeature.calendarViews: _ownerBeta,
  WorkspaceFeature.messagesHub: _ownerBeta,
  WorkspaceFeature.reportDesigner: _ownerBeta,
  WorkspaceFeature.memberPage: _ownerBeta,
  WorkspaceFeature.invoicingWizard: _ownerBeta,
  WorkspaceFeature.expenseRepartition: _sharedExpenses,
  WorkspaceFeature.settlementFold: _ownerBeta,
  WorkspaceFeature.configurationTransfer: _ownerBeta,
  WorkspaceFeature.navigationStyle: _ownerBeta,
  WorkspaceFeature.demoMode: _demo,
  WorkspaceFeature.instanceWizard: _ownerBeta,
  WorkspaceFeature.memberOrigin: _ownerBeta,
  WorkspaceFeature.memberEnvironments: _ownerBeta,
  WorkspaceFeature.workspaceLibrary: _ownerBeta,
  WorkspaceFeature.singleRoomLevelNames: _ownerBeta,
  WorkspaceFeature.publicHolidays: _ownerBeta,
  WorkspaceFeature.workspaceVocabulary: _ownerBeta,
  WorkspaceFeature.carnets: _allowances,
  WorkspaceFeature.workspaceBranding: _ownerBeta,
  WorkspaceFeature.customRoles: _ownerBeta,
  WorkspaceFeature.customFields: _ownerBeta,
  WorkspaceFeature.decisionSurface: _ownerBeta,
  WorkspaceFeature.recordingPrivacy: _ownerBeta,
  WorkspaceFeature.memberAccountMenu: _ownerBeta,
  WorkspaceFeature.mcpAccess: _ownerBeta,
  WorkspaceFeature.calendarFileExport: _ownerBeta,
  WorkspaceFeature.memberGettingStarted: _ownerBeta,
  WorkspaceFeature.placeFeedback: _ownerBeta,
  WorkspaceFeature.publicListings: _ownerBeta,
  WorkspaceFeature.spaceInquiries: _ownerBeta,
  WorkspaceFeature.messageForwarding: _ownerBeta,
  WorkspaceFeature.captureProtection: _ownerBeta,
  WorkspaceFeature.holidayImport: _ownerBeta,
  WorkspaceFeature.capacityKpi: _ownerBeta,
  WorkspaceFeature.accountingBook: _ownerBeta,
  WorkspaceFeature.roleAssignment: _ownerBeta,
  WorkspaceFeature.taskRecorder: _ownerBeta,
  WorkspaceFeature.guestParticipation: _ownerBeta,
  WorkspaceFeature.messageMentions: _ownerBeta,
  WorkspaceFeature.supplyClassification: _ownerBeta,
  WorkspaceFeature.viesVerification: _ownerBeta,
  WorkspaceFeature.recapitulativeStatement: _ownerBeta,
  WorkspaceFeature.inputVat: _ownerBeta,
  WorkspaceFeature.configurableSettings: _ownerBeta,
  WorkspaceFeature.salesTax: _ownerBeta, WorkspaceFeature.meetingRooms: _ownerBeta, WorkspaceFeature.parking: _ownerBeta, WorkspaceFeature.webMcp: _ownerBeta, WorkspaceFeature.purchases: _ownerBeta,
};

/// Keys that were registered once and are gone. They stay here so a
/// retired key is never reused for something else with the old meaning
/// still sitting in stored flag maps and templates.
const Map<String, FeatureAssessment> retiredFeatureAssessments = {};

/// The assessment of [feature]; unreviewed if the map has no entry,
/// which the lint forbids but a reader must still survive.
FeatureAssessment featureAssessmentOf(
  WorkspaceFeature feature, {
  Map<WorkspaceFeature, FeatureAssessment> assessments = featureAssessments,
}) => assessments[feature] ?? _legacy;

/// What is wrong with how [a] is backed: beta or stable needs evidence
/// unless it is the owner's declaration (#2519), which is beta only and
/// names its date.
List<String> _basisProblems(String key, FeatureAssessment a) {
  final owned = a.basis == AssessmentBasis.ownerDecision;
  return [
    if (a.maturity.index >= FeatureMaturity.beta.index &&
        a.evidence.isEmpty &&
        !owned)
      '$key: ${a.maturity.name} without evidence',
    if (owned && a.maturity == FeatureMaturity.stable)
      '$key: stable on an owner decision',
    if (owned && !a.rationale.contains(_ownerBetaDecisionDate))
      '$key: an owner decision that does not name its date',
  ];
}

/// What is wrong with a ledger, as one sentence per problem — empty when
/// it is sound. [evidenceIds] are the capability ids the evidence ledger
/// actually declares.
List<String> validateFeatureAssessments({
  required Map<WorkspaceFeature, FeatureAssessment> assessments,
  required Map<String, FeatureAssessment> retired,
  required Set<String> evidenceIds,
}) {
  final problems = <String>[];
  final live = {for (final f in WorkspaceFeature.values) f.name};
  final all = <String, FeatureAssessment>{
    ...retired,
    for (final e in assessments.entries) e.key.name: e.value,
  };
  for (final f in WorkspaceFeature.values) {
    if (!assessments.containsKey(f)) {
      problems.add('${f.name}: no assessment');
    }
    // #1851 — an alpha is off until an owner opts in to it.
    if (assessments[f]?.maturity == FeatureMaturity.alpha &&
        featureManifest[f]?.defaultOn == true) {
      problems.add('${f.name}: alpha but on by default');
    }
  }
  for (final e in retired.entries) {
    if (live.contains(e.key)) {
      problems.add('${e.key}: a retired key is registered again');
    }
    if (e.value.lifecycle != FeatureLifecycle.retired) {
      problems.add('${e.key}: in the retired list but not retired');
    }
  }
  for (final e in all.entries) {
    final key = e.key;
    final a = e.value;
    if (a.rationale.trim().isEmpty) problems.add('$key: no rationale');
    if (live.contains(key) && a.lifecycle == FeatureLifecycle.retired) {
      problems.add('$key: retired but still registered');
    }
    problems.addAll(_basisProblems(key, a));
    for (final ref in a.evidence) {
      if (!evidenceIds.contains(ref)) {
        problems.add('$key: unknown evidence "$ref"');
      }
    }
    if (a.lifecycle == FeatureLifecycle.active && a.replacedBy.isNotEmpty) {
      problems.add('$key: replaced while still active');
    }
    if (a.lifecycle != FeatureLifecycle.active && a.deprecatedIn == null) {
      problems.add('$key: ${a.lifecycle.name} without a version');
    }
    for (final r in a.replacedBy) {
      if (r == key) {
        problems.add('$key: replaced by itself');
      } else if (!live.contains(r)) {
        problems.add('$key: replaced by unknown or retired "$r"');
      }
    }
  }
  // A replacement chain must end: walk every edge, refuse a return.
  for (final start in all.keys) {
    final direct = all[start]!.replacedBy;
    if (direct.contains(start)) continue; // reported above
    final seen = <String>{};
    final stack = [...direct];
    while (stack.isNotEmpty) {
      final r = stack.removeLast();
      if (r == start) {
        problems.add('$start: replacement cycle');
        break;
      }
      if (seen.add(r)) stack.addAll(all[r]?.replacedBy ?? const []);
    }
  }
  return problems;
}
