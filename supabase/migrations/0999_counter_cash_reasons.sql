-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
--
-- #4514 (audit STK-10) -- the reasons of cash put into or taken out of a till drawer, and of a count's difference, are
-- records of the business, not a comma-separated text.
--   * counterCashReasons       a flag under counterTillSessions, on by default: the reasons' card on Master data. The
--                              till reads the reasons whatever the flag; every door refuses a reason that is not active
--                              for its process.
--   * counter_cash_reasons     a business's reasons: a code (stable, unique in the business), the processes it serves
--                              (paid_in, paid_out, count_difference), active or archived, a sort order. A built-in reason
--                              (change, expense, other, counting_error) is named by the app in its five languages; a
--                              business's own reason carries the one name it was typed with. Every business has the
--                              built-in ones; the words of the setting `counter.cash_reasons` become reasons once
--                              (the built-in ones by their code, any other as the business's own), and the setting is
--                              removed.
--   * counter_cash_entry_v1    takes only an active reason of the entry's kind (DKL13 reason_unknown), by code.
--   * the template field registry names the flag in 1000 (#4512), restated there from a tree holding both flags.
--   * a session's difference   a count's difference reason is an active count_difference reason (DKL13 reason_unknown),
--     reason                   whatever door writes it; a reason stored before keeps its text.
-- BEGIN FEATURE REGISTRY ROWS (dart run tool/build_feature_registry_sql.dart)
insert into public.feature_registry_entries (feature_key, parent, default_on, core, countries) values
('counterCashReasons', null, true, false, null)
on conflict (feature_key) do update set parent = excluded.parent, default_on = excluded.default_on, core = excluded.core, countries = excluded.countries;
-- END FEATURE REGISTRY ROWS

create table public.counter_cash_reasons (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  code text not null check (code ~ '^[a-z0-9_]{1,40}$'),
  builtin boolean not null default false,
  name text check (name is null or char_length(btrim(name)) between 1 and 60),
  processes text[] not null check (cardinality(processes) between 1 and 3
    and processes <@ array['paid_in', 'paid_out', 'count_difference']),
  archived boolean not null default false,
  sort_order integer not null default 0,
  unique (workspace_id, code),
  check (builtin = (name is null))
);
select public.ensure_system_columns('counter_cash_reasons');
create index counter_cash_reasons_workspace on public.counter_cash_reasons (workspace_id, sort_order);

comment on table public.counter_cash_reasons is
  '#4514 -- the reasons of cash in or out of a till drawer and of a count''s difference: coded records of the business.';

alter table public.counter_cash_reasons enable row level security;
revoke all on public.counter_cash_reasons from public, anon, authenticated;
grant select on public.counter_cash_reasons to authenticated;
create policy counter_cash_reasons_select on public.counter_cash_reasons for select to authenticated
  using (public.is_member_of(workspace_id));
create policy mcp_delegated_deny on public.counter_cash_reasons as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The built-in reasons, as a business starts with them.
create or replace function public.counter_cash_reasons_builtin()
returns table (code text, processes text[], sort_order integer) language sql immutable set search_path = '' as $fn$
  values ('change', array['paid_in', 'paid_out'], 10),
         ('expense', array['paid_out'], 20),
         ('counting_error', array['count_difference'], 30),
         ('other', array['paid_in', 'paid_out', 'count_difference'], 40)
$fn$;
revoke execute on function public.counter_cash_reasons_builtin() from public, anon, authenticated;

-- A business's reasons: the built-in ones it lacks, then the words of its old setting that are none of them.
create or replace function public.counter_cash_reasons_seed(p_workspace_id uuid, p_words text)
returns void language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_word text;
  v_code text;
  v_position integer := 100;
begin
  insert into public.counter_cash_reasons (workspace_id, code, builtin, processes, sort_order)
  select p_workspace_id, b.code, true, b.processes, b.sort_order from public.counter_cash_reasons_builtin() b
  on conflict (workspace_id, code) do nothing;
  foreach v_word in array coalesce(string_to_array(p_words, ','), '{}') loop
    v_word := btrim(v_word);
    continue when v_word = '' or char_length(v_word) > 60;
    v_code := left(coalesce(nullif(btrim(regexp_replace(lower(v_word), '[^a-z0-9]+', '_', 'g'), '_'), ''), 'reason_' || v_position), 36);
    continue when exists (select 1 from public.counter_cash_reasons r where r.workspace_id = p_workspace_id and r.code = v_code);
    insert into public.counter_cash_reasons (workspace_id, code, builtin, name, processes, sort_order)
    values (p_workspace_id, v_code, false, v_word, array['paid_in', 'paid_out'], v_position);
    v_position := v_position + 10;
  end loop;
end;
$fn$;
revoke execute on function public.counter_cash_reasons_seed(uuid, text) from public, anon, authenticated;

-- Every business, now: its setting's words (or the built-in ones), then the setting removed.
do $migration$
declare
  w record;
begin
  for w in select id from public.workspaces loop
    perform public.counter_cash_reasons_seed(w.id, public.setting_value(w.id, 'counter.cash_reasons') #>> '{}');
  end loop;
end
$migration$;

-- A new business starts with the built-in reasons.
create or replace function public.workspaces_cash_reasons_seed()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  perform public.counter_cash_reasons_seed(new.id, null);
  return new;
end;
$fn$;
revoke execute on function public.workspaces_cash_reasons_seed() from public, anon, authenticated;
drop trigger if exists workspaces_cash_reasons_seed on public.workspaces;
create trigger workspaces_cash_reasons_seed after insert on public.workspaces
  for each row execute function public.workspaces_cash_reasons_seed();

-- Who configures the tills writes a reason: a new one of the business's own (null [p_code], its code made from its name),
-- or an existing one's name (its own only), processes, sort_order and archive. Answers the reason's code.
create or replace function public.counter_cash_reason_save_v1(
  p_workspace_id uuid, p_code text, p_name text, p_processes text[], p_sort_order integer, p_archived boolean
) returns jsonb language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_row public.counter_cash_reasons;
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
  v_code text;
  v_base text;
  v_n integer := 1;
begin
  perform public.command_actor(p_workspace_id, 'configureTill', 'counterCashReasons',
    'only who configures the tills sets the cash reasons', 'cash reasons are off in this business');
  if p_processes is null or cardinality(p_processes) = 0
     or not (p_processes <@ array['paid_in', 'paid_out', 'count_difference']) then
    perform public.refuse('DKL13', '{"reason": "reason_process"}'::jsonb, 'a reason serves at least one process');
  end if;
  if p_code is null then
    if v_name is null or char_length(v_name) > 60 then
      perform public.refuse('DKL13', '{"reason": "reason_name"}'::jsonb, 'a reason of the business has a name');
    end if;
    v_base := left(coalesce(nullif(btrim(regexp_replace(lower(v_name), '[^a-z0-9]+', '_', 'g'), '_'), ''), 'reason'), 36);
    v_code := v_base;
    while exists (select 1 from public.counter_cash_reasons r where r.workspace_id = p_workspace_id and r.code = v_code) loop
      v_n := v_n + 1;
      v_code := v_base || '_' || v_n;
    end loop;
    insert into public.counter_cash_reasons (workspace_id, code, builtin, name, processes, sort_order, archived)
    values (p_workspace_id, v_code, false, v_name, p_processes, coalesce(p_sort_order, 100), coalesce(p_archived, false))
    returning * into v_row;
  else
    select * into v_row from public.counter_cash_reasons
     where workspace_id = p_workspace_id and code = p_code for update;
    if v_row.id is null then
      perform public.refuse('DKL13', '{"reason": "reason_unknown"}'::jsonb, 'no such reason in this business');
    end if;
    if not v_row.builtin and (v_name is null or char_length(v_name) > 60) then
      perform public.refuse('DKL13', '{"reason": "reason_name"}'::jsonb, 'a reason of the business has a name');
    end if;
    update public.counter_cash_reasons
       set name = case when builtin then null else v_name end,
           processes = (select array_agg(distinct p order by p) from unnest(p_processes) p),
           sort_order = coalesce(p_sort_order, sort_order),
           archived = coalesce(p_archived, archived)
     where id = v_row.id
     returning * into v_row;
  end if;
  return jsonb_build_object('code', v_row.code, 'builtin', v_row.builtin, 'name', v_row.name,
                            'processes', to_jsonb(v_row.processes), 'archived', v_row.archived, 'sort_order', v_row.sort_order);
end;
$fn$;
revoke execute on function public.counter_cash_reason_save_v1(uuid, text, text, text[], integer, boolean) from public, anon;
grant execute on function public.counter_cash_reason_save_v1(uuid, text, text, text[], integer, boolean) to authenticated;

-- Whether [p_code] is an active reason of the business for [p_process].
create or replace function public.counter_cash_reason_active(p_workspace_id uuid, p_code text, p_process text)
returns boolean language sql stable security definer set search_path = '' as $fn$
  select exists (select 1 from public.counter_cash_reasons r
                  where r.workspace_id = p_workspace_id and r.code = btrim(coalesce(p_code, ''))
                    and not r.archived and p_process = any (r.processes))
$fn$;
revoke execute on function public.counter_cash_reason_active(uuid, text, text) from public, anon, authenticated;

-- A count's difference reason is an active count_difference reason, whatever door writes it; one stored before stays.
create or replace function public.counter_till_sessions_difference_reason()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  if new.difference_reason is not null and btrim(new.difference_reason) <> ''
     and new.difference_reason is distinct from (case when tg_op = 'UPDATE' then old.difference_reason end)
     and not public.counter_cash_reason_active(new.workspace_id, new.difference_reason, 'count_difference') then
    perform public.refuse('DKL13', '{"reason": "reason_unknown"}'::jsonb, 'this reason is not on the business''s list');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.counter_till_sessions_difference_reason() from public, anon, authenticated;
drop trigger if exists counter_till_sessions_difference_reason on public.counter_till_sessions;
create trigger counter_till_sessions_difference_reason
  before insert or update of difference_reason on public.counter_till_sessions
  for each row execute function public.counter_till_sessions_difference_reason();

-- A cash entry's reason, whatever door writes it, is an active reason of the entry's kind.
create or replace function public.counter_cash_entries_reason()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  if not public.counter_cash_reason_active(new.workspace_id, new.reason, new.kind) then
    perform public.refuse('DKL13', '{"reason": "reason_unknown"}'::jsonb, 'this reason is not on the business''s list');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.counter_cash_entries_reason() from public, anon, authenticated;
drop trigger if exists counter_cash_entries_reason on public.counter_cash_entries;
create trigger counter_cash_entries_reason before insert on public.counter_cash_entries
  for each row execute function public.counter_cash_entries_reason();

-- counter_cash_entry_v1 reads the reasons instead of the setting (anchored patch of the live body).
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text) returns text language plpgsql as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    perform public.refuse('DKG11', jsonb_build_object('field', left(p_old, 60), 'reason', 'anchor_missing'), '0999: anchor not found exactly once');
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_cash_entry_v1(uuid,uuid,uuid,text,bigint,text,uuid)'::regprocedure);
begin
  execute pg_temp.anchor_replace(v_def,
    $a$v_reasons := array(select btrim(x) from unnest(string_to_array(coalesce(public.setting_value(p_workspace_id, 'counter.cash_reasons') #>> '{}', 'change,expense,other'), ',')) x where btrim(x) <> '');$a$,
    $a$v_reasons := array(select r.code from public.counter_cash_reasons r where r.workspace_id = p_workspace_id and not r.archived and p_kind = any (r.processes)); -- #4514 (0999)$a$);
end
$patch$;

-- the old setting goes: its words are reasons now
delete from public.setting_values where key = 'counter.cash_reasons';
delete from public.setting_definitions where key = 'counter.cash_reasons';

-- ── the builtin association template writes the feature flags: it names counterCashReasons (dart run tool/build_builtin_templates.dart) ──
-- restates 0982
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
  $cfg${"workspace":{"default_locale":"fr","vat_regime":"not_subject","booking_rules":{"granularity":"half_day","open_weekdays":[1,2,3,4,5],"work_start_minutes":420,"half_boundary_minutes":780,"work_end_minutes":1140,"max_series_days":180,"advance_horizon_days":90,"max_duration_minutes":1440,"min_duration_minutes":30},"subscription_levels":{"allow_custom":false,"extra_levels":[],"enabled_presets":[50,100]},"feature_flags":{"accessorySupplements":false,"accountingBook":false,"accountingConnectors":false,"accountingPeriods":false,"adminInvoicing":false,"adminLevelAssign":false,"adminSeatBlocking":false,"assetRegister":false,"autoCheckInOut":false,"badgeSignIn":false,"bankImport":false,"biReportDesigner":false,"billingCustomers":false,"bookForOthers":true,"bookingGate":true,"bookingPolicies":true,"calendarFileExport":true,"calendarHub":true,"calendarTab":true,"calendarValidations":true,"calendarViews":true,"capacityKpi":false,"captureProtection":true,"carnets":true,"coOwner":false,"configurableSettings":false,"configurationTransfer":false,"counterCashReasons":true,"counterEmbeddedTerminal":false,"counterOfflineCash":false,"counterReceiptPrinter":false,"counterReceipts":false,"counterTillLayout":false,"counterTillSessions":false,"customFields":false,"customRoles":true,"customerQuotes":false,"dataAccessLog":false,"dataExport":true,"dataReport":true,"decisionSurface":false,"deletionRequests":true,"demoMode":false,"deployments":false,"documents":true,"dunning":false,"einvoiceCustomerDelivery":false,"environmentPairs":false,"eventsTab":false,"expenseRepartition":false,"expenseRepartitionWizard":false,"externalRooms":false,"financeFaces":true,"foreignCurrencyPurchases":false,"formHelpHints":true,"guestParticipation":false,"guestPasses":false,"holidayImport":false,"inputVat":false,"instanceWizard":false,"invoiceAddressWindow":false,"invoiceEmail":false,"invoiceJourney":false,"invoicePdfTemplate":false,"invoiceSettlement":false,"invoicing":true,"invoicingWizard":false,"kioskEnrolment":false,"kioskMemberPhotos":false,"kioskMode":false,"letterStandard":false,"levelBooking":false,"managedProfileAccess":false,"managedProfiles":false,"mcpAccess":false,"meetingRooms":false,"memberAccountMenu":false,"memberDataExport":true,"memberEnvironments":false,"memberGettingStarted":true,"memberNotifications":true,"memberOrigin":false,"memberPage":false,"memberPaymentTerms":false,"memberReports":false,"membersDirectory":false,"messageForwarding":true,"messageGestures":true,"messageMentions":true,"messagesHub":true,"moneyTab":true,"mtdSubmission":false,"multiSite":false,"navigationStyle":true,"nfcBadges":false,"nfcSeatTags":false,"notificationGrouping":false,"numberSequences":false,"onlinePayments":false,"organisation":true,"parking":false,"paymentReminders":false,"pdfExport":true,"personalInfo":true,"personalShell":false,"placeBooking":true,"placeFeedback":true,"planDecor":true,"planMemberPhotos":false,"planObjectDelete":true,"premisesLease":false,"priceNegotiations":false,"publicHolidays":false,"publicListings":false,"purchaseAnalytics":false,"purchaseOrders":false,"purchases":false,"pushNotifications":true,"qrBadges":false,"quickSearch":true,"recapitulativeStatement":false,"recordingPrivacy":false,"regionalFormats":true,"reminderEmail":false,"reportDesignExchange":false,"reportDesigner":false,"reportLayouts":false,"reportTexts":false,"richMessageRefs":true,"roleAssignment":true,"roleManagement":true,"salesTax":false,"scheduledExpenses":false,"seatDayTimeline":true,"seriesBooking":true,"serviceFulfilment":false,"services":true,"settlementFold":false,"setupGuide":true,"singleRoomLevelNames":true,"spaceInquiries":true,"spaceQrCodes":true,"standaloneInvoicing":false,"stockCounts":false,"stockCycleCounts":false,"stockExpiryReport":false,"stockHandlingUnits":false,"stockItemGroups":false,"stockLots":false,"stockManagement":false,"stockReceiving":false,"stockReorder":false,"stockReturns":false,"stockScanning":false,"stockTagReads":false,"stockTags":false,"stockTakeOut":false,"subscriptionInvoices":false,"supplyClassification":false,"supplyExpenses":false,"taskRecorder":false,"uiAnimations":true,"uniqueMonograms":true,"unitsOfMeasure":false,"usageInvoices":false,"usageRecords":false,"usageReport":false,"validationChain":false,"validationScopes":false,"vatCounterparty":false,"vatDeclarations":false,"vatGroups":false,"vatManagement":false,"vatRateHistory":false,"vatReport":false,"viesVerification":false,"webMcp":false,"whatsappIntegration":false,"workingHours":true,"workspaceBranding":false,"workspaceLibrary":false,"workspaceOverview":false,"workspaceStatus":false,"workspaceVocabulary":true},"lexicon":{"fr":{"spaceKindSeat":"Place","spaceKindLevel":"Étage","shellReserveButton":"Réservations"}}},"tables":{"fee_bands":[{"from_pct":0,"to_pct":50,"fee_cents":5000,"overage_fee_cents":0},{"from_pct":50,"to_pct":100,"fee_cents":10000,"overage_fee_cents":0}],"workspace_roles":[{"key":"tresorier","names":{"fr":"Trésorier·ère","en":"Treasurer","de":"Kassenwart","es":"Tesorero/a","it":"Tesoriere"},"permissions":["viewFinances","issueInvoices","manageBilling","approveExpenses","exportData"],"sort_order":1,"active":true},{"key":"secretaire","names":{"fr":"Secrétaire","en":"Secretary","de":"Schriftführer","es":"Secretario/a","it":"Segretario"},"permissions":["manageMembers","manageDocuments","viewPersonalData"],"sort_order":2,"active":true},{"key":"referent_salle","names":{"fr":"Référent·e de salle","en":"Room steward","de":"Raumverantwortlicher","es":"Responsable de sala","it":"Referente di sala"},"permissions":["manageReservations","manageValidation","operateKiosk"],"sort_order":3,"active":true}],"credit_products":[{"name":"Carnet 10 demi-journées","half_days":10,"price_cents":5000,"validity_months":null,"active":true,"sort_order":1},{"name":"Carnet 20 demi-journées","half_days":20,"price_cents":8000,"validity_months":null,"active":true,"sort_order":2}]},"holidays":{"years":2}}$cfg$::jsonb,
  $tpl$[{"name":"Rez-de-chaussée","sort_order":0,"bookable_as_whole":false,"price_cents":0,"background_path":"","site":null,"images":[],"offices":[{"name":"Salle principale","color":0,"bookable_as_whole":true,"price_cents":0,"x":0,"y":0,"w":40,"h":24,"desks":[{"name":"Table 1","x":2,"y":2,"w":14,"h":8,"bookable_as_whole":true,"price_cents":0,"seats":[{"name":"A1","x":4,"y":4,"orientation":"n","chair":"standard","amenities":[],"accessories":[]},{"name":"A2","x":12,"y":4,"orientation":"n","chair":"standard","amenities":[],"accessories":[]}]},{"name":"Table 2","x":22,"y":2,"w":14,"h":8,"bookable_as_whole":true,"price_cents":0,"seats":[{"name":"B1","x":24,"y":4,"orientation":"n","chair":"standard","amenities":[],"accessories":[]},{"name":"B2","x":32,"y":4,"orientation":"n","chair":"standard","amenities":[],"accessories":[]}]}]}]},{"name":"Étage","sort_order":1,"bookable_as_whole":false,"price_cents":0,"background_path":"","site":null,"images":[],"offices":[{"name":"Salle du haut","color":0,"bookable_as_whole":true,"price_cents":0,"x":0,"y":0,"w":40,"h":24,"desks":[{"name":"Table 3","x":2,"y":2,"w":14,"h":8,"bookable_as_whole":true,"price_cents":0,"seats":[{"name":"C1","x":4,"y":4,"orientation":"n","chair":"standard","amenities":[],"accessories":[]},{"name":"C2","x":12,"y":4,"orientation":"n","chair":"standard","amenities":[],"accessories":[]}]},{"name":"Table 4","x":22,"y":2,"w":14,"h":8,"bookable_as_whole":true,"price_cents":0,"seats":[{"name":"D1","x":24,"y":4,"orientation":"n","chair":"standard","amenities":[],"accessories":[]},{"name":"D2","x":32,"y":4,"orientation":"n","chair":"standard","amenities":[],"accessories":[]}]}]}]}]$tpl$::jsonb
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

-- ── the setup levels name counterCashReasons (dart run tool/build_setup_steps.dart, #2923) ──
-- restates 0982
create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json${"processes":[{"process":"bookings","levels":[{"level":"none","features":[],"needs":[]},{"level":"simple","features":["seriesBooking","bookForOthers","spaceQrCodes","workingHours","planObjectDelete","bookingPolicies","seatDayTimeline","bookingGate","singleRoomLevelNames","calendarFileExport","placeFeedback","planDecor","placeBooking"],"needs":[]},{"level":"resources","features":["adminSeatBlocking","levelBooking","adminLevelAssign","planMemberPhotos","multiSite","publicHolidays","holidayImport","guestParticipation","meetingRooms","parking","externalRooms"],"needs":[]},{"level":"measured","features":["kioskMode","nfcBadges","autoCheckInOut","nfcSeatTags","qrBadges","kioskMemberPhotos","badgeSignIn","capacityKpi","kioskEnrolment"],"needs":[]}]},{"process":"community","levels":[{"level":"basic","features":["calendarTab","eventsTab","pushNotifications","membersDirectory","memberNotifications","deletionRequests","roleManagement","notificationGrouping","calendarHub","richMessageRefs","personalInfo","messageGestures","calendarViews","messagesHub","memberPage","messageForwarding","captureProtection","roleAssignment","messageMentions"],"needs":[]},{"level":"organised","features":["whatsappIntegration","coOwner","validationScopes","validationChain","calendarValidations","managedProfiles","managedProfileAccess","memberOrigin","customRoles","customFields"],"needs":[]}]},{"process":"money","levels":[{"level":"none","features":[],"needs":[]},{"level":"statements","features":["moneyTab","services","accessorySupplements","memberReports","dataAccessLog","financeFaces","priceNegotiations"],"needs":[]},{"level":"invoices","features":["invoicing","adminInvoicing","invoicePdfTemplate","invoiceAddressWindow","dunning","paymentReminders","usageRecords","reportDesignExchange","reportLayouts","numberSequences","workspaceStatus","memberPaymentTerms","reportTexts","usageReport","letterStandard","subscriptionInvoices","usageInvoices","invoiceSettlement","invoiceJourney","reportDesigner","invoicingWizard","settlementFold","carnets","guestPasses","reminderEmail","invoiceEmail","standaloneInvoicing","billingCustomers","customerQuotes","serviceFulfilment"],"needs":[]}]},{"process":"payments","levels":[{"level":"off","features":[],"needs":[]},{"level":"online","features":["onlinePayments"],"needs":[{"process":"money","level":"statements"}]}]},{"process":"tax","levels":[{"level":"none","features":[],"needs":[]},{"level":"vat","features":["vatManagement","vatDeclarations","vatGroups","vatRateHistory","vatCounterparty","vatReport","supplyClassification","viesVerification","recapitulativeStatement","inputVat","salesTax"],"needs":[{"process":"money","level":"invoices"}]},{"level":"books","features":["einvoiceCustomerDelivery","accountingBook","accountingPeriods","accountingConnectors","bankImport","mtdSubmission"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"purchases","levels":[{"level":"none","features":[],"needs":[]},{"level":"expenses","features":["supplyExpenses","expenseRepartitionWizard","scheduledExpenses","expenseRepartition"],"needs":[{"process":"money","level":"invoices"}]},{"level":"full","features":["purchases","premisesLease","assetRegister","purchaseAnalytics","foreignCurrencyPurchases","purchaseOrders","stockManagement","stockLots","stockReceiving","stockTakeOut","stockReorder","stockReturns","stockCounts","stockCycleCounts","stockItemGroups","stockTags","stockScanning","counterReceipts","counterTillSessions","stockTagReads","stockExpiryReport","stockHandlingUnits","counterOfflineCash","unitsOfMeasure","counterTillLayout","counterReceiptPrinter","counterEmbeddedTerminal","counterCashReasons"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"presentation","levels":[{"level":"basic","features":["uniqueMonograms"],"needs":[]},{"level":"branded","features":["workspaceVocabulary","workspaceBranding"],"needs":[]},{"level":"public","features":["publicListings","spaceInquiries"],"needs":[]}]},{"process":"operations","levels":[{"level":"basic","features":["pdfExport","dataExport","documents","formHelpHints","uiAnimations","regionalFormats","memberDataExport","navigationStyle","demoMode","memberAccountMenu","memberGettingStarted","setupGuide","dataReport","quickSearch","organisation"],"needs":[]},{"level":"insight","features":["decisionSurface","biReportDesigner","workspaceOverview"],"needs":[]},{"level":"advanced","features":["environmentPairs","deployments","configurationTransfer","instanceWizard","memberEnvironments","workspaceLibrary","configurableSettings"],"needs":[]}]},{"process":"assistant","levels":[{"level":"off","features":[],"needs":[]},{"level":"on","features":["recordingPrivacy","mcpAccess","taskRecorder","webMcp"],"needs":[]}]}],"presets":[{"preset":"essentiel","levels":[{"process":"bookings","level":"simple"},{"process":"community","level":"basic"},{"process":"money","level":"statements"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"none"},{"process":"presentation","level":"basic"},{"process":"operations","level":"basic"},{"process":"assistant","level":"off"}]},{"preset":"standard","levels":[{"process":"bookings","level":"resources"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"expenses"},{"process":"presentation","level":"branded"},{"process":"operations","level":"insight"},{"process":"assistant","level":"off"}]},{"preset":"complet","levels":[{"process":"bookings","level":"measured"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"online"},{"process":"tax","level":"books"},{"process":"purchases","level":"full"},{"process":"presentation","level":"public"},{"process":"operations","level":"advanced"},{"process":"assistant","level":"off"}]}]}$json$::jsonb;
$fn$;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;

select public.set_deskilo_schema_version(999);
