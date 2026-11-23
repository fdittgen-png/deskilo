-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (the feature registry and the setup level catalogue are restated; one setting and one read are added; no stored flag moves)
--
-- #4431 (G17) -- the expiry report: every lot (and every piece of an item tracked piece by piece) still on hand that is expired at a
-- chosen date or expires after it, one row each, sorted by date then place. Off with the feature `stockExpiryReport` (under stock
-- management, off by default).
--   * `stock_expiry_report_v1(workspace, on, scope, horizon_days, location, group, limit, after)` answers the rows a page at a time
--     (1 to 200, a cursor): `expired` is a best-before date before the reference date, `expiring` one on or after it (up to the
--     horizon when one is given, else the setting `stock.expiry_horizon_days`), `both` the two. A lot with nothing on hand is not
--     listed. A piece-tracked item is listed by piece, with its tag, never also as a balance. The reference date defaults to today
--     on the business's calendar. Whoever may see the stock reads it; an assistant is refused.
--   * the setting `stock.expiry_horizon_days` (30 days), edited by whoever manages the stock.
-- restates 0915
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
    "adminSeatBlocking": {"parent": "placeBooking", "default": false, "core": false},
    "levelBooking": {"parent": "placeBooking", "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": "placeBooking", "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": "placeBooking", "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": "placeBooking", "default": false, "core": false},
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
    "planObjectDelete": {"parent": "placeBooking", "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": "placeBooking", "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": "placeBooking", "default": true, "core": false},
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
    "multiSite": {"parent": "placeBooking", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": "placeBooking", "default": true, "core": true},
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
    "singleRoomLevelNames": {"parent": "placeBooking", "default": true, "core": true},
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
    "placeFeedback": {"parent": "placeBooking", "default": true, "core": true},
    "spaceInquiries": {"parent": null, "default": true, "core": true},
    "messageForwarding": {"parent": "memberNotifications", "default": true, "core": true},
    "captureProtection": {"parent": "memberNotifications", "default": true, "core": true},
    "holidayImport": {"parent": "publicHolidays", "default": false, "core": false},
    "capacityKpi": {"parent": "placeBooking", "default": false, "core": false},
    "accountingBook": {"parent": "invoicing", "default": false, "core": false},
    "roleAssignment": {"parent": "roleManagement", "default": true, "core": true},
    "taskRecorder": {"parent": null, "default": false, "core": false},
    "guestParticipation": {"parent": "placeBooking", "default": false, "core": true},
    "messageMentions": {"parent": "memberNotifications", "default": true, "core": true},
    "supplyClassification": {"parent": "vatManagement", "default": true, "core": false},
    "viesVerification": {"parent": "supplyClassification", "default": true, "core": false},
    "recapitulativeStatement": {"parent": "vatDeclarations", "default": true, "core": false, "countries": ["@eu"]},
    "inputVat": {"parent": "vatDeclarations", "default": true, "core": false},
    "configurableSettings": {"parent": null, "default": true, "core": false},
    "salesTax": {"parent": "invoicing", "default": true, "core": false},
    "meetingRooms": {"parent": "placeBooking", "default": false, "core": false},
    "parking": {"parent": "placeBooking", "default": false, "core": false},
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
    "foreignCurrencyPurchases": {"parent": "purchases", "default": false, "core": false},
    "accountingConnectors": {"parent": "accountingBook", "default": false, "core": false},
    "bankImport": {"parent": "invoicing", "default": false, "core": false},
    "planDecor": {"parent": "placeBooking", "default": true, "core": true},
    "mtdSubmission": {"parent": "vatDeclarations", "default": false, "core": false, "countries": ["GB"]},
    "purchaseOrders": {"parent": "purchases", "default": false, "core": false},
    "guestPasses": {"parent": "invoicing", "default": false, "core": false},
    "placeBooking": {"parent": null, "default": true, "core": true},
    "reminderEmail": {"parent": "dunning", "default": false, "core": false},
    "invoiceEmail": {"parent": "invoicing", "default": false, "core": false},
    "standaloneInvoicing": {"parent": "invoicing", "default": false, "core": false},
    "kioskEnrolment": {"parent": "kioskMode", "default": true, "core": false},
    "quickSearch": {"parent": null, "default": true, "core": true},
    "stockManagement": {"parent": "services", "default": false, "core": false},
    "stockLots": {"parent": "stockManagement", "default": false, "core": false},
    "stockReceiving": {"parent": "stockManagement", "default": false, "core": false},
    "stockTakeOut": {"parent": "stockManagement", "default": false, "core": false},
    "stockReorder": {"parent": "stockManagement", "default": false, "core": false},
    "stockReturns": {"parent": "stockManagement", "default": false, "core": false},
    "stockCounts": {"parent": "stockManagement", "default": false, "core": false},
    "stockCycleCounts": {"parent": "stockCounts", "default": false, "core": false},
    "stockItemGroups": {"parent": "stockManagement", "default": false, "core": false},
    "stockTags": {"parent": "stockManagement", "default": false, "core": false},
    "stockScanning": {"parent": "stockManagement", "default": false, "core": false},
    "counterReceipts": {"parent": "standaloneInvoicing", "default": false, "core": false},
    "counterTillSessions": {"parent": "counterReceipts", "default": false, "core": false},
    "stockTagReads": {"parent": "stockTags", "default": false, "core": false},
    "stockExpiryReport": {"parent": "stockManagement", "default": false, "core": false},
    "organisation": {"parent": null, "default": true, "core": true},
    "billingCustomers": {"parent": "invoicing", "default": false, "core": false},
    "customerQuotes": {"parent": "invoicing", "default": false, "core": false},
    "serviceFulfilment": {"parent": "billingCustomers", "default": false, "core": false}
  }'::jsonb
$registry$;
revoke execute on function public.feature_registry() from public, anon;

-- restates 0915
create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json${"processes":[{"process":"bookings","levels":[{"level":"none","features":[],"needs":[]},{"level":"simple","features":["seriesBooking","bookForOthers","spaceQrCodes","workingHours","planObjectDelete","bookingPolicies","seatDayTimeline","bookingGate","singleRoomLevelNames","calendarFileExport","placeFeedback","planDecor","placeBooking"],"needs":[]},{"level":"resources","features":["adminSeatBlocking","levelBooking","adminLevelAssign","planMemberPhotos","multiSite","publicHolidays","holidayImport","guestParticipation","meetingRooms","parking","externalRooms"],"needs":[]},{"level":"measured","features":["kioskMode","nfcBadges","autoCheckInOut","nfcSeatTags","qrBadges","kioskMemberPhotos","badgeSignIn","capacityKpi","kioskEnrolment"],"needs":[]}]},{"process":"community","levels":[{"level":"basic","features":["calendarTab","eventsTab","pushNotifications","membersDirectory","memberNotifications","deletionRequests","roleManagement","notificationGrouping","calendarHub","richMessageRefs","personalInfo","messageGestures","calendarViews","messagesHub","memberPage","messageForwarding","captureProtection","roleAssignment","messageMentions"],"needs":[]},{"level":"organised","features":["whatsappIntegration","coOwner","validationScopes","validationChain","calendarValidations","managedProfiles","managedProfileAccess","memberOrigin","customRoles","customFields"],"needs":[]}]},{"process":"money","levels":[{"level":"none","features":[],"needs":[]},{"level":"statements","features":["moneyTab","services","accessorySupplements","memberReports","dataAccessLog","financeFaces","priceNegotiations"],"needs":[]},{"level":"invoices","features":["invoicing","adminInvoicing","invoicePdfTemplate","invoiceAddressWindow","dunning","paymentReminders","usageRecords","reportDesignExchange","reportLayouts","numberSequences","workspaceStatus","memberPaymentTerms","reportTexts","usageReport","letterStandard","subscriptionInvoices","usageInvoices","invoiceSettlement","invoiceJourney","reportDesigner","invoicingWizard","settlementFold","carnets","guestPasses","reminderEmail","invoiceEmail","standaloneInvoicing","billingCustomers","customerQuotes","serviceFulfilment"],"needs":[]}]},{"process":"payments","levels":[{"level":"off","features":[],"needs":[]},{"level":"online","features":["onlinePayments"],"needs":[{"process":"money","level":"statements"}]}]},{"process":"tax","levels":[{"level":"none","features":[],"needs":[]},{"level":"vat","features":["vatManagement","vatDeclarations","vatGroups","vatRateHistory","vatCounterparty","vatReport","supplyClassification","viesVerification","recapitulativeStatement","inputVat","salesTax"],"needs":[{"process":"money","level":"invoices"}]},{"level":"books","features":["einvoiceCustomerDelivery","accountingBook","accountingPeriods","accountingConnectors","bankImport","mtdSubmission"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"purchases","levels":[{"level":"none","features":[],"needs":[]},{"level":"expenses","features":["supplyExpenses","expenseRepartitionWizard","scheduledExpenses","expenseRepartition"],"needs":[{"process":"money","level":"invoices"}]},{"level":"full","features":["purchases","premisesLease","assetRegister","purchaseAnalytics","foreignCurrencyPurchases","purchaseOrders","stockManagement","stockLots","stockReceiving","stockTakeOut","stockReorder","stockReturns","stockCounts","stockCycleCounts","stockItemGroups","stockTags","stockScanning","counterReceipts","counterTillSessions","stockTagReads","stockExpiryReport"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"presentation","levels":[{"level":"basic","features":["uniqueMonograms"],"needs":[]},{"level":"branded","features":["workspaceVocabulary","workspaceBranding"],"needs":[]},{"level":"public","features":["publicListings","spaceInquiries"],"needs":[]}]},{"process":"operations","levels":[{"level":"basic","features":["pdfExport","dataExport","documents","formHelpHints","uiAnimations","regionalFormats","memberDataExport","navigationStyle","demoMode","memberAccountMenu","memberGettingStarted","setupGuide","dataReport","quickSearch","organisation"],"needs":[]},{"level":"insight","features":["decisionSurface","biReportDesigner","workspaceOverview"],"needs":[]},{"level":"advanced","features":["environmentPairs","deployments","configurationTransfer","instanceWizard","memberEnvironments","workspaceLibrary","configurableSettings"],"needs":[]}]},{"process":"assistant","levels":[{"level":"off","features":[],"needs":[]},{"level":"on","features":["recordingPrivacy","mcpAccess","taskRecorder","webMcp"],"needs":[]}]}],"presets":[{"preset":"essentiel","levels":[{"process":"bookings","level":"simple"},{"process":"community","level":"basic"},{"process":"money","level":"statements"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"none"},{"process":"presentation","level":"basic"},{"process":"operations","level":"basic"},{"process":"assistant","level":"off"}]},{"preset":"standard","levels":[{"process":"bookings","level":"resources"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"expenses"},{"process":"presentation","level":"branded"},{"process":"operations","level":"insight"},{"process":"assistant","level":"off"}]},{"preset":"complet","levels":[{"process":"bookings","level":"measured"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"online"},{"process":"tax","level":"books"},{"process":"purchases","level":"full"},{"process":"presentation","level":"public"},{"process":"operations","level":"advanced"},{"process":"assistant","level":"off"}]}]}$json$::jsonb;
$fn$;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('stock.expiry_horizon_days', 'int', '30'::jsonb, 1, 3650, 'days', 'business', array['workspace'], 'manageStock', null, true, null, 'expiry report (#4431)', 'How many days after the reference date the expiry report looks ahead for what is about to expire, when the person who prints it does not name a horizon of their own.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the expiry report ───────────────────────────────────────────────────
create or replace function public.stock_expiry_report_v1(
  p_workspace_id uuid, p_on date default null, p_scope text default 'both', p_horizon_days int default null,
  p_location_id uuid default null, p_group_id uuid default null, p_limit int default 50, p_after jsonb default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_zero constant uuid := '00000000-0000-0000-0000-000000000000';
  v_on date;
  v_horizon int;
  v_exp date; v_code text; v_loc uuid; v_item uuid; v_var uuid; v_lot uuid; v_piece uuid;
  v_rows jsonb; v_n int; v_last jsonb;
begin
  perform public.stock_page_reader(p_workspace_id, p_limit);
  if not public.feature_effective(p_workspace_id, 'stockExpiryReport') then
    return jsonb_build_object('rows', '[]'::jsonb, 'complete', true, 'next', null, 'as_of', null);
  end if;
  if p_scope is null or p_scope not in ('expired', 'expiring', 'both') then
    raise exception 'invalid scope' using errcode = 'DKG09';
  end if;
  if p_horizon_days is not null and (p_horizon_days < 1 or p_horizon_days > 3650) then
    raise exception 'invalid horizon' using errcode = 'DKG09';
  end if;
  v_on := coalesce(p_on, public.workspace_today(p_workspace_id));
  v_horizon := coalesce(p_horizon_days, (public.setting_value(p_workspace_id, 'stock.expiry_horizon_days') #>> '{}')::int);
  if p_after is not null then
    begin
      if p_after->>'version' is distinct from '1' then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
      v_exp := (p_after->>'expires_on')::date;
      v_code := p_after->>'location_code';
      v_loc := (p_after->>'location_id')::uuid;
      v_item := (p_after->>'item_id')::uuid;
      v_var := coalesce((p_after->>'variant_id')::uuid, v_zero);
      v_lot := coalesce((p_after->>'lot_id')::uuid, v_zero);
      v_piece := coalesce((p_after->>'piece_id')::uuid, v_zero);
      if v_exp is null or v_code is null or v_loc is null or v_item is null then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
    exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow then
      raise exception 'invalid cursor' using errcode = 'DKG09';
    end;
  end if;
  with src as (
    -- what a lot holds at a real place (an item tracked piece by piece is read by piece, below)
    select b.item_id, b.variant_id, b.lot_id, null::uuid as piece_id, b.location_id, b.quantity, t.expires_on, null::text as tag
      from public.stock_balances b
      join public.services s on s.id = b.item_id
      join public.stock_lots t on t.id = b.lot_id
     where b.workspace_id = p_workspace_id and b.quantity > 0 and t.expires_on is not null and s.tracking is distinct from 'serial'
    union all
    select u.item_id, u.variant_id, u.lot_id, u.id, u.location_id, 1::numeric, t.expires_on,
           (select g.code from public.stock_tags g where g.workspace_id = p_workspace_id and g.piece_id = u.id and g.state = 'active'
             order by g.created_datetime, g.id limit 1)
      from public.stock_tagged_units u
      join public.stock_lots t on t.id = u.lot_id
     where u.workspace_id = p_workspace_id and u.state = 'in_stock' and t.expires_on is not null
  ), page as (
    select x.item_id, x.variant_id, x.lot_id, x.piece_id, x.location_id, x.quantity, x.expires_on, x.tag,
           s.name as item_name, s.inventory_unit as unit, l.code as location_code, l.name as location_name, t.lot_code
      from src x
      join public.services s on s.id = x.item_id
      join public.stock_locations l on l.id = x.location_id
      join public.stock_location_kinds k on k.key = l.kind
      join public.stock_lots t on t.id = x.lot_id
     where not k.virtual
       and (p_location_id is null or x.location_id = p_location_id)
       and (p_group_id is null or s.group_id = p_group_id
            or s.group_id in (select g.id from public.item_groups g where g.workspace_id = p_workspace_id and g.parent_id = p_group_id))
       and ((p_scope in ('expired', 'both') and x.expires_on < v_on)
         or (p_scope in ('expiring', 'both') and x.expires_on >= v_on and x.expires_on <= v_on + v_horizon))
       and (p_after is null
            or (x.expires_on, l.code, x.location_id, x.item_id, coalesce(x.variant_id, v_zero), coalesce(x.lot_id, v_zero), coalesce(x.piece_id, v_zero))
             > (v_exp, v_code, v_loc, v_item, v_var, v_lot, v_piece))
     order by x.expires_on, l.code, x.location_id, x.item_id, coalesce(x.variant_id, v_zero), coalesce(x.lot_id, v_zero), coalesce(x.piece_id, v_zero)
     limit p_limit + 1)
  select count(*), coalesce(jsonb_agg(jsonb_build_object(
           'item_id', item_id, 'item_name', item_name, 'variant_id', variant_id, 'variant_label', public.stock_variant_label(variant_id),
           'lot_id', lot_id, 'lot_code', lot_code, 'piece_id', piece_id, 'tag', tag,
           'expires_on', expires_on, 'days', expires_on - v_on,
           'quantity', quantity::text, 'unit', unit,
           'location_id', location_id, 'location_code', location_code, 'location_name', location_name)
           order by expires_on, location_code, location_id, item_id, coalesce(variant_id, v_zero), coalesce(lot_id, v_zero), coalesce(piece_id, v_zero)), '[]'::jsonb)
    into v_n, v_rows from page;
  if v_n > p_limit then
    v_rows := v_rows - p_limit;                     -- drop the look-ahead row
    v_last := v_rows -> (p_limit - 1);
    return jsonb_build_object('rows', v_rows, 'complete', false, 'as_of', v_on, 'next', jsonb_build_object(
      'version', 1, 'expires_on', v_last -> 'expires_on', 'location_code', v_last -> 'location_code', 'location_id', v_last -> 'location_id',
      'item_id', v_last -> 'item_id', 'variant_id', v_last -> 'variant_id', 'lot_id', v_last -> 'lot_id', 'piece_id', v_last -> 'piece_id'));
  end if;
  return jsonb_build_object('rows', v_rows, 'complete', true, 'as_of', v_on, 'next', null);
end;
$fn$;
revoke execute on function public.stock_expiry_report_v1(uuid, date, text, int, uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.stock_expiry_report_v1(uuid, date, text, int, uuid, uuid, int, jsonb) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(921);
