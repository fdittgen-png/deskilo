// SPDX-License-Identifier: AGPL-3.0-or-later

import 'feature_assessment.dart';
import 'feature_assessment_finance.dart';
import 'feature_assessment_operations.dart';
import 'workspace_feature.dart';

export 'feature_assessment.dart';

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

/// Every registered feature has an explicit assessment. Reviewed entries
/// cite the capability ledger; the remaining shipped features retain the
/// owner's beta declaration until their evidence is reviewed.
const Map<WorkspaceFeature, FeatureAssessment> featureAssessments = {
  WorkspaceFeature.calendarTab: _ownerBeta,
  WorkspaceFeature.eventsTab: _ownerBeta,
  WorkspaceFeature.moneyTab: bankReconciliationAssessment,
  WorkspaceFeature.services: _ownerBeta,
  WorkspaceFeature.accessorySupplements: _ownerBeta,
  WorkspaceFeature.onlinePayments: onlinePaymentsAssessment,
  WorkspaceFeature.pdfExport: _ownerBeta,
  WorkspaceFeature.seriesBooking: bookingAssessment,
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
  WorkspaceFeature.invoicing: invoicingAssessment,
  WorkspaceFeature.adminInvoicing: _ownerBeta,
  WorkspaceFeature.autoCheckInOut: bookingAssessment,
  WorkspaceFeature.dataExport: accountingExportAssessment,
  WorkspaceFeature.workingHours: _ownerBeta,
  WorkspaceFeature.invoicePdfTemplate: _ownerBeta,
  WorkspaceFeature.invoiceAddressWindow: _ownerBeta,
  WorkspaceFeature.memberNotifications: _ownerBeta,
  WorkspaceFeature.documents: _ownerBeta,
  WorkspaceFeature.dunning: _ownerBeta,
  WorkspaceFeature.memberReports: _ownerBeta,
  WorkspaceFeature.deletionRequests: approvalsAssessment,
  WorkspaceFeature.roleManagement: _ownerBeta,
  WorkspaceFeature.vatManagement: vatManagementAssessment,
  WorkspaceFeature.vatDeclarations: taxHmrcMtdAssessment,
  WorkspaceFeature.einvoiceCustomerDelivery: einvoiceTransmitAssessment,
  WorkspaceFeature.planObjectDelete: _ownerBeta,
  WorkspaceFeature.notificationGrouping: _ownerBeta,
  WorkspaceFeature.bookingPolicies: bookingAssessment,
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
  WorkspaceFeature.memberDataExport: privacyMemberRightsAssessment,
  WorkspaceFeature.financeFaces: statementsSharedExpensesAssessment,
  WorkspaceFeature.paymentReminders: _ownerBeta,
  WorkspaceFeature.supplyExpenses: supplyExpensesAssessment,
  WorkspaceFeature.validationScopes: approvalsAssessment,
  WorkspaceFeature.validationChain: approvalsAssessment,
  WorkspaceFeature.richMessageRefs: _ownerBeta,
  WorkspaceFeature.calendarValidations: _ownerBeta,
  WorkspaceFeature.usageRecords: membershipAllowancesAssessment,
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
  WorkspaceFeature.bookingGate: bookingAssessment,
  WorkspaceFeature.calendarViews: _ownerBeta,
  WorkspaceFeature.messagesHub: _ownerBeta,
  WorkspaceFeature.reportDesigner: _ownerBeta,
  WorkspaceFeature.memberPage: _ownerBeta,
  WorkspaceFeature.invoicingWizard: _ownerBeta,
  WorkspaceFeature.expenseRepartition: statementsSharedExpensesAssessment,
  WorkspaceFeature.settlementFold: _ownerBeta,
  WorkspaceFeature.configurationTransfer: _ownerBeta,
  WorkspaceFeature.navigationStyle: _ownerBeta,
  WorkspaceFeature.demoMode: demoAssessment,
  WorkspaceFeature.instanceWizard: _ownerBeta,
  WorkspaceFeature.memberOrigin: _ownerBeta,
  WorkspaceFeature.memberEnvironments: _ownerBeta,
  WorkspaceFeature.workspaceLibrary: _ownerBeta,
  WorkspaceFeature.singleRoomLevelNames: _ownerBeta,
  WorkspaceFeature.publicHolidays: _ownerBeta,
  WorkspaceFeature.workspaceVocabulary: _ownerBeta,
  WorkspaceFeature.carnets: membershipAllowancesAssessment,
  WorkspaceFeature.workspaceBranding: _ownerBeta,
  WorkspaceFeature.customRoles: _ownerBeta,
  WorkspaceFeature.customFields: _ownerBeta,
  WorkspaceFeature.decisionSurface: _ownerBeta,
  WorkspaceFeature.recordingPrivacy: _ownerBeta,
  WorkspaceFeature.memberAccountMenu: _ownerBeta,
  WorkspaceFeature.mcpAccess: mcpAccessAssessment,
  WorkspaceFeature.calendarFileExport: calendarInterchangeAssessment,
  WorkspaceFeature.memberGettingStarted: _ownerBeta,
  WorkspaceFeature.placeFeedback: _ownerBeta,
  WorkspaceFeature.publicListings: _ownerBeta,
  WorkspaceFeature.spaceInquiries: _ownerBeta,
  WorkspaceFeature.messageForwarding: _ownerBeta,
  WorkspaceFeature.captureProtection: _ownerBeta,
  WorkspaceFeature.holidayImport: _ownerBeta,
  WorkspaceFeature.capacityKpi: _ownerBeta,
  WorkspaceFeature.accountingBook: accountingBookAssessment,
  WorkspaceFeature.roleAssignment: _ownerBeta,
  WorkspaceFeature.taskRecorder: _ownerBeta,
  WorkspaceFeature.guestParticipation: _ownerBeta,
  WorkspaceFeature.messageMentions: _ownerBeta,
  WorkspaceFeature.supplyClassification: _ownerBeta,
  WorkspaceFeature.viesVerification: suppliersLookupAssessment,
  WorkspaceFeature.recapitulativeStatement: _ownerBeta,
  WorkspaceFeature.inputVat: purchasesPayablesAssessment,
  WorkspaceFeature.configurableSettings: _ownerBeta,
  WorkspaceFeature.salesTax: _ownerBeta,
  WorkspaceFeature.meetingRooms: _ownerBeta,
  WorkspaceFeature.parking: _ownerBeta,
  WorkspaceFeature.webMcp: webmcpBrowserAssessment,
  WorkspaceFeature.purchases: purchasesAssessment,
  WorkspaceFeature.premisesLease: _ownerBeta,
  WorkspaceFeature.assetRegister: _ownerBeta,
  WorkspaceFeature.externalRooms: _ownerBeta,
  WorkspaceFeature.accountingPeriods: _ownerBeta,
  WorkspaceFeature.biReportDesigner: _ownerBeta,
  WorkspaceFeature.workspaceOverview: _ownerBeta,
  WorkspaceFeature.setupGuide: setupGuideAssessment,
  WorkspaceFeature.dataReport: _ownerBeta,
  WorkspaceFeature.purchaseAnalytics: _ownerBeta,
  WorkspaceFeature.personalShell: personalWorkspaceSeparationAssessment,
  WorkspaceFeature.bankImport: bankReconciliationAssessment,
  WorkspaceFeature.foreignCurrencyPurchases: _ownerBeta,
  WorkspaceFeature.accountingConnectors: accountingConnectorsAssessment,
  WorkspaceFeature.planDecor: _ownerBeta,
  WorkspaceFeature.mtdSubmission: taxHmrcMtdAssessment,
  WorkspaceFeature.purchaseOrders: purchasesOrdersAssessment,
  WorkspaceFeature.guestPasses: guestsPassesAssessment,
  WorkspaceFeature.placeBooking: _legacy,
  WorkspaceFeature.reminderEmail: _legacy,
  WorkspaceFeature.invoiceEmail: _legacy,
  WorkspaceFeature.kioskEnrolment: _legacy,
  WorkspaceFeature.quickSearch: _legacy,
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
