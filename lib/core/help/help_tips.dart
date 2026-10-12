// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../features/workspace/domain/workspace_feature.dart';
import '../../l10n/app_localizations.dart';

/// Every surface that carries a contextual help hint (#606). The enum
/// name is the persisted dismissal id — renaming a value revives its
/// hint on devices that had dismissed it.
enum HelpHintId {
  reserve,
  plan,
  calendar,
  events,
  editor,
  availability,
  features,
  members,
  money,
  moneyStatement,
  moneyPayments,
  moneyInvoices,
  moneyDocuments,
  validation,
  workspaceSettings,
  badges,
  messages,
  privacy,
}

/// One tip of a surface's carousel (#610, #2313): a scenario the person
/// may want from that screen ("To …: …"), the form it continues on when
/// it names one ([route], opened by the tip's link), the feature it needs
/// (a tip about a switched-off feature is not shown) and, when a more
/// specific guide section exists, its own "Learn more" [topic]. A null
/// [topic] falls back to the surface's topic.
class HelpTip {
  const HelpTip(this.text, {this.topic, this.route, this.feature});

  final String text;
  final String? topic;

  /// The form the tip names, as a route the router resolves.
  final String? route;

  /// The workspace feature the scenario needs; null: always available.
  final WorkspaceFeature? feature;
}

/// Tip 1 — the surface's basic how-to sentence (#606).
String helpHintText(AppLocalizations l10n, HelpHintId id) => switch (id) {
  HelpHintId.reserve =>
    l10n.helpHintReserve,
  HelpHintId.plan =>
    l10n.helpHintPlan,
  HelpHintId.calendar =>
    l10n.helpHintCalendar,
  HelpHintId.events =>
    l10n.helpHintEvents,
  HelpHintId.editor =>
    l10n.helpHintEditor,
  HelpHintId.availability =>
    l10n.helpHintAvailability,
  HelpHintId.features =>
    l10n.helpHintFeatures,
  HelpHintId.members =>
    l10n.helpHintMembers,
  HelpHintId.money =>
    l10n.helpHintMoney,
  HelpHintId.moneyStatement =>
    l10n.helpHintMoneyStatement,
  HelpHintId.moneyPayments =>
    l10n.helpHintMoneyPayments,
  HelpHintId.moneyInvoices =>
    l10n.helpHintMoneyInvoices,
  HelpHintId.moneyDocuments =>
    l10n.helpHintMoneyDocuments,
  HelpHintId.validation =>
    l10n.helpHintValidation,
  HelpHintId.workspaceSettings =>
    l10n.helpHintWorkspace,
  HelpHintId.messages =>
    l10n.helpHintMessages,
  HelpHintId.privacy =>
    l10n.helpHintPrivacy,
  HelpHintId.badges =>
    l10n.helpHintBadges,
};

/// A distinctive fragment of the matching guide heading, localized —
/// the help guides are per-language, so the jump text must be too.
/// This is the surface's DEFAULT topic; a tip may carry its own.
String helpHintTopic(AppLocalizations l10n, HelpHintId id) => switch (id) {
  HelpHintId.reserve => l10n.helpHintReserveTopic,
  HelpHintId.plan => l10n.helpHintPlanTopic,
  HelpHintId.calendar => l10n.helpHintCalendarTopic,
  HelpHintId.events => l10n.helpHintEventsTopic,
  HelpHintId.editor => l10n.helpHintEditorTopic,
  HelpHintId.availability => l10n.helpHintAvailabilityTopic,
  HelpHintId.features => l10n.helpHintFeaturesTopic,
  HelpHintId.members => l10n.helpHintMembersTopic,
  HelpHintId.money => l10n.helpHintMoneyTopic,
  HelpHintId.moneyStatement =>
    l10n.helpHintMoneyStatementTopic,
  HelpHintId.moneyPayments =>
    l10n.helpHintMoneyPaymentsTopic,
  HelpHintId.moneyInvoices =>
    l10n.helpHintMoneyInvoicesTopic,
  HelpHintId.moneyDocuments =>
    l10n.helpHintMoneyDocumentsTopic,
  HelpHintId.validation => l10n.helpHintValidationTopic,
  HelpHintId.workspaceSettings =>
    l10n.helpHintWorkspaceTopic,
  HelpHintId.badges => l10n.helpHintBadgesTopic,
  HelpHintId.messages => l10n.helpHintMessagesTopic,
  HelpHintId.privacy => l10n.helpHintPrivacyTopic,
};

/// The guide section a surface's "Learn more" opens on the guide site.
String helpHintAnchor(HelpHintId id) => switch (id) {
  HelpHintId.reserve => 'user.reserve.hub',
  HelpHintId.plan => 'user.reserve.plan-levels',
  HelpHintId.calendar => 'user.reserve.calendar',
  HelpHintId.events => 'user.collaborate.events',
  HelpHintId.editor => 'user.space.overview',
  HelpHintId.availability => 'user.workspace.availability.open-weekdays',
  HelpHintId.features => 'user.features.switch',
  HelpHintId.members => 'user.people.overview',
  HelpHintId.money => 'user.money.overview',
  HelpHintId.moneyStatement => 'user.money.statement',
  HelpHintId.moneyPayments => 'user.money.payments',
  HelpHintId.moneyInvoices => 'user.money.invoices',
  HelpHintId.moneyDocuments => 'user.money.documents.library',
  HelpHintId.validation => 'user.validation.overview',
  HelpHintId.workspaceSettings => 'user.workspace.settings.country',
  HelpHintId.badges => 'user.badges.nfc',
  HelpHintId.messages => 'user.collaborate.messages',
  HelpHintId.privacy => 'user.privacy.visibility',
};

/// The surface's carousel (#2313): every scenario a person may want from
/// that screen, each naming the controls by their own labels (built from
/// the label keys, so all five languages quote the real buttons) and
/// linking to the form it continues on. Regenerated from the current
/// screens; tips of a switched-off feature are filtered by [HelpHint].
List<HelpTip> helpHintTips(AppLocalizations l10n, HelpHintId id) {
  final t = l10n;
  return switch (id) {
    // The live plan lives in Reserve now: the same scenarios.
    HelpHintId.plan => helpHintTips(l10n, HelpHintId.reserve),
    HelpHintId.reserve => [
      HelpTip(t.tipReserveBook),
      HelpTip(t.tipReserveAhead),
      HelpTip(t.tipReserveList),
      HelpTip(t.tipReserveRepeat, feature: WorkspaceFeature.seriesBooking),
      HelpTip(t.tipReserveCheckIn),
      HelpTip(t.tipReserveScan, feature: WorkspaceFeature.spaceQrCodes),
      HelpTip(t.tipReserveChange),
      HelpTip(t.tipReserveFavourite, feature: WorkspaceFeature.placeFeedback),
      HelpTip(t.tipReserveLevel, feature: WorkspaceFeature.levelBooking),
      HelpTip(t.tipReserveDefault, route: '/settings'),
    ],
    HelpHintId.calendar => [
      HelpTip(t.tipCalendarViews, feature: WorkspaceFeature.calendarViews),
      HelpTip(t.tipCalendarKinds),
      HelpTip(t.tipCalendarMine),
      HelpTip(t.tipCalendarAlerts, feature: WorkspaceFeature.eventsTab),
      HelpTip(t.tipCalendarMoney, route: '/money'),
    ],
    HelpHintId.events => [
      HelpTip(t.tipEventsDecide),
      HelpTip(t.tipEventsTopic),
      HelpTip(t.tipEventsUnread),
      HelpTip(t.tipEventsGroup, feature: WorkspaceFeature.notificationGrouping),
      HelpTip(t.tipEventsMessages, route: '/me?tab=messages'),
    ],
    HelpHintId.editor => [
      HelpTip(t.tipEditorLevel),
      HelpTip(t.tipEditorDraw),
      HelpTip(t.tipEditorSeats),
      HelpTip(t.tipEditorSeat),
      HelpTip(t.tipEditorNfc, feature: WorkspaceFeature.nfcSeatTags),
      HelpTip(t.tipEditorBackground),
      HelpTip(
        t.tipEditorAccessories,
        route: '/accessories',
        feature: WorkspaceFeature.accessorySupplements,
      ),
      HelpTip(
        t.tipEditorQr,
        route: '/reports?section=documents',
        feature: WorkspaceFeature.spaceQrCodes,
      ),
    ],
    HelpHintId.availability => [
      HelpTip(t.tipAvailabilityDays),
      HelpTip(t.tipAvailabilityGrid),
      HelpTip(t.tipAvailabilityHours, feature: WorkspaceFeature.workingHours),
      HelpTip(t.tipAvailabilityClosure),
      HelpTip(
        t.tipAvailabilityHolidays,
        feature: WorkspaceFeature.publicHolidays,
      ),
      HelpTip(
        t.tipAvailabilityPolicies,
        feature: WorkspaceFeature.bookingPolicies,
      ),
    ],
    HelpHintId.features => [
      HelpTip(t.tipFeaturesProcess),
      HelpTip(t.tipFeaturesSwitch),
      HelpTip(t.tipFeaturesChanged),
      HelpTip(t.tipFeaturesRequires),
    ],
    HelpHintId.members => [
      HelpTip(t.tipMembersInvite, route: '/workspace-code'),
      HelpTip(
        t.tipMembersManaged,
        route: '/members/managed',
        feature: WorkspaceFeature.managedProfiles,
      ),
      HelpTip(t.tipMembersPlan),
      HelpTip(t.tipMembersApprove),
      HelpTip(t.tipMembersBadge),
      HelpTip(
        t.tipMembersRole,
        route: '/roles',
        feature: WorkspaceFeature.roleManagement,
      ),
      HelpTip(t.tipMembersPrices, route: '/billing'),
      HelpTip(
        t.tipMembersNotify,
        feature: WorkspaceFeature.memberNotifications,
      ),
    ],
    HelpHintId.money => [
      HelpTip(t.tipMoneyMonth),
      HelpTip(t.tipMoneyPdf, feature: WorkspaceFeature.pdfExport),
      HelpTip(t.tipMoneyRecord),
      HelpTip(t.tipMoneyExpense),
      HelpTip(t.tipMoneyDays),
    ],
    HelpHintId.moneyStatement => [
      HelpTip(t.tipMoneyStatementMonth),
      HelpTip(t.tipMoneyStatementOut),
      HelpTip(t.tipMoneyStatementAcross, route: '/account-activity'),
    ],
    HelpHintId.moneyPayments => [
      HelpTip(
        t.tipMoneyPaymentsOnline,
        feature: WorkspaceFeature.onlinePayments,
      ),
      HelpTip(t.tipMoneyPaymentsTransfer),
      HelpTip(t.tipMoneyPaymentsRecord),
      HelpTip(t.tipMoneyPaymentsExpense),
      HelpTip(
        t.tipMoneyPaymentsScheduled,
        feature: WorkspaceFeature.scheduledExpenses,
      ),
      HelpTip(t.tipMoneyPaymentsDays),
      HelpTip(
        t.tipMoneyPaymentsConsumption,
        feature: WorkspaceFeature.services,
      ),
      HelpTip(t.tipMoneyPaymentsAcross, route: '/account-activity'),
    ],
    HelpHintId.moneyInvoices => [
      HelpTip(t.tipMoneyInvoicesPay),
      HelpTip(t.tipMoneyInvoicesRead),
      HelpTip(t.tipMoneyInvoicesAcross, route: '/account-activity'),
    ],
    HelpHintId.moneyDocuments => [
      HelpTip(
        t.tipMoneyDocumentsConditions,
        feature: WorkspaceFeature.memberReports,
      ),
      HelpTip(
        t.tipMoneyDocumentsPayments,
        feature: WorkspaceFeature.memberReports,
      ),
      HelpTip(t.tipMoneyDocumentsUsage, feature: WorkspaceFeature.usageReport),
      HelpTip(
        t.tipMoneyDocumentsStatement,
        feature: WorkspaceFeature.pdfExport,
      ),
      HelpTip(
        t.tipMoneyDocumentsLibrary,
        route: '/documents',
        feature: WorkspaceFeature.documents,
      ),
    ],
    HelpHintId.validation => [
      HelpTip(t.tipValidationDefault),
      HelpTip(t.tipValidationOverride),
      HelpTip(t.tipValidationCount),
      HelpTip(t.tipValidationChain, feature: WorkspaceFeature.validationChain),
      HelpTip(t.tipValidationWho, feature: WorkspaceFeature.validationScopes),
      HelpTip(
        t.tipValidationRoles,
        route: '/roles',
        feature: WorkspaceFeature.roleManagement,
      ),
    ],
    HelpHintId.workspaceSettings => [
      HelpTip(t.tipWorkspaceSettingsGeneral),
      HelpTip(t.tipWorkspaceSettingsPay, route: '/payment-methods'),
      HelpTip(t.tipWorkspaceSettingsLegal, route: '/legal-identity'),
      HelpTip(t.tipWorkspaceSettingsNewMembers),
      HelpTip(t.tipWorkspaceSettingsWording, route: '/settings/wording'),
      HelpTip(
        t.tipWorkspaceSettingsColours,
        route: '/settings/colours',
        feature: WorkspaceFeature.workspaceBranding,
      ),
      HelpTip(
        t.tipWorkspaceSettingsDocuments,
        route: '/reports?section=documents',
      ),
      HelpTip(t.tipWorkspaceSettingsBackup),
      HelpTip(t.tipWorkspaceSettingsSave),
    ],
    HelpHintId.badges => [
      HelpTip(t.tipBadgesQr, feature: WorkspaceFeature.qrBadges),
      HelpTip(t.tipBadgesNfc, feature: WorkspaceFeature.nfcBadges),
      HelpTip(t.tipBadgesLost),
      HelpTip(t.tipBadgesSignIn),
    ],
    HelpHintId.privacy => [
      HelpTip(t.tipPrivacyWho),
      HelpTip(t.tipPrivacyExport, feature: WorkspaceFeature.memberDataExport),
      HelpTip(t.tipPrivacyErase, feature: WorkspaceFeature.memberDataExport),
      HelpTip(t.tipPrivacyConsent, route: '/consent?review=1'),
    ],
    HelpHintId.messages => [
      HelpTip(t.tipMessagesWrite, route: '/me?tab=messages'),
      HelpTip(t.tipMessagesUnread, route: '/me?tab=messages'),
      HelpTip(t.tipMessagesAlerts, feature: WorkspaceFeature.eventsTab),
    ],
  };
}

/// The name of the form a tip links to: the title its screen carries.
String helpTipDestination(AppLocalizations l10n, String route) {
  final t = l10n;
  return switch (Uri.parse(route).path) {
    '/accessories' => t.accessoriesTitle,
    '/account-activity' => t.financesTitle,
    '/billing' => t.billingTitle,
    '/consent' => t.consentTitle,
    '/documents' => t.documentsTitle,
    '/legal-identity' => t.legalIdentityTitle,
    '/me' => t.meTabMessages,
    '/members/managed' => t.managedProfileTitle,
    '/money' => t.tabMoney,
    '/payment-methods' => t.paymentInstructionsTitle,
    '/reports' => t.uxReportsWorkspace,
    '/roles' => t.rolesTitle,
    '/settings' => t.settingsTitle,
    '/settings/colours' => t.coloursTitle,
    '/settings/wording' => t.wordingRow,
    '/workspace-code' => t.workspaceCodeTitle,
    _ => t.helpHintLearnMore,
  };
}

/// Where a fresh visit opens: the tip AFTER the last shown one,
/// rotating past the end back to 0. [lastShown] may be null (never
/// visited), stale-high (the tip list shrank) or garbage-negative —
/// the double modulo tolerates all of it.
int helpHintInitialTipIndex(int? lastShown, int tipCount) {
  if (tipCount <= 0) return 0;
  return (((lastShown ?? -1) + 1) % tipCount + tipCount) % tipCount;
}
