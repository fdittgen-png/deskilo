-- SPDX-License-Identifier: 0BSD
-- #573 — a check-in RIDES a reservation, and the reservation is the
-- workspace's own slot, not the arrival instant.
--
-- canonical_walkup_start answers which slot start canonically pairs
-- with a chosen walk-up END under day-based granularity: arrive at
-- 10:00 in a half-day workspace and "morning" books 08:00-12:00 (not
-- 10:00-12:00), "full day" books 08:00-17:00, "afternoon" stays
-- 12:00-17:00. Overtime windows (after the working day) keep the old
-- now-to-local-midnight shape. create_reservation v9 and kiosk_act v5
-- snap a walk-up check-in's start back to that slot start; when the
-- early slot part is genuinely taken (someone else's active row, or the
-- member's own morning elsewhere), ONE retry anchors the start at now()
-- instead of refusing the check-in outright.
--
-- check_in_reservation v4: being early on your own reservation's DAY is
-- presence, not a violation — under day-based/hours granularity a
-- same-workspace-day check-in is allowed ahead of the 15-minute leeway;
-- minute grids widen the leeway to one grid step. The reserved period
-- is CONFIRMED as reserved — the flip never rewrites the window.
-- kiosk_act v5 uses the same rule in its own-reservation lookup (the
-- 15-minute leeway was the only bridge — outside it the kiosk fell
-- through to a walk-up INSERT the one-place trigger rightly refused:
-- the "impossible to check in" field reports).
--
-- update_reservation v2 (#574): a CHECKED-IN booking may move its END
-- to a later canonical edge (morning to full day while sitting in the
-- seat); the start of a running booking never moves. enforce_booking_
-- rules v5 relaxes the half-day walk-up arms so a full-day walk-up (or
-- extension) may START mid-morning — v4 made "check in for the whole
-- day" at 10:00 impossible.

-- 1. The canonical slot start for a chosen walk-up end. NULL for
-- non-day-based granularities and for overtime windows — the caller
-- keeps what it was given. Mirrors enforce_booking_rules' own fallback
-- triple so constraint and derivation can never disagree.
create or replace function public.canonical_walkup_start(
  p_workspace_id uuid, p_starts_at timestamptz, p_ends_at timestamptz
) returns timestamptz language plpgsql stable security definer
set search_path = public as $$
declare
  rules jsonb; tz text; gran text;
  ws_start int; ws_bound int; ws_end int;
  local_start timestamp; local_end timestamp; d date;
  ts_start timestamp; ts_bound timestamp; ts_end timestamp;
begin
  select booking_rules, timezone into rules, tz
    from public.workspaces where id = p_workspace_id;
  gran := rules->>'granularity';
  if gran not in ('half_day', 'full_day') then return null; end if;

  ws_start := coalesce((rules->>'work_start_minutes')::int, 480);
  ws_bound := coalesce((rules->>'half_boundary_minutes')::int, 720);
  ws_end := coalesce((rules->>'work_end_minutes')::int, 1020);
  if not (ws_start >= 0 and ws_start < ws_bound
          and ws_bound < ws_end and ws_end <= 1440) then
    ws_start := 480; ws_bound := 720; ws_end := 1020;
  end if;
  local_start := p_starts_at at time zone tz;
  local_end := p_ends_at at time zone tz;
  d := local_start::date;
  ts_start := d::timestamp + make_interval(mins => ws_start);
  ts_bound := d::timestamp + make_interval(mins => ws_bound);
  ts_end := d::timestamp + make_interval(mins => ws_end);

  if gran = 'half_day' then
    if local_end = ts_bound then
      return ts_start at time zone tz;                 -- morning slot
    elsif local_end = ts_end then
      if local_start >= ts_bound then
        return ts_bound at time zone tz;               -- afternoon slot
      end if;
      return ts_start at time zone tz;                 -- full day
    end if;
  elsif local_end = ts_end then
    return ts_start at time zone tz;                   -- full day
  end if;
  return null;  -- overtime or an odd window: keep the caller's shape.
end;
$$;
revoke execute on function
  public.canonical_walkup_start(uuid, timestamptz, timestamptz)
  from public, anon, authenticated;

-- 2. enforce_booking_rules v5 — the 0087 body with the half-day
-- WALK-UP arms relaxed: a walk-up may end at the boundary OR at the end
-- of the working day from ANY earlier start. v4 required a full-day
-- walk-up to start at/after the boundary, which made "check in for the
-- whole day" at 10:00 impossible (the field report), and would refuse
-- the #573 retry-anchored windows and checked-in extensions.
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

  -- Half-day granularity (#200/#201, #446, #573): the three canonical
  -- windows are the CONFIGURED working day. Walk-ups end at a canonical
  -- edge — the boundary or the end of the day — from any earlier start
  -- (#573: a 10:00 arrival checking in for the whole day is a walk-up
  -- ending at the day's end); at or after the end of the working day
  -- they may run to local midnight (overtime, the 0026 behaviour). The
  -- client pins the substring 'half-day' (BookingGranularityError).
  if gran = 'half_day' then
    if p_walk_up then
      if not (
        (local_end = ts_bound and local_start < ts_bound)
        or (local_end = ts_end and local_start < ts_end)
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

-- 3. create_reservation v9 — the 0079 body with the canonical walk-up
-- slot and the one-retry anchor. The validate+insert section runs in a
-- two-attempt loop: attempt 1 uses the snapped-back slot; a refusal
-- whose cause can only be the slot's EARLY part retries once anchored
-- at now(). Anything else re-raises unchanged.
create or replace function public.create_reservation(
  p_workspace_id uuid,
  p_seat_id uuid,
  p_office_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_check_in boolean default false,
  p_level_id uuid default null,
  p_desk_id uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_seat public.seats;
  v_office_id uuid;
  v_level_id uuid;
  v_id uuid;
  v_canon timestamptz;
  v_snapped boolean := false;
  v_starts timestamptz := p_starts_at;
  v_ends timestamptz := p_ends_at;
  v_attempt int;
begin
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if (case when p_seat_id is null then 0 else 1 end
      + case when p_desk_id is null then 0 else 1 end
      + case when p_office_id is null then 0 else 1 end
      + case when p_level_id is null then 0 else 1 end) <> 1 then
    raise exception 'exactly one of seat, desk, office or level required';
  end if;

  -- #573: a day-based walk-up check-in books the SLOT the chosen end
  -- belongs to, not the arrival instant — the start snaps BACK to the
  -- slot start, the chosen end stays the member's choice.
  if p_check_in then
    v_canon := public.canonical_walkup_start(
      p_workspace_id, p_starts_at, p_ends_at);
    if v_canon is not null and v_canon < v_starts then
      v_starts := v_canon;
      v_snapped := true;
    end if;
  end if;

  for v_attempt in 1..2 loop
    begin
      perform public.enforce_booking_rules(p_workspace_id, v_starts, v_ends, p_check_in);

      if p_seat_id is not null then
        select * into v_seat from public.seats
          where id = p_seat_id and workspace_id = p_workspace_id;
        if v_seat.id is null then raise exception 'unknown seat'; end if;
        if tstzrange(coalesce(v_seat.blocked_from, '-infinity'::timestamptz),
                     coalesce(v_seat.blocked_to, 'infinity'::timestamptz))
           && tstzrange(v_starts, v_ends)
           and (v_seat.blocked_from is not null or v_seat.blocked_to is not null) then
          raise exception 'seat is blocked in that period';
        end if;
        -- 0059: the seat's DESK reserved as a whole blocks the seat.
        if exists (
          select 1 from public.reservations r
          where r.desk_id = v_seat.desk_id
            and r.status in ('reserved','checked_in')
            and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
        ) then
          raise exception 'desk is reserved as a whole in that period';
        end if;
        select d.office_id into v_office_id from public.desks d where d.id = v_seat.desk_id;
        if exists (
          select 1 from public.reservations r
          where r.office_id = v_office_id
            and r.status in ('reserved','checked_in')
            and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
        ) then
          raise exception 'office is reserved as a whole in that period';
        end if;
        select o.level_id into v_level_id from public.offices o where o.id = v_office_id;
        if exists (
          select 1 from public.reservations r
          where r.level_id = v_level_id
            and r.status in ('reserved','checked_in')
            and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
        ) then
          raise exception 'level is reserved as a whole in that period';
        end if;
      elsif p_desk_id is not null then
        -- Whole-DESK path (0059): the level/office gates, desk-scale.
        if not public.level_booking_enabled(p_workspace_id) then
          raise exception 'level booking is not enabled';
        end if;
        if not (v_member.can_reserve_level or v_member.is_owner
                or v_member.is_admin) then
          -- the client pins this substring (0050)
          raise exception 'not allowed to reserve a level';
        end if;
        if not exists (
          select 1 from public.desks d
          where d.id = p_desk_id and d.workspace_id = p_workspace_id
            and d.bookable_as_whole
        ) then
          raise exception 'desk not bookable as a whole';
        end if;
        if exists (
          select 1 from public.reservations r
          join public.seats s on s.id = r.seat_id
          where s.desk_id = p_desk_id
            and r.status in ('reserved','checked_in')
            and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
        ) then
          raise exception 'a seat on this desk is already reserved in that period';
        end if;
        select d.office_id into v_office_id from public.desks d where d.id = p_desk_id;
        if exists (
          select 1 from public.reservations r
          where r.office_id = v_office_id
            and r.status in ('reserved','checked_in')
            and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
        ) then
          raise exception 'office is reserved as a whole in that period';
        end if;
        select o.level_id into v_level_id from public.offices o where o.id = v_office_id;
        if exists (
          select 1 from public.reservations r
          where r.level_id = v_level_id
            and r.status in ('reserved','checked_in')
            and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
        ) then
          raise exception 'level is reserved as a whole in that period';
        end if;
      elsif p_office_id is not null then
        -- Whole-space gates (0057): feature + personal grant, like levels.
        if not public.level_booking_enabled(p_workspace_id) then
          raise exception 'level booking is not enabled';
        end if;
        if not (v_member.can_reserve_level or v_member.is_owner
                or v_member.is_admin) then
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
            and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
        ) then
          raise exception 'a seat in this office is already reserved in that period';
        end if;
        -- 0059: a desk inside reserved as a whole blocks the office too.
        if exists (
          select 1 from public.reservations r
          join public.desks d on d.id = r.desk_id
          where d.office_id = p_office_id
            and r.status in ('reserved','checked_in')
            and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
        ) then
          raise exception 'a desk in this office is already reserved in that period';
        end if;
        select o.level_id into v_level_id from public.offices o where o.id = p_office_id;
        if exists (
          select 1 from public.reservations r
          where r.level_id = v_level_id
            and r.status in ('reserved','checked_in')
            and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
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
        if not (v_member.can_reserve_level or v_member.is_owner
                or v_member.is_admin) then
          -- the client pins this substring
          raise exception 'not allowed to reserve a level';
        end if;
        if public.level_has_conflict(p_level_id, v_starts, v_ends) then
          raise exception 'the level has reservations in that period';
        end if;
      end if;

      insert into public.reservations
        (workspace_id, seat_id, desk_id, office_id, level_id, member_id,
         starts_at, ends_at, status, checked_in_at)
      values (
        p_workspace_id, p_seat_id, p_desk_id, p_office_id, p_level_id,
        v_member.id, v_starts, v_ends,
        case when p_check_in then 'checked_in' else 'reserved' end,
        case when p_check_in then now() end
      )
      returning id into v_id;
      exit; -- validated and inserted — leave the retry loop.
    exception when others then
      -- The one-retry anchor: only a snapped-back walk-up can retry,
      -- and only once — the early slot part was genuinely taken, so
      -- the reservation anchors at now() and keeps the slot's END.
      if v_attempt = 1 and v_snapped
         and v_starts < now() and now() < v_ends then
        v_starts := now();
      else
        raise;
      end if;
    end;
  end loop;

  perform public.assert_member_quota(v_member.id, v_starts);

  -- 0059: whole-space bookings route through the REGULAR validation
  -- feature when the owner configured a rule for them — the reservation
  -- blocks the space immediately, validators confirm or reject (a
  -- reject cancels it via respond_to_event's existing branch).
  if p_desk_id is not null or p_office_id is not null
     or p_level_id is not null then
    if exists (
      select 1 from public.validation_policies vp
      where vp.workspace_id = p_workspace_id
        and vp.event_type = 'space_reservation'
    ) then
      update public.events
        set status = 'pending', type = 'space_reservation'
        where reservation_id = v_id and action = 'created';
    end if;
  end if;
  return v_id;
end;
$$;

-- 4. check_in_reservation v4 — the 0079 body with the same-day presence
-- rule. The reserved window itself is never rewritten: the check-in
-- CONFIRMS the reservation, exactly as booked.
create or replace function public.check_in_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_own boolean;
  v_rules jsonb;
  v_tz text;
  v_gran text;
  v_leeway interval := interval '15 minutes';
begin
  select r.* into v_res from public.reservations r
    where r.id = p_reservation_id;
  if v_res.id is null then raise exception 'not your reservation'; end if;

  select exists (
    select 1 from public.members m
    where m.id = v_res.member_id and m.user_id = auth.uid()
  ) into v_own;

  if not v_own then
    -- The authorized-for-others path (0077): admin/owner + the
    -- bookForOthers feature (default ON, so ABSENT counts as ON).
    if not (
      public.is_admin_of(v_res.workspace_id)
      and coalesce((
        select w.feature_flags->'bookForOthers' is distinct from 'false'::jsonb
        from public.workspaces w where w.id = v_res.workspace_id
      ), true)
    ) then
      raise exception 'not your reservation';
    end if;
  end if;

  if v_res.status <> 'reserved' then raise exception 'not in reserved state'; end if;

  -- Presence window (0077 → #573). Day-based and hours granularity: the
  -- slot IS the working day, so any same-workspace-day arrival counts
  -- as presence. Minute grids: the leeway widens to one grid step.
  select w.booking_rules, w.timezone into v_rules, v_tz
    from public.workspaces w where w.id = v_res.workspace_id;
  v_gran := v_rules->>'granularity';
  if v_gran in ('minutes_5','minutes_15','minutes_30','minutes_60') then
    v_leeway := greatest(v_leeway,
      make_interval(mins => split_part(v_gran, '_', 2)::int));
  end if;
  if now() < v_res.starts_at - v_leeway
     and not (v_gran in ('half_day','full_day','hours')
              and (v_res.starts_at at time zone v_tz)::date
                  = (now() at time zone v_tz)::date) then
    raise exception 'check-in window not open yet';
  end if;
  if now() >= v_res.ends_at then
    raise exception 'check-in window closed';
  end if;

  -- One place at a time (#412): a forgotten check-out whose own end has
  -- passed completes itself (stamped at its own end, 0075 semantics)...
  update public.reservations
    set status = 'completed', checked_out_at = ends_at
    where member_id = v_res.member_id
      and id <> v_res.id
      and status = 'checked_in'
      and ends_at <= now();
  -- ...but a check-in still RUNNING elsewhere means the member is
  -- physically somewhere else: refuse, check out there first.
  if exists (
    select 1 from public.reservations r
    where r.member_id = v_res.member_id
      and r.id <> v_res.id
      and r.status = 'checked_in'
      and r.ends_at > now()
  ) then
    -- the client pins this substring
    raise exception 'already checked in elsewhere';
  end if;

  perform public.assert_workspace_open(v_res.workspace_id, now(), now() + interval '1 minute');
  update public.reservations
    set status = 'checked_in', checked_in_at = now()
    where id = p_reservation_id;
end;
$$;

-- 5. kiosk_act v5 — the 0085 body with the same-day own-reservation
-- lookup and the canonical walk-up slot.
create or replace function public.kiosk_act(
  p_workspace_id uuid,
  p_badge_token text,
  p_action text,             -- 'reserve' | 'check_in' | 'check_out'
  p_seat_id uuid default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_level_id uuid default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_kiosk public.members;
  v_badge public.member_badges;
  v_subject public.members;
  v_seat public.seats;
  v_office_id uuid;
  v_res public.reservations;
  v_id uuid;
  v_rules jsonb;
  v_tz text;
  v_gran text;
  v_canon timestamptz;
  v_snapped boolean := false;
  v_starts timestamptz;
  v_ends timestamptz;
  v_attempt int;
begin
  select * into v_kiosk from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and is_kiosk;
  if v_kiosk.id is null then raise exception 'not a kiosk of this workspace'; end if;

  select * into v_badge from public.member_badges
    where workspace_id = p_workspace_id
      and token_hash = public.badge_token_hash(p_badge_token)
      and revoked_at is null;
  if v_badge.id is null then
    raise exception 'badge not recognized';
  end if;
  select * into v_subject from public.members
    where id = v_badge.member_id and status = 'active';
  if v_subject.id is null then raise exception 'badge member not active'; end if;

  select w.booking_rules, w.timezone into v_rules, v_tz
    from public.workspaces w where w.id = p_workspace_id;
  v_gran := v_rules->>'granularity';

  if p_action = 'check_out' then
    select r.* into v_res from public.reservations r
      where r.member_id = v_subject.id and r.status = 'checked_in'
        and (p_seat_id is null or r.seat_id = p_seat_id)
        and (p_level_id is null or r.level_id = p_level_id)
      order by r.checked_in_at desc limit 1;
    if v_res.id is null then raise exception 'not checked in'; end if;
    update public.reservations
      set status = 'completed', checked_out_at = now(),
          ends_at = least(ends_at, now())
      where id = v_res.id;
    return jsonb_build_object('action', 'check_out', 'reservation_id', v_res.id);
  end if;

  if p_action not in ('reserve', 'check_in') then
    raise exception 'unknown kiosk action';
  end if;
  if (p_seat_id is null) = (p_level_id is null)
     or p_starts_at is null or p_ends_at is null then
    raise exception 'seat or level, and window required';
  end if;

  v_starts := p_starts_at;
  v_ends := p_ends_at;
  -- #573: a day-based walk-up check-in books the SLOT the chosen end
  -- belongs to — the start snaps back, the member's chosen end stays.
  if p_action = 'check_in' then
    v_canon := public.canonical_walkup_start(
      p_workspace_id, p_starts_at, p_ends_at);
    if v_canon is not null and v_canon < v_starts then
      v_starts := v_canon;
      v_snapped := true;
    end if;
  end if;

  if p_level_id is not null then
    -- Level path: same gates as create_reservation — feature, bookable,
    -- the badge member's personal grant, no conflicts on the level.
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
    if not v_subject.can_reserve_level then
      raise exception 'not allowed to reserve a level';
    end if;

    if p_action = 'check_in' then
      select r.* into v_res from public.reservations r
        where r.member_id = v_subject.id and r.level_id = p_level_id
          and r.status = 'reserved'
          and r.ends_at > now()
          -- #573: the 15-minute leeway (0077/#430) OR the reservation's
          -- own workspace day under day-based/hours granularity — being
          -- early on your own slot's day is presence.
          and (r.starts_at - interval '15 minutes' <= now()
               or (v_gran in ('half_day','full_day','hours')
                   and (r.starts_at at time zone v_tz)::date
                       = (now() at time zone v_tz)::date))
        order by r.starts_at limit 1;
      if v_res.id is not null then
        -- One place (#430, mirroring check_in_reservation): stale
        -- check-ins complete at their own end; still-running elsewhere
        -- refuses with the pinned substring.
        update public.reservations
          set status = 'completed', checked_out_at = ends_at
          where member_id = v_subject.id and id <> v_res.id
            and status = 'checked_in' and ends_at <= now();
        if exists (
          select 1 from public.reservations r2
          where r2.member_id = v_subject.id and r2.id <> v_res.id
            and r2.status = 'checked_in' and r2.ends_at > now()
        ) then
          raise exception 'already checked in elsewhere';
        end if;
        update public.reservations
          set status = 'checked_in', checked_in_at = now()
          where id = v_res.id;
        return jsonb_build_object('action', 'check_in', 'reservation_id', v_res.id);
      end if;
    end if;

    for v_attempt in 1..2 loop
      begin
        perform public.enforce_booking_rules(
          p_workspace_id, v_starts, v_ends, p_action = 'check_in');
        if public.level_has_conflict(p_level_id, v_starts, v_ends) then
          raise exception 'the level has reservations in that period';
        end if;

        insert into public.reservations
          (workspace_id, level_id, member_id, starts_at, ends_at, status, checked_in_at)
        values (
          p_workspace_id, p_level_id, v_subject.id, v_starts, v_ends,
          case when p_action = 'check_in' then 'checked_in' else 'reserved' end,
          case when p_action = 'check_in' then now() end
        )
        returning id into v_id;
        exit;
      exception when others then
        if v_attempt = 1 and v_snapped
           and v_starts < now() and now() < v_ends then
          v_starts := now();
        else
          raise;
        end if;
      end;
    end loop;
    perform public.assert_member_quota(v_subject.id, v_starts);
    return jsonb_build_object('action', p_action, 'reservation_id', v_id);
  end if;

  select * into v_seat from public.seats
    where id = p_seat_id and workspace_id = p_workspace_id;
  if v_seat.id is null then raise exception 'unknown seat'; end if;

  if p_action = 'check_in' then
    select r.* into v_res from public.reservations r
      where r.member_id = v_subject.id and r.seat_id = p_seat_id
        and r.status = 'reserved'
        and r.ends_at > now()
        -- #573: leeway OR same workspace day, as on the level path.
        and (r.starts_at - interval '15 minutes' <= now()
             or (v_gran in ('half_day','full_day','hours')
                 and (r.starts_at at time zone v_tz)::date
                     = (now() at time zone v_tz)::date))
      order by r.starts_at limit 1;
    if v_res.id is not null then
      -- One place (#430): same guards as the level path.
      update public.reservations
        set status = 'completed', checked_out_at = ends_at
        where member_id = v_subject.id and id <> v_res.id
          and status = 'checked_in' and ends_at <= now();
      if exists (
        select 1 from public.reservations r2
        where r2.member_id = v_subject.id and r2.id <> v_res.id
          and r2.status = 'checked_in' and r2.ends_at > now()
      ) then
        raise exception 'already checked in elsewhere';
      end if;
      update public.reservations
        set status = 'checked_in', checked_in_at = now()
        where id = v_res.id;
      return jsonb_build_object('action', 'check_in', 'reservation_id', v_res.id);
    end if;
  end if;

  for v_attempt in 1..2 loop
    begin
      perform public.enforce_booking_rules(
        p_workspace_id, v_starts, v_ends, p_action = 'check_in');
      if tstzrange(coalesce(v_seat.blocked_from, '-infinity'::timestamptz),
                   coalesce(v_seat.blocked_to, 'infinity'::timestamptz))
         && tstzrange(v_starts, v_ends)
         and (v_seat.blocked_from is not null or v_seat.blocked_to is not null) then
        raise exception 'seat is blocked in that period';
      end if;
      -- 0059: the seat's DESK reserved as a whole blocks the walk-up too.
      if exists (
        select 1 from public.reservations r
        where r.desk_id = v_seat.desk_id
          and r.status in ('reserved','checked_in')
          and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
      ) then
        raise exception 'desk is reserved as a whole in that period';
      end if;
      select d.office_id into v_office_id from public.desks d where d.id = v_seat.desk_id;
      if exists (
        select 1 from public.reservations r
        where r.office_id = v_office_id
          and r.status in ('reserved','checked_in')
          and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
      ) then
        raise exception 'office is reserved as a whole in that period';
      end if;
      if exists (
        select 1 from public.reservations r
        where r.level_id = (select o.level_id from public.offices o where o.id = v_office_id)
          and r.status in ('reserved','checked_in')
          and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
      ) then
        raise exception 'level is reserved as a whole in that period';
      end if;

      insert into public.reservations
        (workspace_id, seat_id, member_id, starts_at, ends_at, status, checked_in_at)
      values (
        p_workspace_id, p_seat_id, v_subject.id, v_starts, v_ends,
        case when p_action = 'check_in' then 'checked_in' else 'reserved' end,
        case when p_action = 'check_in' then now() end
      )
      returning id into v_id;
      exit;
    exception when others then
      if v_attempt = 1 and v_snapped
         and v_starts < now() and now() < v_ends then
        v_starts := now();
      else
        raise;
      end if;
    end;
  end loop;
  perform public.assert_member_quota(v_subject.id, v_starts);
  return jsonb_build_object('action', p_action, 'reservation_id', v_id);
end;
$$;

-- 6. update_reservation v2 (#574) — the 0033 body plus the checked-in
-- extension: a RUNNING booking may move its end to a later canonical
-- edge (half day to full day from the seat), never its start. Day-based
-- granularities validate the strict canonical windows (morning to full
-- day IS canonical); grids/hours validate the end against the grid via
-- the walk-up branch, since a walk-up-born start may sit off-grid.
create or replace function public.update_reservation(
  p_reservation_id uuid, p_starts_at timestamptz, p_ends_at timestamptz
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
begin
  select r.* into v_res from public.reservations r
    join public.members m on m.id = r.member_id
    where r.id = p_reservation_id and m.user_id = auth.uid();
  if v_res.id is null then raise exception 'not your reservation'; end if;

  if v_res.status = 'checked_in' then
    if p_starts_at <> v_res.starts_at then
      raise exception 'a running booking keeps its start';
    end if;
    if p_ends_at <= now() then
      raise exception 'the new end must lie ahead';
    end if;
    -- Walk-up shape checks: the END must land on a canonical edge /
    -- the grid, the (immovable) start may sit anywhere — a running
    -- booking's start is often the anchored arrival instant.
    perform public.enforce_booking_rules(
      v_res.workspace_id, p_starts_at, p_ends_at, true);
  elsif v_res.status = 'reserved' then
    perform public.enforce_booking_rules(
      v_res.workspace_id, p_starts_at, p_ends_at);
  else
    raise exception 'only upcoming reservations can be edited';
  end if;

  if v_res.seat_id is not null then
    perform public.assert_seat_not_blocked(
      v_res.seat_id, p_starts_at, p_ends_at);
  end if;
  update public.reservations
    set starts_at = p_starts_at, ends_at = p_ends_at
    where id = p_reservation_id;
  perform public.assert_member_quota(v_res.member_id, p_starts_at);
end;
$$;
revoke execute on function public.update_reservation(uuid, timestamptz, timestamptz) from public, anon;
