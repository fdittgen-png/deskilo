// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4422 — a route path is a symbol. A screen that opens a page names it
// here instead of spelling `'/…'` where it calls `context.go` or
// `context.push`; test/lint/route_registry_test.dart checks every symbol
// against the paths the live router registers, so a link to a page that
// no longer exists fails there, and test/lint/route_symbols_test.dart
// holds the inline spellings that remain to a budget that only falls.
//
// A fixed path is a `static const`; a path with a parameter is a
// `static String` builder whose body is the path with the parameter
// interpolated. A query a page reads (`?tab=`, `?join=`) is part of the
// symbol.

/// The locations the app opens, by name.
abstract final class Routes {
  static const accessories = '/accessories';
  static const accountActivity = '/account-activity';
  static const accountMessages = '/account-messages';
  static const applications = '/applications';
  static const assistants = '/assistants';
  static const auth = '/auth';
  static const availability = '/availability';
  static const badgeKiosks = '/badge-kiosks';
  static const bi = '/bi';
  static const billing = '/billing';
  static const connections = '/connections';
  static const consentReview = '/consent?review=1';
  static const databaseAssistantApprovals = '/database/assistant-approvals';
  static const deployment = '/deployment';
  static const developer = '/developer';
  static const discover = '/discover';
  static const documents = '/documents';
  static const editor = '/editor';
  static const einvoiceConfig = '/einvoice-config';
  static const events = '/events';
  static const features = '/features';
  static const installationAssistants = '/installation/assistants';
  static const invoiceRegister = '/invoice-register';
  static const invoices = '/invoices';
  static const invoicingStandaloneNew = '/invoicing/standalone/new';
  static const legalIdentity = '/legal-identity';
  static const library = '/library';
  static const linkedAccounts = '/linked-accounts';
  static const me = '/me';
  static const meTabMe = '/me?tab=me';
  static const meTabMessages = '/me?tab=messages';
  static const meSpaces = '/me/spaces';
  static const members = '/members';
  static const membersManaged = '/members/managed';
  static const membersPrivacy = '/members/privacy';
  static const messages = '/messages';
  static const money = '/money';
  static const moneyAccounting = '/money/accounting';
  static const moneyCash = '/money/cash';
  static const moneyPurchases = '/money/purchases';
  static const moneyQuotes = '/money/quotes';
  static const moneyQuoteNew = '/money/quotes/new/edit';
  static const moneyRepartitionWizard = '/money/repartition-wizard';
  static const moneyStatus = '/money/status';
  static const moneySuppliers = '/money/suppliers';
  static const nfcConfig = '/nfc-config';
  static const onboarding = '/onboarding';
  static const onboardingJoin = '/onboarding?join=1';
  static const paymentConfig = '/payment-config';
  static const paymentMethods = '/payment-methods';
  static const plan = '/plan';
  static const privacy = '/privacy';
  static const profiles = '/profiles';
  static const reports = '/reports';
  static const reportsDocuments = '/reports?section=documents';
  static const reserve = '/reserve';
  static const roles = '/roles';
  static const scanJoin = '/scan-join';
  static const server = '/server';
  static const serverNewInstance = '/server/new-instance';
  static const services = '/services';
  static const settings = '/settings';
  static const settingsAssistantSetup = '/settings/assistant-setup';
  static const settingsAssistants = '/settings/assistants';
  static const settingsColours = '/settings/colours';
  static const settingsNumberSequences = '/settings/number-sequences';
  static const settingsPaymentTerms = '/settings/payment-terms';
  static const settingsPersonalInfo = '/settings/personal-info';
  static const settingsPublicPage = '/settings/public-page';
  static const settingsQuestions = '/settings/questions';
  static const settingsRolesOfThisSpace = '/settings/roles-of-this-space';
  static const settingsSites = '/settings/sites';
  static const settingsWhatYouCanDo = '/settings/what-you-can-do';
  static const setup = '/setup';
  static const setupLaunch = '/setup/launch';
  static const setupLevels = '/setup/levels';
  static const stockItemsAdd = '/stock/items?add=1';
  static const stockPlacesAdd = '/stock/places?add=1';
  static const stockSettings = '/stock/settings';
  static const validation = '/validation';
  static const vat = '/vat';
  static const vatDeclarations = '/vat-declarations';
  static const workspaceCode = '/workspace-code';
  static const workspaceOverview = '/workspace-overview';
  static const workspaceSettings = '/workspace-settings';

  static String biReport(String id) => '/bi/report/$id';
  static String conversation(String id) => '/conversation/$id';
  static String editorLevel(String levelId) => '/editor/level/$levelId';
  static String invoice(String id) => '/invoices/$id';
  static String mcpConfirm(String id) =>
      '/mcp/confirm/${Uri.encodeComponent(id)}';
  static String member(String memberId) => '/member/$memberId';
  static String membersManagedFor(String memberId) =>
      '/members/managed?member=$memberId';
  static String moneyEngagement(String id) => '/money/engagements/$id';
  static String moneyQuote(String id) => '/money/quotes/$id';
  static String moneyQuoteEdit(String id) => '/money/quotes/$id/edit';
  static String reservation(String id) => '/res/$id';
  static String setupStep(String id) => '/setup/step/$id';
  static String stockCycleCount(String taskId) => '/stock/cycle-counts/$taskId';
  static String stockMovement(String id) => '/stock/movements/$id';
  static String stockWhere(String itemId, {String? lotId}) =>
      '/stock/where/$itemId${lotId == null ? '' : '?lot=$lotId'}';
}
