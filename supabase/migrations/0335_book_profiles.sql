-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0335 (#1869) -- who keeps the official books of each issuer.
--
-- A book profile belongs to one issuing site (its own legal identity),
-- never to a workspace name or a locale: two issuers that share a
-- workspace keep two books, and one issuer keeps one whatever else the
-- workspace holds. It states ONE authority mode:
--   * pre_accounting -- what DesKilo has always been: member balances
--                       and invoices, nothing posted (ADR 0022 stands);
--   * local_book     -- DesKilo is the book (#1871 owns posting);
--   * external_book  -- a named external system stays authoritative,
--                       and whatever DesKilo derives is labelled derived.
-- With the functional currency, the fiscal year's first day, the
-- accounting basis and the first day the version governs. Versions are
-- prospective: a new one takes effect from its date and never rewrites
-- what an earlier one governed.
--
-- The table is reached only through two definer functions:
--   * book_profiles(workspace)  -- read: viewFinances or manageBilling.
--                                  Not gated on the flag: what was
--                                  configured stays readable (#1851).
--   * save_book_profile(...)    -- write: manageBilling, accountingBook
--                                  accepting new work, an issuer of THIS
--                                  workspace, and the revision the saver
--                                  read (0 for a new version).
-- Nothing here posts, migrates or touches an invoice; with the flag off
-- every member, invoice and payment works as before.
--
-- The flag `accountingBook` (Money, Platform, default OFF, under
-- invoicing) joins the server's registry. Everything below the two
-- functions is GENERATED:
--   * `feature_registry()`       -- dart run tool/build_feature_registry_sql.dart
--   * `template_field_registry()`-- dart run tool/build_template_field_registry_sql.dart
--   * the association builtin     -- supabase/templates/association_fr.json
--     (dart run tool/build_builtin_templates.dart), restated because the
--     builtin names every feature; accountingBook is false there.

create table if not exists public.book_profiles (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  issuer_site_id uuid not null references public.sites (id) on delete restrict,
  authority_mode text not null default 'pre_accounting'
    check (authority_mode in ('pre_accounting', 'local_book', 'external_book')),
  external_system text not null default ''
    check (char_length(external_system) <= 80),
  functional_currency text not null check (functional_currency ~ '^[A-Z]{3}$'),
  fiscal_year_start_month smallint not null check (fiscal_year_start_month between 1 and 12),
  fiscal_year_start_day smallint not null check (fiscal_year_start_day between 1 and 31),
  accounting_basis text not null check (accounting_basis in ('accrual', 'cash')),
  effective_from date not null,
  revision integer not null default 1 check (revision >= 1),
  constraint book_profiles_external_named
    check (authority_mode <> 'external_book' or btrim(external_system) <> ''),
  constraint book_profiles_issuer_version unique (issuer_site_id, effective_from)
);
select public.ensure_system_columns('book_profiles');
create index if not exists book_profiles_workspace_idx
  on public.book_profiles (workspace_id, issuer_site_id, effective_from);
alter table public.book_profiles enable row level security;
revoke all on table public.book_profiles from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.book_profiles;
create policy mcp_delegated_deny on public.book_profiles
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.book_profiles(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not (public.has_permission(p_workspace_id, 'viewFinances')
             or public.has_permission(p_workspace_id, 'manageBilling')) then
    raise exception 'only someone who reads this workspace''s finances reads its books'
      using errcode = '42501';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', b.id, 'workspace_id', b.workspace_id, 'issuer_site_id', b.issuer_site_id,
      'authority_mode', b.authority_mode, 'external_system', b.external_system,
      'functional_currency', b.functional_currency,
      'fiscal_year_start_month', b.fiscal_year_start_month,
      'fiscal_year_start_day', b.fiscal_year_start_day,
      'accounting_basis', b.accounting_basis,
      'effective_from', to_char(b.effective_from, 'YYYY-MM-DD'),
      'revision', b.revision)
    order by b.issuer_site_id, b.effective_from)
    from public.book_profiles b where b.workspace_id = p_workspace_id), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.book_profiles(uuid) from public, anon;
grant execute on function public.book_profiles(uuid) to authenticated;

create or replace function public.save_book_profile(
  p_workspace_id uuid, p_issuer_site_id uuid, p_authority_mode text, p_external_system text,
  p_functional_currency text, p_fiscal_year_start_month int, p_fiscal_year_start_day int,
  p_accounting_basis text, p_effective_from date, p_expected_revision int
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.book_profiles;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'only someone who manages billing sets the books' using errcode = '42501';
  end if;
  if not public.feature_operation_allowed(p_workspace_id, 'accountingBook', 'accept_new') then
    raise exception 'the accounting book is not switched on' using errcode = '42501';
  end if;
  if not exists (select 1 from public.sites s
                  where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'the issuer is not a site of this workspace' using errcode = '42501';
  end if;
  if p_authority_mode is null or p_authority_mode not in ('pre_accounting', 'local_book', 'external_book') then
    raise exception 'unknown authority mode' using errcode = '22023';
  end if;
  if p_authority_mode = 'external_book' and btrim(coalesce(p_external_system, '')) = '' then
    raise exception 'an external book names the system that stays authoritative' using errcode = '22023';
  end if;
  if p_functional_currency is null or p_functional_currency !~ '^[A-Z]{3}$' then
    raise exception 'a currency is three capital letters' using errcode = '22023';
  end if;
  if p_accounting_basis is null or p_accounting_basis not in ('accrual', 'cash') then
    raise exception 'unknown accounting basis' using errcode = '22023';
  end if;
  -- A fiscal year starts on a day every year has: never 29 February.
  if p_fiscal_year_start_month is null or p_fiscal_year_start_day is null
     or p_fiscal_year_start_month not between 1 and 12 or p_fiscal_year_start_day < 1
     or p_fiscal_year_start_day > extract(day from (make_date(2026, p_fiscal_year_start_month, 1)
                                                    + interval '1 month - 1 day'))::int then
    raise exception 'a fiscal year starts on a day every year has' using errcode = '22023';
  end if;
  if p_effective_from is null then
    raise exception 'a book profile takes effect from a date' using errcode = '22023';
  end if;

  select * into v from public.book_profiles
   where issuer_site_id = p_issuer_site_id and effective_from = p_effective_from
   for update;
  if v.id is null then
    if coalesce(p_expected_revision, -1) <> 0 then
      raise exception 'stale book profile: it was removed or never saved' using errcode = '40001';
    end if;
    insert into public.book_profiles (workspace_id, issuer_site_id, authority_mode, external_system,
        functional_currency, fiscal_year_start_month, fiscal_year_start_day, accounting_basis, effective_from)
    values (p_workspace_id, p_issuer_site_id, p_authority_mode, btrim(coalesce(p_external_system, '')),
        p_functional_currency, p_fiscal_year_start_month, p_fiscal_year_start_day, p_accounting_basis,
        p_effective_from)
    returning * into v;
  else
    if coalesce(p_expected_revision, -1) <> v.revision then
      raise exception 'stale book profile: someone saved it since you read it' using errcode = '40001';
    end if;
    update public.book_profiles
       set authority_mode = p_authority_mode, external_system = btrim(coalesce(p_external_system, '')),
           functional_currency = p_functional_currency,
           fiscal_year_start_month = p_fiscal_year_start_month,
           fiscal_year_start_day = p_fiscal_year_start_day,
           accounting_basis = p_accounting_basis, revision = v.revision + 1
     where id = v.id
     returning * into v;
  end if;
  return jsonb_build_object(
      'id', v.id, 'workspace_id', v.workspace_id, 'issuer_site_id', v.issuer_site_id,
      'authority_mode', v.authority_mode, 'external_system', v.external_system,
      'functional_currency', v.functional_currency,
      'fiscal_year_start_month', v.fiscal_year_start_month,
      'fiscal_year_start_day', v.fiscal_year_start_day,
      'accounting_basis', v.accounting_basis,
      'effective_from', to_char(v.effective_from, 'YYYY-MM-DD'),
      'revision', v.revision);
end;
$fn$;
revoke execute on function public.save_book_profile(uuid, uuid, text, text, text, int, int, text, date, int) from public, anon;
grant execute on function public.save_book_profile(uuid, uuid, text, text, text, int, int, text, date, int) to authenticated;

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
    "calendarHub": {"parent": null, "default": true, "core": true},
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
    "spaceInquiries": {"parent": null, "default": true, "core": true},
    "messageForwarding": {"parent": "memberNotifications", "default": true, "core": true},
    "captureProtection": {"parent": "memberNotifications", "default": true, "core": true},
    "holidayImport": {"parent": "publicHolidays", "default": false, "core": false},
    "capacityKpi": {"parent": null, "default": false, "core": false},
    "accountingBook": {"parent": "invoicing", "default": false, "core": false}
  }'::jsonb
$registry$;

revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

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
    {"id":"tables.workspace_roles[].permissions","entity":"workspace_roles","type":"list","portability":"literal","absent":"inherit","key":"key","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd"],"process":"workspaceAccess"},
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
    {"id":"workspace.feature_flags.adminInvoicing","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.adminLevelAssign","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.levelBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.adminSeatBlocking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.autoCheckInOut","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.badgeSignIn","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.nfcBadges"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.bookForOthers","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.bookingGate","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.bookingPolicies"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.bookingPolicies","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.calendarFileExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.calendarHub","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.calendarTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.calendarValidations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarHub"],"process":"coordination"},
    {"id":"workspace.feature_flags.calendarViews","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarHub"],"process":"coordination"},
    {"id":"workspace.feature_flags.capacityKpi","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.captureProtection","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.carnets","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.coOwner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.configurationTransfer","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dataExport"],"process":"operations"},
    {"id":"workspace.feature_flags.customFields","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.customRoles","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.dataAccessLog","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.dataExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
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
    {"id":"workspace.feature_flags.financeFaces","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.formHelpHints","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.holidayImport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.publicHolidays"],"process":"spaceManagement"},
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
    {"id":"workspace.feature_flags.messagesHub","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.moneyTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"billingPayments"},
    {"id":"workspace.feature_flags.multiSite","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.navigationStyle","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.nfcBadges","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.nfcSeatTags","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.notificationGrouping","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.eventsTab"],"process":"coordination"},
    {"id":"workspace.feature_flags.numberSequences","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.onlinePayments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.paymentReminders","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dunning"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.pdfExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.personalInfo","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.planMemberPhotos","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.planObjectDelete","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.priceNegotiations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.publicHolidays","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.publicListings","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.pushNotifications","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"integrations"},
    {"id":"workspace.feature_flags.qrBadges","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.recordingPrivacy","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.regionalFormats","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.reportDesignExchange","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportDesigner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicePdfTemplate"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportLayouts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportTexts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.richMessageRefs","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.roleManagement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.scheduledExpenses","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.seatDayTimeline","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.seriesBooking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.services","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.settlementFold","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoiceSettlement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.singleRoomLevelNames","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.siteDocuments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.multiSite"],"process":"operations"},
    {"id":"workspace.feature_flags.spaceInquiries","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.spaceQrCodes","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.subscriptionInvoices","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.supplyExpenses","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.services"],"process":"billingPayments"},
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
    {"id":"workspace.feature_flags.whatsappIntegration","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"integrations"},
    {"id":"workspace.feature_flags.workingHours","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.workspaceBranding","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.workspaceLibrary","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
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
    {"id":"workspace.pair_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.payment_instructions.iban","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.lydia","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.paypal_me","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.reference","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.wero","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.wise","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.postal_code","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.role_permissions","entity":"roles","type":"map","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.role_permissions.admin","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd"],"process":"workspaceAccess"},
    {"id":"workspace.role_permissions.co_owner","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd"],"process":"workspaceAccess"},
    {"id":"workspace.role_permissions.member","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd"],"process":"workspaceAccess"},
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
    {"id":"workspace.whatsapp_group","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"}
  ]$json$::jsonb
$registry$;

revoke execute on function public.template_field_registry() from public,anon;
grant execute on function public.template_field_registry() to authenticated;

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
  $cfg${
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
      "adminInvoicing": false,
      "adminLevelAssign": false,
      "adminSeatBlocking": false,
      "autoCheckInOut": false,
      "badgeSignIn": false,
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
      "configurationTransfer": false,
      "customFields": false,
      "customRoles": true,
      "dataAccessLog": false,
      "dataExport": true,
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
      "financeFaces": true,
      "formHelpHints": true,
      "holidayImport": false,
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
      "messagesHub": true,
      "moneyTab": true,
      "multiSite": false,
      "navigationStyle": true,
      "nfcBadges": false,
      "nfcSeatTags": false,
      "notificationGrouping": false,
      "numberSequences": false,
      "onlinePayments": false,
      "paymentReminders": false,
      "pdfExport": true,
      "personalInfo": true,
      "planMemberPhotos": false,
      "planObjectDelete": true,
      "priceNegotiations": false,
      "publicHolidays": false,
      "publicListings": false,
      "pushNotifications": true,
      "qrBadges": false,
      "recordingPrivacy": false,
      "regionalFormats": true,
      "reportDesignExchange": false,
      "reportDesigner": false,
      "reportLayouts": false,
      "reportTexts": false,
      "richMessageRefs": true,
      "roleManagement": true,
      "scheduledExpenses": false,
      "seatDayTimeline": true,
      "seriesBooking": true,
      "services": true,
      "settlementFold": false,
      "singleRoomLevelNames": true,
      "siteDocuments": false,
      "spaceInquiries": true,
      "spaceQrCodes": true,
      "subscriptionInvoices": false,
      "supplyExpenses": false,
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
      "whatsappIntegration": false,
      "workingHours": true,
      "workspaceBranding": false,
      "workspaceLibrary": false,
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
}$cfg$::jsonb,
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

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(335);
