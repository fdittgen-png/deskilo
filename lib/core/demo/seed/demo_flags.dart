// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the demo shows what the product can do, so the features a
// fresh workspace keeps off are switched on here, where the demo has the
// data to show them. Left at their default: the ones that need a server
// or data the demo does not invent (MCP access, several sites, a
// development twin, guest visits, public listings, the capacity KPI,
// the accounting book).
//
// #2566 — a key absent from the stored map is off for a platform feature,
// so the platform features the demo has always shown are stored here
// explicitly (`platformFeaturesOnByDefault`), then the literal below.
import '../../../features/workspace/domain/workspace_feature.dart';

final Map<String, dynamic> demoFeatureFlags = {
  ...platformFeaturesOnByDefault,
  'accessorySupplements': true,
  'onlinePayments': true,
  'adminInvoicing': true,
  'numberSequences': true,
  'workspaceStatus': true,
  'expenseRepartitionWizard': true,
  'carnets': true,
  'vatGroups': true,
  'vatRateHistory': true,
  'vatCounterparty': true,
  'adminSeatBlocking': true,
  'levelBooking': true,
  'adminLevelAssign': true,
  'autoCheckInOut': true,
  'publicHolidays': true,
  'holidayImport': true,
  'managedProfileAccess': true,
  'badgeSignIn': true,
  'customRoles': true,
  'customFields': true,
  'workspaceVocabulary': true,
  'workspaceBranding': true,
  'workspaceLibrary': true,
  'decisionSurface': true,
  'taskRecorder': true,
  'meetingRooms': true,
  'parking': true,
  'multiSite': true,
  'siteDocuments': true,
};
