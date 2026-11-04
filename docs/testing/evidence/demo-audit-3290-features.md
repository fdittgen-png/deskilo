# Demo features, setup and workspace values — #3290

Run 2026-11-04 on master `f75677088` plus this change, in the in-memory Demo (`lib/core/demo`). Pinned by
`test/core/demo/demo_feature_audit_test.dart`, whose expectations come from the feature manifest, the space's
country (`effectiveFeatures(…, country:)`, the client twin of the server's `feature_effective` + `feature_available_in`,
0486), the space's row and its invoices, not from the setup code.

## The spaces

| Space | Country | Currency | Time zone | VAT regime | Features | Setup guide |
|---|---|---|---|---|---|---|
| `ws-1` Atelier du Marché, Pézenas | FR | EUR | Europe/Paris | VAT registered | every feature but those `demoFeaturesLeftOff` names (`demo_flags.dart`) | every applicable step ready (`demo_setup_status_test`) |
| `ws-1-dev` its development twin | FR | EUR | Europe/Paris | VAT registered | its production's, same pair | not modelled (see limits) |
| `ws-2` Kontorhaus Plagwitz, Leipzig | DE | EUR | Europe/Berlin | exempt (§ 19 UStG) | a new space's defaults (`defaultFeatureFlagsForNewWorkspace`) | bookable reached; pricing next (`demo_setup_status_test`, `demo_leipzig_setup_test`) |
| `ws-3` Camden Yard Cowork, London | GB | GBP | Europe/London | VAT registered (synthetic VRN) | the main space's plus `mtdSubmission`; the EC Sales List off by country | VAT ready after this change |
| `ws-4` Hudson Cooperative, New York | US | USD | America/New_York | not subject | the main space's with the VAT family off (this change); sales tax on | no VAT step after this change |

## Findings

| # | Space | Expected (source) | Observed | Status |
|---|---|---|---|---|
| 1 | London | a VAT-registered space holds the rates its invoices charge; its VAT step is ready (`vat` evidence = rates held) | invoices at 20 % and 0 %, a prepared MTD return, but **no VAT rate**: the guide read "VAT: to configure" | FIXED: the UK's standard 20 %, reduced 5 % and zero rates seeded |
| 2 | New York | a space not subject to VAT has no VAT step and no VAT returns | the whole VAT family on: the guide asked a US space to set VAT rates, returns, e-invoicing VAT | FIXED: `vatManagement` off, its ten descendants follow by the chain; `salesTax` stays on |
| 3 | all | a step applies when its feature is effective in the space's country (server: `feature_effective` includes `feature_available_in`) | the Demo's setup status ignored the country | FIXED: `demoSetupStatus(country:)`; no step's feature is country-limited today, so this is parity, pinned for every step |
| 4 | London | its comment states its features | the comment said "a new space's … accounting connectors stay off" while the flags are the main space's | FIXED: comment states the real set |
| 5 | all | the manifest names where a feature is offered | `mtdSubmission` is UK-only in purpose but declares no `availableIn`; the Demo keeps it off outside London by its flags | FOLLOW-UP: a manifest + `feature_registry()` change (a migration), outside a Demo audit |

## Changed settings stay in their space

Switching `kioskMode` off in London makes London's kiosk step not applicable. Every other space's kiosk step is
unchanged. The change survives a persona switch (member, then owner). A fresh fixture (the Demo's reset) restores
it. Pinned in `demo_feature_audit_test`. A changed setup level stays in Leipzig (`demo_setup_status_test`). The
reset starts the guide over (`demo_setup_status_test`).

## Intentional exclusions and Demo limits

- `mcpAccess`, `webMcp`: an assistant needs a server endpoint and an OAuth account (none in the Demo).
- `recordingPrivacy`: filming mode would replace the invented cast.
- `mtdSubmission` outside London: UK only (finding 5).
- Evidence no Demo can hold, decided from what the space is (`demoMainSpaceDecidedEvidence`): a payment provider's
  account, an e-invoicing platform, a recorded export.
- The twin: its features, country, currency, time zone and VAT regime equal its production's and it shares the
  pair (pinned). Its deployment preview counts (`tariffs 1/1/0`, …) are sample content, not computed from a
  differing configuration. Its setup guide is not modelled: the Demo's guide sources cover the four production
  spaces.

## Every feature in every space

Legend: `on` = effective. `off` in Leipzig = a new space's default. `off: left off` = `demoFeaturesLeftOff`.
`off: country` = the manifest's `availableIn` excludes the country. `off: needs X` = its chain is off.

| Feature | Tier | Requires | Countries | Pézenas FR | Leipzig DE | London GB | New York US |
|---|---|---|---|---|---|---|---|
| `calendarTab` | core |  | all | on | on | on | on |
| `eventsTab` | core |  | all | on | on | on | on |
| `moneyTab` | core |  | all | on | on | on | on |
| `services` | core | `moneyTab` | all | on | on | on | on |
| `accessorySupplements` | platform | `moneyTab` | all | on | off | on | on |
| `onlinePayments` | platform | `moneyTab` | all | on | off | on | on |
| `pdfExport` | core |  | all | on | on | on | on |
| `seriesBooking` | core |  | all | on | on | on | on |
| `bookForOthers` | core |  | all | on | on | on | on |
| `pushNotifications` | core |  | all | on | on | on | on |
| `adminSeatBlocking` | platform |  | all | on | off | on | on |
| `levelBooking` | platform |  | all | on | off | on | on |
| `adminLevelAssign` | platform | `levelBooking` | all | on | off | on | on |
| `kioskMode` | platform |  | all | on | off | on | on |
| `nfcBadges` | platform | `kioskMode` | all | on | off | on | on |
| `membersDirectory` | core |  | all | on | on | on | on |
| `whatsappIntegration` | platform | `membersDirectory` | all | on | off | on | on |
| `spaceQrCodes` | core |  | all | on | on | on | on |
| `coOwner` | platform |  | all | on | off | on | on |
| `invoicing` | core | `moneyTab` | all | on | on | on | on |
| `adminInvoicing` | platform | `invoicing` | all | on | off | on | on |
| `autoCheckInOut` | platform |  | all | on | off | on | on |
| `dataExport` | core |  | all | on | on | on | on |
| `workingHours` | core |  | all | on | on | on | on |
| `invoicePdfTemplate` | platform | `invoicing` | all | on | off | on | on |
| `invoiceAddressWindow` | platform | `invoicing` | all | on | off | on | on |
| `memberNotifications` | core |  | all | on | on | on | on |
| `documents` | core |  | all | on | on | on | on |
| `dunning` | platform | `invoicing` | all | on | off | on | on |
| `memberReports` | platform | `moneyTab` | all | on | off | on | on |
| `deletionRequests` | core |  | all | on | on | on | on |
| `roleManagement` | core |  | all | on | on | on | on |
| `vatManagement` | platform | `invoicing` | all | on | off | on | off |
| `vatDeclarations` | platform | `vatManagement` | all | on | off | on | off: needs vatManagement |
| `einvoiceCustomerDelivery` | platform | `invoicing` | all | on | off | on | on |
| `planObjectDelete` | core |  | all | on | on | on | on |
| `notificationGrouping` | core | `eventsTab` | all | on | on | on | on |
| `bookingPolicies` | core |  | all | on | on | on | on |
| `nfcSeatTags` | platform |  | all | on | off | on | on |
| `qrBadges` | platform | `kioskMode` | all | on | off | on | on |
| `kioskMemberPhotos` | platform | `kioskMode` | all | on | off | on | on |
| `formHelpHints` | core |  | all | on | on | on | on |
| `uiAnimations` | core |  | all | on | on | on | on |
| `planMemberPhotos` | platform |  | all | on | off | on | on |
| `badgeSignIn` | platform | `nfcBadges` | all | on | off | on | on |
| `regionalFormats` | core |  | all | on | on | on | on |
| `calendarHub` | core | `calendarTab` | all | on | on | on | on |
| `dataAccessLog` | platform | `moneyTab` | all | on | off | on | on |
| `memberDataExport` | core |  | all | on | on | on | on |
| `financeFaces` | core | `moneyTab` | all | on | on | on | on |
| `paymentReminders` | platform | `dunning` | all | on | off | on | on |
| `supplyExpenses` | platform | `services` | all | on | off | on | on |
| `validationScopes` | platform |  | all | on | off | on | on |
| `validationChain` | platform |  | all | on | off | on | on |
| `richMessageRefs` | core | `memberNotifications` | all | on | on | on | on |
| `calendarValidations` | platform | `calendarHub` | all | on | off | on | on |
| `usageRecords` | platform | `invoicing` | all | on | off | on | on |
| `reportDesignExchange` | platform | `reportDesigner` | all | on | off | on | on |
| `reportLayouts` | platform | `reportDesigner` | all | on | off | on | on |
| `personalInfo` | core |  | all | on | on | on | on |
| `managedProfiles` | platform | `membersDirectory` | all | on | off | on | on |
| `managedProfileAccess` | platform | `managedProfiles` | all | on | off | on | on |
| `numberSequences` | platform | `invoicing` | all | on | off | on | on |
| `workspaceStatus` | platform | `invoicing` | all | on | off | on | on |
| `expenseRepartitionWizard` | platform | `expenseRepartition` | all | on | off | on | on |
| `multiSite` | platform |  | all | on | off | on | on |
| `siteDocuments` | platform | `multiSite` | all | on | off | on | on |
| `vatGroups` | platform | `vatManagement` | all | on | off | on | off: needs vatManagement |
| `vatRateHistory` | platform | `vatManagement` | all | on | off | on | off: needs vatManagement |
| `vatCounterparty` | platform | `vatManagement` | all | on | off | on | off: needs vatManagement |
| `environmentPairs` | platform |  | all | on | off | on | on |
| `deployments` | platform | `environmentPairs` | all | on | off | on | on |
| `seatDayTimeline` | core |  | all | on | on | on | on |
| `memberPaymentTerms` | platform | `invoicing` | all | on | off | on | on |
| `reportTexts` | platform | `reportDesigner` | all | on | off | on | on |
| `usageReport` | platform | `usageRecords` | all | on | off | on | on |
| `vatReport` | platform | `vatDeclarations` | all | on | off | on | off: needs vatDeclarations |
| `letterStandard` | platform | `reportLayouts` | all | on | off | on | on |
| `priceNegotiations` | platform | `moneyTab` | all | on | off | on | on |
| `scheduledExpenses` | platform | `moneyTab` | all | on | off | on | on |
| `uniqueMonograms` | core |  | all | on | on | on | on |
| `messageGestures` | core |  | all | on | on | on | on |
| `subscriptionInvoices` | platform | `invoicing` | all | on | off | on | on |
| `usageInvoices` | platform | `invoicing` | all | on | off | on | on |
| `invoiceSettlement` | platform | `invoicing` | all | on | off | on | on |
| `invoiceJourney` | platform | `invoicing` | all | on | off | on | on |
| `bookingGate` | core | `bookingPolicies` | all | on | on | on | on |
| `calendarViews` | core | `calendarHub` | all | on | on | on | on |
| `messagesHub` | core |  | all | on | on | on | on |
| `reportDesigner` | platform | `invoicePdfTemplate` | all | on | off | on | on |
| `memberPage` | core | `membersDirectory` | all | on | on | on | on |
| `invoicingWizard` | platform | `invoicing` | all | on | off | on | on |
| `expenseRepartition` | platform | `invoicing` | all | on | off | on | on |
| `settlementFold` | platform | `invoiceSettlement` | all | on | off | on | on |
| `configurationTransfer` | platform | `dataExport` | all | on | off | on | on |
| `navigationStyle` | core |  | all | on | on | on | on |
| `demoMode` | platform |  | all | on | off | on | on |
| `instanceWizard` | platform |  | all | on | off | on | on |
| `memberOrigin` | platform | `membersDirectory` | all | on | off | on | on |
| `memberEnvironments` | platform | `environmentPairs` | all | on | off | on | on |
| `workspaceLibrary` | platform |  | all | on | off | on | on |
| `singleRoomLevelNames` | core |  | all | on | on | on | on |
| `publicHolidays` | platform |  | all | on | off | on | on |
| `workspaceVocabulary` | platform |  | all | on | off | on | on |
| `carnets` | platform | `invoicing` | all | on | off | on | on |
| `workspaceBranding` | platform |  | all | on | off | on | on |
| `customRoles` | platform |  | all | on | off | on | on |
| `customFields` | platform |  | all | on | off | on | on |
| `decisionSurface` | platform |  | all | on | off | on | on |
| `recordingPrivacy` | platform |  | all | off: left off | off | off: left off | off: left off |
| `memberAccountMenu` | platform |  | all | on | off | on | on |
| `mcpAccess` | platform |  | all | off: left off | off | off: left off | off: left off |
| `calendarFileExport` | core |  | all | on | on | on | on |
| `memberGettingStarted` | core |  | all | on | on | on | on |
| `placeFeedback` | core |  | all | on | on | on | on |
| `publicListings` | core |  | all | on | off | on | on |
| `spaceInquiries` | core |  | all | on | on | on | on |
| `messageForwarding` | core | `memberNotifications` | all | on | on | on | on |
| `captureProtection` | core | `memberNotifications` | all | on | on | on | on |
| `holidayImport` | platform | `publicHolidays` | all | on | off | on | on |
| `capacityKpi` | platform |  | all | on | off | on | on |
| `accountingBook` | platform | `invoicing` | all | on | off | on | on |
| `roleAssignment` | core | `roleManagement` | all | on | on | on | on |
| `taskRecorder` | platform |  | all | on | off | on | on |
| `guestParticipation` | core |  | all | on | off | on | on |
| `messageMentions` | core | `memberNotifications` | all | on | on | on | on |
| `supplyClassification` | platform | `vatManagement` | all | on | off | on | off: needs vatManagement |
| `viesVerification` | platform | `supplyClassification` | all | on | off | on | off: needs supplyClassification |
| `recapitulativeStatement` | platform | `vatDeclarations` | @eu | on | off | off: country | off: needs vatDeclarations |
| `inputVat` | platform | `vatDeclarations` | all | on | off | on | off: needs vatDeclarations |
| `configurableSettings` | platform |  | all | on | off | on | on |
| `salesTax` | platform | `invoicing` | all | on | off | on | on |
| `meetingRooms` | platform |  | all | on | off | on | on |
| `parking` | platform |  | all | on | off | on | on |
| `webMcp` | platform | `mcpAccess` | all | off: left off | off | off: left off | off: left off |
| `purchases` | platform | `moneyTab` | all | on | off | on | on |
| `premisesLease` | platform | `scheduledExpenses` | all | on | off | on | on |
| `assetRegister` | platform | `purchases` | all | on | off | on | on |
| `externalRooms` | platform | `levelBooking` | all | on | off | on | on |
| `accountingPeriods` | platform | `accountingBook` | all | on | off | on | on |
| `biReportDesigner` | platform |  | all | on | off | on | on |
| `purchaseAnalytics` | platform | `purchases` | all | on | off | on | on |
| `workspaceOverview` | platform |  | all | on | off | on | on |
| `setupGuide` | core |  | all | on | on | on | on |
| `dataReport` | core | `dataExport` | all | on | on | on | on |
| `personalShell` | platform |  | all | on | off | on | on |
| `foreignCurrencyPurchases` | platform | `purchases` | all | on | off | on | on |
| `accountingConnectors` | platform | `accountingBook` | all | on | off | on | on |
| `bankImport` | platform | `invoicing` | all | on | off | on | on |
| `planDecor` | core |  | all | on | on | on | on |
| `mtdSubmission` | platform | `vatDeclarations` | all | off: left off | off | on | off: left off |
