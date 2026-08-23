-- SPDX-License-Identifier: 0BSD
-- #600 — reservation/check-in edge fixes + the owner-configurable
-- booking-behavior matrix, driven by a 60-case live-RPC test matrix.
--
-- Defects fixed:
--   1. A check-out BEFORE the reserved slot's start (possible since
--      0113's same-day early check-in) tried to write
--      ends_at = now() < starts_at and died on reservations_time_valid.
--      complete_check_out() now records the REAL presence
--      [checked_in_at, now), floored at one minute — used by both
--      check_out_reservation and kiosk_act.
--   2. validation_policies_event_type_check refused the two event types
--      the validation-settings screen offers cards for
--      (reservation_delete, invoice_writeoff) — widened.
--   3. create_reservation accepted p_check_in for a FUTURE day (a
--      "checked-in" reservation for tomorrow), inconsistent with
--      check_in_reservation's same-day rule — refused now.
--
-- New booking_rules policy keys (defaults keep today's behavior):
--   allow_past_bookings — OFF: fully-past bookings are refused
--                         (they silently succeeded before; a member
--                         could self-create attendance history);
--                         ON restores deliberate backfill.
--   grid_within_hours   — OFF: minute grids stay free-time (0032);
--                         ON confines them to the working day,
--                         overtime walk-ups excepted.
--   admin_check_out     — OFF: check-out stays owner-only; ON lets an
--                         admin check a member out (the #412 overrule
--                         family).

-- 1. The one truthful check-out.
create or replace function public.complete_check_out(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_start timestamptz;
  v_end timestamptz;
begin
  select r.* into v_res from public.reservations r
    where r.id = p_reservation_id;
  -- The completed row must describe a real, forward-running presence:
  -- an early same-day check-in (0113) can sit BEFORE starts_at.
  v_start := least(v_res.starts_at, coalesce(v_res.checked_in_at, now()));
  v_end := least(v_res.ends_at, now());
  if v_end <= v_start then v_end := v_start + interval '1 minute'; end if;
  update public.reservations
    set status = 'completed', checked_out_at = now(),
        starts_at = v_start, ends_at = v_end
    where id = p_reservation_id;
end;
$$;
revoke execute on function public.complete_check_out(uuid)
  from public, anon, authenticated;

-- 2. check_out_reservation v2 — helper + the admin_check_out policy.
create or replace function public.check_out_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_own boolean;
  v_rules jsonb;
begin
  select r.* into v_res from public.reservations r
    where r.id = p_reservation_id;
  if v_res.id is null then raise exception 'not your reservation'; end if;
  select exists (
    select 1 from public.members m
    where m.id = v_res.member_id and m.user_id = auth.uid()
  ) into v_own;
  if not v_own then
    -- #600: admins may check a member out only when the owner switched
    -- the admin_check_out policy on.
    select w.booking_rules into v_rules
      from public.workspaces w where w.id = v_res.workspace_id;
    if not (public.is_admin_of(v_res.workspace_id)
            and coalesce(v_rules->>'admin_check_out', 'false') = 'true') then
      raise exception 'not your reservation';
    end if;
  end if;
  if v_res.status <> 'checked_in' then raise exception 'not checked in'; end if;
  perform public.complete_check_out(p_reservation_id);
end;
$$;

-- 3. The validation-policy types the client already offers (#600).
alter table public.validation_policies
  drop constraint validation_policies_event_type_check;
alter table public.validation_policies
  add constraint validation_policies_event_type_check check (
    event_type is null or event_type in (
      'reservation','payment','expense','adjustment','service_charge',
      'quota','role_change','member_join','space_reservation',
      'invoice_payment','reservation_delete','invoice_writeoff'));

-- 4. enforce_booking_rules v6 — the 0113 body + grid_within_hours.
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
    -- #600: grids are free-time by design (0032), but the owner may now
    -- confine them to the working day (booking_rules.grid_within_hours).
    -- Overtime walk-ups (at/after the working day's end, until local
    -- midnight) stay allowed — the same escape the day-based modes have.
    if coalesce(rules->>'grid_within_hours', 'false') = 'true'
       and not (p_walk_up and local_start >= ts_end
                and local_end <= ts_midnight)
       and (local_start < ts_start or local_end > ts_end) then
      raise exception 'bookings must stay within the working hours';
    end if;
  end if;

  perform public.assert_workspace_open(p_workspace_id, p_starts_at, p_ends_at);
end;
$$;

-- 5. create_reservation v10 — the 0113 body + the past and
-- walk-up-today guards.
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
  v_tz text;
  v_rules jsonb;
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
  select timezone, booking_rules into v_tz, v_rules
    from public.workspaces where id = p_workspace_id;
  -- #600: a booking on a DAY that already ended (workspace-local) is
  -- refused unless the owner switched allow_past_bookings on
  -- (deliberate backfill). Same-day retro windows stay legal — booking
  -- this morning at 15:00 records same-day attendance, the sweep's own
  -- semantics.
  if ((p_ends_at - interval '1 second') at time zone v_tz)::date
       < (now() at time zone v_tz)::date
     and coalesce(v_rules->>'allow_past_bookings', 'false') <> 'true' then
    raise exception 'the booking lies entirely in the past';
  end if;
  -- #600: a walk-up check-in means "I am here NOW" — its slot must
  -- start on the workspace-local TODAY (check_in_reservation already
  -- refuses other days; creation now mirrors it on every granularity).
  if p_check_in
     and (p_starts_at at time zone v_tz)::date
         <> (now() at time zone v_tz)::date then
    raise exception 'a walk-up check-in must start today';
  end if;
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

-- 6. kiosk_act v6 — the 0113 body, check-out through the helper.
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
    perform public.complete_check_out(v_res.id);
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
