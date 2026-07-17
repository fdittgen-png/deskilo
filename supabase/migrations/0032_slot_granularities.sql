-- SPDX-License-Identifier: MIT
-- Configurable reservation slots. NOT YET applied to the hosted
-- reference project — the owner applies it after review.
--
-- booking_rules.granularity (owner-set via set_booking_granularity's
-- merge write under workspaces_update RLS) now accepts, next to the
-- 0025 values 'flexible' and 'half_day':
--   * 'minutes_5' / 'minutes_15' / 'minutes_30' / 'minutes_60' —
--     bookings must start AND end on the N-minute grid (workspace-local
--     wall clock). Walk-ups start now and only their END must align.
--   * 'full_day' — bookings cover exactly the local 00:00→24:00 window;
--     a walk-up starts now and must END at the next local midnight.
-- 'flexible' keeps enforcing nothing (legacy), 'half_day' keeps the
-- 0026 canonical-window rules verbatim.

create or replace function public.enforce_booking_rules(
  p_workspace_id uuid, p_starts_at timestamptz, p_ends_at timestamptz,
  p_walk_up boolean default false
) returns void language plpgsql stable security definer set search_path = public as $$
declare rules jsonb; horizon int; min_min int; max_min int; dur int;
        tz text; local_start timestamp; local_end timestamp;
        gran text; slot int;
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

  -- Half-day granularity (#200/#201): unchanged from 0026 — the three
  -- canonical windows, walk-ups end at the half boundary. The client
  -- pins the substring 'half-day' (BookingGranularityError).
  if gran = 'half_day' then
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

  -- Full-day granularity (0032): exactly the local day window. The
  -- client pins the substring 'cover the full day'.
  elsif gran = 'full_day' then
    if not (
      local_end::time = time '00:00'
      and local_end::date = local_start::date + 1
      and (p_walk_up or local_start::time = time '00:00')
    ) then
      raise exception 'bookings must cover the full day (00:00-24:00)';
    end if;

  -- Minute grid (0032): start and end align to the configured step; a
  -- walk-up's start is "now" and exempt. The client pins the substring
  -- 'minute grid'.
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
