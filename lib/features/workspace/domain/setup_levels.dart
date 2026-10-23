// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 (ADR 0047 §3) — completeness as a level per process. Each process
// has ordered levels; a level lists the features it adds to the ones below
// it. Choosing level k of a process turns on its features up to k and off
// above it, so lowering a level is the same table read the other way. The
// presets are level vectors; the recommendation reads plain answers about
// the space and says why. Declarative and pure Dart: the app, the MCP and
// `web/setup.html` read the same table.
import 'package:meta/meta.dart';

import 'workspace_feature.dart';

/// The owner-facing processes, in the guide's order.
@visibleForTesting
enum SetupProcess {
  bookings,
  community,
  money,
  payments,
  tax,
  purchases,
  presentation,
  operations,
  assistant,
}

/// One level of a process.
class SetupLevel {
  const SetupLevel(this.id, {required this.features, this.needs = const {}});

  /// Stable id within its process (`statements`, `invoices`, …).
  final String id;

  /// What this level adds to the levels below it.
  final Set<WorkspaceFeature> features;

  /// Levels of other processes this one cannot do without, by their
  /// minimum: the tax levels need invoices.
  final Map<SetupProcess, String> needs;
}

/// Every process's levels, lowest first. The first level of a process
/// that can be switched off entirely adds nothing.
@visibleForTesting
const Map<SetupProcess, List<SetupLevel>> setupLevels = {
  SetupProcess.bookings: [
    SetupLevel(
      'simple',
      features: {
        WorkspaceFeature.workingHours,
        WorkspaceFeature.bookingPolicies,
        WorkspaceFeature.bookingGate,
        WorkspaceFeature.seriesBooking,
        WorkspaceFeature.bookForOthers,
        WorkspaceFeature.seatDayTimeline,
        WorkspaceFeature.calendarFileExport,
        WorkspaceFeature.spaceQrCodes,
        WorkspaceFeature.planObjectDelete,
      },
    ),
    SetupLevel(
      'resources',
      features: {
        WorkspaceFeature.levelBooking,
        WorkspaceFeature.meetingRooms,
        WorkspaceFeature.parking,
        WorkspaceFeature.externalRooms,
        WorkspaceFeature.adminLevelAssign,
        WorkspaceFeature.adminSeatBlocking,
        WorkspaceFeature.multiSite,
        WorkspaceFeature.publicHolidays,
        WorkspaceFeature.holidayImport,
      },
    ),
    SetupLevel(
      'measured',
      features: {
        WorkspaceFeature.autoCheckInOut,
        WorkspaceFeature.capacityKpi,
        WorkspaceFeature.kioskMode,
        WorkspaceFeature.nfcBadges,
        WorkspaceFeature.nfcSeatTags,
        WorkspaceFeature.qrBadges,
        WorkspaceFeature.kioskMemberPhotos,
        WorkspaceFeature.badgeSignIn,
      },
    ),
  ],
  SetupProcess.community: [
    SetupLevel(
      'basic',
      features: {
        WorkspaceFeature.membersDirectory,
        WorkspaceFeature.roleManagement,
        WorkspaceFeature.roleAssignment,
        WorkspaceFeature.personalInfo,
        WorkspaceFeature.memberPage,
        WorkspaceFeature.calendarTab,
        WorkspaceFeature.calendarHub,
        WorkspaceFeature.calendarViews,
        WorkspaceFeature.memberNotifications,
        WorkspaceFeature.notificationGrouping,
        WorkspaceFeature.pushNotifications,
        WorkspaceFeature.messagesHub,
        WorkspaceFeature.richMessageRefs,
        WorkspaceFeature.messageGestures,
        WorkspaceFeature.messageForwarding,
        WorkspaceFeature.messageMentions,
        WorkspaceFeature.captureProtection,
        WorkspaceFeature.eventsTab,
        WorkspaceFeature.deletionRequests,
      },
    ),
    SetupLevel(
      'organised',
      features: {
        WorkspaceFeature.coOwner,
        WorkspaceFeature.customRoles,
        WorkspaceFeature.customFields,
        WorkspaceFeature.managedProfiles,
        WorkspaceFeature.managedProfileAccess,
        WorkspaceFeature.memberOrigin,
        WorkspaceFeature.guestParticipation,
        WorkspaceFeature.validationScopes,
        WorkspaceFeature.validationChain,
        WorkspaceFeature.calendarValidations,
        WorkspaceFeature.whatsappIntegration,
      },
    ),
  ],
  SetupProcess.money: [
    SetupLevel('none', features: {}),
    // Essentiel (ADR 0047): what members owe, without invoices or VAT.
    SetupLevel(
      'statements',
      features: {
        WorkspaceFeature.moneyTab,
        WorkspaceFeature.dataAccessLog,
        WorkspaceFeature.financeFaces,
        WorkspaceFeature.memberReports,
        WorkspaceFeature.services,
        WorkspaceFeature.accessorySupplements,
        WorkspaceFeature.priceNegotiations,
      },
    ),
    SetupLevel(
      'invoices',
      features: {
        WorkspaceFeature.invoicing,
        WorkspaceFeature.workspaceStatus,
        WorkspaceFeature.usageReport,
        WorkspaceFeature.reportDesignExchange,
        WorkspaceFeature.reportTexts,
        WorkspaceFeature.reportLayouts,
        WorkspaceFeature.reportDesigner,
        WorkspaceFeature.letterStandard,
        WorkspaceFeature.paymentReminders,
        WorkspaceFeature.carnets,
        WorkspaceFeature.adminInvoicing,
        WorkspaceFeature.subscriptionInvoices,
        WorkspaceFeature.usageInvoices,
        WorkspaceFeature.usageRecords,
        WorkspaceFeature.invoiceSettlement,
        WorkspaceFeature.invoiceJourney,
        WorkspaceFeature.invoicingWizard,
        WorkspaceFeature.settlementFold,
        WorkspaceFeature.numberSequences,
        WorkspaceFeature.dunning,
        WorkspaceFeature.memberPaymentTerms,
        WorkspaceFeature.invoicePdfTemplate,
        WorkspaceFeature.invoiceAddressWindow,
      },
    ),
  ],
  SetupProcess.payments: [
    SetupLevel('off', features: {}),
    SetupLevel(
      'online',
      features: {WorkspaceFeature.onlinePayments},
      needs: {SetupProcess.money: 'statements'},
    ),
  ],
  SetupProcess.tax: [
    SetupLevel('none', features: {}),
    SetupLevel(
      'vat',
      needs: {SetupProcess.money: 'invoices'},
      features: {
        WorkspaceFeature.vatManagement,
        WorkspaceFeature.vatRateHistory,
        WorkspaceFeature.vatGroups,
        WorkspaceFeature.vatCounterparty,
        WorkspaceFeature.supplyClassification,
        WorkspaceFeature.vatDeclarations,
        WorkspaceFeature.inputVat,
        WorkspaceFeature.viesVerification,
        WorkspaceFeature.recapitulativeStatement,
        WorkspaceFeature.salesTax,
        WorkspaceFeature.vatReport,
      },
    ),
    SetupLevel(
      'books',
      needs: {SetupProcess.money: 'invoices'},
      features: {
        WorkspaceFeature.accountingBook,
        WorkspaceFeature.accountingPeriods,
        WorkspaceFeature.einvoiceCustomerDelivery,
      },
    ),
  ],
  SetupProcess.purchases: [
    SetupLevel('none', features: {}),
    SetupLevel(
      'expenses',
      needs: {SetupProcess.money: 'invoices'},
      features: {
        WorkspaceFeature.supplyExpenses,
        WorkspaceFeature.expenseRepartition,
        WorkspaceFeature.expenseRepartitionWizard,
        WorkspaceFeature.scheduledExpenses,
      },
    ),
    SetupLevel(
      'full',
      needs: {SetupProcess.money: 'invoices'},
      features: {
        WorkspaceFeature.purchases,
        WorkspaceFeature.premisesLease,
        WorkspaceFeature.assetRegister,
        WorkspaceFeature.purchaseAnalytics,
      },
    ),
  ],
  SetupProcess.presentation: [
    SetupLevel(
      'basic',
      features: {
        WorkspaceFeature.planMemberPhotos,
        WorkspaceFeature.uniqueMonograms,
        WorkspaceFeature.singleRoomLevelNames,
      },
    ),
    SetupLevel(
      'branded',
      features: {
        WorkspaceFeature.workspaceBranding,
        WorkspaceFeature.workspaceVocabulary,
      },
    ),
    SetupLevel(
      'public',
      features: {
        WorkspaceFeature.publicListings,
        WorkspaceFeature.spaceInquiries,
      },
    ),
  ],
  SetupProcess.operations: [
    SetupLevel(
      'basic',
      features: {
        WorkspaceFeature.formHelpHints,
        WorkspaceFeature.setupGuide,
        WorkspaceFeature.memberGettingStarted,
        WorkspaceFeature.placeFeedback,
        WorkspaceFeature.uiAnimations,
        WorkspaceFeature.regionalFormats,
        WorkspaceFeature.navigationStyle,
        WorkspaceFeature.memberAccountMenu,
        WorkspaceFeature.demoMode,
        WorkspaceFeature.documents,
        WorkspaceFeature.pdfExport,
        WorkspaceFeature.dataExport,
        WorkspaceFeature.dataReport,
        WorkspaceFeature.memberDataExport,
      },
    ),
    SetupLevel(
      'insight',
      features: {
        WorkspaceFeature.workspaceOverview,
        WorkspaceFeature.decisionSurface,
        WorkspaceFeature.biReportDesigner,
      },
    ),
    SetupLevel(
      'advanced',
      features: {
        WorkspaceFeature.environmentPairs,
        WorkspaceFeature.memberEnvironments,
        WorkspaceFeature.deployments,
        WorkspaceFeature.configurationTransfer,
        WorkspaceFeature.configurableSettings,
        WorkspaceFeature.workspaceLibrary,
        WorkspaceFeature.instanceWizard,
      },
    ),
  ],
  SetupProcess.assistant: [
    SetupLevel('off', features: {}),
    SetupLevel(
      'on',
      features: {
        WorkspaceFeature.mcpAccess,
        WorkspaceFeature.webMcp,
        WorkspaceFeature.taskRecorder,
        WorkspaceFeature.recordingPrivacy,
      },
    ),
  ],
};

/// A choice of one level per process.
typedef SetupLevelVector = Map<SetupProcess, String>;

/// The quick starts (ADR 0047 §3).
@visibleForTesting
enum SetupPreset { essentiel, standard, complet }

/// Each preset's levels.
@visibleForTesting
const Map<SetupPreset, SetupLevelVector> setupPresets = {
  SetupPreset.essentiel: {
    SetupProcess.bookings: 'simple',
    SetupProcess.community: 'basic',
    SetupProcess.money: 'statements',
    SetupProcess.payments: 'off',
    SetupProcess.tax: 'none',
    SetupProcess.purchases: 'none',
    SetupProcess.presentation: 'basic',
    SetupProcess.operations: 'basic',
    SetupProcess.assistant: 'off',
  },
  SetupPreset.standard: {
    SetupProcess.bookings: 'resources',
    SetupProcess.community: 'organised',
    SetupProcess.money: 'invoices',
    SetupProcess.payments: 'off',
    SetupProcess.tax: 'none',
    SetupProcess.purchases: 'expenses',
    SetupProcess.presentation: 'branded',
    SetupProcess.operations: 'insight',
    SetupProcess.assistant: 'off',
  },
  SetupPreset.complet: {
    SetupProcess.bookings: 'measured',
    SetupProcess.community: 'organised',
    SetupProcess.money: 'invoices',
    SetupProcess.payments: 'online',
    SetupProcess.tax: 'books',
    SetupProcess.purchases: 'full',
    SetupProcess.presentation: 'public',
    SetupProcess.operations: 'advanced',
    SetupProcess.assistant: 'off',
  },
};

/// The rank of [level] within [process]; -1 when it is not one of its
/// levels.
@visibleForTesting
int setupLevelRank(SetupProcess process, String level) =>
    setupLevels[process]!.indexWhere((l) => l.id == level);

/// The features [vector] turns on and off: on up to each chosen level, off
/// above it. A process the vector does not name is left as it is.
@visibleForTesting
({Set<WorkspaceFeature> on, Set<WorkspaceFeature> off}) setupFeatureDelta(
  SetupLevelVector vector,
) {
  final on = <WorkspaceFeature>{};
  final off = <WorkspaceFeature>{};
  for (final MapEntry(key: process, value: chosen) in vector.entries) {
    final rank = setupLevelRank(process, chosen);
    for (final (i, level) in setupLevels[process]!.indexed) {
      (i <= rank ? on : off).addAll(level.features);
    }
  }
  return (on: on, off: off);
}

/// What [vector] lacks: each level whose [SetupLevel.needs] the vector
/// does not meet, as `process.level → process.minimum`.
@visibleForTesting
List<String> setupVectorGaps(SetupLevelVector vector) => [
  for (final MapEntry(key: process, value: chosen) in vector.entries)
    // A level carries the needs of the levels below it: their features are
    // on too.
    for (final level in setupLevels[process]!.take(
      setupLevelRank(process, chosen) + 1,
    ))
      for (final MapEntry(key: needed, value: minimum) in level.needs.entries)
        if (setupLevelRank(needed, vector[needed] ?? '') <
            setupLevelRank(needed, minimum))
          '${process.name}.${level.id} → ${needed.name}.$minimum',
];

/// The plain facts the owner states about the space (ADR 0047 §3). Legal
/// obligations are not asked: they come from the tax reference data.
@visibleForTesting
class SetupAnswers {
  const SetupAnswers({
    this.membersOweMoney = false,
    this.issueInvoices = false,
    this.payOnline = false,
    this.vatRegistered = false,
    this.keepBooks = false,
    this.tracksPurchases = false,
    this.severalRoomsOrSites = false,
    this.doorTablet = false,
    this.publicPage = false,
    this.organised = false,
  });

  final bool membersOweMoney;
  final bool issueInvoices;
  final bool payOnline;
  final bool vatRegistered;
  final bool keepBooks;
  final bool tracksPurchases;
  final bool severalRoomsOrSites;
  final bool doorTablet;
  final bool publicPage;

  /// Committees, custom roles and questions, approvals by several people.
  final bool organised;
}

/// One recommended level and the reason it is recommended, by key.
typedef SetupRecommendation = ({String level, String reason});

/// The levels [answers] call for, each with its reason; every process is
/// named, and the result never has a gap ([setupVectorGaps] is empty).
@visibleForTesting
Map<SetupProcess, SetupRecommendation> recommendSetupLevels(
  SetupAnswers answers,
) {
  // Tracking purchases shares their costs on invoices (expenseRepartition).
  final invoices =
      answers.issueInvoices ||
      answers.vatRegistered ||
      answers.keepBooks ||
      answers.tracksPurchases;
  final money =
      invoices ||
      answers.membersOweMoney ||
      answers.payOnline ||
      answers.tracksPurchases;
  return {
    SetupProcess.bookings: answers.doorTablet
        ? (level: 'measured', reason: 'door_tablet')
        : answers.severalRoomsOrSites
        ? (level: 'resources', reason: 'several_rooms')
        : (level: 'simple', reason: 'shared_places'),
    SetupProcess.community: answers.organised
        ? (level: 'organised', reason: 'organised')
        : (level: 'basic', reason: 'small_community'),
    SetupProcess.money: invoices
        ? (
            level: 'invoices',
            reason:
                answers.issueInvoices ||
                    answers.vatRegistered ||
                    answers.keepBooks
                ? 'issues_invoices'
                : 'tracks_purchases',
          )
        : money
        ? (level: 'statements', reason: 'members_owe')
        : (level: 'none', reason: 'no_money'),
    SetupProcess.payments: answers.payOnline
        ? (level: 'online', reason: 'pay_online')
        : (level: 'off', reason: 'pay_by_transfer'),
    SetupProcess.tax: answers.keepBooks
        ? (level: 'books', reason: 'keeps_books')
        : answers.vatRegistered
        ? (level: 'vat', reason: 'vat_registered')
        : (level: 'none', reason: 'no_vat'),
    SetupProcess.purchases: answers.tracksPurchases
        ? (level: 'full', reason: 'tracks_purchases')
        : (level: 'none', reason: 'no_purchases'),
    SetupProcess.presentation: answers.publicPage
        ? (level: 'public', reason: 'public_page')
        : (level: 'basic', reason: 'members_only'),
    SetupProcess.operations: (level: 'basic', reason: 'start_simple'),
    SetupProcess.assistant: (level: 'off', reason: 'later'),
  };
}
