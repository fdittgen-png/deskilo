// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_feature.dart';

/// Localized display name for a [WorkspaceFeature] (#146) — shared by the
/// owner Features screen and the configuration-PDF export so both read
/// from one source of truth.
String featureName(AppLocalizations l10n, WorkspaceFeature feature) =>
    switch (feature) {
      WorkspaceFeature.calendarTab => l10n.featureCalendarTab,
      WorkspaceFeature.eventsTab => l10n.featureEventsTab,
      WorkspaceFeature.moneyTab => l10n.featureMoneyTab,
      WorkspaceFeature.services => l10n.featureServices,
      WorkspaceFeature.pdfExport => l10n.featurePdfExport,
      WorkspaceFeature.seriesBooking =>
        l10n.featureSeriesBooking,
      WorkspaceFeature.bookForOthers =>
        l10n.featureBookForOthers,
      WorkspaceFeature.pushNotifications =>
        l10n.featurePushNotifications,
      WorkspaceFeature.adminSeatBlocking =>
        l10n.featureAdminSeatBlocking,
      WorkspaceFeature.accessorySupplements =>
        l10n.featureAccessorySupplements,
      WorkspaceFeature.onlinePayments =>
        l10n.featureOnlinePayments,
      WorkspaceFeature.kioskMode =>
        l10n.featureKioskMode,
      WorkspaceFeature.nfcBadges =>
        l10n.featureNfcBadges,
      WorkspaceFeature.levelBooking =>
        l10n.featureLevelBooking,
      WorkspaceFeature.membersDirectory =>
        l10n.featureMembersDirectory,
      WorkspaceFeature.whatsappIntegration =>
        l10n.featureWhatsappIntegration,
      WorkspaceFeature.spaceQrCodes =>
        l10n.featureSpaceQrCodes,
      WorkspaceFeature.coOwner =>
        l10n.featureCoOwner,
      WorkspaceFeature.invoicing =>
        l10n.featureInvoicing,
      WorkspaceFeature.adminInvoicing =>
        l10n.featureAdminInvoicing,
      WorkspaceFeature.adminLevelAssign =>
        l10n.featureAdminLevelAssign,
      WorkspaceFeature.autoCheckInOut =>
        l10n.featureAutoCheckInOut,
      WorkspaceFeature.dataExport =>
        l10n.featureDataExport,
      WorkspaceFeature.workingHours =>
        l10n.featureWorkingHours,
      WorkspaceFeature.invoicePdfTemplate =>
        l10n.featureInvoicePdfTemplate,
      WorkspaceFeature.invoiceAddressWindow =>
        l10n.featureInvoiceAddressWindow,
      WorkspaceFeature.memberNotifications =>
        l10n.featureMemberNotifications,
      WorkspaceFeature.documents =>
        l10n.featureDocuments,
      WorkspaceFeature.dunning =>
        l10n.featureDunning,
      WorkspaceFeature.memberReports =>
        l10n.featureMemberReports,
      WorkspaceFeature.deletionRequests =>
        l10n.featureDeletionRequests,
      WorkspaceFeature.roleManagement =>
        l10n.featureRoleManagement,
      WorkspaceFeature.vatManagement =>
        l10n.featureVatManagementTitle,
      WorkspaceFeature.vatDeclarations =>
        l10n.featureVatDeclarationsTitle,
      WorkspaceFeature.einvoiceCustomerDelivery =>
        l10n.featureEinvoiceCustomerDeliveryTitle,
      WorkspaceFeature.planObjectDelete =>
        l10n.featurePlanObjectDeleteTitle,
      WorkspaceFeature.notificationGrouping =>
        l10n.featureNotificationGroupingTitle,
      WorkspaceFeature.bookingPolicies =>
        l10n.featureBookingPoliciesTitle,
      WorkspaceFeature.nfcSeatTags =>
        l10n.featureNfcSeatTagsTitle,
      WorkspaceFeature.qrBadges =>
        l10n.featureQrBadgesTitle,
      WorkspaceFeature.formHelpHints =>
        l10n.featureFormHelpHintsTitle,
      WorkspaceFeature.uiAnimations =>
        l10n.featureUiAnimationsTitle,
      WorkspaceFeature.memberOrigin =>
        l10n.featureMemberOriginTitle,
      WorkspaceFeature.workspaceLibrary =>
        l10n.featureWorkspaceLibraryTitle,
      WorkspaceFeature.memberEnvironments =>
        l10n.featureMemberEnvironmentsTitle,
      WorkspaceFeature.kioskMemberPhotos =>
        l10n.featureKioskMemberPhotosTitle,
      WorkspaceFeature.planMemberPhotos =>
        l10n.featurePlanMemberPhotosTitle,

      WorkspaceFeature.regionalFormats =>
        l10n.featureRegionalFormatsTitle,


      WorkspaceFeature.calendarHub =>
        l10n.featureCalendarHubTitle,
      WorkspaceFeature.financeFaces =>
        l10n.featureFinanceFacesTitle,
      WorkspaceFeature.paymentReminders =>
        l10n.featurePaymentRemindersTitle,
      WorkspaceFeature.supplyExpenses =>
        l10n.featureSupplyExpensesTitle,
      WorkspaceFeature.validationScopes =>
        l10n.featureValidationScopesTitle,
      WorkspaceFeature.validationChain =>
        l10n.featureValidationChainTitle,
      WorkspaceFeature.richMessageRefs =>
        l10n.featureRichMessageRefsTitle,
      WorkspaceFeature.calendarValidations =>
        l10n.featureCalendarValidationsTitle,
      WorkspaceFeature.usageRecords =>
        l10n.featureUsageRecordsTitle,
      WorkspaceFeature.reportDesignExchange =>
        l10n.featureReportDesignExchangeTitle,
      WorkspaceFeature.reportLayouts =>
        l10n.featureReportLayouts,
      WorkspaceFeature.personalInfo =>
        l10n.featurePersonalInfo,
      WorkspaceFeature.managedProfiles =>
        l10n.featureManagedProfiles,
      WorkspaceFeature.numberSequences =>
        l10n.featureNumberSequences,
      WorkspaceFeature.workspaceStatus =>
        l10n.featureWorkspaceStatus,
      WorkspaceFeature.expenseRepartitionWizard =>
        l10n.featureExpenseRepartitionWizard,
      WorkspaceFeature.multiSite => l10n.featureMultiSite,
      WorkspaceFeature.siteDocuments =>
        l10n.featureSiteDocuments,
      WorkspaceFeature.demoMode => l10n.featureDemoMode,
      WorkspaceFeature.instanceWizard =>
        l10n.featureInstanceWizard,
      WorkspaceFeature.navigationStyle =>
        l10n.featureNavigationStyle,
      WorkspaceFeature.configurationTransfer =>
        l10n.featureConfigurationTransfer,
      WorkspaceFeature.vatGroups => l10n.featureVatGroups,
      WorkspaceFeature.vatRateHistory =>
        l10n.featureVatRateHistory,
      WorkspaceFeature.vatCounterparty =>
        l10n.featureVatCounterparty,
      WorkspaceFeature.supplyClassification =>
        l10n.featureSupplyClassificationTitle,
      WorkspaceFeature.viesVerification =>
        l10n.featureViesVerificationTitle,
      WorkspaceFeature.recapitulativeStatement =>
        l10n.featureRecapitulativeStatementTitle,
      WorkspaceFeature.inputVat =>
        l10n.featureInputVatTitle,
      WorkspaceFeature.environmentPairs =>
        l10n.featureEnvironmentPairs,
      WorkspaceFeature.deployments =>
        l10n.featureDeployments,
      WorkspaceFeature.managedProfileAccess =>
        l10n.featureManagedProfileAccess,
      WorkspaceFeature.seatDayTimeline =>
        l10n.featureSeatDayTimeline,
      WorkspaceFeature.memberPaymentTerms =>
        l10n.featureMemberPaymentTerms,
      WorkspaceFeature.reportTexts =>
        l10n.featureReportTexts,
      WorkspaceFeature.usageReport =>
        l10n.featureUsageReport,
      WorkspaceFeature.vatReport =>
        l10n.featureVatReport,
      WorkspaceFeature.letterStandard =>
        l10n.featureLetterStandard,
      WorkspaceFeature.priceNegotiations =>
        l10n.featurePriceNegotiationsTitle,
      WorkspaceFeature.scheduledExpenses =>
        l10n.featureScheduledExpensesTitle,
      WorkspaceFeature.uniqueMonograms =>
        l10n.featureUniqueMonogramsTitle,
      WorkspaceFeature.subscriptionInvoices =>
        l10n.featureSubscriptionInvoicesTitle,
      WorkspaceFeature.usageInvoices =>
        l10n.featureUsageInvoicesTitle,
      WorkspaceFeature.invoiceSettlement =>
        l10n.featureInvoiceSettlementTitle,
      WorkspaceFeature.invoiceJourney =>
        l10n.featureInvoiceJourneyTitle,
      WorkspaceFeature.bookingGate =>
        l10n.featureBookingGateTitle,
      WorkspaceFeature.calendarViews =>
        l10n.featureCalendarViewsTitle,
      WorkspaceFeature.messagesHub =>
        l10n.featureMessagesHubTitle,
      WorkspaceFeature.reportDesigner =>
        l10n.featureReportDesignerTitle,
      WorkspaceFeature.memberPage =>
        l10n.featureMemberPageTitle,
      WorkspaceFeature.invoicingWizard =>
        l10n.featureInvoicingWizardTitle,
      WorkspaceFeature.expenseRepartition =>
        l10n.featureExpenseRepartitionTitle,
      WorkspaceFeature.settlementFold =>
        l10n.featureSettlementFoldTitle,
      WorkspaceFeature.messageGestures =>
        l10n.featureMessageGesturesTitle,


      WorkspaceFeature.dataAccessLog =>
        l10n.featureDataAccessLogTitle,


      WorkspaceFeature.memberDataExport =>
        l10n.featureMemberDataExportTitle,
      WorkspaceFeature.badgeSignIn =>
        l10n.featureBadgeSignInTitle,
      WorkspaceFeature.singleRoomLevelNames =>
        l10n.featureSingleRoomLevelNamesTitle,
      WorkspaceFeature.carnets => l10n.featureCarnetsTitle,
      WorkspaceFeature.publicHolidays =>
        l10n.featurePublicHolidaysTitle,
      WorkspaceFeature.workspaceVocabulary =>
        l10n.featureWorkspaceVocabularyTitle,
      WorkspaceFeature.publicListings => l10n.featurePublicListings,
      WorkspaceFeature.spaceInquiries =>
        l10n.featureSpaceInquiriesTitle,
      WorkspaceFeature.messageForwarding =>
        l10n.featureMessageForwardingTitle,
      WorkspaceFeature.messageMentions =>
        l10n.featureMessageMentionsTitle,
      WorkspaceFeature.captureProtection =>
        l10n.featureCaptureProtectionTitle,
      WorkspaceFeature.holidayImport =>
        l10n.featureHolidayImportTitle,
      WorkspaceFeature.capacityKpi =>
        l10n.featureCapacityKpiTitle,
      WorkspaceFeature.accountingBook =>
        l10n.featureAccountingBookTitle,
      WorkspaceFeature.roleAssignment =>
        l10n.featureRoleAssignmentTitle,
      WorkspaceFeature.taskRecorder =>
        l10n.featureTaskRecorderTitle,
      WorkspaceFeature.guestParticipation =>
        l10n.featureGuestParticipationTitle,
      WorkspaceFeature.workspaceBranding =>
        l10n.featureWorkspaceBrandingTitle,
      WorkspaceFeature.customRoles =>
        l10n.featureCustomRolesTitle,
      WorkspaceFeature.customFields =>
        l10n.featureCustomFieldsTitle,
      _ => _lateName(l10n, feature),
    };

/// The Features screen's later entries (#2484): the main switch above is a
/// held function that may only stay or fall, so a new flag lands here.
String _lateName(AppLocalizations l10n, WorkspaceFeature feature) =>
    switch (feature) {
      WorkspaceFeature.decisionSurface =>
        l10n.featureDecisionSurfaceTitle,
      WorkspaceFeature.recordingPrivacy =>
        l10n.featureRecordingPrivacyTitle,
      WorkspaceFeature.memberAccountMenu =>
        l10n.featureMemberAccountMenuTitle,
      WorkspaceFeature.mcpAccess =>
        l10n.featureMcpAccessTitle,
      WorkspaceFeature.calendarFileExport =>
        l10n.featureCalendarFileExportTitle,
      WorkspaceFeature.memberGettingStarted =>
        l10n.featureMemberGettingStartedTitle,
      WorkspaceFeature.placeFeedback =>
        l10n.featurePlaceFeedbackTitle,
      WorkspaceFeature.configurableSettings =>
        l10n.featureConfigurableSettingsTitle,
      WorkspaceFeature.salesTax => l10n.featureSalesTaxTitle,
      WorkspaceFeature.meetingRooms => l10n.featureMeetingRoomsTitle,
      WorkspaceFeature.parking => l10n.featureParkingTitle,
      WorkspaceFeature.webMcp => l10n.featureWebMcpTitle,
      WorkspaceFeature.purchases => l10n.featurePurchasesTitle,
      WorkspaceFeature.premisesLease => l10n.featurePremisesLeaseTitle,
      WorkspaceFeature.assetRegister => l10n.featureAssetRegisterTitle,
      WorkspaceFeature.externalRooms => l10n.featureExternalRoomsTitle,
      WorkspaceFeature.accountingPeriods => l10n.featureAccountingPeriodsTitle,
      WorkspaceFeature.biReportDesigner => l10n.featureBiReportDesignerTitle,
      WorkspaceFeature.purchaseAnalytics => l10n.featurePurchaseAnalyticsTitle,
      WorkspaceFeature.workspaceOverview => l10n.featureWorkspaceOverviewTitle,
      WorkspaceFeature.setupGuide => l10n.featureSetupGuideTitle,
      _ => feature.name,
    };
