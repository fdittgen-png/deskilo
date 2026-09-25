// SPDX-License-Identifier: AGPL-3.0-or-later
import 'workspace_feature.dart';

/// Business membership only. Dependencies/defaults remain in featureManifest.
/// A server-side effect is still selectable when it represents a user outcome.
/// Only unsupported capabilities are internal, with an explicit reason; shared
/// prerequisites retain one business home and are referenced through requires.
class WorkspaceProcess {
  const WorkspaceProcess(this.key, this.subprocesses);
  final String key;
  final List<WorkspaceSubprocess> subprocesses;
  String get titleKey => 'process${key[0].toUpperCase()}${key.substring(1)}';
  String get descriptionKey => '${titleKey}Desc';
}

class WorkspaceSubprocess {
  const WorkspaceSubprocess(this.key, this.capabilities);
  final String key;
  final List<WorkspaceFeature> capabilities;
  String get titleKey => 'subprocess${key[0].toUpperCase()}${key.substring(1)}';
  String get descriptionKey => '${titleKey}Desc';
}

const internalCapabilities = <WorkspaceFeature, String>{
  WorkspaceFeature.siteDocuments:
      'Reserved site-document flag: no implementation consumes it (#1325). '
      'Not selectable until a gated workflow is implemented.',
};

const workspaceProcesses = <WorkspaceProcess>[
  WorkspaceProcess('workspaceAccess', [
    WorkspaceSubprocess('people', [
      WorkspaceFeature.membersDirectory,
      WorkspaceFeature.coOwner,
      WorkspaceFeature.roleManagement,
      WorkspaceFeature.customRoles,
      WorkspaceFeature.customFields,
      WorkspaceFeature.personalInfo,
      WorkspaceFeature.managedProfiles,
      WorkspaceFeature.managedProfileAccess,
      WorkspaceFeature.memberPage,
      WorkspaceFeature.memberOrigin,
      WorkspaceFeature.memberEnvironments,
    ]),
    WorkspaceSubprocess('physicalAccess', [
      WorkspaceFeature.kioskMode,
      WorkspaceFeature.nfcBadges,
      WorkspaceFeature.nfcSeatTags,
      WorkspaceFeature.qrBadges,
      WorkspaceFeature.kioskMemberPhotos,
      WorkspaceFeature.badgeSignIn,
      WorkspaceFeature.spaceQrCodes,
    ]),
  ]),
  WorkspaceProcess('spaceManagement', [
    WorkspaceSubprocess('structure', [
      WorkspaceFeature.multiSite,
      WorkspaceFeature.planObjectDelete,
      WorkspaceFeature.adminSeatBlocking,
    ]),
    WorkspaceSubprocess('availability', [
      WorkspaceFeature.workingHours,
      WorkspaceFeature.publicHolidays,
    ]),
    WorkspaceSubprocess('presentation', [
      WorkspaceFeature.planMemberPhotos,
      WorkspaceFeature.uniqueMonograms,
      WorkspaceFeature.singleRoomLevelNames,
      WorkspaceFeature.workspaceVocabulary,
      WorkspaceFeature.workspaceBranding,
    ]),
  ]),
  WorkspaceProcess('reservationsUsage', [
    WorkspaceSubprocess('reservations', [
      WorkspaceFeature.seriesBooking,
      WorkspaceFeature.bookForOthers,
      WorkspaceFeature.levelBooking,
      WorkspaceFeature.adminLevelAssign,
      WorkspaceFeature.bookingPolicies,
      WorkspaceFeature.bookingGate,
      WorkspaceFeature.seatDayTimeline,
    ]),
    WorkspaceSubprocess('attendance', [
      WorkspaceFeature.autoCheckInOut,
      WorkspaceFeature.usageRecords,
    ]),
  ]),
  WorkspaceProcess('coordination', [
    WorkspaceSubprocess('calendar', [
      WorkspaceFeature.calendarTab,
      WorkspaceFeature.calendarHub,
      WorkspaceFeature.calendarViews,
      WorkspaceFeature.calendarValidations,
    ]),
    WorkspaceSubprocess('decisions', [
      WorkspaceFeature.eventsTab,
      WorkspaceFeature.validationScopes,
      WorkspaceFeature.validationChain,
      WorkspaceFeature.deletionRequests,
    ]),
    WorkspaceSubprocess('communication', [
      WorkspaceFeature.memberNotifications,
      WorkspaceFeature.notificationGrouping,
      WorkspaceFeature.richMessageRefs,
      WorkspaceFeature.messageGestures,
      WorkspaceFeature.messagesHub,
    ]),
  ]),
  WorkspaceProcess('membershipCommerce', [
    WorkspaceSubprocess('pricing', [
      WorkspaceFeature.services,
      WorkspaceFeature.accessorySupplements,
      WorkspaceFeature.priceNegotiations,
      WorkspaceFeature.memberPaymentTerms,
      WorkspaceFeature.carnets,
    ]),
  ]),
  WorkspaceProcess('billingPayments', [
    WorkspaceSubprocess('records', [
      WorkspaceFeature.moneyTab,
      WorkspaceFeature.financeFaces,
      WorkspaceFeature.memberReports,
    ]),
    WorkspaceSubprocess('invoicing', [
      WorkspaceFeature.invoicing,
      WorkspaceFeature.adminInvoicing,
      WorkspaceFeature.subscriptionInvoices,
      WorkspaceFeature.usageInvoices,
      WorkspaceFeature.invoiceSettlement,
      WorkspaceFeature.invoiceJourney,
      WorkspaceFeature.invoicingWizard,
      WorkspaceFeature.settlementFold,
      WorkspaceFeature.numberSequences,
    ]),
    WorkspaceSubprocess('collection', [
      WorkspaceFeature.onlinePayments,
      WorkspaceFeature.dunning,
      WorkspaceFeature.paymentReminders,
    ]),
    WorkspaceSubprocess('expenses', [
      WorkspaceFeature.supplyExpenses,
      WorkspaceFeature.expenseRepartitionWizard,
      WorkspaceFeature.scheduledExpenses,
      WorkspaceFeature.expenseRepartition,
    ]),
    WorkspaceSubprocess('tax', [
      WorkspaceFeature.vatManagement,
      WorkspaceFeature.vatDeclarations,
      WorkspaceFeature.vatGroups,
      WorkspaceFeature.vatRateHistory,
      WorkspaceFeature.vatCounterparty,
    ]),
  ]),
  WorkspaceProcess('documentsInformation', [
    WorkspaceSubprocess('documents', [
      WorkspaceFeature.documents,
      WorkspaceFeature.pdfExport,
      WorkspaceFeature.invoicePdfTemplate,
      WorkspaceFeature.invoiceAddressWindow,
      WorkspaceFeature.letterStandard,
    ]),
    WorkspaceSubprocess('reportDesign', [
      WorkspaceFeature.reportDesignExchange,
      WorkspaceFeature.reportLayouts,
      WorkspaceFeature.reportTexts,
      WorkspaceFeature.reportDesigner,
      WorkspaceFeature.usageReport,
      WorkspaceFeature.vatReport,
    ]),
    WorkspaceSubprocess('privacy', [
      WorkspaceFeature.dataAccessLog,
      WorkspaceFeature.memberDataExport,
      WorkspaceFeature.dataExport,
      // #1514 — filming mode belongs with the privacy obligations and
      // not with the look-and-feel switches: what it decides is whether
      // a picture of this space may carry a member's personal data.
      WorkspaceFeature.recordingPrivacy,
    ]),
  ]),
  WorkspaceProcess('operations', [
    WorkspaceSubprocess('configuration', [
      WorkspaceFeature.workspaceStatus,
      WorkspaceFeature.environmentPairs,
      WorkspaceFeature.deployments,
      WorkspaceFeature.configurationTransfer,
      WorkspaceFeature.workspaceLibrary,
      WorkspaceFeature.instanceWizard,
    ]),
    WorkspaceSubprocess('experience', [
      // #1247 — what needs a person, ranked. Under operations because
      // it is how an administrator starts their day, not a setting.
      WorkspaceFeature.decisionSurface,
      WorkspaceFeature.formHelpHints,
      WorkspaceFeature.uiAnimations,
      WorkspaceFeature.regionalFormats,
      WorkspaceFeature.navigationStyle,
      // #1598 — beside navigationStyle, for the same reason: it decides
      // what the navigation offers a member, not what anyone may do.
      WorkspaceFeature.memberAccountMenu,
      WorkspaceFeature.demoMode,
    ]),
  ]),
  WorkspaceProcess('integrations', [
    WorkspaceSubprocess('delivery', [
      WorkspaceFeature.pushNotifications,
      WorkspaceFeature.whatsappIntegration,
      WorkspaceFeature.einvoiceCustomerDelivery,
      // #1607 — an integration like the two above it: a channel a
      // workspace opens to the outside, not a right anybody holds.
      WorkspaceFeature.mcpAccess,
    ]),
  ]),
];

/// Useful paths, rather than count-only failures, make additions actionable.
List<String> validateProcessRegistry(
  List<WorkspaceProcess> processes, {
  Map<WorkspaceFeature, String> internal = internalCapabilities,
}) {
  final errors = <String>[];
  final keys = <String>{};
  final homes = <WorkspaceFeature, String>{};
  for (final process in processes) {
    if (!keys.add(process.key)) errors.add('${process.key}: duplicate key');
    if (process.subprocesses.isEmpty) errors.add('${process.key}: empty process');
    for (final subprocess in process.subprocesses) {
      final path = '${process.key}/${subprocess.key}';
      if (!keys.add(subprocess.key)) errors.add('$path: duplicate key');
      if (subprocess.capabilities.isEmpty) errors.add('$path: empty subprocess');
      for (final feature in subprocess.capabilities) {
        if (homes.containsKey(feature) || internal.containsKey(feature)) {
          errors.add('$path/${feature.name}: duplicate membership');
        }
        homes[feature] = path;
      }
    }
  }
  for (final entry in internal.entries) {
    if (entry.value.trim().isEmpty) {
      errors.add('${entry.key.name}: internal reason missing');
    }
  }
  for (final feature in WorkspaceFeature.values) {
    if (!homes.containsKey(feature) && !internal.containsKey(feature)) {
      errors.add('${feature.name}: add it to workspaceProcesses in '
          'workspace_process.dart or classify it internal');
    }
    for (final parent in requirementChain(feature)) {
      if (!homes.containsKey(parent) && !internal.containsKey(parent)) {
        errors.add('${homes[feature]}/${feature.name}: unmapped prerequisite '
            '${parent.name}');
      }
    }
  }
  return errors;
}

/// The process whose subprocess names [feature], or null for a capability
/// no subprocess lists (an internal one reached through `requires`).
String? homeProcessOf(
  WorkspaceFeature feature, {
  List<WorkspaceProcess> processes = workspaceProcesses,
}) {
  for (final process in processes) {
    for (final subprocess in process.subprocesses) {
      if (subprocess.capabilities.contains(feature)) return process.key;
    }
  }
  return null;
}
