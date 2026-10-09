// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../features/workspace/domain/workspace_feature.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';

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
String helpHintText(AppLocalizations? l10n, HelpHintId id) => switch (id) {
  HelpHintId.reserve =>
    l10n?.helpHintReserve ??
        'Pick a day and time window, then tap a free seat to book it.',
  HelpHintId.plan =>
    l10n?.helpHintPlan ??
        'The live floor plan: tap a free seat to book it, tap your '
            'own booking to check in.',
  HelpHintId.calendar =>
    l10n?.helpHintCalendar ??
        'Pick a day or a range: everything dated that you may see, in '
            'one list, each row opening its source.',
  HelpHintId.events =>
    l10n?.helpHintEvents ??
        'Everything that happened, in one feed. Decisions waiting '
            'for you sit on top; the chips filter the rest.',
  HelpHintId.editor =>
    l10n?.helpHintEditor ??
        'Draw rooms and desks, stamp seats onto them — tap a seat '
            'twice to edit its properties.',
  HelpHintId.availability =>
    l10n?.helpHintAvailability ??
        'Set the open weekdays and working hours, and add closure '
            'days nobody can book.',
  HelpHintId.features =>
    l10n?.helpHintFeatures ??
        'Switch workspace functionality on or off — every member\'s '
            'app follows immediately.',
  HelpHintId.members =>
    l10n?.helpHintMembers ??
        'Invite members, set their plan percentage and role, and '
            'manage their badges.',
  HelpHintId.money =>
    l10n?.helpHintMoney ??
        'Your monthly bill: browse months with the arrows; pay, '
            'export or share from here.',
  HelpHintId.moneyStatement =>
    l10n?.helpHintMoneyStatement ??
        'The month as it stands: your account, days used and left, '
            'subscription, services, packages, open positions, credits '
            'and the balance. Browse months with the arrows.',
  HelpHintId.moneyPayments =>
    l10n?.helpHintMoneyPayments ??
        'Settle and ask: the balance, how to pay it or pay online, '
            'record a payment — and submit an expense, request '
            'half-days or add a consumption.',
  HelpHintId.moneyInvoices =>
    l10n?.helpHintMoneyInvoices ??
        'Your invoices: what is open and when it is due, every invoice '
            'issued to you with its status, one tap to the detail and '
            'to paying it.',
  HelpHintId.moneyDocuments =>
    l10n?.helpHintMoneyDocuments ??
        'Your paperwork: your conditions, the payments report, the '
            'month\'s statement as PDF, the document library.',
  HelpHintId.validation =>
    l10n?.helpHintValidation ??
        'Decide which actions need confirmation, who confirms, and '
            'how many approvals it takes.',
  HelpHintId.workspaceSettings =>
    l10n?.helpHintWorkspace ??
        'Country, currency, language and billing details — '
            'documents and taxes follow these settings.',
  HelpHintId.messages =>
    l10n?.helpHintMessages ??
        'Every conversation in one list, newest first. Tap the pencil to '
            'write to someone or start a group.',
  HelpHintId.privacy =>
    l10n?.helpHintPrivacy ??
        'See who can read your data and who did, export everything as '
            'one file, or leave with your personal data erased.',
  HelpHintId.badges =>
    l10n?.helpHintBadges ??
        'Issue a printable QR badge or register an NFC card; revoke '
            'lost badges any time.',
};

/// A distinctive fragment of the matching guide heading, localized —
/// the help guides are per-language, so the jump text must be too.
/// This is the surface's DEFAULT topic; a tip may carry its own.
String helpHintTopic(AppLocalizations? l10n, HelpHintId id) => switch (id) {
  HelpHintId.reserve => l10n?.helpHintReserveTopic ?? 'Reserve hub',
  HelpHintId.plan => l10n?.helpHintPlanTopic ?? 'floor plan',
  HelpHintId.calendar => l10n?.helpHintCalendarTopic ?? 'Calendar',
  HelpHintId.events => l10n?.helpHintEventsTopic ?? 'confirmations',
  HelpHintId.editor => l10n?.helpHintEditorTopic ?? 'space editor',
  HelpHintId.availability => l10n?.helpHintAvailabilityTopic ?? 'Availability',
  HelpHintId.features => l10n?.helpHintFeaturesTopic ?? 'Features',
  HelpHintId.members => l10n?.helpHintMembersTopic ?? 'Members & plans',
  HelpHintId.money => l10n?.helpHintMoneyTopic ?? 'Money',
  HelpHintId.moneyStatement =>
    l10n?.helpHintMoneyStatementTopic ?? 'The Statement face',
  HelpHintId.moneyPayments =>
    l10n?.helpHintMoneyPaymentsTopic ?? 'The Payments face',
  HelpHintId.moneyInvoices =>
    l10n?.helpHintMoneyInvoicesTopic ?? 'The Invoices face',
  HelpHintId.moneyDocuments =>
    l10n?.helpHintMoneyDocumentsTopic ?? 'The Documents face',
  HelpHintId.validation => l10n?.helpHintValidationTopic ?? 'confirmations',
  HelpHintId.workspaceSettings =>
    l10n?.helpHintWorkspaceTopic ?? 'Workspace settings',
  HelpHintId.badges => l10n?.helpHintBadgesTopic ?? 'NFC badges',
  HelpHintId.messages => l10n?.helpHintMessagesTopic ?? 'Messages',
  HelpHintId.privacy => l10n?.helpHintPrivacyTopic ?? 'Privacy',
};

/// The surface's carousel (#2313): every scenario a person may want from
/// that screen, each naming the controls by their own labels (built from
/// the label keys, so all five languages quote the real buttons) and
/// linking to the form it continues on. Regenerated from the current
/// screens; tips of a switched-off feature are filtered by [HelpHint].
List<HelpTip> helpHintTips(AppLocalizations? l10n, HelpHintId id) {
  final t = l10n ?? AppLocalizationsEn();
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
String helpTipDestination(AppLocalizations? l10n, String route) {
  final t = l10n ?? AppLocalizationsEn();
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
