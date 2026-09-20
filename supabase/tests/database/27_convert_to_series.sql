-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1394 — converting a booking to a repeat must never leave the member
-- with less than they started with.
--
-- The client did it in two RPCs: `cancel_reservation` then
-- `create_series`. Each is transactional alone; the composition was not.
--
-- And the failure is the ORDINARY path, not a race. `create_series`
-- wraps every generated date in `begin … exception when others then
-- v_skipped := …`, so a blocked seat, a closure, a conflict or a quota
-- refusal becomes a skipped date rather than an error. When no date can
-- be booked it returns normally with `booked: []` — the client's
-- try/catch never fires, the success branch runs, and the original is
-- already cancelled.
--
-- So the assertion that matters most here is the REFUSAL one: after a
-- conversion that books nothing, the original must still be `reserved`.
-- The happy path passing proves the function works; that one proves it
-- is worth having.
begin;
select plan(12);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner  uuid := '00000000-0000-4000-8000-0000000000d1';
  u_other  uuid := '00000000-0000-4000-8000-0000000000d2';
  ws       uuid;
  m_owner  uuid;
  m_other  uuid;
  lvl uuid; off uuid; dsk uuid; seat uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'convert-owner@deskilo.test', '', now(), now(), now()),
         (u_other, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'convert-other@deskilo.test', '', now(), now(), now());

  -- Mon–Fri, half-day granularity: the canonical windows are 08:00–12:00,
  -- 12:00–17:00 and 08:00–17:00 in the workspace's own timezone.
  -- Every NOT NULL column without a default: name, country_code,
  -- currency_code, timezone, created_by.
  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, booking_rules)
  values ('Convert', 'FR', 'EUR', 'Europe/Paris', u_owner,
          jsonb_build_object(
            'granularity', 'half_day',
            'open_weekdays', jsonb_build_array(1,2,3,4,5),
            'max_series_days', 180,
            'advance_horizon_days', 365,
            'allow_past_bookings', false))
  returning id into ws;

  -- `members` has no display_name, and `status` defaults to 'active'
  -- (26_workspace_lexicon.sql is the working form).
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true) returning id into m_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_other, false, false) returning id into m_other;

  -- The plan objects carry geometry, and every coordinate is NOT NULL
  -- without a default — offices and desks need x/y/w/h, seats x/y.
  insert into public.levels (workspace_id, name)
    values (ws, 'Ground') returning id into lvl;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
    values (ws, lvl, 'Open space', 0, 0, 10, 10) returning id into off;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
    values (ws, off, 1, 1, 4, 2) returning id into dsk;
  insert into public.seats (workspace_id, desk_id, x, y)
    values (ws, dsk, 1, 1) returning id into seat;

  perform set_config('deskilo.t.ws', ws::text, false);
  perform set_config('deskilo.t.owner', m_owner::text, false);
  perform set_config('deskilo.t.other', m_other::text, false);
  perform set_config('deskilo.t.u_owner', u_owner::text, false);
  perform set_config('deskilo.t.u_other', u_other::text, false);
  perform set_config('deskilo.t.seat', seat::text, false);
end
$seed$;
select pg_temp.seed();

-- The canonical MORNING window of the same day — the other half-day the
-- member may pick. #1562: `convert_to_series` builds the repeat from
-- THIS window when it is given one.
create or replace function pg_temp.morning(offset_days int default 0)
returns timestamptz[] language sql stable as $morning$
  select array[
    ((date_trunc('week', (now() at time zone 'Europe/Paris')::date
      + interval '28 days')::date + offset_days)::timestamp
      + interval '8 hours') at time zone 'Europe/Paris',
    ((date_trunc('week', (now() at time zone 'Europe/Paris')::date
      + interval '28 days')::date + offset_days)::timestamp
      + interval '12 hours') at time zone 'Europe/Paris'
  ];
$morning$;

-- A Monday afternoon well inside the horizon, in the workspace's clock.
create or replace function pg_temp.slot(offset_days int default 0)
returns timestamptz[] language sql stable as $slot$
  select array[
    ((date_trunc('week', (now() at time zone 'Europe/Paris')::date
      + interval '28 days')::date + offset_days)::timestamp
      + interval '12 hours') at time zone 'Europe/Paris',
    ((date_trunc('week', (now() at time zone 'Europe/Paris')::date
      + interval '28 days')::date + offset_days)::timestamp
      + interval '17 hours') at time zone 'Europe/Paris'
  ];
$slot$;

create or replace function pg_temp.book(p_member uuid, p_offset int default 0)
returns uuid language plpgsql as $book$
declare v uuid; s timestamptz[];
begin
  s := pg_temp.slot(p_offset);
  insert into public.reservations
    (workspace_id, seat_id, member_id, starts_at, ends_at, status)
  values (current_setting('deskilo.t.ws')::uuid,
          current_setting('deskilo.t.seat')::uuid,
          p_member, s[1], s[2], 'reserved')
  returning id into v;
  return v;
end
$book$;

-- No `set local role authenticated` here, deliberately. `pg_temp.book`
-- inserts into `reservations` directly, and under that role RLS refuses
-- the row ("new row violates row-level security policy"). The four
-- neighbouring files (23-26) do the same thing: set the claims, stay
-- `postgres` for the seeding, and let the SECURITY DEFINER functions
-- read `auth.uid()` from the claims — which is all `convert_to_series`
-- needs to resolve its caller.

-- ---------------------------------------------------------------- 1–3
-- The refusal: every date impossible, so nothing is booked.
do $be_owner$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.t.u_owner'),
                      'role', 'authenticated')::text, false);
end;
$be_owner$;

select lives_ok(
  $$select pg_temp.book(current_setting('deskilo.t.owner')::uuid)$$,
  'the member holds one ordinary booking to convert');

-- Block the seat across every date the repeat would want.
update public.seats set blocked_from = now(), blocked_to = now() + interval '400 days'
  where id = current_setting('deskilo.t.seat')::uuid;

select throws_ok(
  format($$select public.convert_to_series(%L, 'weekly', %L)$$,
    (select id from public.reservations
      where member_id = current_setting('deskilo.t.owner')::uuid
      order by created_at desc limit 1),
    (pg_temp.slot())[1] + interval '14 days'),
  'the repeat could not book any date — your booking is unchanged',
  'a conversion that books nothing raises, naming what happened');

select is(
  (select status from public.reservations
    where member_id = current_setting('deskilo.t.owner')::uuid
    order by created_at desc limit 1),
  'reserved',
  'AND the original survives: the raise rolled the cancel back with it. '
  'This is the assertion the two-RPC client could never make.');

-- ---------------------------------------------------------------- 4–6
-- The happy path, once the seat is free again.
update public.seats set blocked_from = null, blocked_to = null
  where id = current_setting('deskilo.t.seat')::uuid;

select lives_ok(
  format($$select public.convert_to_series(%L, 'weekly', %L)$$,
    (select id from public.reservations
      where member_id = current_setting('deskilo.t.owner')::uuid
      order by created_at desc limit 1),
    (pg_temp.slot())[1] + interval '14 days'),
  'a conversion whose dates are free succeeds');

select is(
  (select count(*)::int from public.reservations
    where member_id = current_setting('deskilo.t.owner')::uuid
      and series_id is not null and status = 'reserved'),
  3,
  'three weekly occurrences exist');

select is(
  (select count(*)::int from public.reservations
    where member_id = current_setting('deskilo.t.owner')::uuid
      and series_id is null and status = 'cancelled'),
  1,
  'and the original is cancelled — exactly once, by the same transaction');

-- ---------------------------------------------------------------- 7–9
-- The gate, both directions.
do $be_other$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.t.u_other'),
                      'role', 'authenticated')::text, false);
end;
$be_other$;

select throws_ok(
  format($$select public.convert_to_series(%L, 'weekly', %L)$$,
    (select id from public.reservations
      where member_id = current_setting('deskilo.t.owner')::uuid
        and series_id is not null limit 1),
    (pg_temp.slot())[1] + interval '14 days'),
  'not your reservation',
  'a member without manageReservations cannot convert somebody else''s '
  'booking');

-- A booking of their own, already in a series, is refused for the right
-- reason — the gate passed, the state check did not.
select lives_ok(
  $$select pg_temp.book(current_setting('deskilo.t.other')::uuid, 1)$$,
  'the other member holds a booking of their own');

select throws_ok(
  format($$select public.convert_to_series(%L, 'monthly', %L)$$,
    (select id from public.reservations
      where member_id = current_setting('deskilo.t.other')::uuid
      order by created_at desc limit 1),
    (pg_temp.slot(1))[1] + interval '14 days'),
  'unknown pattern',
  'their OWN booking passes the caller gate and is then judged on its '
  'merits — create_series rejects the pattern, and the raise leaves the '
  'booking untouched');

-- --------------------------------------------------------------- 10–12
-- #1562 — the window the member CHOSE, not the one that is stored.
--
-- The detail sheet collects a new window and then a recurrence, in one
-- gesture. Before 0256 the second half threw the first away: the
-- function had nowhere to put a window and built the repeat from
-- `v_res.starts_at` / `v_res.ends_at`. Every case above converts a
-- booking without moving it, which is exactly why the defect was
-- invisible here.
do $be_owner_again$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.t.u_owner'),
                      'role', 'authenticated')::text, false);
end;
$be_owner_again$;

-- A fresh afternoon booking on the Wednesday, to be repeated in the
-- MORNING instead.
select lives_ok(
  $$select pg_temp.book(current_setting('deskilo.t.owner')::uuid, 2)$$,
  'the member holds an afternoon booking on another day');

select lives_ok(
  format($$select public.convert_to_series(%L, 'weekly', %L, %L, %L)$$,
    (select id from public.reservations
      where member_id = current_setting('deskilo.t.owner')::uuid
        and series_id is null and status = 'reserved'
      order by created_at desc limit 1),
    (pg_temp.morning(2))[1] + interval '14 days',
    (pg_temp.morning(2))[1],
    (pg_temp.morning(2))[2]),
  'a conversion may carry the window the member chose');

-- The first occurrence is the requested instant itself, so this compares
-- absolute timestamps and no daylight-saving step can blur it.
select is(
  (select count(*)::int from public.reservations
    where member_id = current_setting('deskilo.t.owner')::uuid
      and series_id is not null and status = 'reserved'
      and starts_at = (pg_temp.morning(2))[1]
      and ends_at = (pg_temp.morning(2))[2]),
  1,
  'the repeat begins at the CHOSEN morning window. Before 0256 it began '
  'at the stored afternoon one and the member was never told.');

select * from finish();
rollback;
