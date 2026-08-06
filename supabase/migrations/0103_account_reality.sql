-- SPDX-License-Identifier: 0BSD
-- #512 — the account becomes REAL. Three rules and one view:
--   1. A month fully before the membership begins owes nothing.
--   2. An account credit (avoir excess) settles any outstanding
--      invoice — imputation, past months included.
--   3. Every credit spends exactly once: baked into an issued invoice
--      OR consumed by a match, never both, never twice.
--   4. member_account(): the member's true position — credit on
--      account, open remainders, refunds due, net.
-- Bodies generated from 0087 (member_statement), 0072
-- (invoice_lines_for) and 0101 (match_invoice) — never hand-copied.

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
    if v_gran = 'hours' then
      -- #446: half-day-equivalent units per seat and day.
      select coalesce(sum(seat_supp.total_cents * hd.units), 0)
      into v_supplement
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
      select sa.seat_id, sum(a.supplement_cents)::int as total_cents
      from public.seat_accessories sa
      join public.accessories a on a.id = sa.accessory_id
      where a.active and a.supplement_cents > 0
      group by sa.seat_id
    ) seat_supp on seat_supp.seat_id = hd.seat_id;
    else
      select coalesce(sum(seat_supp.total_cents), 0) into v_supplement
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
        select sa.seat_id, sum(a.supplement_cents)::int as total_cents
        from public.seat_accessories sa
        join public.accessories a on a.id = sa.accessory_id
        where a.active and a.supplement_cents > 0
        group by sa.seat_id
      ) seat_supp on seat_supp.seat_id = hd.seat_id;
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
begin
  v_stmt := public.member_statement(p_member_id, p_period);
  select workspace_id into v_workspace from public.members where id = p_member_id;
  v_default := public.workspace_default_vat_percent(v_workspace);

  if (v_stmt->>'fee_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'subscription',
      'label', v_stmt->>'subscription_pct',
      'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'fee_cents')::int);
  end if;
  if (v_stmt->>'overage_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'overage',
      'label', '',
      'quantity', (v_stmt->>'extra_half_days')::int,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'overage_cents')::int);
  end if;
  if coalesce((v_stmt->>'accessory_supplement_cents')::int, 0) > 0 then
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

create or replace function public.match_invoice(
  p_invoice_id uuid,
  p_payment_ledger_id uuid,
  p_resolution text,
  p_note text default ''
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_existing public.invoice_matches;
  v_payment public.ledger_entries;
  v_paid int;
  v_due int;
  v_actor public.members;
  v_actor_name text;
  v_note text := btrim(coalesce(p_note, ''));
  v_has_policy boolean;
  v_event_id uuid;
  v_credit_id uuid := null;
  v_additional boolean := false;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  select * into v_existing from public.invoice_matches
    where invoice_id = p_invoice_id;
  if v_existing.invoice_id is not null then
    -- #506 — only a STANDING partial (not written off) accepts more.
    if v_existing.status <> 'confirmed'
       or v_existing.resolution <> 'under_accepted'
       or v_existing.writeoff_at is not null then
      raise exception 'invoice already matched';
    end if;
    v_additional := true;
    v_due := v_invoice.total_cents - v_existing.paid_cents;
  else
    v_due := v_invoice.total_cents;
  end if;
  select * into v_actor from public.members
    where workspace_id = v_invoice.workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not public.is_owner_of(v_invoice.workspace_id) and not coalesce(
    (select w.feature_flags -> 'adminInvoicing' = to_jsonb(true)
       from public.workspaces w where w.id = v_invoice.workspace_id), false) then
    raise exception 'admins may not issue invoices here';
  end if;

  -- #512 — settlement sources: registered payments AND account credits
  -- (category 'adjustment': credit-note excess) — the imputation of an
  -- avoir on any outstanding invoice, past months included.
  select * into v_payment from public.ledger_entries
    where id = p_payment_ledger_id
      and workspace_id = v_invoice.workspace_id
      and member_id = v_invoice.member_id
      and kind = 'credit' and category in ('payment', 'adjustment');
  if v_payment.id is null then raise exception 'unknown payment'; end if;
  -- A credit already BAKED into an issued invoice (negative line at
  -- derivation) was spent there — it cannot settle a second document.
  if exists (
    select 1 from public.invoices i
    where i.member_id = v_invoice.member_id
      and i.period = v_payment.period
      and i.voided_at is null
      and i.issued_at > v_payment.created_at) then
    raise exception 'credit already deducted on an issued invoice';
  end if;
  if exists (select 1 from public.invoice_match_payments
              where payment_ledger_id = p_payment_ledger_id) then
    raise exception 'payment already matched';
  end if;
  v_paid := v_payment.amount_cents;

  if p_resolution not in
      ('exact','over_forced','over_credit_note','under_accepted') then
    raise exception 'unknown resolution';
  end if;
  -- All amount rules compare against what is STILL DUE (#506).
  if p_resolution = 'exact' and v_paid <> v_due then
    raise exception 'amount does not match the invoice';
  end if;
  if p_resolution in ('over_forced','over_credit_note')
     and v_paid <= v_due then
    raise exception 'amount does not exceed the invoice';
  end if;
  if p_resolution = 'under_accepted' and v_paid >= v_due then
    raise exception 'amount is not below the invoice';
  end if;
  if p_resolution in ('over_forced','under_accepted') and v_note = '' then
    raise exception 'a note is required';
  end if;

  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;

  if p_resolution = 'over_credit_note' then
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents,
       description, period)
    values
      (v_invoice.workspace_id, v_invoice.member_id, 'credit',
       'adjustment', v_paid - v_due,
       'Credit note ' || v_invoice.number
         || case when v_note = '' then '' else ' — ' || v_note end,
       to_char(now(), 'YYYY-MM'))
    returning id into v_credit_id;
  end if;

  v_has_policy := exists (
    select 1 from public.validation_policies vp
    where vp.workspace_id = v_invoice.workspace_id
      and vp.event_type = 'invoice_payment');

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (v_invoice.workspace_id, 'invoice_payment', 'submitted',
     v_actor.id, v_invoice.member_id,
     jsonb_build_object(
       'invoice_id', v_invoice.id,
       'number', v_invoice.number,
       'due_cents', v_due,
       'paid_cents', v_paid,
       'amount_cents', v_paid,
       'payment_ledger_id', p_payment_ledger_id,
       'resolution', p_resolution,
       'note', v_note,
       'additional', v_additional),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event_id;

  -- The junction row reserves the payment even while pending.
  insert into public.invoice_match_payments
    (workspace_id, invoice_id, payment_ledger_id, amount_cents,
     resolution, note, event_id, credit_ledger_id, by_name)
  values
    (v_invoice.workspace_id, p_invoice_id, p_payment_ledger_id, v_paid,
     p_resolution, v_note, v_event_id, v_credit_id, v_actor_name);

  if v_additional then
    -- The aggregate moves only when the payment stands.
    if not v_has_policy then
      update public.invoice_matches
        set paid_cents = paid_cents + v_paid,
            resolution = p_resolution,
            note = case when v_note = '' then note else v_note end,
            payment_ledger_id = p_payment_ledger_id,
            credit_ledger_id = coalesce(v_credit_id, credit_ledger_id),
            matched_at = now(),
            by_name = v_actor_name
        where invoice_id = p_invoice_id;
    end if;
  else
    insert into public.invoice_matches
      (workspace_id, invoice_id, paid_cents, resolution, note, status,
       event_id, credit_ledger_id, payment_ledger_id, by_name)
    values
      (v_invoice.workspace_id, p_invoice_id, v_paid, p_resolution,
       v_note, case when v_has_policy then 'pending' else 'confirmed' end,
       v_event_id, v_credit_id, p_payment_ledger_id, v_actor_name);
  end if;
end;
$$;
revoke execute on function public.match_invoice(uuid, uuid, text, text) from public, anon;

-- 4. The member's REAL position, cross-month (#512). RLS-equivalent
-- guard inline: the member themselves or a workspace admin/owner.
create or replace function public.member_account(
  p_member_id uuid
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_member public.members;
  v_credit int;
  v_refunds int;
  v_open jsonb;
  v_open_total int;
begin
  select * into v_member from public.members where id = p_member_id;
  if v_member.id is null then raise exception 'unknown member'; end if;
  if not public.is_admin_of(v_member.workspace_id) and not exists (
    select 1 from public.members m
    where m.id = p_member_id and m.user_id = auth.uid()
  ) then
    raise exception 'not your account';
  end if;

  -- Credit on account: unconsumed, not baked into an issued invoice,
  -- and genuinely SPARE — an avoir (adjustment) of any month, or a
  -- payment left over from a PAST month. A payment declared for the
  -- running month is not spare: it offsets that month's upcoming
  -- invoice and stays an ordinary payment on the bill.
  select coalesce(sum(le.amount_cents), 0) into v_credit
  from public.ledger_entries le
  where le.member_id = p_member_id
    and le.kind = 'credit' and le.category in ('payment', 'adjustment')
    and (le.category = 'adjustment'
         or le.period < to_char(now(), 'YYYY-MM'))
    and not exists (
      select 1 from public.invoice_match_payments jr
      where jr.payment_ledger_id = le.id)
    and not exists (
      select 1 from public.invoices i
      where i.member_id = p_member_id
        and i.period = le.period
        and i.voided_at is null
        and i.issued_at > le.created_at);

  -- Open POSITIVE invoices (not voided, not replaced) at their
  -- remaining value; pending matches settle nothing yet.
  select coalesce(jsonb_agg(jsonb_build_object(
           'invoice_id', o.id, 'number', o.number, 'period', o.period,
           'total_cents', o.total_cents, 'paid_cents', o.paid,
           'remaining_cents', o.remaining) order by o.issued_at),
         '[]'::jsonb),
         coalesce(sum(o.remaining), 0)
    into v_open, v_open_total
  from (
    select i.id, i.number, i.period, i.total_cents, i.issued_at,
           coalesce(m.paid_cents, 0) as paid,
           i.total_cents - case
             when m.invoice_id is not null and m.status = 'confirmed'
                  and m.resolution = 'under_accepted'
                  and m.writeoff_at is null then m.paid_cents
             else 0 end as remaining
    from public.invoices i
    left join public.invoice_matches m on m.invoice_id = i.id
    where i.member_id = p_member_id
      and i.total_cents > 0
      and i.voided_at is null
      and not exists (select 1 from public.invoices r
                       where r.replaces_invoice_id = i.id
                         and r.voided_at is null)
      and (m.invoice_id is null
           or m.status = 'pending'
           or (m.resolution = 'under_accepted' and m.writeoff_at is null))
  ) o;

  -- Refunds due: open credit notes (negative, unmatched).
  select coalesce(sum(-i.total_cents), 0) into v_refunds
  from public.invoices i
  where i.member_id = p_member_id
    and i.total_cents < 0
    and i.voided_at is null
    and not exists (select 1 from public.invoice_matches m
                     where m.invoice_id = i.id);

  return jsonb_build_object(
    'credit_cents', v_credit,
    'open_invoices', v_open,
    'open_total_cents', v_open_total,
    'refunds_due_cents', v_refunds,
    'net_position_cents', v_credit + v_refunds - v_open_total
  );
end;
$$;
revoke execute on function public.member_account(uuid) from public, anon;
