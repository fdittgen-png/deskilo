-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0407 (#2357) — input VAT: an expense states the VAT it carried and the
-- share the space may deduct; the VAT return subtracts it.
--
-- 1. `submit_expense` takes `p_vat` ({percent, deductible_pct}) and keeps
--    it on the expense event's payload, under the `inputVat` flag (a new
--    platform feature under vatDeclarations, default on).
-- 2. `vat_input_amounts`: every approved expense with a VAT rate, dated
--    the day it was approved in the workspace's time zone; its base is the
--    per-line split invoices use, its deductible VAT the share of the
--    rest, half away from zero (`vat_input_split`, the twin of
--    lib/features/money/domain/vat_input.dart). An input line's gross is
--    its base plus the deductible VAT, so gross - net is what is deducted.
-- 3. `vat_return_lines`, `compute_vat_return`, `vat_return_summary` and
--    the filing gain a direction (output | input): the period locks of
--    0406 apply to both, the stored lines say `"direction": "input"`, and
--    the totals are the taxable base of the sales and the net payable
--    (VAT collected minus VAT deducted; negative is a credit).
-- 4. The book chart gains the `vat_input` role (an asset account: FR
--    44566), so a book can say where deductible VAT is posted.

-- ============================================================ the flag
-- ── the feature registry (dart run tool/build_feature_registry_sql.dart) ──
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
    "inputVat": {"parent": "vatDeclarations", "default": true, "core": false}
  }'::jsonb
$registry$;

revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

-- ============================================================ the expense
drop function if exists public.submit_expense(uuid, int, text, text, jsonb);
create function public.submit_expense(
  p_workspace_id uuid,
  p_amount_cents int,
  p_category text,
  p_description text default '',
  p_supply jsonb default null,
  p_vat jsonb default null
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_event_id uuid;
  v_supply jsonb := null;
  v_vat jsonb := null;
  v_qty int;
  v_unit int;
  v_name text;
  v_service_id uuid;
  v_percent numeric;
  v_share numeric;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
  if p_supply is not null then
    v_qty := (p_supply ->> 'quantity')::int;
    if v_qty is null or v_qty < 1 or v_qty > 9999 then
      raise exception 'supply quantity must be between 1 and 9999';
    end if;
    v_unit := coalesce((p_supply ->> 'unit_price_cents')::int,
                       ceil(p_amount_cents::numeric / v_qty)::int);
    if v_unit < 0 then raise exception 'unit price must not be negative'; end if;
    v_service_id := nullif(p_supply ->> 'service_id', '')::uuid;
    if v_service_id is not null then
      select name into v_name from public.services
        where id = v_service_id and workspace_id = p_workspace_id;
      if v_name is null then raise exception 'unknown service'; end if;
    else
      v_name := trim(coalesce(p_supply ->> 'name', ''));
      if char_length(v_name) between 1 and 80 is not true then
        raise exception 'supply name must be 1–80 characters';
      end if;
    end if;
    v_supply := jsonb_build_object(
      'name', v_name, 'quantity', v_qty, 'unit_price_cents', v_unit,
      'service_id', v_service_id);
  end if;
  -- #2357 — the VAT the expense carried, and the share the space deducts.
  if p_vat is not null and jsonb_typeof(p_vat) = 'object' then
    if not public.feature_effective(p_workspace_id, 'inputVat') then
      raise exception 'input VAT is switched off in this space';
    end if;
    v_percent := (p_vat ->> 'percent')::numeric;
    v_share := coalesce((p_vat ->> 'deductible_pct')::numeric, 100);
    if v_percent is null or v_percent <= 0 or v_percent > 100 then
      raise exception 'the VAT rate of an expense lies between 0 and 100';
    end if;
    if v_share < 0 or v_share > 100 then
      raise exception 'the deductible share lies between 0 and 100';
    end if;
    v_vat := jsonb_build_object('percent', trim_scale(v_percent),
                                'deductible_pct', trim_scale(v_share));
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'expense', 'submitted', v_actor.id, v_actor.id,
    jsonb_build_object(
      'amount_cents', p_amount_cents,
      'category', p_category,
      'note', p_description
    ) || case when v_supply is null then '{}'::jsonb
              else jsonb_build_object('supply', v_supply) end
      || case when v_vat is null then '{}'::jsonb
              else jsonb_build_object('vat', v_vat) end,
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$fn$;
revoke execute on function public.submit_expense(uuid, int, text, text, jsonb, jsonb) from public, anon;
grant execute on function public.submit_expense(uuid, int, text, text, jsonb, jsonb) to authenticated;

-- ============================================================ the amounts
-- vatInputSplit: the base of an expense (vatSplit) and the deductible
-- share of its VAT, half away from zero.
create or replace function public.vat_input_split(
  p_gross bigint, p_percent numeric, p_share numeric
) returns table (net_cents bigint, deductible_cents bigint)
language sql immutable set search_path = public as $fn$
  select n, round((p_gross - n)::numeric * greatest(0, least(100, p_share)) / 100)::bigint
    from (select public.vat_split_net(p_gross, p_percent) as n) x;
$fn$;
revoke execute on function public.vat_input_split(bigint, numeric, numeric)
  from public, anon, authenticated;

-- Every approved expense with a VAT rate whose approval day lies in
-- p_start..p_end — while the space has input VAT on.
create or replace function public.vat_input_amounts(
  p_workspace_id uuid, p_start date, p_end date
) returns table (expense_id uuid, tax_point date, percent numeric,
                 gross_cents bigint, net_cents bigint)
language sql stable security definer set search_path = public as $fn$
  select e.id, (e.decided_at at time zone w.tz)::date,
         trim_scale((e.payload #>> '{vat,percent}')::numeric),
         s.net_cents + s.deductible_cents, s.net_cents
    from public.events e
    cross join lateral (
      select coalesce(nullif(ws.timezone, ''), 'UTC') as tz
        from public.workspaces ws where ws.id = p_workspace_id) w
    cross join lateral public.vat_input_split(
      (e.payload ->> 'amount_cents')::bigint,
      (e.payload #>> '{vat,percent}')::numeric,
      coalesce((e.payload #>> '{vat,deductible_pct}')::numeric, 100)) s
   where e.workspace_id = p_workspace_id
     and e.type = 'expense' and e.status = 'confirmed'
     and e.decided_at is not null
     and coalesce((e.payload #>> '{vat,percent}')::numeric, 0) > 0
     and (e.decided_at at time zone w.tz)::date between p_start and p_end
     and public.feature_effective(p_workspace_id, 'inputVat');
$fn$;
revoke execute on function public.vat_input_amounts(uuid, date, date)
  from public, anon, authenticated;

-- ============================================================ the ledger
alter table public.vat_return_entries
  add column if not exists direction text not null default 'output'
    check (direction in ('output', 'input'));

-- 0406's lines, both directions: the period's own sales and deductible
-- VAT that no filed return of another period covers, then the
-- corrections of every filed period that ended before it.
drop function if exists public.vat_return_lines(uuid, date, date);
create function public.vat_return_lines(
  p_workspace_id uuid, p_start date, p_end date
) returns table (direction text, invoice_id uuid, tax_point date,
                 percent numeric, category text, credit_note boolean,
                 correction boolean, corrects uuid, gross_cents bigint,
                 net_cents bigint)
language sql stable security definer set search_path = public as $fn$
  with locks as (
    select d.id, d.period_start, d.period_end,
           coalesce(d.submitted_at, d.created_at) as filed_at
      from public.vat_declarations d
     where d.workspace_id = p_workspace_id and d.status = 'filed'
  ), earlier as (
    select l.* from locks l where l.period_end < p_start
  ), span as (
    select min(e.period_start) as s, max(e.period_end) as e from earlier e
  ), amounts_now as (
    select 'output'::text as direction, a.invoice_id, a.tax_point, a.percent,
           a.category, a.credit_note, a.gross_cents, a.net_cents
      from span
      cross join lateral public.vat_return_amounts(p_workspace_id, span.s, span.e) a
     where span.s is not null
    union all
    select 'input', i.expense_id, i.tax_point, i.percent, 'S', false,
           i.gross_cents, i.net_cents
      from span
      cross join lateral public.vat_input_amounts(p_workspace_id, span.s, span.e) i
     where span.s is not null
  ), ledger as (
    select a.* from amounts_now a
     where exists (select 1 from earlier l
                    where a.tax_point between l.period_start and l.period_end)
    union all
    select r.direction, r.invoice_id, r.tax_point, r.percent, r.category,
           r.credit_note, -r.gross_cents, -r.net_cents
      from public.vat_return_entries r
     where r.workspace_id = p_workspace_id
       and exists (select 1 from earlier l
                    where r.tax_point between l.period_start and l.period_end)
  ), delta as (
    select g.direction, g.invoice_id, g.tax_point, g.percent, g.category,
           g.credit_note,
           sum(g.gross_cents)::bigint as gross, sum(g.net_cents)::bigint as net
      from ledger g
     group by g.direction, g.invoice_id, g.tax_point, g.percent, g.category,
              g.credit_note
    having sum(g.gross_cents) <> 0 or sum(g.net_cents) <> 0
  ), own as (
    select 'output'::text as direction, a.invoice_id, a.tax_point, a.percent,
           a.category, a.credit_note, a.gross_cents, a.net_cents
      from public.vat_return_amounts(p_workspace_id, p_start, p_end) a
    union all
    select 'input', i.expense_id, i.tax_point, i.percent, 'S', false,
           i.gross_cents, i.net_cents
      from public.vat_input_amounts(p_workspace_id, p_start, p_end) i
  )
  select o.direction, o.invoice_id, o.tax_point, o.percent, o.category,
         o.credit_note, false, null::uuid, o.gross_cents, o.net_cents
    from own o
   where not exists (select 1 from locks l
                      where o.tax_point between l.period_start and l.period_end
                        and (l.period_start, l.period_end) <> (p_start, p_end))
  union all
  select d.direction, d.invoice_id, d.tax_point, d.percent, d.category,
         d.credit_note, true,
         (select l.id from earlier l
           where d.tax_point between l.period_start and l.period_end
           order by l.filed_at, l.id limit 1),
         d.gross, d.net
    from delta d;
$fn$;
revoke execute on function public.vat_return_lines(uuid, date, date)
  from public, anon, authenticated;

-- One row per (direction, rate, category, tax point, credit note,
-- correction): the sales first, then the deductible VAT. Same gate as
-- 0402. An input row's vat_cents is the VAT deducted.
drop function if exists public.compute_vat_return(uuid, date, date);
create function public.compute_vat_return(
  p_workspace uuid, p_start date, p_end date
) returns table (direction text, percent numeric, category text,
                 tax_point date, credit_note boolean, correction boolean,
                 corrects uuid, gross_cents bigint, net_cents bigint,
                 vat_cents bigint, invoice_count int)
language plpgsql stable security definer set search_path = public as $fn$
#variable_conflict use_column
begin
  if p_workspace is null or not exists (
       select 1 from public.workspaces_permitting(array['viewFinances']) w
        where w = p_workspace) then
    raise exception 'not allowed to read this workspace''s VAT';
  end if;
  if p_start is null or p_end is null or p_end < p_start then
    raise exception 'invalid period';
  end if;
  return query
    select a.direction, a.percent, a.category, a.tax_point, a.credit_note,
           a.correction, a.corrects,
           sum(a.gross_cents)::bigint, sum(a.net_cents)::bigint,
           (sum(a.gross_cents) - sum(a.net_cents))::bigint,
           count(distinct a.invoice_id)::int
      from public.vat_return_lines(p_workspace, p_start, p_end) a
     group by a.direction, a.percent, a.category, a.tax_point, a.credit_note,
              a.correction, a.corrects
     order by a.direction desc, a.correction, a.percent desc, a.category,
              a.tax_point, a.credit_note, a.corrects;
end;
$fn$;
revoke execute on function public.compute_vat_return(uuid, date, date) from public, anon;
grant execute on function public.compute_vat_return(uuid, date, date) to authenticated;

-- What a declaration stores: the sales lines exactly as 0406 stored them,
-- then the deductible VAT per rate marked `"direction": "input"`. The
-- totals are the taxable base of the sales and the net payable; the
-- document count is the sales documents'.
create or replace function public.vat_return_summary(
  p_workspace_id uuid, p_start date, p_end date
) returns table (lines jsonb, total_net_cents int, total_vat_cents int,
                 invoice_count int)
language sql stable security definer set search_path = public as $fn$
  with a as (
    select * from public.vat_return_lines(p_workspace_id, p_start, p_end)
  ), l as (
    select a.direction, a.correction, a.corrects, a.percent, a.category,
           sum(a.gross_cents)::bigint as gross, sum(a.net_cents)::bigint as net,
           count(distinct a.invoice_id)::int as n
      from a group by a.direction, a.correction, a.corrects, a.percent, a.category
  ), j as (
    select l.*, d.period_start as c_start, d.period_end as c_end
      from l left join public.vat_declarations d on d.id = l.corrects
  )
  select coalesce((select jsonb_agg(
                     jsonb_build_object(
                       'percent', j.percent, 'category', j.category,
                       'gross_cents', j.gross, 'net_cents', j.net,
                       'vat_cents', j.gross - j.net, 'invoice_count', j.n)
                     || case when j.direction = 'input'
                          then jsonb_build_object('direction', 'input')
                          else '{}'::jsonb end
                     || case when j.correction then jsonb_build_object(
                          'correction', true, 'corrects', j.corrects,
                          'corrects_start', j.c_start, 'corrects_end', j.c_end)
                        else '{}'::jsonb end
                   order by j.direction desc, j.correction, j.c_start,
                            j.percent desc, j.category)
                     from j), '[]'::jsonb),
         coalesce((select sum(l.net) from l where l.direction = 'output'), 0)::int,
         coalesce((select sum(case when l.direction = 'output' then l.gross - l.net
                                   else l.net - l.gross end) from l), 0)::int,
         (select count(distinct a.invoice_id) from a where a.direction = 'output')::int;
$fn$;
revoke execute on function public.vat_return_summary(uuid, date, date)
  from public, anon, authenticated;

-- ============================================================ the filing
-- 0406's filing, recording the direction of each amount it declared.
create or replace function public.mark_vat_declaration_submitted(
  p_declaration_id uuid,
  p_channel text,
  p_receipt text default ''
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_decl public.vat_declarations;
  v_actor public.members;
  v_sum record;
begin
  select * into v_decl from public.vat_declarations
    where id = p_declaration_id for update;
  if v_decl.id is null then raise exception 'unknown declaration'; end if;
  select * into v_actor from public.members
    where workspace_id = v_decl.workspace_id
      and user_id = auth.uid() and status = 'active';
  if v_actor.id is null or not (v_actor.is_owner or coalesce(v_actor.co_owner, 'none') = 'active') then
    raise exception 'only the owner files VAT declarations';
  end if;
  if v_decl.status = 'filed' then
    raise exception 'declaration already filed';
  end if;
  if coalesce(p_channel, '') not in ('manual', 'export') then
    raise exception 'unknown channel: a VAT return is filed by its owner with the tax authority';
  end if;
  if btrim(coalesce(p_receipt, '')) = '' then
    raise exception 'the receipt reference the tax authority gave is required';
  end if;
  if v_decl.status <> 'prepared' then
    raise exception 'prepare the return before filing it';
  end if;
  if public.vat_period_overlaps_filed(v_decl.workspace_id, v_decl.period_start,
                                      v_decl.period_end) then
    raise exception 'this period overlaps a filed return: its changes are declared as corrections of the next period';
  end if;
  select * into v_sum
    from public.vat_return_summary(v_decl.workspace_id, v_decl.period_start,
                                   v_decl.period_end);
  if (v_sum.lines, v_sum.total_net_cents, v_sum.total_vat_cents, v_sum.invoice_count)
     is distinct from
     (v_decl.lines, v_decl.total_net_cents, v_decl.total_vat_cents, v_decl.invoice_count) then
    raise exception 'the period changed since this return was prepared: prepare it again';
  end if;
  perform set_config('deskilo.vat_return_writer', 'file:' || v_decl.id, true);
  insert into public.vat_return_entries
      (workspace_id, declaration_id, direction, invoice_id, tax_point, percent,
       category, credit_note, correction, gross_cents, net_cents)
  select v_decl.workspace_id, v_decl.id, l.direction, l.invoice_id, l.tax_point,
         l.percent, l.category, l.credit_note, l.correction,
         sum(l.gross_cents)::bigint, sum(l.net_cents)::bigint
    from public.vat_return_lines(v_decl.workspace_id, v_decl.period_start,
                                 v_decl.period_end) l
   group by l.direction, l.invoice_id, l.tax_point, l.percent, l.category,
            l.credit_note, l.correction;
  update public.vat_declarations
     set status = 'filed',
         number = case when number = '' then public.next_document_number(workspace_id, 'vat_declaration') else number end,
         submitted_at = now(),
         submitted_channel = p_channel,
         submitted_receipt = left(btrim(p_receipt), 500)
   where id = p_declaration_id;
  perform set_config('deskilo.vat_return_writer', '', true);
end;
$fn$;
revoke execute on function public.mark_vat_declaration_submitted(
  uuid, text, text) from public, anon;

-- ============================================================ the book
-- The deductible VAT gets its role: an asset account (FR 44566).
alter table public.book_mappings drop constraint if exists book_mappings_role_check;
alter table public.book_mappings add constraint book_mappings_role_check
  check (role in ('customers', 'revenue', 'bank', 'vat_output', 'vat_input', 'expenses'));

-- 0338's save_book_mapping, knowing the vat_input role.
create or replace function public.save_book_mapping(
  p_workspace_id uuid, p_issuer_site_id uuid, p_role text, p_account_id uuid,
  p_effective_from date, p_expected_revision int
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  a public.book_accounts;
  v public.book_mappings;
  v_type text;
begin
  perform public.book_write_gate(p_workspace_id, p_issuer_site_id);
  v_type := case p_role
    when 'customers' then 'asset' when 'revenue' then 'income' when 'bank' then 'asset'
    when 'vat_output' then 'liability' when 'expenses' then 'expense'
    when 'vat_input' then 'asset' end;
  if v_type is null then raise exception 'unknown role' using errcode = '22023'; end if;
  if p_effective_from is null then
    raise exception 'a mapping takes effect from a date' using errcode = '22023';
  end if;
  select * into a from public.book_accounts where id = p_account_id;
  if a.id is null or a.issuer_site_id <> p_issuer_site_id then
    raise exception 'that account is not in this issuer''s chart' using errcode = '42501';
  end if;
  if not a.is_posting then
    raise exception 'a grouping account takes no postings' using errcode = '22023';
  end if;
  if a.account_type <> v_type then
    raise exception 'role % books to a % account, not %', p_role, v_type, a.account_type
      using errcode = '22023';
  end if;
  select * into v from public.book_mappings
   where issuer_site_id = p_issuer_site_id and role = p_role and effective_from = p_effective_from
   for update;
  if v.id is null then
    if coalesce(p_expected_revision, -1) <> 0 then
      raise exception 'stale mapping' using errcode = '40001';
    end if;
    insert into public.book_mappings (workspace_id, issuer_site_id, role, account_id, effective_from)
    values (p_workspace_id, p_issuer_site_id, p_role, p_account_id, p_effective_from)
    returning * into v;
  else
    if coalesce(p_expected_revision, -1) <> v.revision then
      raise exception 'stale mapping: someone saved it since you read it' using errcode = '40001';
    end if;
    update public.book_mappings set account_id = p_account_id, revision = v.revision + 1
     where id = v.id returning * into v;
  end if;
  return jsonb_build_object(
    'id', v.id, 'workspace_id', v.workspace_id, 'issuer_site_id', v.issuer_site_id,
    'role', v.role, 'account_id', v.account_id,
    'effective_from', to_char(v.effective_from, 'YYYY-MM-DD'), 'revision', v.revision);
end;
$fn$;
revoke execute on function public.save_book_mapping(uuid, uuid, text, uuid, date, int) from public, anon;
grant execute on function public.save_book_mapping(uuid, uuid, text, uuid, date, int) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(407);
