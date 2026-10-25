// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — every feature a level turns on is reachable from a step. A step
// stands for one feature (`SetupStep.feature`); its page, or the screen it
// opens one tap away, also sets up the features listed here. What is left
// is a switch with nothing to set up: the levels page turns it on and it
// works; `test/lint/setup_step_coverage_test.dart` names those one by one
// and holds every level feature to one of the three. Client-side only:
// the server's catalogue keeps the step's own feature, which is what
// decides whether the step applies.
import 'package:meta/meta.dart';

import 'setup_steps.dart';
import 'workspace_feature.dart';

typedef _F = WorkspaceFeature;

/// Step id → the features its page or the screen it opens also sets up.
@visibleForTesting
const Map<String, Set<WorkspaceFeature>> setupStepTakesIn = {
  // The availability screen: the working day, closures and holidays.
  'hours': {_F.workingHours, _F.publicHolidays, _F.holidayImport},
  // The editor and the library the places page opens; sites group levels.
  'places': {
    _F.levelBooking,
    _F.meetingRooms,
    _F.parking,
    _F.planObjectDelete,
    _F.multiSite,
    _F.nfcSeatTags,
    _F.spaceQrCodes,
    _F.workspaceLibrary,
  },
  // The roles screen: who holds which permission, and the roles of one's own.
  'member_rights': {
    _F.roleManagement,
    _F.roleAssignment,
    _F.customRoles,
    _F.coOwner,
  },
  // People brought in: profiles made for them, and whether they reach
  // the production twin.
  'invite': {
    _F.managedProfiles,
    _F.managedProfileAccess,
    _F.memberEnvironments,
  },
  // The validation rules the approvals page shows and opens.
  'approvals': {_F.validationScopes, _F.validationChain, _F.deletionRequests},
  // The questions the identity form asks.
  'new_members': {_F.customFields},
  'notifications': {_F.memberNotifications, _F.pushNotifications},
  // The availability rules every booking surface checks, and the values
  // the space sets for itself.
  'limits': {_F.bookingGate, _F.configurableSettings},
  'kiosk': {_F.nfcBadges, _F.qrBadges, _F.kioskMemberPhotos, _F.badgeSignIn},
  // Billing, one tap away: carnets, a member's own conditions and the
  // billing rules that invoice the fee ahead and the usage after.
  'pricing': {
    _F.carnets,
    _F.priceNegotiations,
    _F.subscriptionInvoices,
    _F.usageInvoices,
  },
  // The services screen: priced accessories and where a service is taxed.
  'services': {_F.accessorySupplements, _F.supplyClassification},
  'purchases': {
    _F.supplyExpenses,
    _F.expenseRepartition,
    _F.expenseRepartitionWizard,
    _F.scheduledExpenses,
    _F.purchaseAnalytics,
  },
  // A room rented from a lessor is bookable inside the rental.
  'lease': {_F.externalRooms},
  // The colours screen and the wording beside it.
  'look': {_F.workspaceVocabulary},
  'public_page': {_F.spaceInquiries},
  // The VAT screen: rates and their history, the buyer's treatment, the
  // returns and the lists beside them.
  'vat': {
    _F.vatRateHistory,
    _F.vatGroups,
    _F.vatCounterparty,
    _F.vatDeclarations,
    _F.inputVat,
    _F.viesVerification,
    _F.recapitulativeStatement,
    _F.salesTax,
    _F.vatReport,
  },
  // The designer, the shipped looks and the letter they print as.
  'documents': {
    _F.reportLayouts,
    _F.reportDesigner,
    _F.reportTexts,
    _F.reportDesignExchange,
    _F.letterStandard,
    _F.invoiceAddressWindow,
  },
  'accounting': {_F.accountingPeriods},
  // The reminder rules and the payment conditions they recall.
  'reminders': {_F.paymentReminders, _F.memberPaymentTerms},
  // A copy of the space: its data and its configuration.
  'recovery': {_F.dataExport, _F.dataReport, _F.configurationTransfer},
  'assistant': {_F.webMcp},
};

/// The steps that set [features] up, in guide order: each step whose own
/// feature is among them or whose page takes one in.
List<SetupStep> setupStepsFor(Iterable<WorkspaceFeature> features) {
  final wanted = features.toSet();
  return [
    for (final s in setupSteps)
      if ((s.feature != null && wanted.contains(s.feature)) ||
          (setupStepTakesIn[s.id]?.any(wanted.contains) ?? false))
        s,
  ];
}
