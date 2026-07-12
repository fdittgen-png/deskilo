-- SPDX-License-Identifier: MIT
-- DesKilo booking granularity (epic #199, issue #200). NOT YET applied
-- to the hosted reference project — the orchestrator applies it after
-- review.
--
-- The owner can restrict bookings to half days: booking_rules gains an
-- optional 'granularity' key ('flexible' | 'half_day'; absent or unknown
-- means flexible, no backfill needed). Under 'half_day' every booking
-- must cover exactly one canonical workspace-local window — 00:00–13:00
-- (morning), 13:00–24:00 (afternoon) or 00:00–24:00 (full day) — the
-- billing halves (13:00 pivot, spec §7). "24:00" is next-day 00:00; the
-- end instant stays exclusive, matching assert_workspace_open.
--
-- enforce_booking_rules is the shared chokepoint of create_reservation
-- (0006), admin_create_reservation_for (0021) and the first instance of
-- create_series (0021), so every booking path gets the check. Body
-- copied verbatim from migration 0013; the only changes are the timezone
-- in the select (needed for the local-time conversion) and the added
-- granularity block.
create or replace function public.enforce_booking_rules(
  p_workspace_id uuid, p_starts_at timestamptz, p_ends_at timestamptz
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
  -- Half-day granularity (#200): only the three canonical workspace-local
  -- windows pass — morning (00:00–13:00), afternoon (13:00–24:00 = next
  -- day 00:00) and full day (00:00–24:00). The client pins the substring
  -- 'half-day' of this message (BookingGranularityError.serverSubstring).
  if rules->>'granularity' = 'half_day' then
    local_start := p_starts_at at time zone tz;
    local_end := p_ends_at at time zone tz;
    if not (
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
