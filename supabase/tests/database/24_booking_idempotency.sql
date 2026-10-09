-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1241 — a booking can be replayed, and replaying it books once.
--
-- A booking made with no network is lost: the SocketException
-- propagates, the member sees a sentence (a better one since #1240) and
-- the booking is gone. The issue asks for three things in order — say it
-- plainly, retry, queue the one write that matters — and queueing is
-- only safe if a replay cannot book twice.
--
-- The guard has to be on the SERVER. A client that has just lost the
-- network is exactly the client whose local state you cannot trust, so
-- "I already sent this" is not something it gets to assert.
begin;
select plan(10);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_mine uuid := '00000000-0000-4000-8000-0000000000c1';
  u_other uuid := '00000000-0000-4000-8000-0000000000c2';
  ws uuid; m uuid; lvl uuid; office uuid; desk uuid; seat uuid; tz text;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_mine, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'queue-mine@deskilo.test', '', now(), now(), now()),
         (u_other, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'queue-other@deskilo.test', '', now(), now(), now());
  -- A zone where "now" still has an hour of its day left: after 22:00 in
  -- Paris the explicit check-in below would be shorter than the minimum
  -- booking (30 minutes) and refused, so late runs book in Los Angeles,
  -- where it is mid-afternoon.
  tz := case when extract(hour from now() at time zone 'Europe/Paris') >= 22
             then 'America/Los_Angeles' else 'Europe/Paris' end;
  perform set_config('deskilo.queue.tz', tz, false);
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Queue', 'FR', 'EUR', tz, u_mine) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_mine, true, true) returning id into m;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_other, false, false);
  insert into public.levels (workspace_id, name) values (ws, 'Ground') returning id into lvl;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, lvl, 'Open space', 0, 0, 10, 10) returning id into office;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws, office, 1, 1, 4, 2) returning id into desk;
  insert into public.seats (workspace_id, desk_id, x, y)
  values (ws, desk, 1, 1) returning id into seat;

  -- The bookings below are for TOMORROW through the real RPC, and the
  -- closed-day gate (#186) refuses a Saturday: open every weekday, as
  -- 35_zero_subscription and 37_credit_consumption do, so the file does
  -- not turn red on a Friday.
  update public.workspaces
     set booking_rules = coalesce(booking_rules, '{}'::jsonb)
       || '{"open_weekdays": [1, 2, 3, 4, 5, 6, 7]}'::jsonb
   where id = ws;

  perform set_config('deskilo.queue.ws', ws::text, false);
  perform set_config('deskilo.queue.seat', seat::text, false);
  perform set_config('deskilo.queue.u_mine', u_mine::text, false);
  perform set_config('deskilo.queue.u_other', u_other::text, false);
  perform set_config('deskilo.queue.key', '11111111-2222-4333-8444-555555555555', false);
  perform set_config('deskilo.queue.from',
    (date_trunc('day', now()) + interval '1 day 9 hours')::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u_mine::text, 'role', 'authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

create or replace function pg_temp.book(p_key uuid) returns uuid
language sql as $$
  select public.create_reservation_once(
    p_key,
    current_setting('deskilo.queue.ws')::uuid,
    current_setting('deskilo.queue.seat')::uuid,
    null, null, null,
    current_setting('deskilo.queue.from')::timestamptz,
    current_setting('deskilo.queue.from')::timestamptz + interval '4 hours',
    false);
$$;

-- ---------------------------------------------------------- the replay
do $first$
begin
  perform set_config('deskilo.queue.first',
    pg_temp.book(current_setting('deskilo.queue.key')::uuid)::text, false);
end;
$first$;

select is(
  pg_temp.book(current_setting('deskilo.queue.key')::uuid),
  current_setting('deskilo.queue.first')::uuid,
  'replaying a booking returns the reservation the first call made');

select is(
  (select count(*) from public.reservations
    where workspace_id = current_setting('deskilo.queue.ws')::uuid)::int,
  1,
  'and books it exactly once — which is what makes an offline queue safe');

-- #2016 — what the confirmed choice PERSISTS. A plain reservation (the
-- sheet's Reserve, check-in false) is reserved and not checked in; an
-- explicit "check in now" (true) starts checked in. The client sends the
-- final mode; the row must say the same.
select is(
  (select status || '|' || coalesce(checked_in_at::text, 'none') from public.reservations
    where id = current_setting('deskilo.queue.first')::uuid),
  'reserved|none',
  'a plain reservation persists as reserved, never checked in');

select lives_ok(
  $$ select public.create_reservation_once(
       gen_random_uuid(),
       current_setting('deskilo.queue.ws')::uuid,
       current_setting('deskilo.queue.seat')::uuid,
       null, null, null,
       now(),
       -- inside the workspace's day, so the file is green at any hour
       least(now() + interval '1 hour',
             (date_trunc('day', now() at time zone current_setting('deskilo.queue.tz'))
               + interval '1 day' - interval '1 minute')
               at time zone current_setting('deskilo.queue.tz')),
       true) $$,
  'an explicit check-in now is accepted');

select is(
  (select count(*)::int from public.reservations
    where workspace_id = current_setting('deskilo.queue.ws')::uuid
      and status = 'checked_in' and checked_in_at is not null
      and starts_at <= now()),
  1,
  'and persists as checked in, started now');

-- ------------------------------------------------------------ the guards
select throws_ok(
  $$ select public.create_reservation_once(null, null, null, null, null,
       null, null, null, false) $$,
  'a replayable booking needs a request id',
  'the replayable path refuses to run without a key');

-- #1862 — the ordinary path, really called by the member (not a no-op):
-- a later, non-overlapping interval through create_reservation as the
-- authenticated role, then the row it persisted.
set local role authenticated;
select lives_ok(
  $$ select public.create_reservation(
       current_setting('deskilo.queue.ws')::uuid,
       current_setting('deskilo.queue.seat')::uuid,
       null,
       current_setting('deskilo.queue.from')::timestamptz + interval '5 hours',
       current_setting('deskilo.queue.from')::timestamptz + interval '7 hours') $$,
  'ordinary create_reservation still books a non-overlapping interval');
reset role;
select is(
  (select count(*)::int from public.reservations r
     join public.members m on m.id = r.member_id
    where r.workspace_id = current_setting('deskilo.queue.ws')::uuid
      and r.seat_id = current_setting('deskilo.queue.seat')::uuid
      and m.user_id = current_setting('deskilo.queue.u_mine')::uuid
      and r.starts_at = current_setting('deskilo.queue.from')::timestamptz + interval '5 hours'
      and r.ends_at = current_setting('deskilo.queue.from')::timestamptz + interval '7 hours'),
  1,
  'and persists it for the caller, on that seat and those hours');

-- A request id is its member's own: replaying somebody else's would hand
-- them a reservation id they may have no policy to read.
do $be_other$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.queue.u_other'),
                      'role', 'authenticated')::text, false);
end;
$be_other$;

select throws_ok(
  format($$ select pg_temp.book(%L) $$, current_setting('deskilo.queue.key')),
  'that request id belongs to another member',
  'another member cannot replay a key that is not theirs');

-- And the key is not a licence: a DIFFERENT key over the same hours is
-- still a double booking, and the exclusion constraint of #1248 refuses
-- it. Idempotency and the booking rules are separate guards.
select throws_ok(
  $$ select public.create_reservation_once(
       gen_random_uuid(),
       current_setting('deskilo.queue.ws')::uuid,
       current_setting('deskilo.queue.seat')::uuid,
       null, null, null,
       current_setting('deskilo.queue.from')::timestamptz + interval '1 hour',
       current_setting('deskilo.queue.from')::timestamptz + interval '2 hours',
       false) $$,
  '23P01',
  null,
  'a new key over the same hours is still refused — a replay key is not '
  'a licence to double-book');

select * from finish();
rollback;
