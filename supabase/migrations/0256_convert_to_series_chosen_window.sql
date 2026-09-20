-- SPDX-License-Identifier: 0BSD
-- risk: transforming
--
-- 0256 (#1562) — the repeat is built from the window the member CHOSE.
--
-- `reservation_detail_sheet._editTimes` collects a new window and then a
-- recurrence, in one gesture. Both halves reached `rescheduleReservation`
-- and only the first survived: with a pattern the command called
-- `convert_to_series(id, pattern, until)`, which has nowhere to put a
-- window, and 0224 built the series from the stored row:
--
--     v_series := public.create_series(
--       v_res.workspace_id, v_res.seat_id, v_res.starts_at, v_res.ends_at,
--       p_pattern, p_until);
--
-- So a member who asked for 14:00–16:00 weekly received 09:00–10:00
-- weekly, silently — and, worse, the per-date checks inside
-- `create_series` (conflicts, closures, quota) answered for the stored
-- hours, so dates that were free at the requested time could be reported
-- as skipped.
--
-- ## Why this is a DROP and not a `create or replace`
--
-- Adding defaulted parameters to an existing function does not replace
-- it: `convert_to_series(uuid, text, timestamptz)` and
-- `convert_to_series(uuid, text, timestamptz, timestamptz, timestamptz)`
-- are two functions, and a three-argument call then matches both —
-- `function convert_to_series(uuid, text, timestamptz) is not unique`.
-- The old signature goes first.
--
-- ## The default is the stored window
--
-- `coalesce(p_starts_at, v_res.starts_at)`: a caller that passes nothing
-- gets 0224's behaviour exactly, which is what a plain conversion — no
-- time change — must keep. Every other gate is untouched: the owner-or-
-- `manageReservations` check, the three state checks, the single
-- transaction, and THE rule 0224 exists for — a conversion that books no
-- date raises, rolling the cancel back with it (#1394).
--
-- Harnessed on the reference project before applying, rolled back. A
-- half-day workspace, one stored booking on the canonical afternoon
-- window, converted weekly ONCE with the canonical morning window and
-- ONCE with nothing:
--
--     HARNESS_RESULTS chosen_window=08:00-12:00 chosen_count=3
--     chosen_booked=3 original=12:00-17:00/cancelled |
--     stored_window=12:00-17:00 stored_count=3 stored_booked=3 |
--     overloads=1 new_signature=t

drop function if exists public.convert_to_series(uuid, text, timestamptz);

create or replace function public.convert_to_series(
  p_reservation_id uuid,
  p_pattern text,
  p_until timestamptz,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_own boolean;
  v_series jsonb;
begin
  select r.* into v_res from public.reservations r where r.id = p_reservation_id;
  if v_res.id is null then raise exception 'not your reservation'; end if;

  select exists (
    select 1 from public.members m
    where m.id = v_res.member_id and m.user_id = auth.uid()
  ) into v_own;

  if not v_own
     and not public.has_permission(v_res.workspace_id, 'manageReservations') then
    raise exception 'not your reservation';
  end if;

  -- A running or finished booking is not converted: `create_series`
  -- would book from its start, which is in the past.
  if v_res.status <> 'reserved' then
    raise exception 'only an upcoming reservation can become a repeat';
  end if;
  if v_res.seat_id is null then
    raise exception 'only a seat booking can become a repeat';
  end if;
  if v_res.series_id is not null then
    raise exception 'this booking is already part of a repeat';
  end if;

  update public.reservations set status = 'cancelled' where id = p_reservation_id;

  -- Inherits every gate create_series already applies: the member check,
  -- the pattern, max_series_days, enforce_booking_rules, the whole-space
  -- rules, and the per-date skipping — all of them now judging the
  -- window the member asked for (#1562), which defaults to the stored one.
  v_series := public.create_series(
    v_res.workspace_id, v_res.seat_id,
    coalesce(p_starts_at, v_res.starts_at),
    coalesce(p_ends_at, v_res.ends_at),
    p_pattern, p_until);

  -- THE rule this function exists for. The client pins the substring
  -- 'your booking is unchanged'.
  if jsonb_array_length(v_series->'booked') = 0 then
    raise exception
      'the repeat could not book any date — your booking is unchanged';
  end if;

  return v_series;
end;
$$;

-- The ACL 0224 produced, restated because the drop took it with the old
-- function: `exec:authenticated,service_role`.
revoke execute on function
  public.convert_to_series(uuid, text, timestamptz, timestamptz, timestamptz)
  from public, anon;
grant execute on function
  public.convert_to_series(uuid, text, timestamptz, timestamptz, timestamptz)
  to authenticated, service_role;

-- The signature changed, so PostgREST must forget the old argument list
-- or the client's five-key call answers `function not found`.
notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(256);
