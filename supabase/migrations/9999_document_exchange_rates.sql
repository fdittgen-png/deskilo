-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 9999 (#3031) -- a recorded exchange rate per foreign-currency document,
-- read by the books and the FEC.
--
-- The flag `foreignCurrencyPurchases` (Money, platform, default OFF, under
-- `purchases`): a supplier's bill or credit note may be in another currency
-- than the space's, with the exchange rate recorded on it.
--
--   Store. `exchange_rate_sources` is the reference list a rate names
--     (tax_authority, bank, manual); `document_exchange_rates` keeps one
--     rate per purchase document: its currency, the space's currency, the
--     rate (one unit of the document's in the space's), its day and source.
--   Writes. `save_purchase_draft_v1` (0461's, restated whole) accepts the
--     other currency with the feature on and records the draft's
--     `exchange_rate`; `record_purchase_exchange_rate_v1` enters or corrects
--     it (managePurchases or approveExpenses) until the purchase is
--     approved; an approved purchase's rate is fixed. A purchase in another
--     currency is never approved without its rate (trigger
--     `purchase_rate_required`), and the refusal names it.
--   Books. `compute_postings` (0587's, restated whole) books such a purchase
--     and its payments in the space's currency at the recorded rate
--     (`posting_at_rate`, the app's `postingAtRate`), each line with its
--     original amount and the entry with its original currency and rate;
--     without a rate the entry blocks as `missingRate`, named.
--   VAT return. Unchanged: its input side reads member receipts and expense
--     requests, which stay in the space's currency (refused here
--     otherwise); its output side reads invoices, issued in the space's
--     currency.
--
-- Like every flag it belongs to three generated registries: the server's
-- copy of the feature manifest (dart run tool/build_feature_registry_sql.dart),
-- the template field registry (dart run tool/build_template_field_registry_sql.dart)
-- and the builtin workspace template, which writes it explicitly (off:
-- platform tier; dart run tool/build_builtin_templates.dart). Transforming
-- only in that the builtin's row is rewritten; no workspace's stored flags
-- move.

-- ── the feature registry knows it ──
create or replace function public.feature_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select '{
    "calendarTab": {"parent": null, "default": true, "core": true},
    "eventsTab": {"parent": null, "default": true, "core": true},
    "moneyTab": {"parent": null, "default": true, "core": true},
    "services": {"parent": "moneyTab", "default": true, "core": true},
    "accessorySupplements": {"parent": "moneyTab", "default": false, "core": false},
    "onlinePayments": {"parent": "moneyTab", "default": false, "core": false},
    "invoicing": {"parent": "moneyTab", "default": true, "core": true},
    "adminInvoicing": {"parent": "invoicing", "default": false, "core": false},
    "pdfExport": {"parent": null, "default": true, "core": true},
    "seriesBooking": {"parent": null, "default": true, "core": true},
    "bookForOthers": {"parent": null, "default": true, "core": true},
    "pushNotifications": {"parent": null, "default": true, "core": true},
    "adminSeatBlocking": {"parent": null, "default": false, "core": false},
    "levelBooking": {"parent": null, "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": null, "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": null, "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": null, "default": false, "core": false},
    "dataExport": {"parent": null, "default": true, "core": true},
    "workingHours": {"parent": null, "default": true, "core": true},
    "invoicePdfTemplate": {"parent": "invoicing", "default": true, "core": false},
    "invoiceAddressWindow": {"parent": "invoicing", "default": true, "core": false},
    "memberNotifications": {"parent": null, "default": true, "core": true},
    "documents": {"parent": null, "default": true, "core": true},
    "dunning": {"parent": "invoicing", "default": true, "core": false},
    "memberReports": {"parent": "moneyTab", "default": true, "core": false},
    "deletionRequests": {"parent": null, "default": true, "core": true},
    "roleManagement": {"parent": null, "default": true, "core": true},
    "vatManagement": {"parent": "invoicing", "default": true, "core": false},
    "vatDeclarations": {"parent": "vatManagement", "default": true, "core": false},
    "einvoiceCustomerDelivery": {"parent": "invoicing", "default": true, "core": false},
    "planObjectDelete": {"parent": null, "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": null, "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": null, "default": true, "core": false},
    "regionalFormats": {"parent": null, "default": true, "core": true},
    "calendarHub": {"parent": "calendarTab", "default": true, "core": true},
    "calendarViews": {"parent": "calendarHub", "default": true, "core": true},
    "messagesHub": {"parent": null, "default": true, "core": true},
    "reportDesigner": {"parent": "invoicePdfTemplate", "default": true, "core": false},
    "memberPage": {"parent": "membersDirectory", "default": true, "core": true},
    "invoicingWizard": {"parent": "invoicing", "default": true, "core": false},
    "expenseRepartition": {"parent": "invoicing", "default": true, "core": false},
    "settlementFold": {"parent": "invoiceSettlement", "default": true, "core": false},
    "configurationTransfer": {"parent": "dataExport", "default": true, "core": false},
    "navigationStyle": {"parent": null, "default": true, "core": true},
    "demoMode": {"parent": null, "default": true, "core": false},
    "instanceWizard": {"parent": null, "default": true, "core": false},
    "dataAccessLog": {"parent": "moneyTab", "default": true, "core": false},
    "memberDataExport": {"parent": null, "default": true, "core": true},
    "financeFaces": {"parent": "moneyTab", "default": true, "core": true},
    "paymentReminders": {"parent": "dunning", "default": true, "core": false},
    "supplyExpenses": {"parent": "services", "default": true, "core": false},
    "validationScopes": {"parent": null, "default": true, "core": false},
    "validationChain": {"parent": null, "default": true, "core": false},
    "richMessageRefs": {"parent": "memberNotifications", "default": true, "core": true},
    "calendarValidations": {"parent": "calendarHub", "default": true, "core": false},
    "usageRecords": {"parent": "invoicing", "default": true, "core": false},
    "reportDesignExchange": {"parent": "reportDesigner", "default": true, "core": false},
    "reportLayouts": {"parent": "reportDesigner", "default": true, "core": false},
    "personalInfo": {"parent": null, "default": true, "core": true},
    "managedProfiles": {"parent": "membersDirectory", "default": true, "core": false},
    "numberSequences": {"parent": "invoicing", "default": false, "core": false},
    "workspaceStatus": {"parent": "invoicing", "default": false, "core": false},
    "expenseRepartitionWizard": {"parent": "expenseRepartition", "default": false, "core": false},
    "multiSite": {"parent": null, "default": false, "core": false},
    "siteDocuments": {"parent": "multiSite", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": null, "default": true, "core": true},
    "memberPaymentTerms": {"parent": "invoicing", "default": true, "core": false},
    "usageReport": {"parent": "usageRecords", "default": true, "core": false},
    "reportTexts": {"parent": "reportDesigner", "default": true, "core": false},
    "letterStandard": {"parent": "reportLayouts", "default": true, "core": false},
    "vatReport": {"parent": "vatDeclarations", "default": true, "core": false},
    "priceNegotiations": {"parent": "moneyTab", "default": true, "core": false},
    "scheduledExpenses": {"parent": "moneyTab", "default": true, "core": false},
    "badgeSignIn": {"parent": "nfcBadges", "default": false, "core": false},
    "formHelpHints": {"parent": null, "default": true, "core": true},
    "uiAnimations": {"parent": null, "default": true, "core": true},
    "memberOrigin": {"parent": "membersDirectory", "default": false, "core": false},
    "memberEnvironments": {"parent": "environmentPairs", "default": false, "core": false},
    "workspaceLibrary": {"parent": null, "default": false, "core": false},
    "singleRoomLevelNames": {"parent": null, "default": true, "core": true},
    "publicHolidays": {"parent": null, "default": false, "core": false},
    "workspaceVocabulary": {"parent": null, "default": false, "core": false},
    "carnets": {"parent": "invoicing", "default": false, "core": false},
    "publicListings": {"parent": null, "default": false, "core": true},
    "workspaceBranding": {"parent": null, "default": false, "core": false},
    "customRoles": {"parent": null, "default": false, "core": false},
    "customFields": {"parent": null, "default": false, "core": false},
    "decisionSurface": {"parent": null, "default": false, "core": false},
    "recordingPrivacy": {"parent": null, "default": false, "core": false},
    "memberAccountMenu": {"parent": null, "default": false, "core": false},
    "mcpAccess": {"parent": null, "default": false, "core": false},
    "calendarFileExport": {"parent": null, "default": true, "core": true},
    "memberGettingStarted": {"parent": null, "default": true, "core": true},
    "placeFeedback": {"parent": null, "default": true, "core": true},
    "spaceInquiries": {"parent": null, "default": true, "core": true},
    "messageForwarding": {"parent": "memberNotifications", "default": true, "core": true},
    "captureProtection": {"parent": "memberNotifications", "default": true, "core": true},
    "holidayImport": {"parent": "publicHolidays", "default": false, "core": false},
    "capacityKpi": {"parent": null, "default": false, "core": false},
    "accountingBook": {"parent": "invoicing", "default": false, "core": false},
    "roleAssignment": {"parent": "roleManagement", "default": true, "core": true},
    "taskRecorder": {"parent": null, "default": false, "core": false},
    "guestParticipation": {"parent": null, "default": false, "core": true},
    "messageMentions": {"parent": "memberNotifications", "default": true, "core": true},
    "supplyClassification": {"parent": "vatManagement", "default": true, "core": false},
    "viesVerification": {"parent": "supplyClassification", "default": true, "core": false},
    "recapitulativeStatement": {"parent": "vatDeclarations", "default": true, "core": false, "countries": ["@eu"]},
    "inputVat": {"parent": "vatDeclarations", "default": true, "core": false},
    "configurableSettings": {"parent": null, "default": true, "core": false},
    "salesTax": {"parent": "invoicing", "default": true, "core": false},
    "meetingRooms": {"parent": null, "default": false, "core": false},
    "parking": {"parent": null, "default": false, "core": false},
    "webMcp": {"parent": "mcpAccess", "default": false, "core": false},
    "purchases": {"parent": "moneyTab", "default": false, "core": false},
    "premisesLease": {"parent": "scheduledExpenses", "default": false, "core": false},
    "assetRegister": {"parent": "purchases", "default": false, "core": false},
    "externalRooms": {"parent": "levelBooking", "default": false, "core": false},
    "accountingPeriods": {"parent": "accountingBook", "default": false, "core": false},
    "biReportDesigner": {"parent": null, "default": false, "core": false},
    "purchaseAnalytics": {"parent": "purchases", "default": false, "core": false},
    "workspaceOverview": {"parent": null, "default": false, "core": false},
    "setupGuide": {"parent": null, "default": true, "core": true},
    "dataReport": {"parent": "dataExport", "default": true, "core": true},
    "personalShell": {"parent": null, "default": false, "core": false},
    "foreignCurrencyPurchases": {"parent": "purchases", "default": false, "core": false}
  }'::jsonb
$registry$;
revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

-- ── the template field registry knows it ──
create or replace function public.template_field_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select $json$[
    {"id":"floor_plan[].background_path","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"a storage file of the source","process":"spaceManagement"},
    {"id":"floor_plan[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].images","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"a storage file of the source","process":"spaceManagement"},
    {"id":"floor_plan[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].color","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].h","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].accessories","entity":"floor_plan","type":"list","portability":"reference","absent":"inherit","key":"name","bindings":["accessories.name"],"process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].amenities","entity":"floor_plan","type":"list","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].chair","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].orientation","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].w","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].h","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].w","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].site","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites never travel","process":"spaceManagement"},
    {"id":"floor_plan[].sort_order","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].active","entity":"accessories","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].name","entity":"accessories","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].sort_order","entity":"accessories","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].supplement_cents","entity":"accessories","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].vat_rate","entity":"accessories","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"spaceManagement"},
    {"id":"tables.closure_days[].day","entity":"closure_days","type":"date","portability":"literal","absent":"inherit","key":"day","process":"coordination"},
    {"id":"tables.closure_days[].reason","entity":"closure_days","type":"text","portability":"literal","absent":"inherit","key":"day","process":"coordination"},
    {"id":"tables.credit_products[].active","entity":"credit_products","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].half_days","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].name","entity":"credit_products","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].price_cents","entity":"credit_products","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].sort_order","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].validity_months","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].vat_rate","entity":"credit_products","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.fee_bands[].fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].from_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].overage_fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].to_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.number_sequences[].date_part","entity":"number_sequences","type":"enumeration","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].digits","entity":"number_sequences","type":"integer","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].gapless","entity":"number_sequences","type":"boolean","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].journal","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].next_value","entity":"number_sequences","type":"integer","portability":"never","absent":"inherit","key":"journal","reason":"a counter (#1295)","process":"billingPayments"},
    {"id":"tables.number_sequences[].period_key","entity":"number_sequences","type":"text","portability":"never","absent":"inherit","key":"journal","reason":"a counter (#1295)","process":"billingPayments"},
    {"id":"tables.number_sequences[].prefix","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].reset","entity":"number_sequences","type":"enumeration","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].suffix","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.packages[].active","entity":"packages","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].days","entity":"packages","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].name","entity":"packages","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].price_cents","entity":"packages","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].vat_rate","entity":"packages","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.plans[].active","entity":"tariffs","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].base_fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].included_half_days","entity":"tariffs","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].name","entity":"tariffs","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].overage_fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].active","entity":"services","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].name","entity":"services","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].price_cents","entity":"services","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].stock","entity":"services","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].vat_rate","entity":"services","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.sites[].city","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].country_code","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].is_default","entity":"sites","type":"boolean","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].legal_id","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].name","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].postal_code","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].sort_order","entity":"sites","type":"integer","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].street","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].tax_exemption_reason","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].vat_id","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.validation_policies[].admins_may_validate","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].auto_validate_admin","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].auto_validate_owner","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].eligible_admin_ids","entity":"validation_rules","type":"list","portability":"never","absent":"inherit","key":"event_type","reason":"names people, who do not exist where a template is applied","process":"coordination"},
    {"id":"tables.validation_policies[].event_type","entity":"validation_rules","type":"text","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].min_amount_cents","entity":"validation_rules","type":"cents","portability":"unsupported","absent":"inherit","key":"event_type","reason":"the export does not carry it yet (#1655)","process":"coordination"},
    {"id":"tables.validation_policies[].owner_may_self_validate","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].owner_required","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].required_count","entity":"validation_rules","type":"integer","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].sequential","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].validator_scope","entity":"validation_rules","type":"enumeration","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.vat_rates[].active","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].category","entity":"vat","type":"enumeration","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].exemption_reason","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].group_key","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].is_default","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].label","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].outside_base","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].percent","entity":"vat","type":"decimal","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].supersedes","entity":"vat","type":"text","portability":"reference","absent":"inherit","key":"label@percent","bindings":["vat_rates.label"],"process":"billingPayments"},
    {"id":"tables.vat_rates[].valid_from","entity":"vat","type":"date","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].valid_to","entity":"vat","type":"date","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.workspace_documents[].category","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].min_role","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].provider","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].title","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].url","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_field_definitions[].active","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].contexts","entity":"field_definitions","type":"list","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].group_key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels","entity":"field_definitions","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels.{locale}.help_text","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels.{locale}.label","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options","entity":"field_definitions","type":"list","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].active","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].labels.{locale}","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].sort_order","entity":"field_definitions","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].personal_data","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].required","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].sort_order","entity":"field_definitions","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].type","entity":"field_definitions","type":"enumeration","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].validation","entity":"field_definitions","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].visibility","entity":"field_definitions","type":"enumeration","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].active","entity":"workspace_roles","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].key","entity":"workspace_roles","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].names","entity":"workspace_roles","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].names.{locale}","entity":"workspace_roles","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].permissions","entity":"workspace_roles","type":"list","portability":"literal","absent":"inherit","key":"key","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments","manageLease"],"process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].sort_order","entity":"workspace_roles","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"template.description","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.entities","entity":"template","type":"list","portability":"unsupported","absent":"inherit","reason":"what the template carries","process":"operations"},
    {"id":"template.holidays.country","entity":"closure_days","type":"text","portability":"local_binding","absent":"product_default","reason":"the target's country unless the template names one","process":"coordination"},
    {"id":"template.holidays.years","entity":"closure_days","type":"integer","portability":"literal","absent":"product_default","min":1,"max":3,"depends_on":["closure_days"],"process":"coordination"},
    {"id":"template.key","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.name","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.owner_workspace_id","entity":"template","type":"text","portability":"never","absent":"inherit","reason":"who published it","process":"operations"},
    {"id":"template.schema_version","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.sort_order","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.tags","entity":"template","type":"list","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.template_version","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.visibility","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"workspace.accessory_supplements_since","entity":"workspace","type":"date","portability":"never","absent":"inherit","reason":"a date in this space's history","process":"operations"},
    {"id":"workspace.address","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.billing_rules","entity":"tariffs","type":"map","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.new_member_defaults.overage_policy","entity":"tariffs","type":"enumeration","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.new_member_defaults.subscription_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.excluded","entity":"tariffs","type":"map","portability":"never","absent":"inherit","reason":"names people, who do not exist where a template is applied","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.method","entity":"tariffs","type":"enumeration","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.weights","entity":"tariffs","type":"map","portability":"never","absent":"inherit","reason":"names people, who do not exist where a template is applied","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.subscription_advance_days","entity":"tariffs","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"membershipCommerce"},
    {"id":"workspace.billing_rules.subscription_auto","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.usage_auto","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.usage_when_zero","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.booking_rules","entity":"booking_rules","type":"map","portability":"literal","absent":"inherit","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.admin_check_out","entity":"booking_rules","type":"boolean","portability":"literal","absent":"product_default","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.advance_horizon_days","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"max":730,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.allow_past_bookings","entity":"booking_rules","type":"boolean","portability":"literal","absent":"product_default","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.full_day_hours","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.granularity","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["flexible","half_day","minutes_5","minutes_15","minutes_30","minutes_60","full_day","hours"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.grid_within_hours","entity":"booking_rules","type":"boolean","portability":"unsupported","absent":"inherit","reason":"retired by #634; read as outside_hours_mode, never written","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.half_boundary_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.half_day_hours","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.legend_profile","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["full","simple"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.max_duration_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":5,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.max_series_days","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.min_duration_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":5,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.open_weekdays","entity":"booking_rules","type":"list","portability":"literal","absent":"product_default","min":1,"max":7,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.outside_hours_mode","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["off","free","charged","walkup_only"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.simultaneous_reservations","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"max":20,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.work_end_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.work_start_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.branding","entity":"branding","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.branding.office_palette","entity":"branding","type":"list","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.branding.seat_palette","entity":"branding","type":"enumeration","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.branding.seed_color","entity":"branding","type":"color","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.city","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.company_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.country_code","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.created_at","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_by","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_by_user","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_datetime","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.currency_code","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.default_locale","entity":"identity","type":"locale","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.desk_opacity","entity":"booking_rules","type":"percent","portability":"literal","absent":"product_default","min":20,"max":100,"process":"reservationsUsage"},
    {"id":"workspace.dev_mode","entity":"workspace","type":"boolean","portability":"never","absent":"inherit","reason":"this space's own switch","process":"operations"},
    {"id":"workspace.dunning_rules","entity":"reminders","type":"map","portability":"literal","absent":"inherit","process":"billingPayments"},
    {"id":"workspace.dunning_rules.automatic","entity":"reminders","type":"boolean","portability":"literal","absent":"product_default","process":"billingPayments"},
    {"id":"workspace.dunning_rules.between_days","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"billingPayments"},
    {"id":"workspace.dunning_rules.first_after_days","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"billingPayments"},
    {"id":"workspace.dunning_rules.levels","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":1,"max":9,"process":"billingPayments"},
    {"id":"workspace.environment","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.feature_flags","entity":"features","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.feature_flags.accessorySupplements","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.accountingBook","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.accountingPeriods","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.accountingBook"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.adminInvoicing","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.adminLevelAssign","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.levelBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.adminSeatBlocking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.assetRegister","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.purchases"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.autoCheckInOut","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.badgeSignIn","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.nfcBadges"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.biReportDesigner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.bookForOthers","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.bookingGate","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.bookingPolicies"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.bookingPolicies","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.calendarFileExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.calendarHub","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarTab"],"process":"coordination"},
    {"id":"workspace.feature_flags.calendarTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.calendarValidations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarHub"],"process":"coordination"},
    {"id":"workspace.feature_flags.calendarViews","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarHub"],"process":"coordination"},
    {"id":"workspace.feature_flags.capacityKpi","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.captureProtection","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.carnets","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.coOwner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.configurableSettings","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.configurationTransfer","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dataExport"],"process":"operations"},
    {"id":"workspace.feature_flags.customFields","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.customRoles","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.dataAccessLog","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.dataExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.dataReport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dataExport"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.decisionSurface","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.deletionRequests","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.demoMode","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.deployments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.environmentPairs"],"process":"operations"},
    {"id":"workspace.feature_flags.documents","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.dunning","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.einvoiceCustomerDelivery","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"integrations"},
    {"id":"workspace.feature_flags.environmentPairs","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.eventsTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.expenseRepartition","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.expenseRepartitionWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.expenseRepartition"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.externalRooms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.levelBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.financeFaces","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.foreignCurrencyPurchases","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.purchases"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.formHelpHints","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.guestParticipation","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.holidayImport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.publicHolidays"],"process":"spaceManagement"},
    {"id":"workspace.feature_flags.inputVat","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatDeclarations"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.instanceWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.invoiceAddressWindow","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.invoiceJourney","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicePdfTemplate","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.invoiceSettlement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicing","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicingWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.kioskMemberPhotos","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.kioskMode","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.letterStandard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportLayouts"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.levelBooking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.managedProfileAccess","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.managedProfiles"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.managedProfiles","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.mcpAccess","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"integrations"},
    {"id":"workspace.feature_flags.meetingRooms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.memberAccountMenu","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.memberDataExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.memberEnvironments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.environmentPairs"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberGettingStarted","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.memberNotifications","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.memberOrigin","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberPage","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberPaymentTerms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.memberReports","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.membersDirectory","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.messageForwarding","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.messageGestures","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.messageMentions","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.messagesHub","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.moneyTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"billingPayments"},
    {"id":"workspace.feature_flags.multiSite","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.navigationStyle","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.nfcBadges","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.nfcSeatTags","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.notificationGrouping","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.eventsTab"],"process":"coordination"},
    {"id":"workspace.feature_flags.numberSequences","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.onlinePayments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.parking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.paymentReminders","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dunning"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.pdfExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.personalInfo","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.personalShell","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.placeFeedback","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.planMemberPhotos","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.planObjectDelete","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.premisesLease","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.scheduledExpenses"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.priceNegotiations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.publicHolidays","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.publicListings","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.purchaseAnalytics","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.purchases"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.purchases","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.pushNotifications","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"integrations"},
    {"id":"workspace.feature_flags.qrBadges","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.recapitulativeStatement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatDeclarations"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.recordingPrivacy","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.regionalFormats","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.reportDesignExchange","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportDesigner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicePdfTemplate"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportLayouts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportTexts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.richMessageRefs","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.roleAssignment","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.roleManagement"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.roleManagement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.salesTax","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.scheduledExpenses","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.seatDayTimeline","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.seriesBooking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.services","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.settlementFold","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoiceSettlement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.setupGuide","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.singleRoomLevelNames","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.siteDocuments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.multiSite"],"process":"operations"},
    {"id":"workspace.feature_flags.spaceInquiries","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.spaceQrCodes","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.subscriptionInvoices","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.supplyClassification","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.supplyExpenses","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.services"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.taskRecorder","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.uiAnimations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.uniqueMonograms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.usageInvoices","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.usageRecords","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.usageReport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.usageRecords"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.validationChain","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.validationScopes","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.vatCounterparty","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatDeclarations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatGroups","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatManagement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatRateHistory","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatReport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatDeclarations"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.viesVerification","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.supplyClassification"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.webMcp","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.mcpAccess"],"process":"integrations"},
    {"id":"workspace.feature_flags.whatsappIntegration","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"integrations"},
    {"id":"workspace.feature_flags.workingHours","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.workspaceBranding","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.workspaceLibrary","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.workspaceOverview","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.workspaceStatus","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"operations"},
    {"id":"workspace.feature_flags.workspaceVocabulary","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.invitation_template","entity":"invitations","type":"text","portability":"never","absent":"inherit","reason":"names the source space and its people","process":"workspaceAccess"},
    {"id":"workspace.invitation_templates","entity":"invitations","type":"text","portability":"never","absent":"inherit","reason":"names the source space and its people","process":"workspaceAccess"},
    {"id":"workspace.invite_code","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"a secret","process":"operations"},
    {"id":"workspace.invoice_legal","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.invoice_pdf_template","entity":"document_design","type":"map","portability":"never","absent":"inherit","reason":"points at the source's image library; travels with the report design exchange","process":"documentsInformation"},
    {"id":"workspace.legal_id","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.lexicon","entity":"lexicon","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.deskDetail","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.directoryTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendBlocked","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendClosed","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendFree","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendMine","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendOccupied","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendReserved","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendUnavailable","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.levelDetail","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.levelReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.messagesTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planAfternoonChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planBookForLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planCheckInButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planCheckInTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planDurationLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planFromLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planMorningChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveClosedShort","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveDayView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveFullDayChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveMonthView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveWeekView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.shellReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindDesk","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindLevel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindOffice","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindSeat","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabCalendar","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabEvents","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabMoney","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabPlan","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.modified_by_user","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.modified_datetime","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.name","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.network_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"the birth record of this row on its own installation","process":"operations"},
    {"id":"workspace.pair_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.payment_instructions.iban","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.lydia","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.paypal_me","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.reference","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.wero","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.wise","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.postal_code","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.role_permissions","entity":"roles","type":"map","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.role_permissions.admin","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments","manageLease"],"process":"workspaceAccess"},
    {"id":"workspace.role_permissions.co_owner","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments","manageLease"],"process":"workspaceAccess"},
    {"id":"workspace.role_permissions.member","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments","manageLease"],"process":"workspaceAccess"},
    {"id":"workspace.site_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.street","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.subscription_levels","entity":"tariffs","type":"map","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.allow_custom","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.enabled_presets","entity":"tariffs","type":"list","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.extra_levels","entity":"tariffs","type":"list","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.subscription_vat_rate","entity":"vat","type":"text","portability":"reference","absent":"inherit","bindings":["vat_rates.label"],"process":"billingPayments"},
    {"id":"workspace.tax_exemption_reason","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.timezone","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.vat_account","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.vat_id","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.vat_regime","entity":"identity","type":"enumeration","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.visibility","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"the space's own listing choice; a template must not publish a space","process":"operations"},
    {"id":"workspace.visibility_set_at","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"the space's own listing choice; a template must not publish a space","process":"operations"},
    {"id":"workspace.whatsapp_group","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"}
  ]$json$::jsonb
$registry$;
revoke execute on function public.template_field_registry() from public, anon;
grant execute on function public.template_field_registry() to authenticated;

-- ── the builtin template carries `foreignCurrencyPurchases` (off: platform tier) ──
insert into public.workspace_templates
  (key, name, description, sort_order, visibility, schema_version, template_version,
   tags, entities, configuration, floor_plan)
values (
  'association_fr',
  'Association de coworking (France)',
  'Pour une association de coworking en France : demi-journées de 7 h à 13 h et de 13 h à 19 h du lundi au vendredi, jours fériés de l''année et de la suivante, cotisations à 50 % et 100 %, deux carnets prépayés pour qui ne cotise pas, les rôles du bureau, un calendrier où se prennent les validations, les mots de l''association, et deux étages prêts à réserver.',
  1,
  'builtin',
  1,
  1,
  array['association', 'coworking', 'france'],
  array['identity', 'tariffs', 'credit_products', 'floor_plan', 'booking_rules', 'closure_days', 'lexicon', 'workspace_roles', 'features'],
  $cfg$
{
  "workspace": {
    "default_locale": "fr",
    "vat_regime": "not_subject",
    "booking_rules": {
      "granularity": "half_day",
      "open_weekdays": [
        1,
        2,
        3,
        4,
        5
      ],
      "work_start_minutes": 420,
      "half_boundary_minutes": 780,
      "work_end_minutes": 1140,
      "max_series_days": 180,
      "advance_horizon_days": 90,
      "max_duration_minutes": 1440,
      "min_duration_minutes": 30
    },
    "subscription_levels": {
      "allow_custom": false,
      "extra_levels": [],
      "enabled_presets": [
        50,
        100
      ]
    },
    "feature_flags": {
      "accessorySupplements": false,
      "accountingBook": false,
      "accountingPeriods": false,
      "adminInvoicing": false,
      "adminLevelAssign": false,
      "adminSeatBlocking": false,
      "assetRegister": false,
      "autoCheckInOut": false,
      "badgeSignIn": false,
      "biReportDesigner": false,
      "bookForOthers": true,
      "bookingGate": true,
      "bookingPolicies": true,
      "calendarFileExport": true,
      "calendarHub": true,
      "calendarTab": true,
      "calendarValidations": true,
      "calendarViews": true,
      "capacityKpi": false,
      "captureProtection": true,
      "carnets": true,
      "coOwner": false,
      "configurableSettings": false,
      "configurationTransfer": false,
      "customFields": false,
      "customRoles": true,
      "dataAccessLog": false,
      "dataExport": true,
      "dataReport": true,
      "decisionSurface": false,
      "deletionRequests": true,
      "demoMode": false,
      "deployments": false,
      "documents": true,
      "dunning": false,
      "einvoiceCustomerDelivery": false,
      "environmentPairs": false,
      "eventsTab": false,
      "expenseRepartition": false,
      "expenseRepartitionWizard": false,
      "externalRooms": false,
      "financeFaces": true,
      "foreignCurrencyPurchases": false,
      "formHelpHints": true,
      "guestParticipation": false,
      "holidayImport": false,
      "inputVat": false,
      "instanceWizard": false,
      "invoiceAddressWindow": false,
      "invoiceJourney": false,
      "invoicePdfTemplate": false,
      "invoiceSettlement": false,
      "invoicing": true,
      "invoicingWizard": false,
      "kioskMemberPhotos": false,
      "kioskMode": false,
      "letterStandard": false,
      "levelBooking": false,
      "managedProfileAccess": false,
      "managedProfiles": false,
      "mcpAccess": false,
      "meetingRooms": false,
      "memberAccountMenu": false,
      "memberDataExport": true,
      "memberEnvironments": false,
      "memberGettingStarted": true,
      "memberNotifications": true,
      "memberOrigin": false,
      "memberPage": false,
      "memberPaymentTerms": false,
      "memberReports": false,
      "membersDirectory": false,
      "messageForwarding": true,
      "messageGestures": true,
      "messageMentions": true,
      "messagesHub": true,
      "moneyTab": true,
      "multiSite": false,
      "navigationStyle": true,
      "nfcBadges": false,
      "nfcSeatTags": false,
      "notificationGrouping": false,
      "numberSequences": false,
      "onlinePayments": false,
      "parking": false,
      "paymentReminders": false,
      "pdfExport": true,
      "personalInfo": true,
      "personalShell": false,
      "placeFeedback": true,
      "planMemberPhotos": false,
      "planObjectDelete": true,
      "premisesLease": false,
      "priceNegotiations": false,
      "publicHolidays": false,
      "publicListings": false,
      "purchaseAnalytics": false,
      "purchases": false,
      "pushNotifications": true,
      "qrBadges": false,
      "recapitulativeStatement": false,
      "recordingPrivacy": false,
      "regionalFormats": true,
      "reportDesignExchange": false,
      "reportDesigner": false,
      "reportLayouts": false,
      "reportTexts": false,
      "richMessageRefs": true,
      "roleAssignment": true,
      "roleManagement": true,
      "salesTax": false,
      "scheduledExpenses": false,
      "seatDayTimeline": true,
      "seriesBooking": true,
      "services": true,
      "settlementFold": false,
      "setupGuide": true,
      "singleRoomLevelNames": true,
      "siteDocuments": false,
      "spaceInquiries": true,
      "spaceQrCodes": true,
      "subscriptionInvoices": false,
      "supplyClassification": false,
      "supplyExpenses": false,
      "taskRecorder": false,
      "uiAnimations": true,
      "uniqueMonograms": true,
      "usageInvoices": false,
      "usageRecords": false,
      "usageReport": false,
      "validationChain": false,
      "validationScopes": false,
      "vatCounterparty": false,
      "vatDeclarations": false,
      "vatGroups": false,
      "vatManagement": false,
      "vatRateHistory": false,
      "vatReport": false,
      "viesVerification": false,
      "webMcp": false,
      "whatsappIntegration": false,
      "workingHours": true,
      "workspaceBranding": false,
      "workspaceLibrary": false,
      "workspaceOverview": false,
      "workspaceStatus": false,
      "workspaceVocabulary": true
    },
    "lexicon": {
      "fr": {
        "spaceKindSeat": "Place",
        "spaceKindLevel": "Étage",
        "shellReserveButton": "Réservations"
      }
    }
  },
  "tables": {
    "fee_bands": [
      {
        "from_pct": 0,
        "to_pct": 50,
        "fee_cents": 5000,
        "overage_fee_cents": 0
      },
      {
        "from_pct": 50,
        "to_pct": 100,
        "fee_cents": 10000,
        "overage_fee_cents": 0
      }
    ],
    "workspace_roles": [
      {
        "key": "tresorier",
        "names": {
          "fr": "Trésorier·ère",
          "en": "Treasurer",
          "de": "Kassenwart",
          "es": "Tesorero/a",
          "it": "Tesoriere"
        },
        "permissions": [
          "viewFinances",
          "issueInvoices",
          "manageBilling",
          "approveExpenses",
          "exportData"
        ],
        "sort_order": 1,
        "active": true
      },
      {
        "key": "secretaire",
        "names": {
          "fr": "Secrétaire",
          "en": "Secretary",
          "de": "Schriftführer",
          "es": "Secretario/a",
          "it": "Segretario"
        },
        "permissions": [
          "manageMembers",
          "manageDocuments",
          "viewPersonalData"
        ],
        "sort_order": 2,
        "active": true
      },
      {
        "key": "referent_salle",
        "names": {
          "fr": "Référent·e de salle",
          "en": "Room steward",
          "de": "Raumverantwortlicher",
          "es": "Responsable de sala",
          "it": "Referente di sala"
        },
        "permissions": [
          "manageReservations",
          "manageValidation",
          "operateKiosk"
        ],
        "sort_order": 3,
        "active": true
      }
    ],
    "credit_products": [
      {
        "name": "Carnet 10 demi-journées",
        "half_days": 10,
        "price_cents": 5000,
        "validity_months": null,
        "active": true,
        "sort_order": 1
      },
      {
        "name": "Carnet 20 demi-journées",
        "half_days": 20,
        "price_cents": 8000,
        "validity_months": null,
        "active": true,
        "sort_order": 2
      }
    ]
  },
  "holidays": {
    "years": 2
  }
}
$cfg$::jsonb,
  $tpl$
[
  {
    "name": "Rez-de-chaussée",
    "sort_order": 0,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle principale",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 1",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "A1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "A2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 2",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "B1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "B2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  },
  {
    "name": "Étage",
    "sort_order": 1,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle du haut",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 3",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "C1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "C2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 4",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "D1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "D2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  }
]
$tpl$::jsonb
)
on conflict (key) where owner_workspace_id is null do update
  set name = excluded.name,
      description = excluded.description,
      sort_order = excluded.sort_order,
      schema_version = excluded.schema_version,
      template_version = public.workspace_templates.template_version + 1,
      tags = excluded.tags,
      entities = excluded.entities,
      configuration = excluded.configuration,
      floor_plan = excluded.floor_plan;

-- ── the sources a rate may name: reference data, not code ─────────────
-- A rate says where its figure came from. The list is the platform's
-- reference data: a source is added by a row, retired by `active = false`,
-- never renamed (a recorded rate keeps naming it).
create table if not exists public.exchange_rate_sources (
  code text primary key check (code ~ '^[a-z][a-z_]{1,39}$'),
  sort_order integer not null default 0,
  active boolean not null default true
);
select public.ensure_system_columns('exchange_rate_sources');
alter table public.exchange_rate_sources enable row level security;
revoke all on public.exchange_rate_sources from public, anon, authenticated;
grant select on public.exchange_rate_sources to authenticated;
drop policy if exists exchange_rate_sources_read on public.exchange_rate_sources;
create policy exchange_rate_sources_read on public.exchange_rate_sources
  for select to authenticated using (true);
drop policy if exists mcp_delegated_deny on public.exchange_rate_sources;
create policy mcp_delegated_deny on public.exchange_rate_sources as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.exchange_rate_sources;
create policy personal_native_session on public.exchange_rate_sources
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));
insert into public.exchange_rate_sources (code, sort_order) values
  ('tax_authority', 1),   -- the rate the tax authority publishes for the tax point
  ('bank', 2),            -- the rate the bank applied to the payment
  ('manual', 3)           -- a figure a person entered from elsewhere
on conflict (code) do nothing;

-- ── the rate recorded with a document ─────────────────────────────────
-- One row per document in another currency than the space's: how many
-- units of the space's currency one unit of the document's is worth, on
-- which day, from which source. Written only by the definer functions
-- below; read by whoever may read the document.
create table if not exists public.document_exchange_rates (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  document_kind text not null check (document_kind in ('purchase')),
  document_id uuid not null references public.purchase_documents (id) on delete cascade,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  functional_currency text not null check (functional_currency ~ '^[A-Z]{3}$'),
  rate numeric not null check (rate > 0 and scale(rate) <= 10),
  rate_date date not null,
  source text not null references public.exchange_rate_sources (code),
  recorded_by_member_id uuid references public.members (id) on delete set null,
  revision integer not null default 1 check (revision >= 1),
  constraint document_exchange_rates_currencies check (currency <> functional_currency),
  constraint document_exchange_rates_document unique (workspace_id, document_kind, document_id)
);
select public.ensure_system_columns('document_exchange_rates');
create index if not exists document_exchange_rates_document_idx
  on public.document_exchange_rates (document_id);
alter table public.document_exchange_rates enable row level security;
revoke all on public.document_exchange_rates from public, anon, authenticated;
grant select on public.document_exchange_rates to authenticated;
drop policy if exists document_exchange_rates_select on public.document_exchange_rates;
create policy document_exchange_rates_select on public.document_exchange_rates
  for select to authenticated
  using (exists (
    select 1 from public.purchase_documents d
     where d.workspace_id = document_exchange_rates.workspace_id
       and d.id = document_exchange_rates.document_id));
drop policy if exists mcp_delegated_deny on public.document_exchange_rates;
create policy mcp_delegated_deny on public.document_exchange_rates as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the minor digits of a currency (ISO 4217) ─────────────────────────
-- A standard's fixed table, the same as `Currencies` in the app (pinned by
-- currency_minor_digits_test): no minor unit, three, else two.
create or replace function public.currency_minor_digits(p_currency text)
returns integer language sql immutable set search_path = public as $fn$
  select case
    when upper(p_currency) = any (array['BIF', 'CLP', 'DJF', 'GNF', 'ISK', 'JPY', 'KMF', 'KRW', 'PYG',
                                        'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF']) then 0
    when upper(p_currency) = any (array['BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND']) then 3
    else 2 end;
$fn$;
revoke execute on function public.currency_minor_digits(text) from public, anon;
grant execute on function public.currency_minor_digits(text) to authenticated;

-- ── an entry at its document's rate ───────────────────────────────────
-- Each line converted once, rounded half away from zero, with the amount it
-- was converted from (`original_cents`); the cents the rounding leaves go to
-- the largest line of the side that is short (the first of equal ones), so
-- the entry stays balanced. The app's twin is `postingAtRate`.
create or replace function public.posting_at_rate(
  p_entry jsonb, p_currency text, p_rate numeric, p_rate_date date, p_source text
) returns jsonb language plpgsql immutable set search_path = public as $fn$
declare
  v_from text := p_entry ->> 'currency';
  v_scale numeric := power(10::numeric,
    public.currency_minor_digits(p_currency) - public.currency_minor_digits(v_from));
  v_lines jsonb := '[]'::jsonb;
  l jsonb;
  v_debit bigint;
  v_credit bigint;
  v_gap bigint := 0;
  v_side text;
  v_best int := -1;
  v_best_amount bigint := 0;
  v_i int;
begin
  for l in select e from jsonb_array_elements(coalesce(p_entry -> 'lines', '[]'::jsonb)) e loop
    if l ? 'blocked' then
      v_lines := v_lines || jsonb_build_array(l);
      continue;
    end if;
    v_debit := round((l ->> 'debit_cents')::bigint * p_rate * v_scale)::bigint;
    v_credit := round((l ->> 'credit_cents')::bigint * p_rate * v_scale)::bigint;
    v_gap := v_gap + v_debit - v_credit;
    v_lines := v_lines || jsonb_build_array(l || jsonb_build_object(
      'debit_cents', v_debit, 'credit_cents', v_credit,
      'original_cents', case when (l ->> 'debit_cents')::bigint <> 0
                             then (l ->> 'debit_cents')::bigint else (l ->> 'credit_cents')::bigint end));
  end loop;
  if v_gap <> 0 then
    -- Debits ahead: the largest credit takes the cents; credits ahead: the
    -- largest debit does.
    v_side := case when v_gap > 0 then 'credit_cents' else 'debit_cents' end;
    for v_i in 0 .. jsonb_array_length(v_lines) - 1 loop
      l := v_lines -> v_i;
      if l ? 'blocked' or (l ->> v_side)::bigint = 0 then continue; end if;
      if v_best < 0 or (l ->> v_side)::bigint > v_best_amount then
        v_best := v_i;
        v_best_amount := (l ->> v_side)::bigint;
      end if;
    end loop;
    if v_best >= 0 then
      v_lines := jsonb_set(v_lines, array[v_best::text, v_side], to_jsonb(v_best_amount + abs(v_gap)));
    end if;
  end if;
  return p_entry || jsonb_build_object(
    'currency', p_currency, 'original_currency', v_from,
    'exchange_rate', jsonb_build_object('rate', p_rate::text, 'rate_date', p_rate_date, 'source', p_source),
    'lines', v_lines);
end;
$fn$;
revoke execute on function public.posting_at_rate(jsonb, text, numeric, date, text) from public, anon, authenticated;

-- ── recording a rate ──────────────────────────────────────────────────
-- The one writer of the table, for the two doors below: a purchase in
-- another currency than the space's, a rate from the reference list. A
-- recorded rate is corrected while the purchase is a draft or awaits its
-- approval; once approved it is fixed (an approved purchase with none may
-- still receive its first, so the books it blocks can be completed).
create or replace function public.purchase_exchange_rate_write(
  p_workspace_id uuid, p_purchase_id uuid, p_member_id uuid, p_rate jsonb
) returns public.document_exchange_rates
language plpgsql security definer set search_path = public as $fn$
declare
  v_doc public.purchase_documents;
  v_space text;
  v_rate numeric;
  v_day date;
  v_source text := nullif(p_rate ->> 'source', '');
  v_row public.document_exchange_rates;
begin
  select * into v_doc from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id;
  if v_doc.id is null then raise exception 'unknown purchase'; end if;
  select w.currency_code into v_space from public.workspaces w where w.id = p_workspace_id;
  if v_doc.currency = v_space then
    raise exception 'the purchase is in the currency of the space' using errcode = '22023';
  end if;
  begin
    v_rate := (p_rate ->> 'rate')::numeric;
    v_day := (p_rate ->> 'rate_date')::date;
  exception when others then
    raise exception 'a rate is a positive number with its date' using errcode = '22023';
  end;
  if v_rate is null or v_rate <= 0 or scale(v_rate) > 10 or v_day is null then
    raise exception 'a rate is a positive number with its date' using errcode = '22023';
  end if;
  if not exists (select 1 from public.exchange_rate_sources s where s.code = v_source and s.active) then
    raise exception 'unknown rate source' using errcode = '22023';
  end if;
  select * into v_row from public.document_exchange_rates x
   where x.workspace_id = p_workspace_id and x.document_kind = 'purchase' and x.document_id = v_doc.id
   for update;
  if v_row.id is not null and v_doc.state not in ('draft', 'pending') then
    raise exception 'the rate of an approved purchase is fixed' using errcode = '22023';
  end if;
  if v_row.id is null and v_doc.state not in ('draft', 'pending', 'approved') then
    raise exception 'only an open or approved purchase receives a rate' using errcode = '22023';
  end if;
  insert into public.document_exchange_rates
    (workspace_id, document_kind, document_id, currency, functional_currency, rate, rate_date,
     source, recorded_by_member_id)
  values (p_workspace_id, 'purchase', v_doc.id, v_doc.currency, v_space, v_rate, v_day, v_source, p_member_id)
  on conflict (workspace_id, document_kind, document_id) do update
    set currency = excluded.currency, functional_currency = excluded.functional_currency,
        rate = excluded.rate, rate_date = excluded.rate_date, source = excluded.source,
        recorded_by_member_id = excluded.recorded_by_member_id,
        revision = public.document_exchange_rates.revision + 1
  returning * into v_row;
  return v_row;
end;
$fn$;
revoke execute on function public.purchase_exchange_rate_write(uuid, uuid, uuid, jsonb)
  from public, anon, authenticated;

-- Enters or corrects the rate of a purchase in another currency: whoever
-- captures supplier bills or approves them, with the feature on.
create or replace function public.record_purchase_exchange_rate_v1(
  p_workspace_id uuid, p_purchase_id uuid, p_rate numeric, p_rate_date date, p_source text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_row public.document_exchange_rates;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'foreignCurrencyPurchases') then
    raise exception 'purchases in another currency are switched off in this space';
  end if;
  if not (public.has_permission(p_workspace_id, 'managePurchases')
          or public.has_permission(p_workspace_id, 'approveExpenses')) then
    raise exception 'not allowed to record an exchange rate' using errcode = '42501';
  end if;
  v_row := public.purchase_exchange_rate_write(p_workspace_id, p_purchase_id, v_me,
    jsonb_build_object('rate', p_rate::text, 'rate_date', p_rate_date, 'source', p_source));
  return jsonb_build_object(
    'document_id', v_row.document_id, 'currency', v_row.currency,
    'functional_currency', v_row.functional_currency, 'rate', v_row.rate::text,
    'rate_date', v_row.rate_date, 'source', v_row.source, 'revision', v_row.revision);
end;
$fn$;
revoke execute on function public.record_purchase_exchange_rate_v1(uuid, uuid, numeric, date, text)
  from public, anon;
grant execute on function public.record_purchase_exchange_rate_v1(uuid, uuid, numeric, date, text)
  to authenticated;

-- ── no approval without the rate ──────────────────────────────────────
-- A purchase in another currency than the space's is approved only with
-- its rate recorded: the refusal names the document.
create or replace function public.purchase_rate_required()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_space text;
begin
  if new.state = 'approved' and old.state is distinct from 'approved' then
    select w.currency_code into v_space from public.workspaces w where w.id = new.workspace_id;
    if new.currency <> v_space and not exists (
         select 1 from public.document_exchange_rates x
          where x.workspace_id = new.workspace_id and x.document_kind = 'purchase'
            and x.document_id = new.id) then
      raise exception 'the purchase % in % has no recorded exchange rate',
        coalesce(nullif(new.original_reference, ''), new.id::text), new.currency
        using errcode = '22023';
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.purchase_rate_required() from public, anon, authenticated;
drop trigger if exists purchase_rate_required on public.purchase_documents;
create trigger purchase_rate_required
  before update of state on public.purchase_documents
  for each row execute function public.purchase_rate_required();

-- ── saving a draft: 0461's, a supplier's bill in another currency ─────
-- With the feature on, a supplier's bill or credit note may be in another
-- currency than the space's; its rate comes in `exchange_rate` and is
-- recorded with it (the same rules as record_purchase_exchange_rate_v1).
-- A member's receipt stays in the space's currency: the member's account
-- is kept in it. A credit note is in its bill's currency.
create or replace function public.save_purchase_draft_v1(
  p_workspace_id uuid, p_request_id uuid, p_expected_revision int, p_payload jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_id uuid := nullif(p_payload ->> 'purchase_id', '')::uuid;
  v_kind text;
  v_doc public.purchase_documents;
  v_ws public.workspaces;
  v_supplier uuid := nullif(p_payload ->> 'supplier_id', '')::uuid;
  v_payer text;
  v_payer_member uuid;
  v_manager boolean;
  v_currency text;
  v_original uuid := nullif(p_payload ->> 'original_document_id', '')::uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'purchases') then
    raise exception 'purchases are switched off in this space';
  end if;
  v_digest := md5(auth.uid()::text || coalesce(p_expected_revision, 0)::text || p_payload::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'save', v_digest);
  if v_done is not null then return v_done; end if;

  select * into v_ws from public.workspaces where id = p_workspace_id;
  v_manager := public.has_permission(p_workspace_id, 'managePurchases');
  v_kind := coalesce(nullif(p_payload ->> 'kind', ''), 'member_receipt');
  if v_kind not in ('bill', 'credit_note', 'member_receipt') then
    raise exception 'unknown purchase kind';
  end if;
  if v_kind <> 'member_receipt' and not v_manager then
    raise exception 'not allowed to capture supplier bills';
  end if;
  v_currency := upper(coalesce(nullif(p_payload ->> 'currency', ''), v_ws.currency_code));
  if v_currency !~ '^[A-Z]{3}$' then raise exception 'a currency is three capital letters'; end if;
  if v_currency <> v_ws.currency_code
     and (v_kind = 'member_receipt'
          or not public.feature_effective(p_workspace_id, 'foreignCurrencyPurchases')) then
    raise exception 'a purchase is in the currency of the space';
  end if;
  if v_supplier is not null and not exists (
       select 1 from public.suppliers s
        where s.id = v_supplier and s.workspace_id = p_workspace_id and s.status = 'active') then
    raise exception 'unknown supplier';
  end if;
  if v_original is not null and (v_kind <> 'credit_note' or not exists (
       select 1 from public.purchase_documents o
        where o.id = v_original and o.workspace_id = p_workspace_id and o.kind = 'bill')) then
    raise exception 'a credit note reverses a bill of this space';
  end if;
  if v_original is not null and not exists (
       select 1 from public.purchase_documents o where o.id = v_original and o.currency = v_currency) then
    raise exception 'a credit note is in the currency of its bill';
  end if;
  if v_kind = 'member_receipt' then
    v_payer := 'member';
    v_payer_member := v_me;
  else
    v_payer := coalesce(nullif(p_payload ->> 'payer_kind', ''), 'unpaid');
    if v_payer not in ('workspace', 'member', 'unpaid') then raise exception 'unknown payer'; end if;
    v_payer_member := case when v_payer = 'member'
      then nullif(p_payload ->> 'payer_member_id', '')::uuid end;
    if v_payer = 'member' and not exists (
         select 1 from public.members m
          where m.id = v_payer_member and m.workspace_id = p_workspace_id) then
      raise exception 'unknown payer member';
    end if;
  end if;

  if v_id is null then
    if coalesce(p_expected_revision, 0) <> 0 then raise exception 'stale revision'; end if;
    insert into public.purchase_documents
      (workspace_id, kind, currency, category, supplier_id, original_reference, original_date,
       received_on, service_from, service_to, due_on, submitter_member_id, payer_kind,
       payer_member_id, original_document_id)
    values
      (p_workspace_id, v_kind, v_currency, left(coalesce(p_payload ->> 'category', ''), 80),
       v_supplier, left(coalesce(p_payload ->> 'original_reference', ''), 200),
       nullif(p_payload ->> 'original_date', '')::date, nullif(p_payload ->> 'received_on', '')::date,
       nullif(p_payload ->> 'service_from', '')::date, nullif(p_payload ->> 'service_to', '')::date,
       nullif(p_payload ->> 'due_on', '')::date, v_me, v_payer, v_payer_member, v_original)
    returning * into v_doc;
  else
    select * into v_doc from public.purchase_documents
     where id = v_id and workspace_id = p_workspace_id for update;
    if v_doc.id is null then raise exception 'unknown purchase'; end if;
    if v_doc.kind = 'member_receipt' and v_doc.submitter_member_id <> v_me then
      raise exception 'not your purchase';
    end if;
    if v_doc.kind <> 'member_receipt' and not v_manager then
      raise exception 'not allowed to capture supplier bills';
    end if;
    if v_doc.kind <> v_kind then raise exception 'the kind of a purchase does not change'; end if;
    if v_doc.state <> 'draft' then raise exception 'only a draft can be edited'; end if;
    if v_doc.revision <> coalesce(p_expected_revision, 0) then raise exception 'stale revision'; end if;
    update public.purchase_documents set
        revision = revision + 1,
        currency = v_currency,
        category = left(coalesce(p_payload ->> 'category', ''), 80),
        supplier_id = v_supplier,
        original_reference = left(coalesce(p_payload ->> 'original_reference', ''), 200),
        original_date = nullif(p_payload ->> 'original_date', '')::date,
        received_on = nullif(p_payload ->> 'received_on', '')::date,
        service_from = nullif(p_payload ->> 'service_from', '')::date,
        service_to = nullif(p_payload ->> 'service_to', '')::date,
        due_on = nullif(p_payload ->> 'due_on', '')::date,
        payer_kind = v_payer, payer_member_id = v_payer_member,
        original_document_id = v_original
      where id = v_doc.id
      returning * into v_doc;
  end if;
  perform public.purchase_write_lines(p_workspace_id, v_doc.id, p_payload -> 'lines');
  -- The rate goes with the currency: back in the space's currency, a draft
  -- keeps none.
  if v_currency = v_ws.currency_code then
    delete from public.document_exchange_rates x
     where x.workspace_id = p_workspace_id and x.document_kind = 'purchase' and x.document_id = v_doc.id;
  elsif jsonb_typeof(p_payload -> 'exchange_rate') = 'object' then
    perform public.purchase_exchange_rate_write(p_workspace_id, v_doc.id, v_me, p_payload -> 'exchange_rate');
  end if;
  v_result := jsonb_build_object('purchase_id', v_doc.id, 'revision', v_doc.revision,
                                 'state', v_doc.state);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'save', v_digest, v_result);
end;
$fn$;
revoke execute on function public.save_purchase_draft_v1(uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.save_purchase_draft_v1(uuid, uuid, int, jsonb) to authenticated;

-- ── the books: 0587's engine, restated whole ──────────────────────────
-- Only a purchase in another currency than the space's changes: booked at
-- its recorded rate, or blocked, named, without one.
create or replace function public.compute_postings(
  p_workspace_id uuid, p_issuer_site_id uuid, p_from date, p_to date
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_country text;
  v_postings jsonb := '[]'::jsonb;
  v_blockers jsonb := '{}'::jsonb;
  i record;
  m record;
  t record;
  v_lines jsonb;
  v_gross bigint;
  v_paid bigint;
  v_spent bigint;
  v_day date;
  v_rest bigint;
  v_left bigint;
  v_part bigint;
  v_tax bigint;
  v_n int;
  v_k int;
  d record;
  pl record;
  pay record;
  v_sign int;
  v_net bigint;
  v_rec bigint;
  v_grp text;
  v_default boolean;
  v_unqualified boolean;
  v_tz text;
  v_points jsonb;
  v_deferred uuid[];
  v_vat_role text;
  rel record;
  v_space text;
  v_converted jsonb;
  v_entry record;
  v_fx public.document_exchange_rates;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'you may not read the books' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'a period runs from a day to a later one' using errcode = '22023';
  end if;
  select s.country_code, s.is_default into v_country, v_default from public.sites s
   where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id;
  if not found then raise exception 'unknown issuer' using errcode = '22023'; end if;

  -- ── the tax points (0521) ─────────────────────────────────────────────
  -- The declaration's own engine (`vat_return_amounts`, 0402) dates the
  -- output tax of every invoice. Tax not exactly due on the invoice day
  -- waits on `vat_pending` and is released to `vat_output:<group>` on each
  -- tax point, as the FEC does it (`fec_writer.dart`).
  select coalesce(nullif(w.timezone, ''), 'UTC'), w.currency_code into v_tz, v_space
    from public.workspaces w where w.id = p_workspace_id;
  select coalesce(jsonb_agg(jsonb_build_object('id', a.invoice_id, 'on', a.tax_point, 'percent', a.percent,
                                               'category', a.category, 'vat', a.gross_cents - a.net_cents)), '[]'::jsonb)
    into v_points
    from public.vat_return_amounts(p_workspace_id, '1900-01-01', '9999-12-31') a;
  with pts as (
    select (e ->> 'id')::uuid as id, (e ->> 'on')::date as d, (e ->> 'vat')::bigint as vat
      from jsonb_array_elements(v_points) e
  ), docs as (
    select inv.id, (inv.issued_at at time zone v_tz)::date as issued,
           coalesce((select sum((e ->> 'vat_cents')::bigint)
                       from jsonb_array_elements(coalesce(inv.vat_totals, '[]'::jsonb)) e), 0) as vat
      from public.invoices inv
     where inv.workspace_id = p_workspace_id
       and (inv.site_id = p_issuer_site_id or inv.site_id is null)
       and inv.voided_at is null and coalesce(inv.kind, '') <> 'settlement'
  )
  select coalesce(array_agg(docs.id), '{}') into v_deferred
    from docs
   where docs.vat <> 0
     and (exists (select 1 from pts where pts.id = docs.id and pts.vat <> 0 and pts.d <> docs.issued)
          or coalesce((select sum(pts.vat) from pts where pts.id = docs.id and pts.d = docs.issued), 0) <> docs.vat);

  -- ── the documents of the period ───────────────────────────────────────
  for i in
    select inv.* from public.invoices inv
     where inv.workspace_id = p_workspace_id
       and (inv.site_id = p_issuer_site_id or inv.site_id is null)
       and inv.voided_at is null
       and coalesce(inv.kind, '') <> 'settlement'
       and inv.issued_at::date between p_from and p_to
     order by inv.issued_at, inv.number
  loop
    v_day := i.issued_at::date;
    v_gross := coalesce((select sum((e ->> 'net_cents')::bigint + (e ->> 'vat_cents')::bigint)
                           from jsonb_array_elements(coalesce(i.vat_totals, '[]'::jsonb)) e), i.total_cents);
    if jsonb_array_length(coalesce(i.vat_totals, '[]'::jsonb)) = 0 then v_gross := i.total_cents; end if;
    select coalesce(sum(-(l ->> 'amount_cents')::bigint) filter (where l ->> 'kind' = 'payment'), 0),
           coalesce(sum(-(l ->> 'amount_cents')::bigint) filter (where l ->> 'kind' = 'expense'), 0)
      into v_paid, v_spent
      from jsonb_array_elements(coalesce(i.lines, '[]'::jsonb)) l
     where coalesce((l ->> 'vat_percent')::numeric, 0) = 0 and (l ->> 'amount_cents')::bigint < 0;
    if v_gross - v_paid - v_spent <> i.total_cents then
      v_blockers := v_blockers || jsonb_build_object('unbalanced:' || i.number,
        jsonb_build_object('block', 'unbalanced', 'subject', i.number));
      continue;
    end if;
    v_lines := public.posting_line(p_issuer_site_id, 'customers', null, v_day, v_gross, true);
    for t in
      select (e ->> 'net_cents')::bigint as net, (e ->> 'vat_cents')::bigint as vat,
             nullif(public.posting_rate_group(v_country, (e ->> 'percent')::numeric,
                                              coalesce(e ->> 'category', 'S'), v_day), '') as grp
        from jsonb_array_elements(coalesce(i.vat_totals, '[]'::jsonb)) with ordinality x(e, n)
       order by n
    loop
      v_lines := v_lines || public.posting_line(p_issuer_site_id, 'revenue', t.grp, v_day, t.net, false);
      if t.vat <> 0 then
        v_vat_role := case when i.id = any(v_deferred) then 'vat_pending' else 'vat_output' end;
        v_lines := v_lines || public.posting_line(p_issuer_site_id, v_vat_role,
          case when v_vat_role = 'vat_pending' then null else t.grp end, v_day, t.vat, false);
      end if;
    end loop;
    if jsonb_array_length(coalesce(i.vat_totals, '[]'::jsonb)) = 0 then
      v_lines := v_lines || public.posting_line(p_issuer_site_id, 'revenue', null, v_day, i.total_cents, false);
    end if;
    v_postings := v_postings || public.posting_entry('sales',
      case when i.total_cents < 0 then 'credit_note' else 'invoice' end, v_day, i.id, i.number, i.currency, v_lines);
    if v_paid <> 0 then
      v_postings := v_postings || public.posting_entry('bank', 'receipt', v_day, i.id, i.number, i.currency,
        public.posting_line(p_issuer_site_id, 'bank', null, v_day, v_paid, true)
        || public.posting_line(p_issuer_site_id, 'customers', null, v_day, v_paid, false));
    end if;
    -- A netted expense credit (v_spent) books nothing here (0524): the
    -- member's receipt booked the expense against the member's account
    -- when it was approved, and the netting only settles that account.
  end loop;

  -- ── receipts and write-offs dated in the period ───────────────────────
  -- A settlement's payment is allocated to its sources, oldest first and to
  -- the cent (accounting_view.dart); the settlement itself books nothing.
  for m in
    with own as (
      -- A refunded credit note's match holds the amount paid OUT, positive
      -- (0436): it is money leaving the bank, signed as such.
      select inv.id, inv.number, inv.currency, inv.total_cents, inv.vat_totals,
             (case when x.resolution = 'refunded' and inv.total_cents < 0 and x.paid_cents > 0
                   then -x.paid_cents else x.paid_cents end)::bigint as paid,
             x.matched_at, x.writeoff_at
        from public.invoices inv
        join public.invoice_matches x on x.invoice_id = inv.id and x.status = 'confirmed'
       where inv.workspace_id = p_workspace_id
         and (inv.site_id = p_issuer_site_id or inv.site_id is null)
         and inv.voided_at is null and coalesce(inv.kind, '') <> 'settlement'
    ), alloc as (
      select src.id, src.number, src.currency, src.total_cents, src.vat_totals,
             greatest(least(src.total_cents::bigint,
                            x.paid_cents - coalesce(sum(s.total) over (
                              partition by st.id order by s.n rows between unbounded preceding and 1 preceding), 0)),
                      0)::bigint as paid,
             x.matched_at, x.writeoff_at
        from public.invoices st
        join public.invoice_matches x on x.invoice_id = st.id and x.status = 'confirmed'
        cross join lateral (
          select (e ->> 'invoice_id')::uuid as invoice_id, (e ->> 'total_cents')::bigint as total, n
            from jsonb_array_elements(coalesce(st.settles, '[]'::jsonb)) with ordinality y(e, n)) s
        join public.invoices src on src.id = s.invoice_id
       where st.workspace_id = p_workspace_id and st.kind = 'settlement' and st.voided_at is null
    )
    select * from own union all select * from alloc where paid > 0
  loop
    if m.matched_at::date between p_from and p_to and m.paid <> 0 then
      v_day := m.matched_at::date;
      v_postings := v_postings || public.posting_entry('bank',
        case when m.paid < 0 then 'refund' else 'receipt' end, v_day, m.id, m.number, m.currency,
        public.posting_line(p_issuer_site_id, 'bank', null, v_day, m.paid, true)
        || public.posting_line(p_issuer_site_id, 'customers', null, v_day, m.paid, false));
    end if;
    v_rest := m.total_cents - m.paid;
    if m.writeoff_at is not null and m.writeoff_at::date between p_from and p_to and v_rest > 0 then
      v_day := m.writeoff_at::date;
      v_lines := '[]'::jsonb;
      v_n := greatest(jsonb_array_length(coalesce(m.vat_totals, '[]'::jsonb)), 1);
      v_gross := coalesce((select sum((e ->> 'net_cents')::bigint + (e ->> 'vat_cents')::bigint)
                             from jsonb_array_elements(coalesce(m.vat_totals, '[]'::jsonb)) e), 0);
      v_left := v_rest;
      v_k := 0;
      for t in
        select ((e ->> 'net_cents')::bigint + (e ->> 'vat_cents')::bigint) as gross,
               (e ->> 'vat_cents')::bigint as vat,
               nullif(public.posting_rate_group(v_country, (e ->> 'percent')::numeric,
                                                coalesce(e ->> 'category', 'S'), v_day), '') as grp
          from jsonb_array_elements(coalesce(m.vat_totals, '[]'::jsonb)) with ordinality x(e, n)
         order by n
      loop
        v_k := v_k + 1;
        v_part := case when v_k = v_n or v_gross = 0 then v_left else (v_rest * t.gross) / v_gross end;
        v_left := v_left - v_part;
        v_tax := case when t.gross = 0 then 0 else (v_part * t.vat) / t.gross end;
        -- A deferred invoice's unpaid tax never left vat_pending (0526).
        v_lines := v_lines
          || public.posting_line(p_issuer_site_id, 'write_off', null, v_day, v_part - v_tax, true)
          || case when m.id = any(v_deferred)
                  then public.posting_line(p_issuer_site_id, 'vat_pending', null, v_day, v_tax, true)
                  else public.posting_line(p_issuer_site_id, 'vat_output', t.grp, v_day, v_tax, true) end;
      end loop;
      if v_k = 0 then
        v_lines := public.posting_line(p_issuer_site_id, 'write_off', null, v_day, v_rest, true);
      end if;
      v_lines := v_lines || public.posting_line(p_issuer_site_id, 'customers', null, v_day, v_rest, false);
      v_postings := v_postings || public.posting_entry('other', 'write_off', v_day, m.id, m.number, m.currency, v_lines);
    end if;
  end loop;

  -- ── the output tax released on its tax points (0521) ──────────────────
  for rel in
    select (e ->> 'id')::uuid as id, (e ->> 'on')::date as d, inv.number, inv.currency,
           nullif(public.posting_rate_group(v_country, (e ->> 'percent')::numeric,
                                            coalesce(e ->> 'category', 'S'), (e ->> 'on')::date), '') as grp,
           sum((e ->> 'vat')::bigint)::bigint as vat
      from jsonb_array_elements(v_points) e
      join public.invoices inv on inv.id = (e ->> 'id')::uuid
     where (e ->> 'id')::uuid = any(v_deferred)
       and (e ->> 'on')::date between p_from and p_to
     group by 1, 2, 3, 4, 5
    having sum((e ->> 'vat')::bigint) <> 0
     order by 2, 3, 5
  loop
    v_postings := v_postings || public.posting_entry('other', 'vat_release', rel.d, rel.id, rel.number, rel.currency,
      public.posting_line(p_issuer_site_id, 'vat_pending', null, rel.d, rel.vat, true)
      || public.posting_line(p_issuer_site_id, 'vat_output', rel.grp, rel.d, rel.vat, false));
  end loop;

  -- ── purchases and the money paid on them (0519, 0524) ─────────────────
  -- A purchase document names no issuer: the workspace's default issuer
  -- books it. A supplier's bill is owed to `suppliers`; a member's receipt
  -- is credited to the member's account (`customers`), which an invoice
  -- later nets or a reimbursement pays.
  if v_default then
    for d in
      select pd.* from public.purchase_documents pd
       where pd.workspace_id = p_workspace_id and pd.state = 'approved'
         and (pd.kind = 'member_receipt'
              or (pd.kind in ('bill', 'credit_note')
                  and exists (select 1 from public.purchase_obligations o
                               where o.purchase_id = pd.id and o.creditor_kind = 'supplier')))
         and coalesce(pd.original_date, pd.received_on) between p_from and p_to
       order by coalesce(pd.original_date, pd.received_on), pd.original_reference
    loop
      v_day := coalesce(d.original_date, d.received_on);
      v_sign := case when d.kind = 'credit_note' then -1 else 1 end;
      v_lines := '[]'::jsonb;
      v_gross := 0;
      -- A taxed line whose deductible share is not qualified yet is never
      -- guessed: the bill waits, named.
      v_unqualified := exists (select 1 from public.purchase_lines q
                                where q.purchase_id = d.id and coalesce(q.tax_cents, 0) <> 0
                                  and q.recoverable_tax_cents is null);
      if v_unqualified then
        v_blockers := v_blockers || jsonb_build_object('unclassifiedTax:' || d.original_reference,
          jsonb_build_object('block', 'unclassifiedTax', 'subject', d.original_reference));
        continue;
      end if;
      for pl in select * from public.purchase_lines where purchase_id = d.id order by line_no loop
        v_tax := coalesce(pl.tax_cents, 0);
        v_rec := coalesce(pl.recoverable_tax_cents, 0);
        v_net := coalesce(pl.net_cents, pl.gross_cents - v_tax);
        v_gross := v_gross + pl.gross_cents;
        v_grp := case when pl.tax_rate_percent is null then null
                      else nullif(public.posting_rate_group(v_country, pl.tax_rate_percent, 'S', v_day), '') end;
        -- What the line is for decides its debit (0587): equipment, stock,
        -- a prepayment or a deposit is not an operating cost; an unmapped
        -- role blocks, named, instead of falling back to `expenses`.
        v_lines := v_lines || public.posting_line(p_issuer_site_id,
          case pl.recognition_kind
            when 'asset' then 'fixed_assets'
            when 'stock' then 'stock'
            when 'prepayment' then 'prepayments'
            when 'deposit' then 'deposits'
            else 'expenses' end, null, v_day,
                                                  v_sign * (v_net + v_tax - v_rec), true);
        if v_rec <> 0 then
          v_lines := v_lines || public.posting_line(p_issuer_site_id, 'vat_input', v_grp, v_day, v_sign * v_rec, true);
        end if;
      end loop;
      v_lines := v_lines || public.posting_line(p_issuer_site_id,
        case when d.kind = 'member_receipt' then 'customers' else 'suppliers' end,
        null, v_day, v_sign * v_gross, false);
      v_postings := v_postings || public.posting_entry('purchases',
        case when d.kind = 'member_receipt' then 'member_receipt'
             when v_sign < 0 then 'supplier_credit_note' else 'supplier_bill' end,
        v_day, d.id, d.original_reference, d.currency, v_lines);
    end loop;

    for pay in
      select a.amount_cents::bigint as amount, pd.id, pd.original_reference, pd.currency,
             coalesce(p.reported_paid_on, (a.created_datetime at time zone 'UTC')::date) as paid_on,
             o.creditor_kind
        from public.purchase_settlement_allocations a
        join public.purchase_obligations o on o.id = a.obligation_id
        join public.purchase_documents pd on pd.id = o.purchase_id
        left join public.outgoing_payments p on p.workspace_id = a.workspace_id and p.id = a.payment_id
       where a.workspace_id = p_workspace_id and a.kind = 'payment'
         and pd.state = 'approved' and pd.kind in ('bill', 'credit_note', 'member_receipt')
         and not exists (select 1 from public.purchase_settlement_allocations r where r.original_allocation_id = a.id)
       order by 5, a.created_datetime, a.id
    loop
      if pay.paid_on between p_from and p_to then
        v_postings := v_postings || public.posting_entry('bank',
          case when pay.creditor_kind = 'member' then 'reimbursement' else 'supplier_payment' end,
          pay.paid_on, pay.id, pay.original_reference, pay.currency,
          public.posting_line(p_issuer_site_id,
            case when pay.creditor_kind = 'member' then 'customers' else 'suppliers' end,
            null, pay.paid_on, pay.amount, true)
          || public.posting_line(p_issuer_site_id, 'bank', null, pay.paid_on, pay.amount, false));
      end if;
    end loop;
  end if;

  -- ── a purchase in another currency, at its recorded rate ──────────────
  -- A purchase document in another currency than the space's is booked,
  -- with its payments, in the space's currency at the rate recorded with it
  -- (`posting_at_rate`); each line keeps its original amount and the entry
  -- names its original currency and rate. Without a recorded rate the
  -- entry blocks, named `reference (currency)`. An invoice is issued in the
  -- space's currency and passes as it is.
  v_converted := '[]'::jsonb;
  for v_entry in select p from jsonb_array_elements(v_postings) p loop
    if v_entry.p ->> 'currency' = v_space
       or v_entry.p ->> 'kind' not in ('supplier_bill', 'supplier_credit_note', 'member_receipt',
                                 'supplier_payment', 'reimbursement') then
      v_converted := v_converted || jsonb_build_array(v_entry.p);
      continue;
    end if;
    select * into v_fx from public.document_exchange_rates x
     where x.workspace_id = p_workspace_id and x.document_kind = 'purchase'
       and x.document_id = (v_entry.p ->> 'document_id')::uuid
       and x.currency = v_entry.p ->> 'currency' and x.functional_currency = v_space;
    if v_fx.id is null then
      v_grp := coalesce(nullif(v_entry.p ->> 'document_number', ''), v_entry.p ->> 'document_id')
               || ' (' || (v_entry.p ->> 'currency') || ')';
      v_blockers := v_blockers || jsonb_build_object('missingRate:' || v_grp,
        jsonb_build_object('block', 'missingRate', 'subject', v_grp));
      continue;
    end if;
    v_converted := v_converted || jsonb_build_array(
      public.posting_at_rate(v_entry.p, v_space, v_fx.rate, v_fx.rate_date, v_fx.source));
  end loop;
  v_postings := v_converted;

  -- ── what blocks, each named once ──────────────────────────────────────
  select v_blockers || coalesce(jsonb_object_agg(b ->> 'block' || ':' || (b ->> 'subject'), b), '{}'::jsonb)
    into v_blockers
    from jsonb_array_elements(v_postings) p, jsonb_array_elements(p -> 'lines') l,
         lateral (select l -> 'blocked' as b) q
   where l ? 'blocked';

  return jsonb_build_object(
    'period', jsonb_build_object('from', p_from, 'to', p_to),
    'postings', coalesce((
      select jsonb_agg(jsonb_set(p, '{lines}', coalesce((
               select jsonb_agg(l order by n) from jsonb_array_elements(p -> 'lines') with ordinality z(l, n)
                where not l ? 'blocked'), '[]'::jsonb))
             order by (p ->> 'date'), array_position(array['sales', 'bank', 'purchases', 'other'], p ->> 'journal'),
                      (p ->> 'document_number'))
        from jsonb_array_elements(v_postings) p), '[]'::jsonb),
    'blockers', coalesce((select jsonb_agg(v order by k) from jsonb_each(v_blockers) e(k, v)), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.compute_postings(uuid, uuid, date, date) from public, anon;
grant execute on function public.compute_postings(uuid, uuid, date, date) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(9999);
