-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0409 (#2357) — input VAT on fixed assets and on scheduled expenses.
--
-- 1. `expense_vat_payload` validates and normalises an expense's VAT —
--    {percent, deductible_pct, asset} — for every writer: `submit_expense`
--    now keeps `asset` (the expense bought a fixed asset) beside the rate
--    and the share.
-- 2. `vat_input_amounts` returns the category: `asset` for a fixed asset,
--    `S` otherwise; `vat_return_lines` files input VAT under it, so the
--    forms put it on CA3 line 19, the Swiss 405, the Spanish 30/31.
-- 3. A scheduled expense states its VAT once (`expense_schedules.vat`,
--    `set_expense_schedule_vat`), and every occurrence's expense carries
--    it: a trigger copies it onto the expense event an occurrence files.

-- ============================================================ the payload
create or replace function public.expense_vat_payload(
  p_workspace_id uuid, p_vat jsonb
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_percent numeric;
  v_share numeric;
begin
  if p_vat is null or jsonb_typeof(p_vat) <> 'object' then
    return null;
  end if;
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
  return jsonb_build_object('percent', trim_scale(v_percent),
                            'deductible_pct', trim_scale(v_share))
         || case when coalesce((p_vat ->> 'asset')::boolean, false)
                 then jsonb_build_object('asset', true) else '{}'::jsonb end;
end;
$fn$;
revoke execute on function public.expense_vat_payload(uuid, jsonb)
  from public, anon, authenticated;

-- 0408's submit_expense, its VAT through the shared payload.
create or replace function public.submit_expense(
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
  -- #2357 — the VAT the expense carried, the share the space deducts and
  -- whether it bought a fixed asset (0409).
  v_vat := public.expense_vat_payload(p_workspace_id, p_vat);
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
-- 0408's amounts, with the category the input VAT is filed under.
drop function if exists public.vat_input_amounts(uuid, date, date);
create function public.vat_input_amounts(
  p_workspace_id uuid, p_start date, p_end date
) returns table (expense_id uuid, tax_point date, percent numeric,
                 category text, gross_cents bigint, net_cents bigint)
language sql stable security definer set search_path = public as $fn$
  select e.id, (e.decided_at at time zone w.tz)::date,
         trim_scale((e.payload #>> '{vat,percent}')::numeric),
         case when coalesce((e.payload #>> '{vat,asset}')::boolean, false)
              then 'asset' else 'S' end,
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

-- 0408's lines, the input VAT under its category.
create or replace function public.vat_return_lines(
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
    select 'input', i.expense_id, i.tax_point, i.percent, i.category, false,
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
    select 'input', i.expense_id, i.tax_point, i.percent, i.category, false,
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

-- ============================================================ schedules
alter table public.expense_schedules add column if not exists vat jsonb;

-- The VAT every occurrence of a schedule carries; null clears it. The
-- member who scheduled it, or whoever approves expenses, while it runs.
create or replace function public.set_expense_schedule_vat(
  p_schedule_id uuid, p_vat jsonb
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_s public.expense_schedules;
begin
  select * into v_s from public.expense_schedules where id = p_schedule_id;
  if v_s.id is null then raise exception 'unknown schedule'; end if;
  if not (exists (select 1 from public.members m
                   where m.id = v_s.member_id and m.user_id = auth.uid()
                     and m.status = 'active')
          or public.has_permission(v_s.workspace_id, 'approveExpenses')) then
    raise exception 'not allowed';
  end if;
  if v_s.status not in ('pending', 'active') then
    raise exception 'this schedule no longer runs';
  end if;
  update public.expense_schedules
     set vat = public.expense_vat_payload(v_s.workspace_id, p_vat)
   where id = v_s.id;
end;
$fn$;
revoke execute on function public.set_expense_schedule_vat(uuid, jsonb) from public, anon;
grant execute on function public.set_expense_schedule_vat(uuid, jsonb) to authenticated;

-- An occurrence's expense carries its schedule's VAT, whichever writer
-- files it (born settled or sent for validation).
create or replace function public.expense_event_schedule_vat()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  v_vat jsonb;
begin
  if new.type = 'expense' and new.payload ? 'schedule_id'
     and not new.payload ? 'vat' then
    select s.vat into v_vat from public.expense_schedules s
     where s.id = nullif(new.payload ->> 'schedule_id', '')::uuid
       and s.workspace_id = new.workspace_id;
    if v_vat is not null and public.feature_effective(new.workspace_id, 'inputVat') then
      new.payload := new.payload || jsonb_build_object('vat', v_vat);
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.expense_event_schedule_vat() from public, anon, authenticated;

drop trigger if exists expense_event_schedule_vat on public.events;
create trigger expense_event_schedule_vat
  before insert on public.events
  for each row execute function public.expense_event_schedule_vat();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(409);
