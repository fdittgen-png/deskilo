-- SPDX-License-Identifier: 0BSD
-- DesKilo half-day walk-up exemption (epic #199, issue #201). NOT YET
-- applied to the hosted reference project — the orchestrator applies it
-- after review.
--
-- Issue #201 (validated): under half-day granularity a walk-up check-in
-- starts NOW and ends at the current half-day boundary (13:00, or next
-- day 00:00) — a window 0025's canonical check would reject. The rule
-- gains a p_walk_up flag: walk-ups must END exactly at the boundary of
-- the half containing their start; everything else keeps the three
-- canonical windows. Only create_reservation forwards its p_check_in;
-- admin_create_reservation_for and create_series call with three args
-- and bind to the default (strict).
--
-- The 3-arg function must be DROPPED first: keeping it alongside a
-- 4-arg-with-default overload would make every existing 3-arg call
-- ambiguous. Body below = 0025 verbatim + the p_walk_up branch.

drop function public.enforce_booking_rules(uuid, timestamptz, timestamptz);

create or replace function public.enforce_booking_rules(
  p_workspace_id uuid, p_starts_at timestamptz, p_ends_at timestamptz,
  p_walk_up boolean default false
) returns void language plpgsql stable security definer set search_path = public as $$
declare rules jsonb; horizon int; min_min int; max_min int; dur int;
        tz text; local_start timestamp; local_end timestamp;
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
  -- Half-day granularity (#200/#201): reservations must cover one of the
  -- three canonical workspace-local windows — morning (00:00–13:00),
  -- afternoon (13:00–24:00 = next day 00:00) or full day — while a
  -- walk-up (#201) starts now and must END at the boundary of the half
  -- containing its start. The client pins the substring 'half-day' of
  -- this message (BookingGranularityError.serverSubstring).
  if rules->>'granularity' = 'half_day' then
    local_start := p_starts_at at time zone tz;
    local_end := p_ends_at at time zone tz;
    if p_walk_up then
      if not (
        (local_start::time < time '13:00'
          and local_end::time = time '13:00'
          and local_end::date = local_start::date)
        or (local_start::time >= time '13:00'
          and local_end::time = time '00:00'
          and local_end::date = local_start::date + 1)
      ) then
        raise exception 'walk-ups must end at the half-day boundary (13:00 or midnight)';
      end if;
    elsif not (
      (local_start::time = time '00:00'
        and local_end::time = time '13:00'
        and local_end::date = local_start::date)
      or (local_start::time = time '13:00'
        and local_end::time = time '00:00'
        and local_end::date = local_start::date + 1)
      or (local_start::time = time '00:00'
        and local_end::time = time '00:00'
        and local_end::date = local_start::date + 1)
    ) then
      raise exception 'bookings must cover a half-day (00:00-13:00, 13:00-24:00) or the full day';
    end if;
  end if;
  perform public.assert_workspace_open(p_workspace_id, p_starts_at, p_ends_at);
end;
$$;
revoke execute on function public.enforce_booking_rules(uuid, timestamptz, timestamptz, boolean) from public, anon, authenticated;

-- create_reservation: body copied verbatim from migration 0006; the only
-- change is forwarding p_check_in as the walk-up flag to the rules check.
create or replace function public.create_reservation(
  p_workspace_id uuid,
  p_seat_id uuid,
  p_office_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_check_in boolean default false
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_seat public.seats;
  v_office_id uuid;
  v_id uuid;
begin
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if (p_seat_id is null) = (p_office_id is null) then
    raise exception 'exactly one of seat or office required';
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
  else
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
  end if;

  insert into public.reservations
    (workspace_id, seat_id, office_id, member_id, starts_at, ends_at, status, checked_in_at)
  values (
    p_workspace_id, p_seat_id, p_office_id, v_member.id, p_starts_at, p_ends_at,
    case when p_check_in then 'checked_in' else 'reserved' end,
    case when p_check_in then now() end
  )
  returning id into v_id;
  return v_id;
end;
$$;
