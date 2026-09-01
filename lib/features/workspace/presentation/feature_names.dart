// SPDX-License-Identifier: 0BSD
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_feature.dart';

/// Localized display name for a [WorkspaceFeature] (#146) — shared by the
/// owner Features screen and the configuration-PDF export so both read
/// from one source of truth.
String featureName(AppLocalizations? l10n, WorkspaceFeature feature) =>
    switch (feature) {
      WorkspaceFeature.calendarTab => l10n?.featureCalendarTab ?? 'Calendar tab',
      WorkspaceFeature.eventsTab => l10n?.featureEventsTab ?? 'Events tab',
      WorkspaceFeature.moneyTab => l10n?.featureMoneyTab ?? 'Money tab',
      WorkspaceFeature.services => l10n?.featureServices ?? 'Services',
      WorkspaceFeature.pdfExport => l10n?.featurePdfExport ?? 'PDF export',
      WorkspaceFeature.seriesBooking =>
        l10n?.featureSeriesBooking ?? 'Series booking',
      WorkspaceFeature.bookForOthers =>
        l10n?.featureBookForOthers ?? 'Book for others',
      WorkspaceFeature.pushNotifications =>
        l10n?.featurePushNotifications ?? 'Push notifications',
      WorkspaceFeature.adminSeatBlocking =>
        l10n?.featureAdminSeatBlocking ?? 'Admins can block seats',
      WorkspaceFeature.accessorySupplements =>
        l10n?.featureAccessorySupplements ?? 'Accessory supplements',
      WorkspaceFeature.onlinePayments =>
        l10n?.featureOnlinePayments ?? 'Online payments',
      WorkspaceFeature.kioskMode =>
        l10n?.featureKioskMode ?? 'Kiosk mode',
      WorkspaceFeature.nfcBadges =>
        l10n?.featureNfcBadges ?? 'RFID / NFC badges',
      WorkspaceFeature.levelBooking =>
        l10n?.featureLevelBooking ?? 'Level reservations',
      WorkspaceFeature.membersDirectory =>
        l10n?.featureMembersDirectory ?? 'Members directory',
      WorkspaceFeature.whatsappIntegration =>
        l10n?.featureWhatsappIntegration ?? 'WhatsApp integration',
      WorkspaceFeature.spaceQrCodes =>
        l10n?.featureSpaceQrCodes ?? 'Space QR codes',
      WorkspaceFeature.coOwner =>
        l10n?.featureCoOwner ?? 'Co-owners',
      WorkspaceFeature.invoicing =>
        l10n?.featureInvoicing ?? 'Invoices',
      WorkspaceFeature.adminInvoicing =>
        l10n?.featureAdminInvoicing ?? 'Admins issue invoices',
      WorkspaceFeature.adminLevelAssign =>
        l10n?.featureAdminLevelAssign ?? 'Admins can assign levels',
      WorkspaceFeature.autoCheckInOut =>
        l10n?.featureAutoCheckInOut ?? 'Auto check-in/out at day end',
      WorkspaceFeature.dataExport =>
        l10n?.featureDataExport ?? 'Data export (Excel)',
      WorkspaceFeature.workingHours =>
        l10n?.featureWorkingHours ?? 'Working hours',
      WorkspaceFeature.invoicePdfTemplate =>
        l10n?.featureInvoicePdfTemplate ?? 'Invoice PDF template',
      WorkspaceFeature.memberNotifications =>
        l10n?.featureMemberNotifications ?? 'Member notifications',
      WorkspaceFeature.documents =>
        l10n?.featureDocuments ?? 'Document library',
      WorkspaceFeature.dunning =>
        l10n?.featureDunning ?? 'Payment reminders (Mahnwesen)',
      WorkspaceFeature.memberReports =>
        l10n?.featureMemberReports ?? 'Member reports',
      WorkspaceFeature.deletionRequests =>
        l10n?.featureDeletionRequests ?? 'Booking deletion requests',
      WorkspaceFeature.roleManagement =>
        l10n?.featureRoleManagement ?? 'Role management',
      WorkspaceFeature.vatManagement =>
        l10n?.featureVatManagementTitle ?? 'VAT management',
      WorkspaceFeature.vatDeclarations =>
        l10n?.featureVatDeclarationsTitle ?? 'VAT declarations',
      WorkspaceFeature.einvoiceCustomerDelivery =>
        l10n?.featureEinvoiceCustomerDeliveryTitle ??
            'E-invoice delivery to customers',
      WorkspaceFeature.planObjectDelete =>
        l10n?.featurePlanObjectDeleteTitle ?? 'Delete spaces with history',
      WorkspaceFeature.notificationGrouping =>
        l10n?.featureNotificationGroupingTitle ??
            'Notification feed grouping',
      WorkspaceFeature.bookingPolicies =>
        l10n?.featureBookingPoliciesTitle ?? 'Booking policies',
      WorkspaceFeature.nfcSeatTags =>
        l10n?.featureNfcSeatTagsTitle ?? 'NFC/RFID chair tags',
      WorkspaceFeature.qrBadges =>
        l10n?.featureQrBadgesTitle ?? 'QR badges',
      WorkspaceFeature.formHelpHints =>
        l10n?.featureFormHelpHintsTitle ?? 'Help hints',
      WorkspaceFeature.uiAnimations =>
        l10n?.featureUiAnimationsTitle ?? 'Interface animations',
      WorkspaceFeature.kioskMemberPhotos =>
        l10n?.featureKioskMemberPhotosTitle ?? 'Member photos at the kiosk',
      WorkspaceFeature.planMemberPhotos =>
        l10n?.featurePlanMemberPhotosTitle ?? 'Member photos on the plan',

      WorkspaceFeature.regionalFormats =>
        l10n?.featureRegionalFormatsTitle ?? 'Region & formats',


      WorkspaceFeature.calendarHub =>
        l10n?.featureCalendarHubTitle ?? 'Calendar hub',
      WorkspaceFeature.financeFaces =>
        l10n?.featureFinanceFacesTitle ?? 'Finance faces',
      WorkspaceFeature.paymentReminders =>
        l10n?.featurePaymentRemindersTitle ?? 'Automatic payment reminders',
      WorkspaceFeature.supplyExpenses =>
        l10n?.featureSupplyExpensesTitle ?? 'Supplies from expenses',
      WorkspaceFeature.validationScopes =>
        l10n?.featureValidationScopesTitle ?? 'Validators by role or person',
      WorkspaceFeature.priceNegotiations =>
        l10n?.featurePriceNegotiationsTitle ?? 'Price negotiations',
      WorkspaceFeature.scheduledExpenses =>
        l10n?.featureScheduledExpensesTitle ?? 'Scheduled expenses',
      WorkspaceFeature.uniqueMonograms =>
        l10n?.featureUniqueMonogramsTitle ?? 'Distinct avatar initials',
      WorkspaceFeature.subscriptionInvoices =>
        l10n?.featureSubscriptionInvoicesTitle ?? 'Subscription invoices',
      WorkspaceFeature.usageInvoices =>
        l10n?.featureUsageInvoicesTitle ?? 'End-of-month invoices',
      WorkspaceFeature.invoiceSettlement =>
        l10n?.featureInvoiceSettlementTitle ?? 'Regroup invoices',
      WorkspaceFeature.messageGestures =>
        l10n?.featureMessageGesturesTitle ?? 'Swipe to quote or take back',


      WorkspaceFeature.dataAccessLog =>
        l10n?.featureDataAccessLogTitle ?? 'Data access log',


      WorkspaceFeature.memberDataExport =>
        l10n?.featureMemberDataExportTitle ?? 'Export & erasure',
      WorkspaceFeature.badgeSignIn =>
        l10n?.featureBadgeSignInTitle ?? 'Sign in with a badge',
    };
