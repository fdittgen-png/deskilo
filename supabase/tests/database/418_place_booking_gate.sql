-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3862 (0758) -- with place booking off, the server refuses what creates or
-- extends a use of a place, with 55000, the code of a switched-off
-- functionality: a booking, a replayable booking (the assistant's), a series,
-- an administrator's booking for a member, a kiosk's walk-up reservation, a
-- change that ends a booking later, and a carnet sale. What a person does with
-- a booking that exists stays open: shortening and cancelling it, checking in
-- and out at the kiosk. With place booking on, each gated path works.
-- Rolled back.
begin;
select plan(18);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000003862' || p)::uuid
$$;
create function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.pb.ws')::uuid
$$;
create function pg_temp.seat() returns uuid language sql as $$
  select current_setting('deskilo.pb.seat')::uuid
$$;
create function pg_temp.slot_from(n int) returns timestamptz language sql as $$
  select date_trunc('day', now() + interval '3 days') + make_interval(hours => n)
$$;
create function pg_temp.slot_to(n int) returns timestamptz language sql as $$
  select date_trunc('day', now() + interval '3 days') + make_interval(hours => n + 1)
$$;
create function pg_temp.member(p text) returns uuid language sql as $$
  select id from public.members where workspace_id = pg_temp.ws() and user_id = pg_temp.u(p)
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(s), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       s || '@place-booking-gate.test', '', now(), now(), now()
  from unnest(array['a1', 'a2', 'a4']) s;
-- a1 owner, a2 member, a4 kiosk.
select pg_temp.act_as(pg_temp.u('a1'));
select set_config('deskilo.pb.ws', public.create_workspace(
  'Place booking gate', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set booking_rules = booking_rules ||
        '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"flexible","work_start_minutes":0,"work_end_minutes":1440,"min_duration_minutes":1}',
       feature_flags = feature_flags || '{"kioskMode":true,"carnets":true,"invoicing":true,"moneyTab":true}',
       -- Members book (#3269: an empty matrix gives them no right to).
       role_permissions = role_permissions || '{"member": ["makeReservations"]}'::jsonb
 where id = pg_temp.ws();
insert into public.members (workspace_id, user_id, status, is_admin, is_kiosk) values
  (pg_temp.ws(), pg_temp.u('a2'), 'active', false, false),
  (pg_temp.ws(), pg_temp.u('a4'), 'active', false, true);
create function pg_temp.add_resource() returns uuid language plpgsql as $f$
declare l uuid; o uuid; d uuid; st uuid;
begin
  insert into public.levels (workspace_id, name) values (pg_temp.ws(), 'Ground') returning id into l;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
    values (pg_temp.ws(), l, 'Open space', 0, 0, 10, 10) returning id into o;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
    values (pg_temp.ws(), o, 1, 1, 4, 2) returning id into d;
  insert into public.seats (workspace_id, desk_id, x, y)
    values (pg_temp.ws(), d, 1, 1) returning id into st;
  return st;
end $f$;
select set_config('deskilo.pb.seat', pg_temp.add_resource()::text, true);
insert into public.member_badges (workspace_id, member_id, token_hash)
select pg_temp.ws(), pg_temp.member('a2'), public.badge_token_hash('PB-A2');

insert into public.credit_products (workspace_id, name, half_days, price_cents)
values (pg_temp.ws(), 'Carnet', 10, 5000);

-- Bookings made while place booking is on: one to change and cancel, and one
-- of the member's that starts now, to check in and out at the kiosk.
select pg_temp.act_as(pg_temp.u('a1'));
select set_config('deskilo.pb.res', public.create_reservation(pg_temp.ws(), pg_temp.seat(), null,
  pg_temp.slot_from(9), pg_temp.slot_to(9))::text, true);
select set_config('deskilo.pb.now', public.admin_create_reservation_for(pg_temp.ws(), pg_temp.member('a2'),
  pg_temp.seat(), date_trunc('minute', now()) + interval '1 minute', date_trunc('minute', now()) + interval '61 minutes')::text, true);
reset role;

update public.workspaces set feature_flags = feature_flags || '{"placeBooking":false}' where id = pg_temp.ws();

select pg_temp.act_as(pg_temp.u('a1'));
select throws_ok($$ select public.create_reservation(pg_temp.ws(), pg_temp.seat(), null,
  pg_temp.slot_from(11), pg_temp.slot_to(11)) $$, '55000', 'place booking is off in this workspace',
  'with place booking off, no booking is made');
select throws_ok($$ select public.create_reservation_once(gen_random_uuid(), pg_temp.ws(), pg_temp.seat(), null, null, null,
  pg_temp.slot_from(12), pg_temp.slot_to(12), false) $$, '55000', 'place booking is off in this workspace',
  'with place booking off, no replayable booking is made (the assistant''s path)');
select throws_ok($$ select public.create_series(pg_temp.ws(), pg_temp.seat(), pg_temp.slot_from(13), pg_temp.slot_to(13),
  'daily', pg_temp.slot_from(13) + interval '2 days', null, null, null) $$, '55000', 'place booking is off in this workspace',
  'with place booking off, no series is made');
select throws_ok(format($$ select public.admin_create_reservation_for(pg_temp.ws(), %L, pg_temp.seat(),
  pg_temp.slot_from(14), pg_temp.slot_to(14)) $$, pg_temp.member('a2')), '55000', 'place booking is off in this workspace',
  'with place booking off, an administrator books for nobody');
select throws_ok(format($$ select public.sell_credit(pg_temp.ws(), %L, gen_random_uuid()) $$, pg_temp.member('a2')),
  '55000', 'place booking is off in this workspace',
  'with place booking off, no carnet is sold');
select throws_ok(format($$ select public.update_reservation(%L, pg_temp.slot_from(9), pg_temp.slot_to(9) + interval '1 hour') $$,
    current_setting('deskilo.pb.res')), '55000', 'place booking is off in this workspace',
  'with place booking off, a booking does not end later');
select lives_ok(format($$ select public.update_reservation(%L, pg_temp.slot_from(9), pg_temp.slot_to(9) - interval '30 minutes') $$,
    current_setting('deskilo.pb.res')),
  'a booking can still be shortened');
select lives_ok(format($$ select public.cancel_reservation(%L) $$, current_setting('deskilo.pb.res')),
  'a booking made before can still be cancelled');
reset role;

select pg_temp.act_as(pg_temp.u('a4'));
select throws_ok($$ select public.kiosk_act(pg_temp.ws(), 'PB-A2', 'reserve', pg_temp.seat(),
  pg_temp.slot_from(15), pg_temp.slot_to(15)) $$, '55000', 'place booking is off in this workspace',
  'with place booking off, a kiosk reserves nothing');
select lives_ok($$ select public.kiosk_act(pg_temp.ws(), 'PB-A2', 'check_in', pg_temp.seat(),
  date_trunc('minute', now()) + interval '1 minute', date_trunc('minute', now()) + interval '61 minutes') $$,
  'the kiosk checks in to a booking that exists');
select lives_ok($$ select public.kiosk_act(pg_temp.ws(), 'PB-A2', 'check_out') $$,
  'and checks out of it');
reset role;

update public.workspaces set feature_flags = feature_flags || '{"placeBooking":true}' where id = pg_temp.ws();
select pg_temp.act_as(pg_temp.u('a1'));
select isnt(public.create_reservation(pg_temp.ws(), pg_temp.seat(), null,
  pg_temp.slot_from(16), pg_temp.slot_to(16))::text, null::text,
  'with place booking on, a booking is made');
select lives_ok($$ select public.create_reservation_once(gen_random_uuid(), pg_temp.ws(), pg_temp.seat(), null, null, null,
  pg_temp.slot_from(17), pg_temp.slot_to(17), false) $$, 'and a replayable booking');
select lives_ok($$ select public.create_series(pg_temp.ws(), pg_temp.seat(), pg_temp.slot_from(18), pg_temp.slot_to(18),
  'daily', pg_temp.slot_from(18) + interval '2 days', null, null, null) $$, 'and a series');
select lives_ok(format($$ select public.admin_create_reservation_for(pg_temp.ws(), %L, pg_temp.seat(),
  pg_temp.slot_from(19), pg_temp.slot_to(19)) $$, pg_temp.member('a2')), 'and an administrator''s booking for a member');
select lives_ok(format($$ select public.sell_credit(pg_temp.ws(), %L,
  (select id from public.credit_products where workspace_id = pg_temp.ws() limit 1)) $$, pg_temp.member('a2')),
  'and a carnet sale');
reset role;
select pg_temp.act_as(pg_temp.u('a4'));
select lives_ok($$ select public.kiosk_act(pg_temp.ws(), 'PB-A2', 'reserve', pg_temp.seat(),
  pg_temp.slot_from(20), pg_temp.slot_to(20)) $$, 'and a kiosk''s walk-up reservation');
reset role;
select is((select status from public.reservations where id = current_setting('deskilo.pb.res')::uuid), 'cancelled',
  'the cancelled booking is cancelled');

select * from finish();
rollback;
