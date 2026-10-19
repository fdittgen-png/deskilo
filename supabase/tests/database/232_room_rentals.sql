-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2568 / 0494-0496: a room the space rents. The window (last day inclusive),
-- the audience (plan or member), who sees the room, what a member is shown,
-- and the refusal wording of each cause. Real roles; every refusal is followed
-- by a readback. Hand-written expectations: window 2027-03-01 .. 2027-08-31.
begin;
select plan(37);
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.as_err(p_user uuid, p_sql text) returns text
language plpgsql as $$
begin
  perform pg_temp.act_as(p_user);
  execute p_sql;
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$$;
create function pg_temp.as_json(p_user uuid, p_sql text) returns jsonb
language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm);
end;
$$;
create function pg_temp.owner_err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return '';
exception when others then
  return sqlerrm;
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002568' || lpad(n::text, 4, '0'))::uuid;
$$;

create function pg_temp.book(p_user_member uuid, p_where text, p_id uuid, p_from timestamptz, p_to timestamptz) returns text
language plpgsql as $$
begin
  execute format('insert into public.reservations (workspace_id, member_id, %I, starts_at, ends_at) values (%L, %L, %L, %L, %L)',
    p_where, current_setting('t.a'), p_user_member, p_id, p_from, p_to);
  return '';
exception when others then
  return sqlerrm;
end;
$$;
create function pg_temp.paris(p text) returns timestamptz language sql as $$ select (p::timestamp) at time zone 'Europe/Paris'; $$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@rentedrooms.test', '', now(), now(), now()
  from generate_series(1, 5) i;
-- 1 owner of A, 2 Ada (plan Gold), 3 Bruno (no plan), 4 Carol (named in the audience).

select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Rooms A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.plans (id, workspace_id, name) values
  ('00000000-0000-4000-8000-0000256800d1', current_setting('t.a')::uuid, 'Gold');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at, customer_capacity, plan_id) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 1, '2026-01-01', 'consumer', '00000000-0000-4000-8000-0000256800d1'),
 (current_setting('t.a')::uuid, pg_temp.u(3), false, false, 'active', 1, '2026-01-01', 'consumer', null),
 (current_setting('t.a')::uuid, pg_temp.u(4), false, false, 'active', 1, '2026-01-01', 'consumer', null);
insert into public.suppliers (id, workspace_id, supplier_number, name) values
 ('00000000-0000-4000-8000-0000256800a1', current_setting('t.a')::uuid, '1', 'Landlord SA');
insert into public.sites (id, workspace_id, name, country_code) values
 ('00000000-0000-4000-8000-0000256800e1', current_setting('t.a')::uuid, 'Berlin annex', 'DE');
insert into public.levels (id, workspace_id, name) values
 ('00000000-0000-4000-8000-0000256800b1', current_setting('t.a')::uuid, 'Own floor'),
 ('00000000-0000-4000-8000-0000256800b2', current_setting('t.a')::uuid, 'Rented floor'),
 ('00000000-0000-4000-8000-0000256800b3', current_setting('t.a')::uuid, 'Berlin floor');
update public.levels set site_id = '00000000-0000-4000-8000-0000256800e1' where id = '00000000-0000-4000-8000-0000256800b3';
insert into public.offices (id, workspace_id, level_id, name, bookable_as_whole, x, y, w, h) values
 ('00000000-0000-4000-8000-0000256800c1', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000256800b1', 'Own room', true, 0, 0, 10, 10),
 ('00000000-0000-4000-8000-0000256800c2', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000256800b2', 'Rented room', true, 0, 0, 10, 10),
 ('00000000-0000-4000-8000-0000256800c3', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000256800b3', 'Berlin room', true, 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, x, y, w, h) values
 ('00000000-0000-4000-8000-0000256800f2', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000256800c2', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, x, y) values
 ('00000000-0000-4000-8000-0000256800f3', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000256800f2', 1, 1);

-- the flag is off: nothing to manage
select alike(pg_temp.as_err(pg_temp.u(1), format('select public.set_level_kind_v1(%L, %L, ''external'')', current_setting('t.a'), '00000000-0000-4000-8000-0000256800b2')),
  '%switched off%', '1 the commands refuse while the flag is off');
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"levelBooking": true, "externalRooms": true}'
 where id = current_setting('t.a')::uuid;
select alike(pg_temp.as_err(pg_temp.u(3), format('select public.set_level_kind_v1(%L, %L, ''external'')', current_setting('t.a'), '00000000-0000-4000-8000-0000256800b2')),
  '%may not manage%', '2 a plain member cannot make a level external');
select is(pg_temp.as_json(pg_temp.u(1), format('select public.set_level_kind_v1(%L, %L, ''external'')', current_setting('t.a'), '00000000-0000-4000-8000-0000256800b2'))->>'kind',
  'external', '3 the owner marks the level external');
select is((select kind from public.levels where id = '00000000-0000-4000-8000-0000256800b2'), 'external', '3b readback: the level is external');

create function pg_temp.save(p_status text, p_rev int, p_office text default '00000000-0000-4000-8000-0000256800c2') returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(pg_temp.u(1), format(
    'select public.save_room_rental_v1(%L, %L, %L, ''2027-03-01'', ''2027-08-31'', ''fixed_per_period'', 40000, ''month'', %L, null, %s)',
    current_setting('t.a'), p_office, '00000000-0000-4000-8000-0000256800a1', p_status, p_rev));
end;
$$;
select is(pg_temp.save('draft', 0)->>'status', 'draft', '4 the owner records the rental as a draft');
select set_config('t.r', (select id::text from public.room_rentals limit 1), true);
select is(pg_temp.book((select id from public.members where user_id = pg_temp.u(2) and workspace_id = current_setting('t.a')::uuid),
  'office_id', '00000000-0000-4000-8000-0000256800c2', pg_temp.paris('2027-04-12 09:00'), pg_temp.paris('2027-04-12 13:00')),
  'that room is not rented', '5 a draft rental books nothing');

select is(pg_temp.as_json(pg_temp.u(1), format('select public.set_room_rental_audience_v1(%L, %L, %L)', current_setting('t.a'), current_setting('t.r'),
  jsonb_build_array(jsonb_build_object('plan_id', '00000000-0000-4000-8000-0000256800d1'),
                    jsonb_build_object('member_id', (select id from public.members where user_id = pg_temp.u(4) and workspace_id = current_setting('t.a')::uuid)))::text))->>'revision',
  '2', '6 the audience is a plan and a named member');
select is(pg_temp.save('active', 2)->>'status', 'active', '7 the rental goes active');
select is(pg_temp.as_json(pg_temp.u(1), format('select public.set_room_rental_fees_v1(%L, %L, %L)', current_setting('t.a'), current_setting('t.r'),
  jsonb_build_array(jsonb_build_object('unit', 'half_day', 'fee_cents', 1500),
                    jsonb_build_object('unit', 'half_day', 'fee_cents', 1000, 'member_id',
                      (select id from public.members where user_id = pg_temp.u(4) and workspace_id = current_setting('t.a')::uuid)))::text))->>'revision',
  '4', '8 two fees: the general one and one for Carol');

create function pg_temp.ada() returns uuid language sql as $$ select id from public.members where user_id = pg_temp.u(2) and workspace_id = current_setting('t.a')::uuid $$;
create function pg_temp.bruno() returns uuid language sql as $$ select id from public.members where user_id = pg_temp.u(3) and workspace_id = current_setting('t.a')::uuid $$;

select is(pg_temp.book(pg_temp.ada(), 'office_id', '00000000-0000-4000-8000-0000256800c2', pg_temp.paris('2027-04-12 09:00'), pg_temp.paris('2027-04-12 13:00')),
  '', '9 Ada books inside the window');
select is(pg_temp.book(pg_temp.ada(), 'office_id', '00000000-0000-4000-8000-0000256800c2', pg_temp.paris('2027-08-31 14:00'), pg_temp.paris('2027-08-31 18:00')),
  '', '10 the last day is bookable');
select is(pg_temp.book(pg_temp.ada(), 'office_id', '00000000-0000-4000-8000-0000256800c2', pg_temp.paris('2027-09-01 09:00'), pg_temp.paris('2027-09-01 13:00')),
  'that room is available until 2027-08-31', '11 the day after is refused with the end date');
select is(pg_temp.book(pg_temp.ada(), 'office_id', '00000000-0000-4000-8000-0000256800c2', pg_temp.paris('2027-08-31 22:00'), pg_temp.paris('2027-09-01 02:00')),
  'that room is available until 2027-08-31', '12 a booking running past midnight into the 1st is refused');
select is(pg_temp.book(pg_temp.ada(), 'office_id', '00000000-0000-4000-8000-0000256800c2', pg_temp.paris('2027-02-28 09:00'), pg_temp.paris('2027-02-28 13:00')),
  'that room is available from 2027-03-01', '13 the day before the start is refused with the start date');
select is(pg_temp.book(pg_temp.ada(), 'seat_id', '00000000-0000-4000-8000-0000256800f3', pg_temp.paris('2027-09-02 09:00'), pg_temp.paris('2027-09-02 13:00')),
  'that room is available until 2027-08-31', '14 a seat of the room follows the room');
select is(pg_temp.book(pg_temp.bruno(), 'office_id', '00000000-0000-4000-8000-0000256800c2', pg_temp.paris('2027-04-13 09:00'), pg_temp.paris('2027-04-13 13:00')),
  'that room is not open to you', '15 Bruno is refused by id');
select is(pg_temp.book((select id from public.members where user_id = pg_temp.u(4) and workspace_id = current_setting('t.a')::uuid),
  'office_id', '00000000-0000-4000-8000-0000256800c2', pg_temp.paris('2027-04-14 09:00'), pg_temp.paris('2027-04-14 13:00')),
  '', '16 Carol, named in the audience, books');
select is(pg_temp.book(pg_temp.ada(), 'level_id', '00000000-0000-4000-8000-0000256800b2', pg_temp.paris('2027-04-15 09:00'), pg_temp.paris('2027-04-15 13:00')),
  'a rented room is booked room by room, not as a whole level', '17 an external level is not booked as a whole');
select is(pg_temp.book(pg_temp.bruno(), 'office_id', '00000000-0000-4000-8000-0000256800c1', pg_temp.paris('2027-04-13 09:00'), pg_temp.paris('2027-04-13 13:00')),
  '', '18 an own room is unchanged for Bruno');
select is((select count(*)::int from public.reservations where workspace_id = current_setting('t.a')::uuid), 4, '18b readback: Ada twice, Carol once, Bruno on the own room; no refusal left a row');

-- who sees the room
select pg_temp.act_as(pg_temp.u(3));
select is((select count(*)::int from public.offices where id = '00000000-0000-4000-8000-0000256800c2'), 0, '19 Bruno does not see the rented room');
select is((select count(*)::int from public.seats where id = '00000000-0000-4000-8000-0000256800f3'), 0, '20 nor its seat');
select is((select count(*)::int from public.levels where id = '00000000-0000-4000-8000-0000256800b2'), 0, '21 nor its level');
select is((select count(*)::int from public.room_rentals), 0, '22 nor any rental, cost or lessor');
reset role;
select pg_temp.act_as(pg_temp.u(2));
select is((select count(*)::int from public.offices where id = '00000000-0000-4000-8000-0000256800c2'), 1, '23 Ada sees the room');
select is((select count(*)::int from public.levels where id = '00000000-0000-4000-8000-0000256800b2'), 1, '24 and its level');
select is((select count(*)::int from public.room_rentals), 0, '25 but not the rental behind it');
reset role;

-- what Ada is shown, never the cost
select is(pg_temp.as_json(pg_temp.u(2), format('select public.room_offer_v1(%L, %L)', current_setting('t.a'), '00000000-0000-4000-8000-0000256800c2'))->'fees',
  '[{"unit": "half_day", "fee_cents": 1500}]'::jsonb, '26 Ada is offered 15.00 per half day');
select is(pg_temp.as_json(pg_temp.u(2), format('select public.room_offer_v1(%L, %L)', current_setting('t.a'), '00000000-0000-4000-8000-0000256800c2')) ?| array['cost_cents', 'supplier_id', 'supplier_name', 'document_id'],
  false, '27 the offer never carries the cost, the lessor or the contract');
select is(pg_temp.as_json(pg_temp.u(4), format('select public.room_offer_v1(%L, %L)', current_setting('t.a'), '00000000-0000-4000-8000-0000256800c2'))->'fees',
  '[{"unit": "half_day", "fee_cents": 1000}]'::jsonb, '28 Carol has her own fee');

-- plan changes mid-series
update public.members set plan_id = null where id = pg_temp.ada();
select is(pg_temp.book(pg_temp.ada(), 'office_id', '00000000-0000-4000-8000-0000256800c2', pg_temp.paris('2027-05-03 09:00'), pg_temp.paris('2027-05-03 13:00')),
  'that room is not open to you', '29 once Ada leaves the plan, a later occurrence is refused');

-- another country
select alike(pg_temp.as_json(pg_temp.u(1), format('select public.set_level_kind_v1(%L, %L, ''external'')', current_setting('t.a'), '00000000-0000-4000-8000-0000256800b3'))::text, '%"kind": "external"%', '30a the Berlin level can be external');
select alike(pg_temp.save('draft', 0, '00000000-0000-4000-8000-0000256800c3')->>'error', '%another country%', '30 a room in another country is refused');

-- the screen's lists (0497)
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format('select public.room_rentals_v1(%L)', current_setting('t.a')))->'levels'), 3,
  '31 the owner reads every level with its kind');
select is((select jsonb_agg(r->>'name' order by r->>'name') from jsonb_array_elements(pg_temp.as_json(pg_temp.u(1), format('select public.room_rentals_v1(%L)', current_setting('t.a')))->'rooms') r),
  '["Berlin room", "Rented room"]'::jsonb, '32 the rooms are those of the external levels only');

-- open to every member (0498)
select is(pg_temp.as_json(pg_temp.u(1), format(
  'select public.save_room_rental_v1(%L, %L, %L, ''2027-03-01'', ''2027-08-31'', ''fixed_per_period'', 40000, ''month'', ''active'', null, %s, true)',
  current_setting('t.a'), '00000000-0000-4000-8000-0000256800c2', '00000000-0000-4000-8000-0000256800a1',
  (select revision from public.room_rentals where office_id = '00000000-0000-4000-8000-0000256800c2')))->>'audience_all',
  'true', '33 the owner opens the room to every member');
select is(pg_temp.book(pg_temp.bruno(), 'office_id', '00000000-0000-4000-8000-0000256800c2', pg_temp.paris('2027-04-20 09:00'), pg_temp.paris('2027-04-20 13:00')),
  '', '34 Bruno, in no named entry, now books');

select * from finish();
rollback;
