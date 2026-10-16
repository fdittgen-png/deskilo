// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_feature.dart';

/// What each switch on the Features screen actually does, in the
/// reader's language (#146).
///
/// Extracted from `features_screen.dart` (#1190): 425 lines of copy in
/// the middle of a screen left no room for the search the screen
/// needed, and this is the half that grows every time a feature ships.
/// The screen is now about listing and filtering; this file is the
/// registry's prose.
String featureDescription(AppLocalizations l10n, WorkspaceFeature feature) =>
      switch (feature) {
        WorkspaceFeature.calendarTab => l10n.featureCalendarTabDesc,
        WorkspaceFeature.eventsTab => l10n.featureEventsTabDesc,
        WorkspaceFeature.moneyTab => l10n.featureMoneyTabDesc,
        WorkspaceFeature.services => l10n.featureServicesDesc,
        WorkspaceFeature.pdfExport => l10n.featurePdfExportDesc,
        WorkspaceFeature.seriesBooking => l10n.featureSeriesBookingDesc,
        WorkspaceFeature.bookForOthers => l10n.featureBookForOthersDesc,
        WorkspaceFeature.pushNotifications =>
          l10n.featurePushNotificationsDesc,
        WorkspaceFeature.adminSeatBlocking =>
          l10n.featureAdminSeatBlockingDesc,
        WorkspaceFeature.accessorySupplements =>
          l10n.featureAccessorySupplementsDesc,
        WorkspaceFeature.onlinePayments =>
          l10n.featureOnlinePaymentsDesc,
        WorkspaceFeature.kioskMode =>
          l10n.featureKioskModeDesc,
        WorkspaceFeature.nfcBadges =>
          l10n.featureNfcBadgesDesc,
        WorkspaceFeature.levelBooking =>
          l10n.featureLevelBookingDesc,
        WorkspaceFeature.membersDirectory =>
          l10n.featureMembersDirectoryDesc,
        WorkspaceFeature.whatsappIntegration =>
          l10n.featureWhatsappIntegrationDesc,
        WorkspaceFeature.spaceQrCodes =>
          l10n.featureSpaceQrCodesDesc,
        WorkspaceFeature.coOwner =>
          l10n.featureCoOwnerDesc,
        WorkspaceFeature.invoicing =>
          l10n.featureInvoicingDesc,
        WorkspaceFeature.adminInvoicing =>
          l10n.featureAdminInvoicingDesc,
        WorkspaceFeature.autoCheckInOut =>
          l10n.featureAutoCheckInOutDesc,
        WorkspaceFeature.dataExport =>
          l10n.featureDataExportDesc,
        WorkspaceFeature.adminLevelAssign =>
          l10n.featureAdminLevelAssignDesc,
        WorkspaceFeature.workingHours =>
          l10n.featureWorkingHoursDesc,
        WorkspaceFeature.invoicePdfTemplate =>
          l10n.featureInvoicePdfTemplateDesc,
        WorkspaceFeature.invoiceAddressWindow =>
          l10n.featureInvoiceAddressWindowDesc,
        WorkspaceFeature.memberNotifications =>
          l10n.featureMemberNotificationsDesc,
        WorkspaceFeature.documents => l10n.featureDocumentsDesc,
        WorkspaceFeature.dunning => l10n.featureDunningDesc,
        WorkspaceFeature.memberReports =>
          l10n.featureMemberReportsDesc,
        WorkspaceFeature.deletionRequests =>
          l10n.featureDeletionRequestsDesc,
        WorkspaceFeature.roleManagement =>
          l10n.featureRoleManagementDesc,
        WorkspaceFeature.vatManagement =>
          l10n.featureVatManagementDesc,
        WorkspaceFeature.vatDeclarations =>
          l10n.featureVatDeclarationsDesc,
        WorkspaceFeature.einvoiceCustomerDelivery =>
          l10n.featureEinvoiceCustomerDeliveryDesc,
        WorkspaceFeature.planObjectDelete =>
          l10n.featurePlanObjectDeleteDesc,
        WorkspaceFeature.notificationGrouping =>
          l10n.featureNotificationGroupingDesc,
        WorkspaceFeature.bookingPolicies =>
          l10n.featureBookingPoliciesDesc,
        WorkspaceFeature.nfcSeatTags =>
          l10n.featureNfcSeatTagsDesc,
        WorkspaceFeature.qrBadges =>
          l10n.featureQrBadgesDesc,
        WorkspaceFeature.formHelpHints =>
          l10n.featureFormHelpHintsDesc,
        WorkspaceFeature.workspaceLibrary =>
          l10n.featureWorkspaceLibraryDesc,
        WorkspaceFeature.memberEnvironments =>
          l10n.featureMemberEnvironmentsDesc,
        WorkspaceFeature.memberOrigin =>
          l10n.featureMemberOriginDesc,
        WorkspaceFeature.uiAnimations =>
          l10n.featureUiAnimationsDesc,
        WorkspaceFeature.kioskMemberPhotos =>
          l10n.featureKioskMemberPhotosDesc,
        WorkspaceFeature.planMemberPhotos =>
          l10n.featurePlanMemberPhotosDesc,
        WorkspaceFeature.regionalFormats =>
          l10n.featureRegionalFormatsDesc,
        WorkspaceFeature.calendarHub =>
          l10n.featureCalendarHubDesc,
        WorkspaceFeature.financeFaces =>
          l10n.featureFinanceFacesDesc,
        WorkspaceFeature.paymentReminders =>
          l10n.featurePaymentRemindersDesc,
        WorkspaceFeature.supplyExpenses =>
          l10n.featureSupplyExpensesDesc,
        WorkspaceFeature.validationScopes =>
          l10n.featureValidationScopesDesc,
        WorkspaceFeature.validationChain =>
          l10n.featureValidationChainDesc,
        WorkspaceFeature.richMessageRefs =>
          l10n.featureRichMessageRefsDesc,
        WorkspaceFeature.calendarValidations =>
          l10n.featureCalendarValidationsDesc,
        WorkspaceFeature.usageRecords =>
          l10n.featureUsageRecordsDesc,
        WorkspaceFeature.reportDesignExchange =>
          l10n.featureReportDesignExchangeDesc,
        WorkspaceFeature.reportLayouts =>
          l10n.featureReportLayoutsDesc,
        WorkspaceFeature.personalInfo =>
          l10n.featurePersonalInfoDesc,
        WorkspaceFeature.numberSequences =>
          l10n.featureNumberSequencesDesc,
        WorkspaceFeature.workspaceStatus =>
          l10n.featureWorkspaceStatusDesc,
        WorkspaceFeature.expenseRepartitionWizard =>
          l10n.featureExpenseRepartitionWizardDesc,
        WorkspaceFeature.multiSite =>
          l10n.featureMultiSiteDesc,
        WorkspaceFeature.instanceWizard =>
          l10n.featureInstanceWizardDesc,
        WorkspaceFeature.demoMode =>
          l10n.featureDemoModeDesc,
        WorkspaceFeature.navigationStyle =>
          l10n.featureNavigationStyleDesc,
        WorkspaceFeature.configurationTransfer =>
          l10n.featureConfigurationTransferDesc,
        WorkspaceFeature.siteDocuments =>
          l10n.featureSiteDocumentsDesc,
        WorkspaceFeature.vatGroups =>
          l10n.featureVatGroupsDesc,
        WorkspaceFeature.vatRateHistory =>
          l10n.featureVatRateHistoryDesc,
        WorkspaceFeature.supplyClassification => l10n.featureSupplyClassificationDesc,
        WorkspaceFeature.viesVerification => l10n.featureViesVerificationDesc,
        WorkspaceFeature.recapitulativeStatement => l10n.featureRecapitulativeStatementDesc,
        WorkspaceFeature.inputVat => l10n.featureInputVatDesc,
        WorkspaceFeature.vatCounterparty =>
          l10n.featureVatCounterpartyDesc,
        WorkspaceFeature.environmentPairs =>
          l10n.featureEnvironmentPairsDesc,
        WorkspaceFeature.deployments =>
          l10n.featureDeploymentsDesc,
        WorkspaceFeature.managedProfileAccess =>
          l10n.featureManagedProfileAccessDesc,
        WorkspaceFeature.managedProfiles =>
          l10n.featureManagedProfilesDesc,
        WorkspaceFeature.seatDayTimeline =>
          l10n.featureSeatDayTimelineDesc,
        WorkspaceFeature.memberPaymentTerms =>
          l10n.featureMemberPaymentTermsDesc,
        WorkspaceFeature.reportTexts =>
          l10n.featureReportTextsDesc,
        WorkspaceFeature.usageReport =>
          l10n.featureUsageReportDesc,
        WorkspaceFeature.vatReport =>
          l10n.featureVatReportDesc,
        WorkspaceFeature.letterStandard =>
          l10n.featureLetterStandardDesc,
        WorkspaceFeature.priceNegotiations =>
          l10n.featurePriceNegotiationsDesc,
        WorkspaceFeature.scheduledExpenses =>
          l10n.featureScheduledExpensesDesc,
        WorkspaceFeature.subscriptionInvoices =>
          l10n.featureSubscriptionInvoicesDesc,
        WorkspaceFeature.usageInvoices =>
          l10n.featureUsageInvoicesDesc,
        WorkspaceFeature.invoiceSettlement =>
          l10n.featureInvoiceSettlementDesc,
        WorkspaceFeature.settlementFold =>
          l10n.featureSettlementFoldDesc,
        WorkspaceFeature.expenseRepartition =>
          l10n.featureExpenseRepartitionDesc,
        WorkspaceFeature.invoicingWizard =>
          l10n.featureInvoicingWizardDesc,
        WorkspaceFeature.memberPage =>
          l10n.featureMemberPageDesc,
        WorkspaceFeature.reportDesigner =>
          l10n.featureReportDesignerDesc,
        WorkspaceFeature.messagesHub =>
          l10n.featureMessagesHubDesc,
        WorkspaceFeature.calendarViews =>
          l10n.featureCalendarViewsDesc,
        WorkspaceFeature.bookingGate =>
          l10n.featureBookingGateDesc,
        WorkspaceFeature.invoiceJourney =>
          l10n.featureInvoiceJourneyDesc,
        WorkspaceFeature.messageGestures =>
          l10n.featureMessageGesturesDesc,
        WorkspaceFeature.uniqueMonograms =>
          l10n.featureUniqueMonogramsDesc,
        WorkspaceFeature.dataAccessLog =>
          l10n.featureDataAccessLogDesc,
        WorkspaceFeature.memberDataExport =>
          l10n.featureMemberDataExportDesc,
        WorkspaceFeature.badgeSignIn =>
          l10n.featureBadgeSignInDesc,
        WorkspaceFeature.singleRoomLevelNames =>
          l10n.featureSingleRoomLevelNamesDesc,
        WorkspaceFeature.carnets => l10n.featureCarnetsDesc,
        WorkspaceFeature.publicHolidays =>
          l10n.featurePublicHolidaysDesc,
        WorkspaceFeature.workspaceVocabulary =>
          l10n.featureWorkspaceVocabularyDesc,
        WorkspaceFeature.publicListings => l10n.featurePublicListingsDesc,
        WorkspaceFeature.spaceInquiries =>
          l10n.featureSpaceInquiriesDesc,
        WorkspaceFeature.messageMentions => l10n.featureMessageMentionsDesc,
        WorkspaceFeature.messageForwarding =>
          l10n.featureMessageForwardingDesc,
        WorkspaceFeature.captureProtection =>
          l10n.featureCaptureProtectionDesc,
        WorkspaceFeature.holidayImport =>
          l10n.featureHolidayImportDesc,
        WorkspaceFeature.capacityKpi =>
          l10n.featureCapacityKpiDesc,
        WorkspaceFeature.accountingBook =>
          l10n.featureAccountingBookDesc,
        WorkspaceFeature.roleAssignment =>
          l10n.featureRoleAssignmentDesc,
        WorkspaceFeature.taskRecorder =>
          l10n.featureTaskRecorderDesc,
        WorkspaceFeature.guestParticipation =>
          l10n.featureGuestParticipationDesc,
      WorkspaceFeature.workspaceBranding =>
          l10n.featureWorkspaceBrandingDesc,
        WorkspaceFeature.customRoles =>
          l10n.featureCustomRolesDesc,
        WorkspaceFeature.customFields =>
          l10n.featureCustomFieldsDesc,
      _ => _lateDescription(l10n, feature),
      };

/// The Features screen's later entries (#2484): the main switch above is a
/// held function that may only stay or fall, so a new flag lands here.
String _lateDescription(AppLocalizations l10n, WorkspaceFeature feature) =>
    switch (feature) {
        WorkspaceFeature.decisionSurface =>
          l10n.featureDecisionSurfaceDesc,
        WorkspaceFeature.recordingPrivacy =>
          l10n.featureRecordingPrivacyDesc,
        WorkspaceFeature.memberAccountMenu =>
          l10n.featureMemberAccountMenuDesc,
        WorkspaceFeature.mcpAccess =>
          l10n.featureMcpAccessDesc,
        WorkspaceFeature.calendarFileExport =>
          l10n.featureCalendarFileExportDesc,
        WorkspaceFeature.memberGettingStarted =>
          l10n.featureMemberGettingStartedDesc,
        WorkspaceFeature.placeFeedback =>
          l10n.featurePlaceFeedbackDesc,
        WorkspaceFeature.configurableSettings => l10n.featureConfigurableSettingsDesc,
        WorkspaceFeature.salesTax => l10n.featureSalesTaxDesc,
        WorkspaceFeature.meetingRooms => l10n.featureMeetingRoomsDesc,
        WorkspaceFeature.parking => l10n.featureParkingDesc,
        WorkspaceFeature.webMcp => l10n.featureWebMcpDesc,
      _ => feature.name,
    };
