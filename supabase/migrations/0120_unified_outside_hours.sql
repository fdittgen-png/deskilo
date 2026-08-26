-- SPDX-License-Identifier: 0BSD
-- #634 — ONE outside-hours policy with four mutually exclusive answers
-- to ONE question: what may happen outside the configured working day?
-- NOT YET applied to the hosted reference project — the orchestrator
-- applies it after review.
--
-- Two settings used to answer that question side by side, with
-- different scopes and different verbs:
--   * booking_rules.grid_within_hours (#600, 0116/0118) — a bool INSIDE
--     the minute-grid arm: it refused a grid window starting before the
--     day start or ending after the day end (partial spill included),
--     except the walk-up starting at/after the day end and ending by
--     local midnight. Minute grids only.
--   * booking_rules.outside_hours_mode (#624, 0118) — a gate BEFORE the
--     granularity arms: 'off' refused windows lying ENTIRELY outside the
--     working day, on every granularity.
-- A workspace could therefore display "grids are free-time (book 6:00)"
-- and "outside hours: refused" at the same time.
--
-- The wire key stays outside_hours_mode; it gains a fourth value:
--
--   off         — nothing outside the working day: no booking ahead, no
--                 walk-up, and a window that merely SPILLS past the day
--                 end (or starts before the day start) is refused too.
--                 DELIBERATELY stricter than #624's 'off', which only
--                 caught entirely-outside windows: if the space closes
--                 at 17:00, a booking until 18:00 is not sensible.
--   walkup_only — the spontaneous check-in outside the hours stays
--                 possible, evening overtime to local midnight
--                 included; RESERVING AHEAD outside the hours is
--                 refused, and so are spilling windows. Exactly what
--                 grid_within_hours = true did, generalized to EVERY
--                 granularity.
--   free        — allowed (ahead or walk-up), never counted or charged.
--   charged     — the absent default: allowed and counted, with the
--                 #624 same-day exemption.
--
-- LEGACY MAPPING — no data migration. The effective mode is
--
--   coalesce(rules->>'outside_hours_mode',
--            case when coalesce(rules->>'grid_within_hours', 'false')
--                      = 'true' then 'walkup_only' else 'charged' end)
--
-- resolved ONCE, by the single gate below (the client mirrors it in
-- BookingPolicies.fromRules). An explicit outside_hours_mode always
-- wins; the old key is never written again, only read as a fallback.
--
-- BILLING SCOPE IS UNCHANGED. reservation_counts_for_usage,
-- assert_member_quota and member_statement are NOT touched here: free
-- and exempt treatment stays keyed on ENTIRELY-outside windows
-- (window_outside_working_hours, 0118). Only the ENFORCEMENT gate now
-- also catches SPILL. Say it plainly, because "enforcement catches
-- spill, billing does not" is the kind of asymmetry a later reader
-- calls a bug: a window that touches the working hours at all is an
-- ordinary, fully counted booking — under 'off' and 'walkup_only' such
-- a window is simply never created in the first place, and under
-- 'free'/'charged' it bills exactly as it always did.
--
-- enforce_booking_rules v8 is GENERATED from its latest definition
-- (v7, 0118) with two hunks only: the #624 'off' gate becomes the
-- unified gate, and the #600 grid_within_hours block inside the
-- minute-grid arm is deleted — its behavior now lives in the gate.
-- Every other line (the half-day/full-day/grid shape arms, the horizon
-- and duration guards, assert_workspace_open) is byte-identical.

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
        v_mode text; v_touches_outside boolean; v_spontaneous boolean;
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

  -- #634: THE outside-hours gate — one resolution, four answers, every
  -- granularity, before the shape arms. The legacy #600 key is read
  -- (never written) as the fallback: grid_within_hours = true IS
  -- 'walkup_only'.
  v_mode := coalesce(
    rules->>'outside_hours_mode',
    case when coalesce(rules->>'grid_within_hours', 'false') = 'true'
         then 'walkup_only' else 'charged' end);
  -- "Touches outside" — the window leaves the working day at either
  -- edge, in workspace-local time. It strictly CONTAINS the 0118
  -- predicate window_outside_working_hours(local_start, local_end,
  -- ws_start, ws_end): a window with no intersection at all is before
  -- ts_start or after ts_end by definition. Enforcement uses the wider
  -- predicate (spill is refused); BILLING keeps the narrow one — see
  -- the header note on that deliberate asymmetry.
  v_touches_outside := local_start < ts_start or local_end > ts_end;
  -- The one spontaneous shape 'walkup_only' still allows: the walk-up
  -- starting at/after the day's end and ending by local midnight —
  -- exactly the escape grid_within_hours had (evening overtime).
  v_spontaneous := p_walk_up and local_start >= ts_end
                   and local_end <= ts_midnight;
  -- The client pins the substring 'outside the opening hours' in BOTH
  -- messages (bookingErrorText); the walkup_only one additionally says
  -- that a spontaneous check-in is still possible.
  if v_mode = 'off' and v_touches_outside then
    raise exception 'bookings outside the opening hours are not allowed';
  elsif v_mode = 'walkup_only' and v_touches_outside
        and not v_spontaneous then
    raise exception 'only spontaneous check-ins are possible outside the opening hours — booking ahead is not';
  end if;

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
