-- SPDX-License-Identifier: 0BSD
-- Configurable working hours + the 'hours' booking granularity (#446).
--
-- booking_rules learns five owner-set keys (WorkHours on the client):
--   * work_start_minutes    (default 480  = 08:00)
--   * half_boundary_minutes (default 720  = 12:00)
--   * work_end_minutes      (default 1020 = 17:00)
--   * half_day_hours        (default 4)  — hours billed as a half day
--   * full_day_hours        (default 8)  — hours billed as a full day
-- and granularity accepts 'hours' next to the 0032 values: free
-- from-to bookings with no server grid, billed as half-day equivalents.
--
-- Three functions are re-emitted:
--   * enforce_booking_rules v4 — the half/full-day canonical windows
--     are the configured working day instead of the hardwired
--     00:00/13:00/24:00; walk-ups end at the next canonical edge, and
--     at/after the end of the working day may run to local midnight
--     (late-arrival overtime). Error substrings unchanged (pinned by
--     the client): 'half-day', 'cover the full day', 'minute grid'.
--   * member_statement v8 (v7: 0059) — the slot pivot is the
--     configured boundary; under 'hours' the used half-days and the
--     seat/level/office/desk supplements convert booked time to
--     half-day equivalents (1 per started half_day_hours block,
--     capped at 2 per day).
--   * assert_member_quota v3 (v2: 0041) — same boundary + same
--     hours-mode conversion, so the quota cap and the bill agree.
--
-- Existing reservations keep their stored instants; only NEW inserts
-- are constrained. Workspaces that never touch the new keys get the
-- 8:00-17:00 defaults (this CHANGES the canonical windows from the old
-- 00:00-13:00-24:00 — the owner-requested new default working day).

create or replace function public.enforce_booking_rules(
  p_workspace_id uuid, p_starts_at timestamptz, p_ends_at timestamptz,
  p_walk_up boolean default false
) returns void language plpgsql stable security definer set search_path = public as $$
declare rules jsonb; horizon int; min_min int; max_min int; dur int;
        tz text; local_start timestamp; local_end timestamp;
        gran text; slot int;
        ws_start int; ws_bound int; ws_end int;
        d date; ts_start timestamp; ts_bound timestamp; ts_end timestamp;
        ts_midnight timestamp;
begin
  select booking_rules, timezone into rules, tz
    from public.workspaces where id = p_workspace_id;
  horizon := coalesce((rules->>'advance_horizon_days')::int, 90);
  min_min := coalesce((rules->>'min_duration_minutes')::int, 30);
  max_min := coalesce((rules->>'max_duration_minutes')::int, 1440);
  if p_starts_at > now() + make_interval(days => horizon) then
    raise exception 'beyond the advance-booking horizon of % days', horizon;
  end if;
  dur := extract(epoch from (p_ends_at - p_starts_at))::int / 60;
  if dur < min_min then
    raise exception 'below the minimum duration of % minutes', min_min;
  end if;
  if dur > max_min then
    raise exception 'above the maximum duration of % minutes', max_min;
  end if;

  gran := rules->>'granularity';
  local_start := p_starts_at at time zone tz;
  local_end := p_ends_at at time zone tz;

  -- #446: the working day comes from booking_rules (defaults 8:00 /
  -- 12:00 / 17:00 — WorkHours.defaults on the client). An inconsistent
  -- triple falls back to the defaults exactly like the client, so the
  -- constraint and the UI always agree on the canonical windows.
  ws_start := coalesce((rules->>'work_start_minutes')::int, 480);
  ws_bound := coalesce((rules->>'half_boundary_minutes')::int, 720);
  ws_end := coalesce((rules->>'work_end_minutes')::int, 1020);
  if not (ws_start >= 0 and ws_start < ws_bound
          and ws_bound < ws_end and ws_end <= 1440) then
    ws_start := 480; ws_bound := 720; ws_end := 1020;
  end if;
  d := local_start::date;
  ts_start := d::timestamp + make_interval(mins => ws_start);
  ts_bound := d::timestamp + make_interval(mins => ws_bound);
  ts_end := d::timestamp + make_interval(mins => ws_end);
  ts_midnight := d::timestamp + interval '1 day';

  -- Half-day granularity (#200/#201, #446): the three canonical
  -- windows are now the CONFIGURED working day — morning start-to-
  -- boundary, afternoon boundary-to-end, full day start-to-end.
  -- Walk-ups start "now" and end at the next canonical edge; at or
  -- after the end of the working day they may run to local midnight
  -- (overtime — the old 0026 behaviour for late arrivals). The client
  -- pins the substring 'half-day' (BookingGranularityError).
  if gran = 'half_day' then
    if p_walk_up then
      if not (
        (local_start < ts_bound and local_end = ts_bound)
        or (local_start >= ts_bound and local_start < ts_end
            and local_end = ts_end)
        or (local_start >= ts_end and local_end = ts_midnight)
      ) then
        raise exception 'walk-ups must end at the half-day boundary or the end of the working day';
      end if;
    elsif not (
      (local_start = ts_start and local_end = ts_bound)
      or (local_start = ts_bound and local_end = ts_end)
      or (local_start = ts_start and local_end = ts_end)
    ) then
      raise exception 'bookings must cover a half-day or the full working day';
    end if;

  -- Full-day granularity (0032, #446): exactly the working day. The
  -- client pins the substring 'cover the full day'.
  elsif gran = 'full_day' then
    if not (
      (local_end = ts_end and (p_walk_up or local_start = ts_start))
      or (p_walk_up and local_start >= ts_end and local_end = ts_midnight)
    ) then
      raise exception 'bookings must cover the full day (working hours)';
    end if;

  -- Minute grid (0032): unchanged. 'hours' (#446) deliberately matches
  -- no branch — free from-to times, no grid; billing converts booked
  -- time to half-day equivalents (member_statement v8).
  elsif gran in ('minutes_5','minutes_15','minutes_30','minutes_60') then
    slot := split_part(gran, '_', 2)::int;
    if not (
      extract(second from local_end) = 0
      and extract(minute from local_end)::int % slot = 0
      and (p_walk_up or (
        extract(second from local_start) = 0
        and extract(minute from local_start)::int % slot = 0))
    ) then
      raise exception 'bookings must start and end on the %-minute grid', slot;
    end if;
  end if;

  perform public.assert_workspace_open(p_workspace_id, p_starts_at, p_ends_at);
end;
$$;
revoke execute on function public.enforce_booking_rules(uuid, timestamptz, timestamptz, boolean) from public, anon, authenticated;

-- ---------------------------------------------------------------------

-- member_statement v8 (body from 0059 v7; changes marked #446).
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

-- ---------------------------------------------------------------------

-- assert_member_quota v3 (body from 0041 v2; changes marked #446).
create or replace function public.assert_member_quota(
  p_member_id uuid, p_at timestamptz
) returns void language plpgsql stable security definer set search_path = public as $$
declare
  v_member public.members;
  v_tz text;
  v_open int[];
  v_pct int;
  v_period text;
  v_month_first date;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_open_days int;
  v_included int;
  v_ext int;
  v_used int;
  -- #446 working hours
  v_rules jsonb;
  v_gran text;
  v_bound int;
  v_half_minutes numeric;
begin
  select * into v_member from public.members where id = p_member_id;
  select timezone,
         coalesce((select array_agg(x::int)
                     from jsonb_array_elements_text(booking_rules->'open_weekdays') x),
                  array[1,2,3,4,5]),
         booking_rules
    into v_tz, v_open, v_rules
    from public.workspaces where id = v_member.workspace_id;
  -- #446: boundary + hours-mode equivalents, defaults like the client.
  v_gran := v_rules->>'granularity';
  v_bound := coalesce((v_rules->>'half_boundary_minutes')::int, 720);
  if v_bound <= 0 or v_bound >= 1440 then v_bound := 720; end if;
  v_half_minutes := greatest(1, coalesce((v_rules->>'half_day_hours')::int, 4)) * 60.0;

  v_period := to_char(p_at at time zone v_tz, 'YYYY-MM');
  v_month_first := to_date(v_period || '-01', 'YYYY-MM-DD');
  v_period_start := to_timestamp(v_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
  v_period_end := (to_timestamp(v_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;

  v_pct := coalesce(v_member.subscription_pct, 100);
  select count(*) into v_open_days
  from generate_series(v_month_first,
                       (v_month_first + interval '1 month' - interval '1 day')::date,
                       interval '1 day') d
  where extract(isodow from d)::int = any(v_open)
    and not exists (select 1 from public.closure_days c
                     where c.workspace_id = v_member.workspace_id and c.day = d::date);
  v_included := ceil(v_open_days * 2 * v_pct / 100.0)::int;

  select coalesce(sum(half_days), 0) into v_ext from public.quota_extensions
    where member_id = p_member_id and period = v_period;

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

  -- #446 hours granularity: same half-day-equivalent conversion as
  -- member_statement, so the cap and the bill agree.
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

  if v_used > v_included + v_ext then
    -- pay-as-you-go members may go over; the overage bills at the band rate
    if coalesce(v_member.overage_policy, 'blocked') = 'payg' then
      return;
    end if;
    -- the client pins the substring 'half-day quota' of this message
    raise exception 'half-day quota exceeded — request additional half-days';
  end if;
end;
$$;
revoke execute on function public.assert_member_quota(uuid, timestamptz) from public, anon, authenticated;