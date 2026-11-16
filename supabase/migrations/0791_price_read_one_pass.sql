-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #3967 -- the price read learns the extra half-days of every member-month
-- of its period in one pass. member_months_extra_half_days applies the rules
-- member_statement applies to one month (the same helpers for the share, the
-- frozen terms, a pause and the credits), and booking_prices calls it once
-- instead of one statement per member and month. The result per booking is
-- unchanged; member_statement is not touched.

create or replace function public.member_months_extra_half_days(
  p_workspace_id uuid, p_members uuid[], p_periods text[])
returns table(member_id uuid, period text, extra_half_days integer)
language plpgsql stable security definer set search_path = public as $fn$
-- #3967 -- the extra half-days of many member-months in one pass, by the
-- rules member_statement applies to one: the counted half-day slots (or, by
-- the hour, the half-day equivalents of each day), less the included
-- half-days of the month (the share of the period, the terms frozen by its
-- invoice, a pause, nothing before the member joined), less the credits used
-- in it. [p_members] and [p_periods] are read pairwise.
declare
  v_tz text;
  v_open int[];
  v_rules jsonb;
  v_gran text;
  v_bound int;
  v_half_minutes numeric;
begin
  select w.timezone,
         coalesce((select array_agg(x::int)
                     from jsonb_array_elements_text(w.booking_rules->'open_weekdays') x),
                  array[1,2,3,4,5]),
         w.booking_rules
    into v_tz, v_open, v_rules
    from public.workspaces w where w.id = p_workspace_id;
  v_gran := v_rules->>'granularity';
  v_bound := coalesce((v_rules->>'half_boundary_minutes')::int, 720);
  if v_bound <= 0 or v_bound >= 1440 then v_bound := 720; end if;
  v_half_minutes := greatest(1, coalesce((v_rules->>'half_day_hours')::int, 4)) * 60.0;

  return query
  with pairs as (
    select distinct t.m, t.p,
           (to_timestamp(t.p || '-01', 'YYYY-MM-DD') at time zone v_tz)::timestamptz as ps,
           ((to_timestamp(t.p || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz)::timestamptz as pe,
           to_date(t.p || '-01', 'YYYY-MM-DD') as first
      from unnest(p_members, p_periods) as t(m, p)
     where t.m is not null and t.p is not null
  ),
  mem as (
    select pr.*, mb.joined_at, mb.subscription_pct, mb.status
      from pairs pr
      join public.members mb on mb.id = pr.m and mb.workspace_id = p_workspace_id
  ),
  counted as (
    select mm.m, mm.p, r as res
      from mem mm
      join public.reservations r
        on r.member_id = mm.m
       and r.status in ('reserved', 'checked_in', 'completed')
       and r.starts_at >= mm.ps and r.starts_at < mm.pe
     where public.reservation_counts_for_usage(r, v_rules, v_tz)
       and public.reservation_uses_seat_quota(r)
  ),
  slots as (
    select c.m, c.p,
           count(distinct (date_trunc('day', (c.res).starts_at at time zone v_tz)::date,
             case when extract(hour from (c.res).starts_at at time zone v_tz)::int * 60
                     + extract(minute from (c.res).starts_at at time zone v_tz)::int < v_bound
                  then 0 else 1 end))::int as used
      from counted c group by c.m, c.p
  ),
  hours as (
    select d.m, d.p, coalesce(sum(least(2, greatest(1, ceil(d.day_minutes / v_half_minutes)::int))), 0)::int as used
      from (select c.m, c.p, date_trunc('day', (c.res).starts_at at time zone v_tz)::date as day,
                   sum(extract(epoch from ((c.res).ends_at - (c.res).starts_at)) / 60.0) as day_minutes
              from counted c group by c.m, c.p, 3) d
     group by d.m, d.p
  ),
  open_days as (
    select f.first, count(*)::int as n
      from (select distinct mm.first from mem mm) f
      cross join lateral generate_series(f.first, (f.first + interval '1 month' - interval '1 day')::date,
                                         interval '1 day') d
     where extract(isodow from d)::int = any(v_open)
       and not exists (select 1 from public.closure_days cd
                        where cd.workspace_id = p_workspace_id and cd.day = d::date)
     group by f.first
  ),
  included as (
    select mm.m, mm.p, mm.ps, mm.pe,
           mm.p < to_char(mm.joined_at at time zone v_tz, 'YYYY-MM') as before_joining,
           case
             when public.member_period_invoiced(mm.m, mm.first)
                  and (public.member_frozen_terms(mm.m, mm.first)).id is not null
               then (public.member_frozen_terms(mm.m, mm.first)).included_half_days
             when public.member_period_invoiced(mm.m, mm.first)
               then ceil(coalesce(od.n, 0) * 2
                         * public.member_pct_in(mm.m, mm.first, coalesce(mm.subscription_pct, 100)) / 100.0)::int
             when public.member_paused_on(mm.m, mm.first, mm.status) then 0
             else ceil(coalesce(od.n, 0) * 2
                       * public.member_pct_in(mm.m, mm.first, coalesce(mm.subscription_pct, 100)) / 100.0)::int
           end as half_days
      from mem mm left join open_days od on od.first = mm.first
  )
  select i.m, i.p,
         case when i.before_joining then 0
              else greatest(0,
                     coalesce(case when v_gran = 'hours' then h.used else s.used end, 0)
                     - i.half_days
                     - public.member_credit_uses_in_period(i.m, i.ps, i.pe))
         end
    from included i
    left join slots s on s.m = i.m and s.p = i.p
    left join hours h on h.m = i.m and h.p = i.p;
end;
$fn$;
revoke execute on function public.member_months_extra_half_days(uuid, uuid[], text[])
  from public, anon, authenticated;

create or replace function public.booking_prices(p_workspace_id uuid, p_from timestamp with time zone, p_to timestamp with time zone)
 RETURNS TABLE(reservation_id uuid, member_id uuid, kind text, amount_cents integer, currency text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $fn$
declare
  v_all boolean;
  v_me uuid;
  v_currency text;
  v_rules jsonb;
  v_tz text;
  v_r public.reservations;
  v_month text;
  v_extra jsonb := '{}'::jsonb;
  v_key text;
begin
  if not public.is_member_of(p_workspace_id) then
    raise exception 'not a member of this workspace' using errcode = 'DKN01';
  end if;
  if p_from is null or p_to is null or p_to <= p_from then
    raise exception 'a period ends after it starts' using errcode = '22023';
  end if;
  v_all := p_workspace_id in (select public.workspaces_permitting(array['viewFinances']));
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = (select auth.uid()) limit 1;
  select w.currency_code, w.booking_rules, coalesce(nullif(w.timezone, ''), 'UTC')
    into v_currency, v_rules, v_tz
    from public.workspaces w where w.id = p_workspace_id;

  -- #3967 -- every member-month of the period's bookings, read in one pass
  -- (member_months_extra_half_days) instead of one statement per member.
  with c as (
    select distinct r.member_id as m, to_char(r.starts_at at time zone v_tz, 'YYYY-MM') as p
      from public.reservations r
     where r.workspace_id = p_workspace_id
       and r.status in ('reserved', 'checked_in', 'completed')
       and r.starts_at < p_to and r.ends_at > p_from
       and (v_all or r.member_id = v_me)
       and r.member_id is not null
  )
  select coalesce(jsonb_object_agg(x.member_id::text || '/' || x.period, x.extra_half_days), '{}'::jsonb)
    into v_extra
    from public.member_months_extra_half_days(p_workspace_id,
           array(select c.m from c order by c.m, c.p), array(select c.p from c order by c.m, c.p)) x;

  for v_r in
    select r.* from public.reservations r
     where r.workspace_id = p_workspace_id
       and r.status in ('reserved', 'checked_in', 'completed')
       and r.starts_at < p_to and r.ends_at > p_from
       and (v_all or r.member_id = v_me)
     order by r.starts_at, r.id
  loop
    reservation_id := v_r.id;
    member_id := v_r.member_id;
    amount_cents := null;
    currency := null;
    select c.amount_cents into amount_cents from public.reservation_charges c
     where c.reservation_id = v_r.id and c.reversed_at is null;
    if amount_cents is not null then
      kind := 'charge';
      currency := v_currency;
    elsif exists (select 1 from public.guest_passes p
                   where p.workspace_id = p_workspace_id and p.revoked_at is null
                     and v_r.id = any(p.reservation_ids)) then
      kind := 'pass';
    elsif exists (select 1 from public.member_credit_uses u
                   where u.reservation_id = v_r.id and u.released_at is null) then
      kind := 'carnet';
    elsif not (public.reservation_counts_for_usage(v_r, v_rules, v_tz)
               and public.reservation_uses_seat_quota(v_r)) then
      kind := 'free';
    else
      -- the member's month: its extra half-days, read before the loop
      v_month := to_char(v_r.starts_at at time zone v_tz, 'YYYY-MM');
      v_key := v_r.member_id::text || '/' || v_month;
      kind := case when coalesce((v_extra ->> v_key)::int, 0) > 0 then 'overage' else 'subscription' end;
    end if;
    return next;
  end loop;
end;
$fn$;

revoke execute on function public.booking_prices(uuid, timestamptz, timestamptz) from public, anon;
grant execute on function public.booking_prices(uuid, timestamptz, timestamptz) to authenticated;

comment on function public.member_months_extra_half_days(uuid, uuid[], text[]) is
  '#3967 -- the extra half-days of many member-months in one pass, by the rules of '
  'member_statement for one; supabase/tests/database/445_price_read_one_pass.sql binds the two: '
  'for every member-month of its fixture they must be equal. Callable only by the definer '
  'functions (booking_prices), never by a client; it reads only the business it is given.';
comment on function public.member_statement(uuid, text) is
  '#3967 -- its extra_half_days has a set-based twin, member_months_extra_half_days, which the '
  'price read uses; supabase/tests/database/445_price_read_one_pass.sql binds the two: a change '
  'to the quota, the share, the frozen terms, a pause or the credits here must change it too.';

select public.set_deskilo_schema_version(791);
