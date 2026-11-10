-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (seeds the feature profile of the four non-place kinds, adds a check
-- trigger on business_kinds, restates the setup level catalogue; no
-- workspace's stored flags move)
--
-- 0709 (#3550) -- a kind proposes the features its business needs.
--
--  * business_kinds.feature_profile: flag key -> on/off. coworking keeps {}
--    (today's defaults). studio, practice, salon and service switch the
--    places off (placeBooking, and its subtree with it) and propose what a
--    service business sells and talks with: the money tab, services,
--    invoices, online payments, messages and a public page. The app shows
--    the proposal and writes it through the feature-write path only when
--    the owner confirms; nothing here touches a workspace.
--  * business_kinds_profile_check: a profile names registered flags only
--    (public.feature_registry()), each with a boolean, so a typo is refused
--    when a migration writes it.
--  * setup_level_catalogue(): the bookings process gains the level 'none'
--    (a business without places), and the four place flags that sat in
--    other processes' levels move into bookings: singleRoomLevelNames and
--    placeFeedback into simple; guestParticipation and planMemberPhotos,
--    which a new space starts without, into resources (a level counts as
--    reached only when all its features are on).

create or replace function public.business_kinds_profile_check()
returns trigger language plpgsql set search_path = public as $fn$
declare
  v_key text;
  v_value jsonb;
begin
  for v_key, v_value in select * from jsonb_each(new.feature_profile) loop
    if not (public.feature_registry() ? v_key) then
      raise exception 'business kind %: unknown feature %', new.code, v_key
        using errcode = '22023';
    end if;
    if jsonb_typeof(v_value) <> 'boolean' then
      raise exception 'business kind %: feature % needs true or false', new.code, v_key
        using errcode = '22023';
    end if;
  end loop;
  return new;
end;
$fn$;
revoke execute on function public.business_kinds_profile_check() from public, anon, authenticated;

drop trigger if exists business_kinds_profile_check on public.business_kinds;
create trigger business_kinds_profile_check
  before insert or update of feature_profile on public.business_kinds
  for each row execute function public.business_kinds_profile_check();

update public.business_kinds
   set feature_profile = '{"placeBooking": false, "moneyTab": true, "services": true, "invoicing": true, "onlinePayments": true, "messagesHub": true, "publicListings": true}'::jsonb
 where code in ('studio', 'practice', 'salon', 'service');

-- ── the setup level catalogue (dart run tool/build_setup_steps.dart) ──
create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json${"processes":[{"process":"bookings","levels":[{"level":"none","features":[],"needs":[]},{"level":"simple","features":["seriesBooking","bookForOthers","spaceQrCodes","workingHours","planObjectDelete","bookingPolicies","seatDayTimeline","bookingGate","singleRoomLevelNames","calendarFileExport","placeFeedback","planDecor","placeBooking"],"needs":[]},{"level":"resources","features":["adminSeatBlocking","levelBooking","adminLevelAssign","planMemberPhotos","multiSite","publicHolidays","holidayImport","guestParticipation","meetingRooms","parking","externalRooms"],"needs":[]},{"level":"measured","features":["kioskMode","nfcBadges","autoCheckInOut","nfcSeatTags","qrBadges","kioskMemberPhotos","badgeSignIn","capacityKpi"],"needs":[]}]},{"process":"community","levels":[{"level":"basic","features":["calendarTab","eventsTab","pushNotifications","membersDirectory","memberNotifications","deletionRequests","roleManagement","notificationGrouping","calendarHub","richMessageRefs","personalInfo","messageGestures","calendarViews","messagesHub","memberPage","messageForwarding","captureProtection","roleAssignment","messageMentions"],"needs":[]},{"level":"organised","features":["whatsappIntegration","coOwner","validationScopes","validationChain","calendarValidations","managedProfiles","managedProfileAccess","memberOrigin","customRoles","customFields"],"needs":[]}]},{"process":"money","levels":[{"level":"none","features":[],"needs":[]},{"level":"statements","features":["moneyTab","services","accessorySupplements","memberReports","dataAccessLog","financeFaces","priceNegotiations"],"needs":[]},{"level":"invoices","features":["invoicing","adminInvoicing","invoicePdfTemplate","invoiceAddressWindow","dunning","paymentReminders","usageRecords","reportDesignExchange","reportLayouts","numberSequences","workspaceStatus","memberPaymentTerms","reportTexts","usageReport","letterStandard","subscriptionInvoices","usageInvoices","invoiceSettlement","invoiceJourney","reportDesigner","invoicingWizard","settlementFold","carnets","guestPasses"],"needs":[]}]},{"process":"payments","levels":[{"level":"off","features":[],"needs":[]},{"level":"online","features":["onlinePayments"],"needs":[{"process":"money","level":"statements"}]}]},{"process":"tax","levels":[{"level":"none","features":[],"needs":[]},{"level":"vat","features":["vatManagement","vatDeclarations","vatGroups","vatRateHistory","vatCounterparty","vatReport","supplyClassification","viesVerification","recapitulativeStatement","inputVat","salesTax"],"needs":[{"process":"money","level":"invoices"}]},{"level":"books","features":["einvoiceCustomerDelivery","accountingBook","accountingPeriods","accountingConnectors","bankImport","mtdSubmission"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"purchases","levels":[{"level":"none","features":[],"needs":[]},{"level":"expenses","features":["supplyExpenses","expenseRepartitionWizard","scheduledExpenses","expenseRepartition"],"needs":[{"process":"money","level":"invoices"}]},{"level":"full","features":["purchases","premisesLease","assetRegister","purchaseAnalytics","foreignCurrencyPurchases","purchaseOrders"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"presentation","levels":[{"level":"basic","features":["uniqueMonograms"],"needs":[]},{"level":"branded","features":["workspaceVocabulary","workspaceBranding"],"needs":[]},{"level":"public","features":["publicListings","spaceInquiries"],"needs":[]}]},{"process":"operations","levels":[{"level":"basic","features":["pdfExport","dataExport","documents","formHelpHints","uiAnimations","regionalFormats","memberDataExport","navigationStyle","demoMode","memberAccountMenu","memberGettingStarted","setupGuide","dataReport"],"needs":[]},{"level":"insight","features":["decisionSurface","biReportDesigner","workspaceOverview"],"needs":[]},{"level":"advanced","features":["environmentPairs","deployments","configurationTransfer","instanceWizard","memberEnvironments","workspaceLibrary","configurableSettings"],"needs":[]}]},{"process":"assistant","levels":[{"level":"off","features":[],"needs":[]},{"level":"on","features":["recordingPrivacy","mcpAccess","taskRecorder","webMcp"],"needs":[]}]}],"presets":[{"preset":"essentiel","levels":[{"process":"bookings","level":"simple"},{"process":"community","level":"basic"},{"process":"money","level":"statements"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"none"},{"process":"presentation","level":"basic"},{"process":"operations","level":"basic"},{"process":"assistant","level":"off"}]},{"preset":"standard","levels":[{"process":"bookings","level":"resources"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"expenses"},{"process":"presentation","level":"branded"},{"process":"operations","level":"insight"},{"process":"assistant","level":"off"}]},{"preset":"complet","levels":[{"process":"bookings","level":"measured"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"online"},{"process":"tax","level":"books"},{"process":"purchases","level":"full"},{"process":"presentation","level":"public"},{"process":"operations","level":"advanced"},{"process":"assistant","level":"off"}]}]}$json$::jsonb;
$fn$;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;

select public.set_deskilo_schema_version(709);
