-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2660 / 0471 (remaining scope of #2631): rooms and parking travel with the
-- plan; only a seat uses the seat quota.
-- Expected values are written by hand: a source space "dev" with a seat S1, a
-- room R1 (8 people, one-hour slot) and a parking P with a standard slot P1
-- and an EV slot P2 (charger "Borne 1", type2, 22 kW, fee accessory "Charge"
-- of 5.00); the target space "prod" starts with the accessory only.
--   A the roundtrip   B a repeated transfer   C an old document
--   D refusals and a readback   E the seat quota   F authority
-- NOT RUN here: the same ids in two installations (one database holds one
-- id once; targets are always resolved by name).
begin;
select plan(36);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return '';
exception when others then
  return sqlerrm;
end;
$$;
create function pg_temp.merge_err(p_tree jsonb) returns text language plpgsql as $$
begin
  perform public.merge_floor_plan(current_setting('t.b')::uuid, p_tree);
  return '';
exception when others then
  return sqlerrm;
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002660a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-2660@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000002660a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'stranger-2660@deskilo.test', '', now(), now(), now());
select pg_temp.act_as('00000000-0000-4000-8000-0000002660a1');
select set_config('t.a', public.create_workspace('Plan', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.b', public.create_workspace('Plan', 'FR', 'EUR', 'Europe/Paris', 'prod', false, null)::text, true);
reset role;
update public.workspaces set pair_id = '00000000-0000-4000-8000-0000002660f1'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"meetingRooms": true, "parking": true, "accessorySupplements": true}',
       booking_rules = '{"granularity":"half_day"}'::jsonb
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
insert into public.accessories (id, workspace_id, name, supplement_cents) values
 ('00000000-0000-4000-8000-0000002660d1', current_setting('t.a')::uuid, 'Charge', 500),
 ('00000000-0000-4000-8000-0000002660d2', current_setting('t.b')::uuid, 'Charge', 500);

-- the source plan
insert into public.levels (id, workspace_id, name) values ('00000000-0000-4000-8000-0000002660b1', current_setting('t.a')::uuid, 'L');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h, area_kind) values
 ('00000000-0000-4000-8000-0000002660b2', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000002660b1', 'O', 0, 0, 10, 10, 'workspace'),
 ('00000000-0000-4000-8000-0000002660b3', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000002660b1', 'P', 20, 0, 10, 10, 'parking');
insert into public.desks (id, workspace_id, office_id, name, x, y, w, h) values
 ('00000000-0000-4000-8000-0000002660b4', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000002660b2', 'D', 1, 1, 4, 2),
 ('00000000-0000-4000-8000-0000002660b5', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000002660b3', 'Slots', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, name, x, y, resource_kind, capacity, parking_kind) values
 ('00000000-0000-4000-8000-0000002660c1', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000002660b4', 'S1', 1, 1, 'seat', null, null),
 ('00000000-0000-4000-8000-0000002660c2', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000002660b4', 'R1', 8, 1, 'room', 8, null),
 ('00000000-0000-4000-8000-0000002660c3', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000002660b5', 'P1', 1, 1, 'parking', null, 'standard'),
 ('00000000-0000-4000-8000-0000002660c4', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000002660b5', 'P2', 8, 1, 'parking', null, 'ev');
insert into public.charging_stations (workspace_id, seat_id, name, connector, power_kw, accessory_id, active)
  values (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000002660c4', 'Borne 1', 'type2', 22, '00000000-0000-4000-8000-0000002660d1', true);

select set_config('t.tree', public.export_floor_plan(current_setting('t.a')::uuid)::text, true);

-- ── A: the roundtrip ───────────────────────────────────────────────────
select is(current_setting('t.tree')::jsonb #>> '{0,offices,1,area_kind}', 'parking', 'A: the export names the area kind');
select is(current_setting('t.tree')::jsonb #>> '{0,offices,1,desks,0,seats,1,station,connector}', 'type2', 'A: and the charger of the EV slot');
select is(current_setting('t.tree')::jsonb #>> '{0,offices,1,desks,0,seats,1,station,accessory}', 'Charge', 'A: with its fee accessory by name, not by id');
select is(current_setting('t.tree')::jsonb #>> '{0,offices,0,desks,0,seats,0,station}', null, 'A: a seat has no station');

select public.merge_floor_plan(current_setting('t.b')::uuid, current_setting('t.tree')::jsonb);
select is(public.export_floor_plan(current_setting('t.b')::uuid), current_setting('t.tree')::jsonb,
  'A: the target reads back exactly what the source exported');
select is((select concat_ws('/', s.resource_kind, s.capacity, s.slot_minutes) from public.seats s
            where s.workspace_id = current_setting('t.b')::uuid and s.name = 'R1'), 'room/8/60',
  'A: the room keeps its kind, capacity and one-hour slot');
select is((select concat_ws('/', s.resource_kind, s.parking_kind, s.slot_minutes) from public.seats s
            where s.workspace_id = current_setting('t.b')::uuid and s.name = 'P2'), 'parking/ev/1440',
  'A: the EV slot keeps its kind and day slot');
select is((select concat_ws('/', c.name, c.connector, c.power_kw, c.active, (c.accessory_id = '00000000-0000-4000-8000-0000002660d2')::text)
             from public.charging_stations c where c.workspace_id = current_setting('t.b')::uuid), 'Borne 1/type2/22.0/t/true',
  'A: the charger points at the TARGET''s accessory, never the source''s');
select is((select count(*)::int from public.charging_stations c where c.seat_id in (select id from public.seats where workspace_id = current_setting('t.b')::uuid)
              and c.accessory_id = '00000000-0000-4000-8000-0000002660d1'), 0,
  'A: nothing in the target refers to a source row');
select is((select area_kind from public.offices where workspace_id = current_setting('t.b')::uuid and name = 'P'), 'parking',
  'A: the parking area stays a parking area');

-- ── B: a repeated transfer ─────────────────────────────────────────────
select public.merge_floor_plan(current_setting('t.b')::uuid, current_setting('t.tree')::jsonb);
select is((select count(*)::int from public.seats where workspace_id = current_setting('t.b')::uuid), 4, 'B: no second slot');
select is((select count(*)::int from public.charging_stations where workspace_id = current_setting('t.b')::uuid), 1, 'B: no second charger');
select is((select count(*)::int from public.seat_accessories where workspace_id = current_setting('t.b')::uuid), 1, 'B: and the fee is attached once');
select is(public.export_floor_plan(current_setting('t.b')::uuid), current_setting('t.tree')::jsonb, 'B: the plan is unchanged');

-- ── C: an old seat-only document ───────────────────────────────────────
select public.merge_floor_plan(current_setting('t.b')::uuid, jsonb_build_array(jsonb_build_object(
  'name', 'L', 'offices', jsonb_build_array(jsonb_build_object('name', 'O', 'x', 0, 'y', 0, 'w', 10, 'h', 10,
    'desks', jsonb_build_array(jsonb_build_object('name', 'D', 'x', 1, 'y', 1, 'w', 4, 'h', 2,
      'seats', jsonb_build_array(jsonb_build_object('name', 'R1', 'x', 8, 'y', 1, 'orientation', 'n')))))))));
select is((select concat_ws('/', s.resource_kind, s.capacity, s.slot_minutes) from public.seats s
            where s.workspace_id = current_setting('t.b')::uuid and s.name = 'R1'), 'room/8/60',
  'C: a document without the new keys leaves a room a room, with its capacity and slot');
select is((select count(*)::int from public.seats where workspace_id = current_setting('t.b')::uuid and name = 'S1' and resource_kind = 'seat'), 1,
  'C: and an old seat is a seat');

-- ── D: refusals, then a readback ───────────────────────────────────────
create function pg_temp.seat_doc(p_office text, p_area text, p_seat jsonb) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('name', 'L', 'offices', jsonb_build_array(
    jsonb_build_object('name', p_office, 'area_kind', p_area, 'x', 0, 'y', 0, 'w', 10, 'h', 10,
      'desks', jsonb_build_array(jsonb_build_object('name', 'D2', 'x', 1, 'y', 1, 'w', 4, 'h', 2,
        'seats', jsonb_build_array(p_seat)))))));
$$;
select ok(pg_temp.merge_err(pg_temp.seat_doc('O', 'workspace',
    jsonb_build_object('name', 'X', 'x', 3, 'y', 3, 'resource_kind', 'boat'))) like '%unknown resource kind%',
  'D: an unknown kind is refused');
select ok(pg_temp.merge_err(jsonb_build_array(jsonb_build_object('name', 'L', 'offices', jsonb_build_array(
    jsonb_build_object('name', 'O', 'x', 0, 'y', 0, 'w', 10, 'h', 10, 'desks', jsonb_build_array(
      jsonb_build_object('name', 'D', 'x', 1, 'y', 1, 'w', 4, 'h', 2, 'seats', jsonb_build_array(
        jsonb_build_object('name', 'S1', 'x', 1, 'y', 1, 'resource_kind', 'room', 'capacity', 4))))))))) like '%cannot become%',
  'D: a seat is not turned into a room');
select ok(pg_temp.merge_err(jsonb_build_array(jsonb_build_object('name', 'L', 'offices', jsonb_build_array(
    jsonb_build_object('name', 'P', 'area_kind', 'workspace', 'x', 20, 'y', 0, 'w', 10, 'h', 10))))) like '%cannot become%',
  'D: a parking area is not turned into a workspace');
select ok(pg_temp.merge_err(jsonb_build_array(jsonb_build_object('name', 'L', 'offices', jsonb_build_array(
    jsonb_build_object('name', 'P', 'area_kind', 'parking', 'x', 20, 'y', 0, 'w', 10, 'h', 10, 'desks', jsonb_build_array(
      jsonb_build_object('name', 'Slots', 'x', 1, 'y', 1, 'w', 4, 'h', 2, 'seats', jsonb_build_array(
        jsonb_build_object('name', 'P2', 'x', 8, 'y', 1, 'resource_kind', 'parking', 'parking_kind', 'ev',
          'station', jsonb_build_object('name', 'B', 'connector', 'type2', 'power_kw', 7, 'accessory', 'Nope'))))))))))
    like '%does not have%', 'D: a charger naming an accessory the target lacks is refused');
select ok(pg_temp.merge_err(jsonb_build_array(jsonb_build_object('name', 'L', 'offices', jsonb_build_array(
    jsonb_build_object('name', 'P', 'area_kind', 'parking', 'x', 20, 'y', 0, 'w', 10, 'h', 10, 'desks', jsonb_build_array(
      jsonb_build_object('name', 'Slots', 'x', 1, 'y', 1, 'w', 4, 'h', 2, 'seats', jsonb_build_array(
        jsonb_build_object('name', 'P1', 'x', 1, 'y', 1, 'resource_kind', 'parking', 'parking_kind', 'standard',
          'station', jsonb_build_object('name', 'B', 'connector', 'type2', 'power_kw', 7))))))))))
    like '%EV%', 'D: a charger on a standard slot is refused');
update public.workspaces set feature_flags = feature_flags || '{"parking": false}' where id = current_setting('t.b')::uuid;
select ok(pg_temp.merge_err(jsonb_build_array(jsonb_build_object('name', 'L2', 'offices', jsonb_build_array(
    jsonb_build_object('name', 'P', 'area_kind', 'parking', 'x', 20, 'y', 0, 'w', 10, 'h', 10))))) like '%feature is off%',
  'D: a parking area where the parking feature is off is refused, not turned into something else');
update public.workspaces set feature_flags = feature_flags || '{"parking": true}' where id = current_setting('t.b')::uuid;
select is(public.export_floor_plan(current_setting('t.b')::uuid) -> 0, current_setting('t.tree')::jsonb -> 0,
  'D: readback: after the refusals the first level is unchanged');
select is((select count(*)::int from public.levels where workspace_id = current_setting('t.b')::uuid), 1, 'D: and no half level was left behind');

-- ── E: the seat quota ──────────────────────────────────────────────────
select set_config('t.day', (date_trunc('week', now() + interval '14 days') + interval '2 days')::text, true);
select set_config('t.period', to_char(current_setting('t.day')::timestamp, 'YYYY-MM'), true);
select set_config('t.m', (select m.id::text from public.members m where m.workspace_id = current_setting('t.b')::uuid and m.is_owner), true);
insert into public.reservations (id, workspace_id, member_id, seat_id, starts_at, ends_at) values
 ('00000000-0000-4000-8000-0000002660e1', current_setting('t.b')::uuid, current_setting('t.m')::uuid,
  (select id from public.seats where workspace_id = current_setting('t.b')::uuid and name = 'S1'),
  (current_setting('t.day')::timestamp + interval '8 hours') at time zone 'Europe/Paris',
  (current_setting('t.day')::timestamp + interval '12 hours') at time zone 'Europe/Paris'),
 ('00000000-0000-4000-8000-0000002660e2', current_setting('t.b')::uuid, current_setting('t.m')::uuid,
  (select id from public.seats where workspace_id = current_setting('t.b')::uuid and name = 'R1'),
  (current_setting('t.day')::timestamp + interval '10 hours') at time zone 'Europe/Paris',
  (current_setting('t.day')::timestamp + interval '11 hours') at time zone 'Europe/Paris'),
 ('00000000-0000-4000-8000-0000002660e3', current_setting('t.b')::uuid, current_setting('t.m')::uuid,
  (select id from public.seats where workspace_id = current_setting('t.b')::uuid and name = 'P2'),
  (current_setting('t.day')::timestamp + interval '8 hours') at time zone 'Europe/Paris',
  (current_setting('t.day')::timestamp + interval '17 hours') at time zone 'Europe/Paris');
select is((public.member_statement(current_setting('t.m')::uuid, current_setting('t.period'))->>'used_half_days')::int, 1,
  'E: a seat morning, a room hour and a parking day use exactly one half-day of the seat allowance');
select is(public.member_quota_shortfall(current_setting('t.m')::uuid, (current_setting('t.day')::timestamp + interval '9 hours') at time zone 'Europe/Paris'),
  greatest(0, 1 - (public.member_statement(current_setting('t.m')::uuid, current_setting('t.period'))->>'included_half_days')::int),
  'E: and the quota check reads the same single half-day');
select is((public.member_statement(current_setting('t.m')::uuid, current_setting('t.period'))->>'accessory_supplement_cents')::int, 500,
  'E: the charger fee still rides the parking day, once (5.00), by the existing accessory path');
update public.reservations set status = 'cancelled' where id = '00000000-0000-4000-8000-0000002660e1';
select is((public.member_statement(current_setting('t.m')::uuid, current_setting('t.period'))->>'used_half_days')::int, 0,
  'E: without the seat the room hour and the parking day use no seat half-day');
select is((public.member_statement(current_setting('t.m')::uuid, current_setting('t.period'))->>'accessory_supplement_cents')::int, 500,
  'E: and cancelling the seat leaves the parking fee as it was');

-- ── F: authority ───────────────────────────────────────────────────────
select ok(not has_function_privilege('authenticated', 'public.merge_floor_plan(uuid, jsonb)', 'execute'),
  'F: the merge is not callable by a signed-in person');
select pg_temp.act_as('00000000-0000-4000-8000-0000002660a2');
select ok(pg_temp.err(format('select public.deploy_entities(%L, %L, array[''floor_plan''])', current_setting('t.a'), current_setting('t.b'))) <> '',
  'F: a stranger cannot deploy the plan');
reset role;
select is((select count(*)::int from public.seats where workspace_id = current_setting('t.b')::uuid), 4, 'F: and nothing was changed');

-- the real path: the owner of both spaces deploys, a prod-side readback follows
delete from public.charging_stations where workspace_id = current_setting('t.b')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000002660a1');
select set_config('t.dep', public.deploy_entities(current_setting('t.a')::uuid, current_setting('t.b')::uuid, array['floor_plan'])::text, true);
reset role;
select ok(current_setting('t.dep')::jsonb ? 'id', 'F: the owner deploys the plan');
select is((select count(*)::int from public.charging_stations where workspace_id = current_setting('t.b')::uuid), 1,
  'F: and the deployment brings the charger back');
select is((select c.name from public.charging_stations c where c.workspace_id = current_setting('t.b')::uuid), 'Borne 1',
  'F: with its name');
select is((select count(*)::int from public.reservations where workspace_id = current_setting('t.b')::uuid and status <> 'cancelled'), 2,
  'F: and no booking was rewritten');

select * from finish();
rollback;
