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
const int featureAssessmentSchemaVersion = 1;

/// The review axis. Declared in increasing order of assurance.
enum FeatureMaturity { unreviewed, alpha, beta, stable }

/// The life axis.
enum FeatureLifecycle { active, deprecated, retired }

/// A stored or transported maturity name, read safely: anything unknown —
/// a newer build's value, a typo, nothing at all — is
/// [FeatureMaturity.unreviewed], never an assurance it did not state.
FeatureMaturity featureMaturityFromName(String? name, {int? schemaVersion}) {
  if (schemaVersion != null &&
      schemaVersion != featureAssessmentSchemaVersion) {
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
  final String limitations;

  /// Registry keys that take over once this one is deprecated or retired.
  final List<String> replacedBy;
  final String? introducedIn;
  final String? deprecatedIn;
}

const _legacy = FeatureAssessment.unreviewed(
  'Registered before #1850; awaiting an assessment against the '
  'capability evidence ledger.',
);

/// Every registered feature's assessment — one explicit line each, so a
/// new flag cannot be added without deciding what it is (the lint fails
/// on a missing key). Unreviewed until evidence says otherwise.
const Map<WorkspaceFeature, FeatureAssessment> featureAssessments = {
  WorkspaceFeature.calendarTab: _legacy,
  WorkspaceFeature.eventsTab: _legacy,
  WorkspaceFeature.moneyTab: _legacy,
  WorkspaceFeature.services: _legacy,
  WorkspaceFeature.accessorySupplements: _legacy,
  WorkspaceFeature.onlinePayments: _legacy,
  WorkspaceFeature.pdfExport: _legacy,
  WorkspaceFeature.seriesBooking: _legacy,
  WorkspaceFeature.bookForOthers: _legacy,
  WorkspaceFeature.pushNotifications: _legacy,
  WorkspaceFeature.adminSeatBlocking: _legacy,
  WorkspaceFeature.levelBooking: _legacy,
  WorkspaceFeature.adminLevelAssign: _legacy,
  WorkspaceFeature.kioskMode: _legacy,
  WorkspaceFeature.nfcBadges: _legacy,
  WorkspaceFeature.membersDirectory: _legacy,
  WorkspaceFeature.whatsappIntegration: _legacy,
  WorkspaceFeature.spaceQrCodes: _legacy,
  WorkspaceFeature.coOwner: _legacy,
  WorkspaceFeature.invoicing: _legacy,
  WorkspaceFeature.adminInvoicing: _legacy,
  WorkspaceFeature.autoCheckInOut: _legacy,
  WorkspaceFeature.dataExport: _legacy,
  WorkspaceFeature.workingHours: _legacy,
  WorkspaceFeature.invoicePdfTemplate: _legacy,
  WorkspaceFeature.invoiceAddressWindow: _legacy,
  WorkspaceFeature.memberNotifications: _legacy,
  WorkspaceFeature.documents: _legacy,
  WorkspaceFeature.dunning: _legacy,
  WorkspaceFeature.memberReports: _legacy,
  WorkspaceFeature.deletionRequests: _legacy,
  WorkspaceFeature.roleManagement: _legacy,
  WorkspaceFeature.vatManagement: _legacy,
  WorkspaceFeature.vatDeclarations: _legacy,
  WorkspaceFeature.einvoiceCustomerDelivery: _legacy,
  WorkspaceFeature.planObjectDelete: _legacy,
  WorkspaceFeature.notificationGrouping: _legacy,
  WorkspaceFeature.bookingPolicies: _legacy,
  WorkspaceFeature.nfcSeatTags: _legacy,
  WorkspaceFeature.qrBadges: _legacy,
  WorkspaceFeature.kioskMemberPhotos: _legacy,
  WorkspaceFeature.formHelpHints: _legacy,
  WorkspaceFeature.uiAnimations: _legacy,
  WorkspaceFeature.planMemberPhotos: _legacy,
  WorkspaceFeature.badgeSignIn: _legacy,
  WorkspaceFeature.regionalFormats: _legacy,
  WorkspaceFeature.calendarHub: _legacy,
  WorkspaceFeature.dataAccessLog: _legacy,
  WorkspaceFeature.memberDataExport: _legacy,
  WorkspaceFeature.financeFaces: _legacy,
  WorkspaceFeature.paymentReminders: _legacy,
  WorkspaceFeature.supplyExpenses: _legacy,
  WorkspaceFeature.validationScopes: _legacy,
  WorkspaceFeature.validationChain: _legacy,
  WorkspaceFeature.richMessageRefs: _legacy,
  WorkspaceFeature.calendarValidations: _legacy,
  WorkspaceFeature.usageRecords: _legacy,
  WorkspaceFeature.reportDesignExchange: _legacy,
  WorkspaceFeature.reportLayouts: _legacy,
  WorkspaceFeature.personalInfo: _legacy,
  WorkspaceFeature.managedProfiles: _legacy,
  WorkspaceFeature.managedProfileAccess: _legacy,
  WorkspaceFeature.numberSequences: _legacy,
  WorkspaceFeature.workspaceStatus: _legacy,
  WorkspaceFeature.expenseRepartitionWizard: _legacy,
  WorkspaceFeature.multiSite: _legacy,
  WorkspaceFeature.siteDocuments: _legacy,
  WorkspaceFeature.vatGroups: _legacy,
  WorkspaceFeature.vatRateHistory: _legacy,
  WorkspaceFeature.vatCounterparty: _legacy,
  WorkspaceFeature.environmentPairs: _legacy,
  WorkspaceFeature.deployments: _legacy,
  WorkspaceFeature.seatDayTimeline: _legacy,
  WorkspaceFeature.memberPaymentTerms: _legacy,
  WorkspaceFeature.reportTexts: _legacy,
  WorkspaceFeature.usageReport: _legacy,
  WorkspaceFeature.vatReport: _legacy,
  WorkspaceFeature.letterStandard: _legacy,
  WorkspaceFeature.priceNegotiations: _legacy,
  WorkspaceFeature.scheduledExpenses: _legacy,
  WorkspaceFeature.uniqueMonograms: _legacy,
  WorkspaceFeature.messageGestures: _legacy,
  WorkspaceFeature.subscriptionInvoices: _legacy,
  WorkspaceFeature.usageInvoices: _legacy,
  WorkspaceFeature.invoiceSettlement: _legacy,
  WorkspaceFeature.invoiceJourney: _legacy,
  WorkspaceFeature.bookingGate: _legacy,
  WorkspaceFeature.calendarViews: _legacy,
  WorkspaceFeature.messagesHub: _legacy,
  WorkspaceFeature.reportDesigner: _legacy,
  WorkspaceFeature.memberPage: _legacy,
  WorkspaceFeature.invoicingWizard: _legacy,
  WorkspaceFeature.expenseRepartition: _legacy,
  WorkspaceFeature.settlementFold: _legacy,
  WorkspaceFeature.configurationTransfer: _legacy,
  WorkspaceFeature.navigationStyle: _legacy,
  WorkspaceFeature.demoMode: _legacy,
  WorkspaceFeature.instanceWizard: _legacy,
  WorkspaceFeature.memberOrigin: _legacy,
  WorkspaceFeature.memberEnvironments: _legacy,
  WorkspaceFeature.workspaceLibrary: _legacy,
  WorkspaceFeature.singleRoomLevelNames: _legacy,
  WorkspaceFeature.publicHolidays: _legacy,
  WorkspaceFeature.workspaceVocabulary: _legacy,
  WorkspaceFeature.carnets: _legacy,
  WorkspaceFeature.workspaceBranding: _legacy,
  WorkspaceFeature.customRoles: _legacy,
  WorkspaceFeature.customFields: _legacy,
  WorkspaceFeature.decisionSurface: _legacy,
  WorkspaceFeature.recordingPrivacy: _legacy,
  WorkspaceFeature.memberAccountMenu: _legacy,
  WorkspaceFeature.mcpAccess: _legacy,
  WorkspaceFeature.calendarFileExport: _legacy,
  WorkspaceFeature.memberGettingStarted: _legacy,
  WorkspaceFeature.publicListings: _legacy,
  WorkspaceFeature.spaceInquiries: _legacy,
  WorkspaceFeature.messageForwarding: _legacy,
  WorkspaceFeature.captureProtection: _legacy,
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
    if (a.maturity.index >= FeatureMaturity.beta.index && a.evidence.isEmpty) {
      problems.add('$key: ${a.maturity.name} without evidence');
    }
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
