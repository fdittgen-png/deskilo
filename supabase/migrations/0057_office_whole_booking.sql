-- SPDX-License-Identifier: 0BSD
-- Whole-office booking parity. NOT YET applied to the hosted reference
-- project — the orchestrator applies it after review.
--
-- Space-barcode epic (field request): reservations target desk seats,
-- whole offices, or whole levels; an office reservation covers all its
-- desks. Whole-OFFICE booking existed since 0003/0005 but ungated and
-- unpriced — this brings it to 0050's level shape: the owner declares
-- the office bookable AND prices it, the workspace enables the
-- whole-space feature (the levelBooking flag now covers office+level),
-- and the member needs the personal whole-space grant
-- (members.can_reserve_level — one grant for both shapes). The
-- seat-vs-office conflict guards (no office booking over reserved
-- seats, no seat booking under a reserved office) already exist and
-- stay verbatim.

-- 1. Office price per half-day (levels got theirs in 0050).
alter table public.offices
  add column if not exists price_cents int not null default 0
    check (price_cents >= 0);

-- 2. create_reservation v5: 0050 v4 verbatim, with the office path
-- gaining the feature gate and the personal grant — SAME pinned error
-- substrings as the level path, so clients map once.
create or replace function public.create_reservation(
  p_workspace_id uuid,
  p_seat_id uuid,
  p_office_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_check_in boolean default false,
  p_level_id uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_seat public.seats;
  v_office_id uuid;
  v_level_id uuid;
  v_id uuid;
begin
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if (case when p_seat_id is null then 0 else 1 end
      + case when p_office_id is null then 0 else 1 end
      + case when p_level_id is null then 0 else 1 end) <> 1 then
    raise exception 'exactly one of seat, office or level required';
  end if;
  perform public.enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at, p_check_in);

  if p_seat_id is not null then
    select * into v_seat from public.seats
      where id = p_seat_id and workspace_id = p_workspace_id;
    if v_seat.id is null then raise exception 'unknown seat'; end if;
    if tstzrange(coalesce(v_seat.blocked_from, '-infinity'::timestamptz),
                 coalesce(v_seat.blocked_to, 'infinity'::timestamptz))
       && tstzrange(p_starts_at, p_ends_at)
       and (v_seat.blocked_from is not null or v_seat.blocked_to is not null) then
      raise exception 'seat is blocked in that period';
    end if;
    select d.office_id into v_office_id from public.desks d where d.id = v_seat.desk_id;
    if exists (
      select 1 from public.reservations r
      where r.office_id = v_office_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'office is reserved as a whole in that period';
    end if;
    select o.level_id into v_level_id from public.offices o where o.id = v_office_id;
    if exists (
      select 1 from public.reservations r
      where r.level_id = v_level_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'level is reserved as a whole in that period';
    end if;
  elsif p_office_id is not null then
    -- Whole-space gates (0057): feature + personal grant, like levels.
    if not public.level_booking_enabled(p_workspace_id) then
      raise exception 'level booking is not enabled';
    end if;
    if not v_member.can_reserve_level then
      -- the client pins this substring (0050)
      raise exception 'not allowed to reserve a level';
    end if;
    if not exists (
      select 1 from public.offices o
      where o.id = p_office_id and o.workspace_id = p_workspace_id
        and o.bookable_as_whole
    ) then
      raise exception 'office not bookable as a whole';
    end if;
    if exists (
      select 1 from public.reservations r
      join public.seats s on s.id = r.seat_id
      join public.desks d on d.id = s.desk_id
      where d.office_id = p_office_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'a seat in this office is already reserved in that period';
    end if;
    select o.level_id into v_level_id from public.offices o where o.id = p_office_id;
    if exists (
      select 1 from public.reservations r
      where r.level_id = v_level_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'level is reserved as a whole in that period';
    end if;
  else
    -- Level path: feature on, level bookable, member personally allowed.
    if not public.level_booking_enabled(p_workspace_id) then
      raise exception 'level booking is not enabled';
    end if;
    if not exists (
      select 1 from public.levels l
      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole
    ) then
      raise exception 'level not bookable as a whole';
    end if;
    if not v_member.can_reserve_level then
      -- the client pins this substring
      raise exception 'not allowed to reserve a level';
    end if;
    if public.level_has_conflict(p_level_id, p_starts_at, p_ends_at) then
      raise exception 'the level has reservations in that period';
    end if;
  end if;

  insert into public.reservations
    (workspace_id, seat_id, office_id, level_id, member_id, starts_at, ends_at,
     status, checked_in_at)
  values (
    p_workspace_id, p_seat_id, p_office_id, p_level_id, v_member.id,
    p_starts_at, p_ends_at,
    case when p_check_in then 'checked_in' else 'reserved' end,
    case when p_check_in then now() end
  )
  returning id into v_id;
  perform public.assert_member_quota(v_member.id, p_starts_at);
  return v_id;
end;
$$;

-- 3. member_statement v6: v5 (0050) verbatim + the office price — the
-- level-supplement shape over offices. Additions marked "#office".
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
  -- #office
  v_office_supplement int := 0;
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
         accessory_supplements_since
    into v_tz, v_open, v_supp_on, v_supp_since
    from public.workspaces where id = v_member.workspace_id;
  v_period_start := to_timestamp(p_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
  v_period_end := (to_timestamp(p_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;
  v_month_first := to_date(p_period || '-01', 'YYYY-MM-DD');

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
    select case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
  ) s
  where r.member_id = p_member_id
    and r.status in ('reserved','checked_in','completed')
    and r.starts_at >= v_period_start and r.starts_at < v_period_end;

  v_extra_half_days := greatest(0, v_used - v_included);
  v_overage := v_extra_half_days * v_overage_rate;

  select coalesce(sum(half_days), 0) into v_granted from public.quota_extensions
    where member_id = p_member_id and period = p_period;
  v_cap := v_included + v_granted;
  v_remaining := greatest(0, v_cap - v_used);

  if v_supp_on and v_supp_since is not null then
    select coalesce(sum(seat_supp.total_cents), 0) into v_supplement
    from (
      select distinct
        r.seat_id,
        date_trunc('day', r.starts_at at time zone v_tz)::date as day,
        case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
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

  select coalesce(sum(l.price_cents), 0) into v_level_supplement
  from (
    select distinct
      r.level_id,
      date_trunc('day', r.starts_at at time zone v_tz)::date as day,
      case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
    from public.reservations r
    where r.member_id = p_member_id
      and r.level_id is not null
      and r.status in ('reserved','checked_in','completed')
      and r.starts_at >= v_period_start and r.starts_at < v_period_end
  ) lh
  join public.levels l on l.id = lh.level_id;

  -- #office: price × distinct half-days per reserved office.
  select coalesce(sum(o.price_cents), 0) into v_office_supplement
  from (
    select distinct
      r.office_id,
      date_trunc('day', r.starts_at at time zone v_tz)::date as day,
      case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
    from public.reservations r
    where r.member_id = p_member_id
      and r.office_id is not null
      and r.status in ('reserved','checked_in','completed')
      and r.starts_at >= v_period_start and r.starts_at < v_period_end
  ) oh
  join public.offices o on o.id = oh.office_id;

  select coalesce(sum(case when kind = 'credit' then amount_cents else -amount_cents end), 0)
  into v_credits
  from public.ledger_entries
  where member_id = p_member_id and period = p_period;

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
    'credits_cents', v_credits,
    'balance_cents',
      v_credits - v_base - v_overage - v_supplement - v_level_supplement
        - v_office_supplement,
    'overage_policy', coalesce(v_member.overage_policy, 'blocked'),
    'overage_rate_cents', v_overage_rate,
    'granted_half_days', v_granted,
    'remaining_half_days', v_remaining
  );
end;
$$;
