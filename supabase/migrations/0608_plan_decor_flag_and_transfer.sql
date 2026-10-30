-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (the builtin template's row is rewritten; no workspace's stored flags move)
--
-- 0608 (#3074) -- the drawn symbols of the plan travel and have their flag.
--
--   1. planDecor           the flag of the Shapes tool, default on (the
--      feature registry and the setup level catalogue).
--   2. (the template field registry and the builtin template follow in 0609,
--      the two together being too long to sit beside the rest.)
--   3. export_floor_plan / merge_floor_plan, restated whole from 0471: an
--      image row is a photo (storage_path) or a symbol (kind, quarter_turns);
--      the export names both, the merge matches a symbol by kind and place so
--      a repeated transfer adds none, and a photo is untouched. Without this a
--      level holding one wall made the deployment raise on
--      plan_images_photo_or_symbol and lose the kind.

-- ── the feature registry knows it (dart run tool/build_feature_registry_sql.dart) ──
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
    "foreignCurrencyPurchases": {"parent": "purchases", "default": false, "core": false},
    "accountingConnectors": {"parent": "accountingBook", "default": false, "core": false},
    "bankImport": {"parent": "invoicing", "default": false, "core": false},
    "planDecor": {"parent": null, "default": true, "core": true}
  }'::jsonb
$registry$;
revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

-- ── the spaces level of the setup guide carries it (dart run tool/build_setup_steps.dart) ──
create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json${"processes":[{"process":"bookings","levels":[{"level":"simple","features":["seriesBooking","bookForOthers","spaceQrCodes","workingHours","planObjectDelete","bookingPolicies","seatDayTimeline","bookingGate","calendarFileExport","planDecor"],"needs":[]},{"level":"resources","features":["adminSeatBlocking","levelBooking","adminLevelAssign","multiSite","publicHolidays","holidayImport","meetingRooms","parking","externalRooms"],"needs":[]},{"level":"measured","features":["kioskMode","nfcBadges","autoCheckInOut","nfcSeatTags","qrBadges","kioskMemberPhotos","badgeSignIn","capacityKpi"],"needs":[]}]},{"process":"community","levels":[{"level":"basic","features":["calendarTab","eventsTab","pushNotifications","membersDirectory","memberNotifications","deletionRequests","roleManagement","notificationGrouping","calendarHub","richMessageRefs","personalInfo","messageGestures","calendarViews","messagesHub","memberPage","messageForwarding","captureProtection","roleAssignment","messageMentions"],"needs":[]},{"level":"organised","features":["whatsappIntegration","coOwner","validationScopes","validationChain","calendarValidations","managedProfiles","managedProfileAccess","memberOrigin","customRoles","customFields","guestParticipation"],"needs":[]}]},{"process":"money","levels":[{"level":"none","features":[],"needs":[]},{"level":"statements","features":["moneyTab","services","accessorySupplements","memberReports","dataAccessLog","financeFaces","priceNegotiations"],"needs":[]},{"level":"invoices","features":["invoicing","adminInvoicing","invoicePdfTemplate","invoiceAddressWindow","dunning","paymentReminders","usageRecords","reportDesignExchange","reportLayouts","numberSequences","workspaceStatus","memberPaymentTerms","reportTexts","usageReport","letterStandard","subscriptionInvoices","usageInvoices","invoiceSettlement","invoiceJourney","reportDesigner","invoicingWizard","settlementFold","carnets"],"needs":[]}]},{"process":"payments","levels":[{"level":"off","features":[],"needs":[]},{"level":"online","features":["onlinePayments"],"needs":[{"process":"money","level":"statements"}]}]},{"process":"tax","levels":[{"level":"none","features":[],"needs":[]},{"level":"vat","features":["vatManagement","vatDeclarations","vatGroups","vatRateHistory","vatCounterparty","vatReport","supplyClassification","viesVerification","recapitulativeStatement","inputVat","salesTax"],"needs":[{"process":"money","level":"invoices"}]},{"level":"books","features":["einvoiceCustomerDelivery","accountingBook","accountingPeriods","accountingConnectors","bankImport"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"purchases","levels":[{"level":"none","features":[],"needs":[]},{"level":"expenses","features":["supplyExpenses","expenseRepartitionWizard","scheduledExpenses","expenseRepartition"],"needs":[{"process":"money","level":"invoices"}]},{"level":"full","features":["purchases","premisesLease","assetRegister","purchaseAnalytics","foreignCurrencyPurchases"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"presentation","levels":[{"level":"basic","features":["planMemberPhotos","uniqueMonograms","singleRoomLevelNames"],"needs":[]},{"level":"branded","features":["workspaceVocabulary","workspaceBranding"],"needs":[]},{"level":"public","features":["publicListings","spaceInquiries"],"needs":[]}]},{"process":"operations","levels":[{"level":"basic","features":["pdfExport","dataExport","documents","formHelpHints","uiAnimations","regionalFormats","memberDataExport","navigationStyle","demoMode","memberAccountMenu","memberGettingStarted","placeFeedback","setupGuide","dataReport"],"needs":[]},{"level":"insight","features":["decisionSurface","biReportDesigner","workspaceOverview"],"needs":[]},{"level":"advanced","features":["environmentPairs","deployments","configurationTransfer","instanceWizard","memberEnvironments","workspaceLibrary","configurableSettings"],"needs":[]}]},{"process":"assistant","levels":[{"level":"off","features":[],"needs":[]},{"level":"on","features":["recordingPrivacy","mcpAccess","taskRecorder","webMcp"],"needs":[]}]}],"presets":[{"preset":"essentiel","levels":[{"process":"bookings","level":"simple"},{"process":"community","level":"basic"},{"process":"money","level":"statements"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"none"},{"process":"presentation","level":"basic"},{"process":"operations","level":"basic"},{"process":"assistant","level":"off"}]},{"preset":"standard","levels":[{"process":"bookings","level":"resources"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"expenses"},{"process":"presentation","level":"branded"},{"process":"operations","level":"insight"},{"process":"assistant","level":"off"}]},{"preset":"complet","levels":[{"process":"bookings","level":"measured"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"online"},{"process":"tax","level":"books"},{"process":"purchases","level":"full"},{"process":"presentation","level":"public"},{"process":"operations","level":"advanced"},{"process":"assistant","level":"off"}]}]}$json$::jsonb;
$fn$;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;

-- ── the plan tree, symbols included ──
create or replace function public.export_floor_plan(p_workspace_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select coalesce((select jsonb_agg(jsonb_build_object(
    'name', l.name, 'sort_order', l.sort_order,
    'bookable_as_whole', coalesce(l.bookable_as_whole, false), 'price_cents', coalesce(l.price_cents, 0),
    'background_path', coalesce(l.background_path, ''),
    'site', (select s.name from public.sites s where s.id = l.site_id),
    'images', coalesce((select jsonb_agg(jsonb_build_object('x', i.x, 'y', i.y, 'w', i.w, 'h', i.h, 'storage_path', i.storage_path,
                'kind', i.kind, 'quarter_turns', i.quarter_turns)
                order by coalesce(i.storage_path, i.kind), i.x, i.y) from public.plan_images i where i.level_id = l.id), '[]'::jsonb),
    'offices', coalesce((select jsonb_agg(jsonb_build_object(
      'name', o.name, 'color', o.color, 'bookable_as_whole', o.bookable_as_whole, 'price_cents', coalesce(o.price_cents, 0),
      'area_kind', o.area_kind,
      'x', o.x, 'y', o.y, 'w', o.w, 'h', o.h,
      'desks', coalesce((select jsonb_agg(jsonb_build_object(
        'name', d.name, 'x', d.x, 'y', d.y, 'w', d.w, 'h', d.h,
        'bookable_as_whole', coalesce(d.bookable_as_whole, false), 'price_cents', coalesce(d.price_cents, 0),
        'seats', coalesce((select jsonb_agg(jsonb_build_object(
          'name', st.name, 'x', st.x, 'y', st.y, 'orientation', st.orientation, 'chair', st.chair,
          'amenities', to_jsonb(st.amenities),
          'resource_kind', st.resource_kind, 'capacity', st.capacity,
          'parking_kind', st.parking_kind, 'slot_minutes', st.slot_minutes,
          'station', (select jsonb_build_object(
                        'name', cs.name, 'connector', cs.connector, 'power_kw', cs.power_kw,
                        'active', cs.active,
                        'accessory', (select a.name from public.accessories a where a.id = cs.accessory_id))
                      from public.charging_stations cs where cs.seat_id = st.id),
          'accessories', coalesce((select jsonb_agg(a.name order by a.name) from public.seat_accessories sa
                                    join public.accessories a on a.id = sa.accessory_id where sa.seat_id = st.id), '[]'::jsonb))
          order by st.name, st.x, st.y) from public.seats st where st.desk_id = d.id), '[]'::jsonb))
        order by d.name, d.x, d.y) from public.desks d where d.office_id = o.id), '[]'::jsonb))
      order by o.name, o.x, o.y) from public.offices o where o.level_id = l.id), '[]'::jsonb))
    order by l.sort_order, l.name) from public.levels l where l.workspace_id = p_workspace_id), '[]'::jsonb);
$fn$;
revoke execute on function public.export_floor_plan(uuid) from public, anon, authenticated;

create or replace function public.merge_floor_plan(p_workspace_id uuid, p_tree jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_l jsonb; v_o jsonb; v_d jsonb; v_s jsonb; v_i jsonb; v_acc text; v_st jsonb;
  v_lid uuid; v_oid uuid; v_did uuid; v_sid uuid; v_aid uuid; v_site uuid;
  v_jobs jsonb := '[]'::jsonb; v_from text; v_to text; v_name text;
  v_kind text; v_area text; v_have_kind text; v_have_area text;
begin
  if p_tree is null or jsonb_typeof(p_tree) <> 'array' then return jsonb_build_object('copy_jobs', v_jobs); end if;
  for v_l in select value from jsonb_array_elements(p_tree) loop
    select id into v_site from public.sites where workspace_id = p_workspace_id and name = v_l->>'site' limit 1;
    select id into v_lid from public.levels where workspace_id = p_workspace_id and name = v_l->>'name' order by created_at limit 1;
    -- the background: the same path under this workspace's prefix
    v_from := coalesce(v_l->>'background_path', '');
    v_to := case when v_from = '' then null else regexp_replace(v_from, '^[^/]+', p_workspace_id::text) end;
    if v_lid is null then
      insert into public.levels (workspace_id, name, sort_order, bookable_as_whole, price_cents, site_id, background_path)
      values (p_workspace_id, v_l->>'name', coalesce((v_l->>'sort_order')::int, 0), coalesce((v_l->>'bookable_as_whole')::boolean, false),
              coalesce((v_l->>'price_cents')::int, 0), v_site, v_to)
      returning id into v_lid;
    else
      update public.levels set sort_order = coalesce((v_l->>'sort_order')::int, sort_order),
        bookable_as_whole = coalesce((v_l->>'bookable_as_whole')::boolean, bookable_as_whole),
        price_cents = coalesce((v_l->>'price_cents')::int, price_cents),
        site_id = coalesce(v_site, site_id),
        background_path = coalesce(v_to, background_path)
       where id = v_lid;
    end if;
    if v_to is not null and v_from <> v_to then
      v_jobs := v_jobs || jsonb_build_object('from', v_from, 'to', v_to);
    end if;
    -- images by their path under the prefix
    for v_i in select value from jsonb_array_elements(coalesce(v_l->'images', '[]'::jsonb)) loop
      -- a drawn symbol (0607) has a kind and no object: it is found by its
      -- kind and place, so a repeated transfer adds no second wall.
      if v_i->>'kind' is not null then
        update public.plan_images set w = (v_i->>'w')::int, h = (v_i->>'h')::int,
               quarter_turns = coalesce((v_i->>'quarter_turns')::smallint, 0)
         where level_id = v_lid and kind = v_i->>'kind'
           and x = (v_i->>'x')::int and y = (v_i->>'y')::int;
        if not found then
          insert into public.plan_images (workspace_id, level_id, x, y, w, h, kind, quarter_turns)
          values (p_workspace_id, v_lid, (v_i->>'x')::int, (v_i->>'y')::int, (v_i->>'w')::int, (v_i->>'h')::int,
                  v_i->>'kind', coalesce((v_i->>'quarter_turns')::smallint, 0));
        end if;
        continue;
      end if;
      v_from := v_i->>'storage_path';
      v_to := regexp_replace(v_from, '^[^/]+', p_workspace_id::text);
      if exists (select 1 from public.plan_images where level_id = v_lid and storage_path = v_to) then
        update public.plan_images set x = (v_i->>'x')::int, y = (v_i->>'y')::int, w = (v_i->>'w')::int, h = (v_i->>'h')::int
         where level_id = v_lid and storage_path = v_to;
      else
        insert into public.plan_images (workspace_id, level_id, x, y, w, h, storage_path)
        values (p_workspace_id, v_lid, (v_i->>'x')::int, (v_i->>'y')::int, (v_i->>'w')::int, (v_i->>'h')::int, v_to);
      end if;
      if v_from <> v_to then v_jobs := v_jobs || jsonb_build_object('from', v_from, 'to', v_to); end if;
    end loop;
    -- offices
    for v_o in select value from jsonb_array_elements(coalesce(v_l->'offices', '[]'::jsonb)) loop
      v_name := coalesce(v_o->>'name', '');
      v_area := v_o->>'area_kind';
      if v_area is not null and v_area not in ('workspace', 'parking') then
        raise exception 'unknown area kind %', v_area;
      end if;
      select id, area_kind into v_oid, v_have_area from public.offices where level_id = v_lid
        and (case when v_name <> '' then name = v_name else name = '' and x = (v_o->>'x')::int and y = (v_o->>'y')::int end)
        order by created_at limit 1;
      if v_oid is null then
        insert into public.offices (workspace_id, level_id, name, color, bookable_as_whole, price_cents, area_kind, x, y, w, h)
        values (p_workspace_id, v_lid, v_name, coalesce((v_o->>'color')::int, 0), coalesce((v_o->>'bookable_as_whole')::boolean, false),
                coalesce((v_o->>'price_cents')::int, 0), coalesce(v_area, 'workspace'),
                (v_o->>'x')::int, (v_o->>'y')::int, (v_o->>'w')::int, (v_o->>'h')::int)
        returning id into v_oid;
      else
        if v_area is not null and v_area <> v_have_area then
          raise exception 'the area % cannot become %', v_name, v_area;
        end if;
        update public.offices set color = coalesce((v_o->>'color')::int, color),
          bookable_as_whole = coalesce((v_o->>'bookable_as_whole')::boolean, bookable_as_whole),
          price_cents = coalesce((v_o->>'price_cents')::int, price_cents),
          x = (v_o->>'x')::int, y = (v_o->>'y')::int, w = (v_o->>'w')::int, h = (v_o->>'h')::int
         where id = v_oid;
      end if;
      -- desks
      for v_d in select value from jsonb_array_elements(coalesce(v_o->'desks', '[]'::jsonb)) loop
        v_name := coalesce(v_d->>'name', '');
        select id into v_did from public.desks where office_id = v_oid
          and (case when v_name <> '' then name = v_name else name = '' and x = (v_d->>'x')::int and y = (v_d->>'y')::int end)
          order by created_at limit 1;
        if v_did is null then
          insert into public.desks (workspace_id, office_id, name, x, y, w, h, bookable_as_whole, price_cents)
          values (p_workspace_id, v_oid, v_name, (v_d->>'x')::int, (v_d->>'y')::int, (v_d->>'w')::int, (v_d->>'h')::int,
                  coalesce((v_d->>'bookable_as_whole')::boolean, false), coalesce((v_d->>'price_cents')::int, 0))
          returning id into v_did;
        else
          update public.desks set x = (v_d->>'x')::int, y = (v_d->>'y')::int, w = (v_d->>'w')::int, h = (v_d->>'h')::int,
            bookable_as_whole = coalesce((v_d->>'bookable_as_whole')::boolean, bookable_as_whole),
            price_cents = coalesce((v_d->>'price_cents')::int, price_cents)
           where id = v_did;
        end if;
        -- seats, rooms and parking slots
        for v_s in select value from jsonb_array_elements(coalesce(v_d->'seats', '[]'::jsonb)) loop
          v_name := coalesce(v_s->>'name', '');
          v_kind := v_s->>'resource_kind';
          if v_kind is not null and v_kind not in ('seat', 'room', 'parking') then
            raise exception 'unknown resource kind %', v_kind;
          end if;
          select id, resource_kind into v_sid, v_have_kind from public.seats where desk_id = v_did
            and (case when v_name <> '' then name = v_name else name = '' and x = (v_s->>'x')::int and y = (v_s->>'y')::int end)
            order by created_at limit 1;
          if v_sid is null then
            insert into public.seats (workspace_id, desk_id, name, x, y, orientation, chair, amenities,
                                      resource_kind, capacity, parking_kind, slot_minutes)
            values (p_workspace_id, v_did, v_name, (v_s->>'x')::int, (v_s->>'y')::int, coalesce(v_s->>'orientation', 'n'),
                    coalesce(v_s->>'chair', ''), public.jsonb_text_array(v_s->'amenities'),
                    coalesce(v_kind, 'seat'), (v_s->>'capacity')::int, v_s->>'parking_kind',
                    (v_s->>'slot_minutes')::int)
            returning id into v_sid;
          else
            if v_kind is not null and v_kind <> v_have_kind then
              raise exception 'the slot % is a % here and cannot become a %', v_name, v_have_kind, v_kind;
            end if;
            update public.seats set x = (v_s->>'x')::int, y = (v_s->>'y')::int, orientation = coalesce(v_s->>'orientation', orientation),
              chair = coalesce(v_s->>'chair', chair),
              amenities = public.jsonb_text_array(v_s->'amenities'),
              capacity = case when v_s ? 'capacity' then (v_s->>'capacity')::int else capacity end,
              parking_kind = case when v_s ? 'parking_kind' then v_s->>'parking_kind' else parking_kind end,
              slot_minutes = case when v_s ? 'slot_minutes' then (v_s->>'slot_minutes')::int else slot_minutes end
             where id = v_sid;
          end if;
          -- accessories by name: the source's set becomes the seat's set
          delete from public.seat_accessories where seat_id = v_sid;
          for v_acc in select jsonb_array_elements_text(coalesce(v_s->'accessories', '[]'::jsonb)) loop
            select id into v_aid from public.accessories where workspace_id = p_workspace_id and name = v_acc limit 1;
            if v_aid is not null then
              insert into public.seat_accessories (workspace_id, seat_id, accessory_id) values (p_workspace_id, v_sid, v_aid)
              on conflict do nothing;
            end if;
          end loop;
          -- its charging station: one per EV slot, upserted on the slot
          v_st := v_s->'station';
          if v_st is not null and jsonb_typeof(v_st) = 'object' then
            v_aid := null;
            if coalesce(v_st->>'accessory', '') <> '' then
              select id into v_aid from public.accessories
               where workspace_id = p_workspace_id and name = v_st->>'accessory' limit 1;
              if v_aid is null then
                raise exception 'the charging station of % names the accessory %, which this space does not have',
                  v_name, v_st->>'accessory';
              end if;
            end if;
            insert into public.charging_stations (workspace_id, seat_id, name, connector, power_kw, accessory_id, active)
            values (p_workspace_id, v_sid, coalesce(v_st->>'name', ''), v_st->>'connector',
                    (v_st->>'power_kw')::numeric, v_aid, coalesce((v_st->>'active')::boolean, true))
            on conflict (seat_id) do update
              set name = excluded.name, connector = excluded.connector, power_kw = excluded.power_kw,
                  accessory_id = excluded.accessory_id, active = excluded.active;
          end if;
        end loop;
      end loop;
    end loop;
  end loop;
  return jsonb_build_object('copy_jobs', v_jobs);
end;
$fn$;
revoke execute on function public.merge_floor_plan(uuid, jsonb) from public, anon, authenticated;

select public.set_deskilo_schema_version(608);
