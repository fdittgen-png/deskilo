-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0441 (#2631, checkpoint 1) — a resource carries its own booking slot.
--
-- Booking granularity was one value per workspace (`booking_rules.granularity`),
-- so a meeting room could not be booked per hour while seats keep the
-- half-day window. `seats.slot_minutes` is the resource's own slot:
--
--   * null (every existing row)  -> the workspace value, nothing changes;
--   * 5 | 15 | 30 | 60           -> that minute grid;
--   * 1440                       -> the full working day.
--
-- `enforce_booking_rules` (the one chokepoint every creation path calls)
-- gains a five-argument form with a trailing `p_seat_id uuid` (the four-argument
-- form stays as a wrapper passing null, so no caller can become ambiguous).
-- With a seat whose slot is set, the slot REPLACES the workspace granularity for that booking; every
-- other rule (horizon, duration, opening hours, past, midnight) is untouched.
-- A caller that passes no seat, or a level booking, behaves exactly as before.
-- The seat-booking callers pass their seat: create_reservation, create_series,
-- admin_create_reservation_for, kiosk_act (seat branch), update_reservation.
-- The slot is read for a seat of the SAME workspace only.

alter table public.seats add column slot_minutes int
  check (slot_minutes is null or slot_minutes in (5, 15, 30, 60, 1440));

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  -- 1. the chokepoint: a five-argument form carrying the seat.
  select pg_get_functiondef('public.enforce_booking_rules(uuid,timestamptz,timestamptz,boolean)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$p_walk_up boolean DEFAULT false)$a$,
    $a$p_walk_up boolean, p_seat_id uuid)$a$);
  if v_def is null then raise exception '0441: enforce_booking_rules signature anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$gran := rules->>'granularity';$a$,
    $a$gran := rules->>'granularity';
  -- #2631: the resource's own slot replaces the workspace granularity.
  if p_seat_id is not null then
    select s.slot_minutes into slot from public.seats s
      where s.id = p_seat_id and s.workspace_id = p_workspace_id;
    if slot is not null then
      gran := case when slot = 1440 then 'full_day' else 'minutes_' || slot end;
    end if;
  end if;$a$);
  if v_def is null then raise exception '0441: enforce_booking_rules granularity anchor missing'; end if;
  execute v_def;
  revoke execute on function public.enforce_booking_rules(uuid, timestamptz, timestamptz, boolean, uuid)
    from public, anon, authenticated;
  -- the four-argument form stays (a caller without a seat, a level booking)
  -- and answers exactly as before: no seat, the workspace value.
  create or replace function public.enforce_booking_rules(
    p_workspace_id uuid, p_starts_at timestamptz, p_ends_at timestamptz,
    p_walk_up boolean default false
  ) returns void language plpgsql stable security definer set search_path = public as $fn$
  begin
    perform public.enforce_booking_rules(
      p_workspace_id, p_starts_at, p_ends_at, p_walk_up, null::uuid);
  end;
  $fn$;

  -- 2. the seat-booking callers pass their seat.
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname = 'create_reservation';
  v_def := pg_temp.anchor_replace(v_def,
    $a$enforce_booking_rules(p_workspace_id, v_starts, v_ends, p_check_in);$a$,
    $a$enforce_booking_rules(p_workspace_id, v_starts, v_ends, p_check_in, p_seat_id);$a$);
  if v_def is null then raise exception '0441: create_reservation anchor missing'; end if;
  execute v_def;

  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname = 'create_series';
  v_def := pg_temp.anchor_replace(v_def,
    $a$enforce_booking_rules(p_workspace_id, p_first_start, p_first_end);$a$,
    $a$enforce_booking_rules(p_workspace_id, p_first_start, p_first_end, false, p_seat_id);$a$);
  if v_def is null then raise exception '0441: create_series anchor missing'; end if;
  execute v_def;

  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname = 'admin_create_reservation_for';
  v_def := pg_temp.anchor_replace(v_def,
    $a$enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at);$a$,
    $a$enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at, false, p_seat_id);$a$);
  if v_def is null then raise exception '0441: admin_create_reservation_for anchor missing'; end if;
  execute v_def;

  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname = 'kiosk_act';
  v_def := pg_temp.anchor_replace(v_def,
    $a$p_workspace_id, v_starts, v_ends, p_action = 'check_in');
      if tstzrange(coalesce(v_seat.blocked_from$a$,
    $a$p_workspace_id, v_starts, v_ends, p_action = 'check_in', p_seat_id);
      if tstzrange(coalesce(v_seat.blocked_from$a$);
  if v_def is null then raise exception '0441: kiosk_act anchor missing'; end if;
  execute v_def;

  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname = 'update_reservation';
  v_def := pg_temp.anchor_replace(v_def,
    $a$v_res.workspace_id, p_starts_at, p_ends_at, true);$a$,
    $a$v_res.workspace_id, p_starts_at, p_ends_at, true, v_res.seat_id);$a$);
  if v_def is null then raise exception '0441: update_reservation walk-up anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$v_res.workspace_id, p_starts_at, p_ends_at);$a$,
    $a$v_res.workspace_id, p_starts_at, p_ends_at, false, v_res.seat_id);$a$);
  if v_def is null then raise exception '0441: update_reservation anchor missing'; end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(441);
