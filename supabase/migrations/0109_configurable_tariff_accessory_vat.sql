-- SPDX-License-Identifier: 0BSD
-- #542: the VAT rate becomes CONFIGURABLE where it was hard-wired to
-- the workspace default — the subscription tariff (fee bands: monthly
-- fee + overage) gets one workspace-level rate, and each accessory gets
-- its own, both null = default (the services/packages resolution:
-- own ACTIVE rate, else the workspace default). Invoices tax
-- subscription/overage at the tariff rate and split the accessories
-- supplement into one line per rate when seats mix rates.
-- member_statement and invoice_lines_for are regenerated from 0103
-- with only those edits; level/office/desk supplements stay at the
-- workspace default (space pricing carries no own rate — yet).

alter table public.accessories
  add column vat_rate_id uuid references public.vat_rates(id)
    on delete set null;

alter table public.workspaces
  add column subscription_vat_rate_id uuid references public.vat_rates(id)
    on delete set null;

-- The tariff's percent: the workspace's chosen subscription rate when
-- it is still active, else the default (mirrors the services rule).
create or replace function public.workspace_tariff_vat_percent(
  p_workspace_id uuid
) returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(
    (select vr.percent from public.vat_rates vr
      join public.workspaces w on w.subscription_vat_rate_id = vr.id
      where w.id = p_workspace_id and vr.active),
    public.workspace_default_vat_percent(p_workspace_id));
$$;
revoke execute on function public.workspace_tariff_vat_percent(uuid)
  from public, anon;

create or replace function public.member_statement(
  p_member_id uuid,
  p_period text
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_member public.members;
  v_caller_is_admin boolean;
  v_band public.fee_bands;
  v_tz text;
  v_open int[];
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_month_first date;
  v_open_days int;
  v_pct int;
  v_included int;
  v_used int;
  v_base int := 0;
  v_overage int := 0;
  v_overage_rate int := 0;
  v_credits int;
  v_extra_half_days int := 0;
  v_supp_on boolean := false;
  v_supp_since timestamptz;
  v_supplement int := 0;
  -- #542: the same supplement broken down by VAT percent — accessories
  -- may carry different rates, and the invoice must tax each slice at
  -- its own rate.
  v_supp_by_rate jsonb := '[]'::jsonb;
  v_acc_default numeric;
  v_granted int := 0;
  v_cap int := 0;
  v_remaining int := 0;
  v_level_supplement int := 0;
  v_office_supplement int := 0;
  -- #desk (0059)
  v_desk_supplement int := 0;
  -- #446 working hours
  v_rules jsonb;
  v_gran text;
  v_bound int;
  v_half_minutes numeric;
begin
  select * into v_member from public.members where id = p_member_id;
  if v_member.id is null then raise exception 'unknown member'; end if;
  v_caller_is_admin := public.is_admin_of(v_member.workspace_id);
  if not v_caller_is_admin and not exists (
    select 1 from public.members m
    where m.id = p_member_id and m.user_id = auth.uid()
  ) then
    raise exception 'not your statement';
  end if;

  select timezone,
         coalesce((select array_agg(x::int)
                     from jsonb_array_elements_text(booking_rules->'open_weekdays') x),
                  array[1,2,3,4,5]),
         coalesce(feature_flags -> 'accessorySupplements' = to_jsonb(true), false),
         accessory_supplements_since,
         booking_rules
    into v_tz, v_open, v_supp_on, v_supp_since, v_rules
    from public.workspaces where id = v_member.workspace_id;
  -- #446: the half-day boundary and the hours-mode billing equivalents
  -- come from booking_rules; inconsistent values fall back to the
  -- defaults exactly like the client (WorkHours.fromRules).
  v_gran := v_rules->>'granularity';
  v_bound := coalesce((v_rules->>'half_boundary_minutes')::int, 720);
  if v_bound <= 0 or v_bound >= 1440 then v_bound := 720; end if;
  v_half_minutes := greatest(1, coalesce((v_rules->>'half_day_hours')::int, 4)) * 60.0;
  v_period_start := to_timestamp(p_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
  v_period_end := (to_timestamp(p_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;
  v_month_first := to_date(p_period || '-01', 'YYYY-MM-DD');

  -- #512 — a month fully before the membership begins owes NOTHING:
  -- no subscription, no entitlement. The workspace started when it
  -- started; earlier months must not read outstanding.
  if p_period < to_char(v_member.joined_at at time zone v_tz, 'YYYY-MM') then
    return jsonb_build_object(
      'period', p_period,
      'subscription_pct', coalesce(v_member.subscription_pct, 100),
      'fee_cents', 0, 'included_half_days', 0, 'open_days', 0,
      'used_half_days', 0, 'extra_half_days', 0, 'overage_cents', 0,
      'accessory_supplement_cents', 0, 'level_supplement_cents', 0,
      'office_supplement_cents', 0, 'desk_supplement_cents', 0,
      'credits_cents', 0, 'balance_cents', 0,
      'overage_policy', coalesce(v_member.overage_policy, 'blocked'),
      'overage_rate_cents', 0, 'granted_half_days', 0,
      'remaining_half_days', 0
    );
  end if;

  v_pct := coalesce(v_member.subscription_pct, 100);
  select * into v_band from public.fee_bands
    where workspace_id = v_member.workspace_id
      and from_pct < v_pct and v_pct <= to_pct;
  if v_band.id is not null then
    v_base := v_band.fee_cents;
    v_overage_rate := v_band.overage_fee_cents;
  end if;

  select count(*) into v_open_days
  from generate_series(v_month_first,
                       (v_month_first + interval '1 month' - interval '1 day')::date,
                       interval '1 day') d
  where extract(isodow from d)::int = any(v_open)
    and not exists (select 1 from public.closure_days c
                     where c.workspace_id = v_member.workspace_id and c.day = d::date);
  v_included := ceil(v_open_days * 2 * v_pct / 100.0)::int;

  select count(distinct (date_trunc('day', r.starts_at at time zone v_tz)::date, s.slot))
  into v_used
  from public.reservations r
  cross join lateral (
    select case when extract(hour from r.starts_at at time zone v_tz)::int * 60
                + extract(minute from r.starts_at at time zone v_tz)::int < v_bound
           then 0 else 1 end as slot
  ) s
  where r.member_id = p_member_id
    and r.status in ('reserved','checked_in','completed')
    and r.starts_at >= v_period_start and r.starts_at < v_period_end;

  -- #446 hours granularity: booked time per day converts to half-day
  -- equivalents — one half day per STARTED half_day_hours block,
  -- capped at 2 (a full day is two halves).
  if v_gran = 'hours' then
    select coalesce(sum(least(2, greatest(1,
             ceil(d.day_minutes / v_half_minutes)::int))), 0)
    into v_used
    from (
      select date_trunc('day', r.starts_at at time zone v_tz)::date as day,
             sum(extract(epoch from (r.ends_at - r.starts_at)) / 60.0)
               as day_minutes
      from public.reservations r
      where r.member_id = p_member_id
        and r.status in ('reserved','checked_in','completed')
        and r.starts_at >= v_period_start and r.starts_at < v_period_end
      group by 1
    ) d;
  end if;

  v_extra_half_days := greatest(0, v_used - v_included);
  v_overage := v_extra_half_days * v_overage_rate;

  select coalesce(sum(half_days), 0) into v_granted from public.quota_extensions
    where member_id = p_member_id and period = p_period;
  v_cap := v_included + v_granted;
  v_remaining := greatest(0, v_cap - v_used);

  if v_supp_on and v_supp_since is not null then
    v_acc_default := public.workspace_default_vat_percent(v_member.workspace_id);
    if v_gran = 'hours' then
      -- #446: half-day-equivalent units per seat and day. #542: seat
      -- totals split by each accessory's VAT percent (its own active
      -- rate, else the workspace default — the services resolution).
      select coalesce(jsonb_agg(jsonb_build_object(
               'percent', pr.percent, 'cents', pr.cents)
               order by pr.percent), '[]'::jsonb),
             coalesce(sum(pr.cents), 0)
      into v_supp_by_rate, v_supplement
      from (
        select rate.percent, sum(rate.unit_cents * hd.units)::int as cents
        from (
          select r.seat_id,
                 least(2, greatest(1, ceil(
                   sum(extract(epoch from (r.ends_at - r.starts_at)) / 60.0)
                     / v_half_minutes)::int)) as units
          from public.reservations r
          where r.member_id = p_member_id
            and r.seat_id is not null
            and r.status in ('reserved','checked_in','completed')
            and r.starts_at >= greatest(v_period_start, v_supp_since)
            and r.starts_at < v_period_end
          group by r.seat_id,
                   date_trunc('day', r.starts_at at time zone v_tz)::date
        ) hd
        join (
          select sa.seat_id,
                 coalesce((select vr.percent from public.vat_rates vr
                            where vr.id = a.vat_rate_id and vr.active),
                          v_acc_default) as percent,
                 sum(a.supplement_cents)::int as unit_cents
          from public.seat_accessories sa
          join public.accessories a on a.id = sa.accessory_id
          where a.active and a.supplement_cents > 0
          group by sa.seat_id, 2
        ) rate on rate.seat_id = hd.seat_id
        group by rate.percent
      ) pr;
    else
      select coalesce(jsonb_agg(jsonb_build_object(
               'percent', pr.percent, 'cents', pr.cents)
               order by pr.percent), '[]'::jsonb),
             coalesce(sum(pr.cents), 0)
      into v_supp_by_rate, v_supplement
      from (
        select rate.percent, sum(rate.unit_cents)::int as cents
        from (
          select distinct
            r.seat_id,
            date_trunc('day', r.starts_at at time zone v_tz)::date as day,
            case when extract(hour from r.starts_at at time zone v_tz)::int * 60
                    + extract(minute from r.starts_at at time zone v_tz)::int < v_bound
               then 0 else 1 end as slot
          from public.reservations r
          where r.member_id = p_member_id
            and r.seat_id is not null
            and r.status in ('reserved','checked_in','completed')
            and r.starts_at >= greatest(v_period_start, v_supp_since)
            and r.starts_at < v_period_end
        ) hd
        join (
          select sa.seat_id,
                 coalesce((select vr.percent from public.vat_rates vr
                            where vr.id = a.vat_rate_id and vr.active),
                          v_acc_default) as percent,
                 sum(a.supplement_cents)::int as unit_cents
          from public.seat_accessories sa
          join public.accessories a on a.id = sa.accessory_id
          where a.active and a.supplement_cents > 0
          group by sa.seat_id, 2
        ) rate on rate.seat_id = hd.seat_id
        group by rate.percent
      ) pr;
    end if;
  end if;

  if v_gran = 'hours' then
    select coalesce(sum(l.price_cents * hx.units), 0) into v_level_supplement
    from (
      select r.level_id,
             least(2, greatest(1, ceil(
               sum(extract(epoch from (r.ends_at - r.starts_at)) / 60.0)
                 / v_half_minutes)::int)) as units
      from public.reservations r
      where r.member_id = p_member_id
        and r.level_id is not null
        and r.status in ('reserved','checked_in','completed')
        and r.starts_at >= v_period_start
        and r.starts_at < v_period_end
      group by r.level_id,
               date_trunc('day', r.starts_at at time zone v_tz)::date
    ) hx
    join public.levels l on l.id = hx.level_id;
  else
    select coalesce(sum(l.price_cents), 0) into v_level_supplement
    from (
      select distinct
        r.level_id,
        date_trunc('day', r.starts_at at time zone v_tz)::date as day,
        case when extract(hour from r.starts_at at time zone v_tz)::int * 60
                  + extract(minute from r.starts_at at time zone v_tz)::int < v_bound
             then 0 else 1 end as slot
      from public.reservations r
      where r.member_id = p_member_id
        and r.level_id is not null
        and r.status in ('reserved','checked_in','completed')
        and r.starts_at >= v_period_start and r.starts_at < v_period_end
    ) lh
    join public.levels l on l.id = lh.level_id;
  end if;

  -- #office: price × distinct half-days per reserved office.
  if v_gran = 'hours' then
    select coalesce(sum(o.price_cents * hx.units), 0) into v_office_supplement
    from (
      select r.office_id,
             least(2, greatest(1, ceil(
               sum(extract(epoch from (r.ends_at - r.starts_at)) / 60.0)
                 / v_half_minutes)::int)) as units
      from public.reservations r
      where r.member_id = p_member_id
        and r.office_id is not null
        and r.status in ('reserved','checked_in','completed')
        and r.starts_at >= v_period_start
        and r.starts_at < v_period_end
      group by r.office_id,
               date_trunc('day', r.starts_at at time zone v_tz)::date
    ) hx
    join public.offices o on o.id = hx.office_id;
  else
    select coalesce(sum(o.price_cents), 0) into v_office_supplement
    from (
      select distinct
        r.office_id,
        date_trunc('day', r.starts_at at time zone v_tz)::date as day,
        case when extract(hour from r.starts_at at time zone v_tz)::int * 60
                  + extract(minute from r.starts_at at time zone v_tz)::int < v_bound
             then 0 else 1 end as slot
      from public.reservations r
      where r.member_id = p_member_id
        and r.office_id is not null
        and r.status in ('reserved','checked_in','completed')
        and r.starts_at >= v_period_start and r.starts_at < v_period_end
    ) oh
    join public.offices o on o.id = oh.office_id;
  end if;

  -- #desk: price × distinct half-days per reserved desk (0059).
  if v_gran = 'hours' then
    select coalesce(sum(d.price_cents * hx.units), 0) into v_desk_supplement
    from (
      select r.desk_id,
             least(2, greatest(1, ceil(
               sum(extract(epoch from (r.ends_at - r.starts_at)) / 60.0)
                 / v_half_minutes)::int)) as units
      from public.reservations r
      where r.member_id = p_member_id
        and r.desk_id is not null
        and r.status in ('reserved','checked_in','completed')
        and r.starts_at >= v_period_start
        and r.starts_at < v_period_end
      group by r.desk_id,
               date_trunc('day', r.starts_at at time zone v_tz)::date
    ) hx
    join public.desks d on d.id = hx.desk_id;
  else
    select coalesce(sum(d.price_cents), 0) into v_desk_supplement
    from (
      select distinct
        r.desk_id,
        date_trunc('day', r.starts_at at time zone v_tz)::date as day,
        case when extract(hour from r.starts_at at time zone v_tz)::int * 60
                  + extract(minute from r.starts_at at time zone v_tz)::int < v_bound
             then 0 else 1 end as slot
      from public.reservations r
      where r.member_id = p_member_id
        and r.desk_id is not null
        and r.status in ('reserved','checked_in','completed')
        and r.starts_at >= v_period_start and r.starts_at < v_period_end
    ) dh
    join public.desks d on d.id = dh.desk_id;
  end if;

  -- #512 — a credit CONSUMED by an invoice match settled that invoice;
  -- it must not ALSO improve its declared month's balance. Charges and
  -- unconsumed credits stay.
  select coalesce(sum(case when kind = 'credit' then amount_cents else -amount_cents end), 0)
  into v_credits
  from public.ledger_entries le
  where le.member_id = p_member_id and le.period = p_period
    and (le.kind <> 'credit' or not exists (
      select 1 from public.invoice_match_payments jr
      where jr.payment_ledger_id = le.id));

  return jsonb_build_object(
    'period', p_period,
    'subscription_pct', v_pct,
    'fee_cents', v_base,
    'included_half_days', v_included,
    'open_days', v_open_days,
    'used_half_days', v_used,
    'extra_half_days', v_extra_half_days,
    'overage_cents', v_overage,
    'accessory_supplement_cents', v_supplement,
    'accessory_supplement_by_rate', v_supp_by_rate,
    'level_supplement_cents', v_level_supplement,
    -- #office
    'office_supplement_cents', v_office_supplement,
    'desk_supplement_cents', v_desk_supplement,
    'credits_cents', v_credits,
    'balance_cents',
      v_credits - v_base - v_overage - v_supplement - v_level_supplement
        - v_office_supplement - v_desk_supplement,
    'overage_policy', coalesce(v_member.overage_policy, 'blocked'),
    'overage_rate_cents', v_overage_rate,
    'granted_half_days', v_granted,
    'remaining_half_days', v_remaining
  );
end;
$$;
revoke execute on function public.member_statement(uuid, text) from public, anon;

create or replace function public.invoice_lines_for(
  p_member_id uuid,
  p_period text
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_stmt jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_row record;
  v_workspace uuid;
  v_default numeric;
  -- #542: the tariff's own rate for subscription + overage, and the
  -- per-rate accessory slices.
  v_tariff numeric;
  v_acc record;
begin
  v_stmt := public.member_statement(p_member_id, p_period);
  select workspace_id into v_workspace from public.members where id = p_member_id;
  v_default := public.workspace_default_vat_percent(v_workspace);
  v_tariff := public.workspace_tariff_vat_percent(v_workspace);

  if (v_stmt->>'fee_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'subscription',
      'label', v_stmt->>'subscription_pct',
      'quantity', 1,
      'vat_percent', v_tariff,
      'amount_cents', (v_stmt->>'fee_cents')::int);
  end if;
  if (v_stmt->>'overage_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'overage',
      'label', '',
      'quantity', (v_stmt->>'extra_half_days')::int,
      'vat_percent', v_tariff,
      'amount_cents', (v_stmt->>'overage_cents')::int);
  end if;
  -- #542: one accessories line PER VAT RATE — the statement's
  -- breakdown sums to accessory_supplement_cents by construction.
  if jsonb_typeof(v_stmt->'accessory_supplement_by_rate') = 'array' then
    for v_acc in
      select (e.value->>'percent')::numeric as percent,
             (e.value->>'cents')::int as cents
        from jsonb_array_elements(v_stmt->'accessory_supplement_by_rate') e
    loop
      if v_acc.cents > 0 then
        v_lines := v_lines || jsonb_build_object(
          'kind', 'accessories', 'label', '', 'quantity', 1,
          'vat_percent', v_acc.percent,
          'amount_cents', v_acc.cents);
      end if;
    end loop;
  elsif coalesce((v_stmt->>'accessory_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'accessories', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'accessory_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'level_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'level', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'level_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'office_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'office', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'office_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'desk_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'desk', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'desk_supplement_cents')::int);
  end if;

  for v_row in
    select kind, category, description, amount_cents, vat_percent
      from public.ledger_entries le
     where le.member_id = p_member_id
       and le.period = p_period
       and ((le.kind = 'charge'
             and le.category in ('service', 'package', 'adjustment'))
         or (le.kind = 'credit'
             and le.category in ('payment', 'expense', 'adjustment')
             -- #512 — a credit consumed by an invoice match already
             -- settled ANOTHER invoice; deducting it here too would
             -- spend it twice.
             and not exists (
               select 1 from public.invoice_match_payments jr
               where jr.payment_ledger_id = le.id)))
     order by le.created_at
  loop
    v_lines := v_lines || jsonb_build_object(
      'kind', v_row.category,
      'label', v_row.description,
      'quantity', 1,
      -- The rate stamped when the charge was booked; the workspace
      -- default for anything older than 0072 or unstamped. A credit is
      -- money moving, not a supply: no VAT.
      'vat_percent', case when v_row.kind = 'credit' then 0
                          else coalesce(v_row.vat_percent, v_default) end,
      'amount_cents', case when v_row.kind = 'credit'
                           then -v_row.amount_cents
                           else v_row.amount_cents end);
  end loop;

  return v_lines;
end;
$$;
revoke execute on function public.invoice_lines_for(uuid, text)
  from public, anon;
