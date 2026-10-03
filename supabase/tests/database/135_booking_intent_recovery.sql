-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0352 (#1855 A) — a booking's original intent survives a lost answer.
-- A replay of the same request id with the same payload returns the one
-- booking; the same id with another payload is refused by name; a claim
-- from before 0352 (no digest) is never certified either way. The
-- member who made a request reads its outcome; another member, an
-- unknown id and a non-member learn nothing.
begin;
select plan(16);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000001855';
  v uuid := '00000000-0000-4000-8000-000000001856';
  s uuid := '00000000-0000-4000-8000-000000001857';
  ws uuid; m uuid; rv uuid; lvl uuid; office uuid; desk uuid; seat uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'intent-1855@deskilo.test', '', now(), now(), now()),
         (v, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rival-1855@deskilo.test', '', now(), now(), now()),
         (s, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'stranger-1855@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Intent', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  update public.workspaces
     set booking_rules = coalesce(booking_rules, '{}'::jsonb)
       || '{"open_weekdays": [1, 2, 3, 4, 5, 6, 7]}'::jsonb
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;
  insert into public.members (workspace_id, user_id) values (ws, v) returning id into rv;
  insert into public.levels (workspace_id, name) values (ws, 'Ground') returning id into lvl;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, lvl, 'Room', 0, 0, 10, 10) returning id into office;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws, office, 1, 1, 4, 2) returning id into desk;
  insert into public.seats (workspace_id, desk_id, x, y) values (ws, desk, 1, 1) returning id into seat;
  perform set_config('t.ws', ws::text, false);
  perform set_config('t.seat', seat::text, false);
  perform set_config('t.m', m::text, false);
  perform set_config('t.u', u::text, false);
  perform set_config('t.v', v::text, false);
  perform set_config('t.s', s::text, false);
  perform set_config('t.from', (date_trunc('day', now()) + interval '1 day 9 hours')::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.as(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.' || p), 'role', 'authenticated')::text, false);
$$;
create or replace function pg_temp.once(p_id text, p_hours int) returns uuid language sql as $$
  select public.create_reservation_once(p_id::uuid, current_setting('t.ws')::uuid,
    current_setting('t.seat')::uuid, null, null, null,
    current_setting('t.from')::timestamptz,
    current_setting('t.from')::timestamptz + make_interval(hours => p_hours), false);
$$;
create or replace function pg_temp.outcome(p_id text) returns jsonb language sql as $$
  select public.reservation_request_outcome(current_setting('t.ws')::uuid, p_id::uuid);
$$;

-- ── the same request, the same booking ───────────────────────────────
select pg_temp.as('u');
select set_config('t.r1', pg_temp.once('00000000-0000-4000-8000-00000000a001', 4)::text, false);
select is((select count(*)::int from public.reservations where workspace_id = current_setting('t.ws')::uuid), 1,
  'the first call books once');
select is(pg_temp.once('00000000-0000-4000-8000-00000000a001', 4)::text, current_setting('t.r1'),
  'the same id with the same payload returns the original booking');
select is((select count(*)::int from public.reservations where workspace_id = current_setting('t.ws')::uuid), 1,
  'and books nothing new');
select isnt((select payload_digest from public.reservation_requests
              where client_request_id = '00000000-0000-4000-8000-00000000a001'), null,
  'the claim carries the payload digest');

-- ── the same id, another payload: refused, nothing certified ─────────
select throws_ok($$select pg_temp.once('00000000-0000-4000-8000-00000000a001', 5)$$,
  'P0001', 'that request id was used for a different booking',
  'a changed window under the same id is refused by name');
select is((select count(*)::int from public.reservations where workspace_id = current_setting('t.ws')::uuid), 1,
  'and still one booking');

-- ── a claim from before 0352: never certified ────────────────────────
insert into public.reservation_requests (workspace_id, client_request_id, member_id, reservation_id)
values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-00000000a002',
        current_setting('t.m')::uuid, current_setting('t.r1')::uuid);
select throws_ok($$select pg_temp.once('00000000-0000-4000-8000-00000000a002', 4)$$,
  'P0001', 'that request id predates payload checks: look the booking up instead of replaying it',
  'a legacy claim is not certified as any payload');

-- ── the own-result lookup ────────────────────────────────────────────
select is(pg_temp.outcome('00000000-0000-4000-8000-00000000a001')->>'status', 'committed',
  'the member reads the committed outcome');
select is(pg_temp.outcome('00000000-0000-4000-8000-00000000a001')->>'reservation_id', current_setting('t.r1'),
  'with the reservation it made');
select is(pg_temp.outcome('00000000-0000-4000-8000-00000000a001')->>'reservation_status', 'reserved',
  'and its current state');
select is(pg_temp.outcome('00000000-0000-4000-8000-00000000a002')->>'status', 'committed',
  'a legacy claim is still readable');
select is(pg_temp.outcome('00000000-0000-4000-8000-00000000a0ff')->>'status', 'absent',
  'an id never claimed reads absent');
select is((pg_temp.outcome('00000000-0000-4000-8000-00000000a0ff')->>'retention_days')::int, 90,
  'with the retention the caller judges age against');

-- ── other people learn nothing ───────────────────────────────────────
select pg_temp.as('v');
select is(pg_temp.outcome('00000000-0000-4000-8000-00000000a001')->>'status', 'absent',
  'another member reads exactly what an unknown id reads');
select throws_ok($$select pg_temp.once('00000000-0000-4000-8000-00000000a001', 4)$$,
  'P0001', 'that request id belongs to another member',
  'and cannot replay it');
select pg_temp.as('s');
select throws_ok($$select pg_temp.outcome('00000000-0000-4000-8000-00000000a001')$$,
  'P0001', 'not an active member', 'a non-member is refused the lookup');

select * from finish();
rollback;
